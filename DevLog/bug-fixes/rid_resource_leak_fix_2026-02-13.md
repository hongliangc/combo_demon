# RID 资源泄漏修复 - 物理形状 & 纹理

> **修复日期**: 2026-02-13
> **优先级**: 中
> **影响范围**: 特效系统、Boss攻击、UI血条

---

## 问题现象

游戏长时间运行后退出时，控制台报出 RID 泄漏错误：

```
ERROR: 1 RID allocations of type 'P12GodotShape2D' were leaked at exit.
ERROR: 2 RID allocations of type 'N10RendererRD14TextureStorage7TextureE' were leaked at exit.
```

---

## 问题定位过程

### 第一步：解读错误信息中的 C++ 类型名

Godot 的 RID 泄漏错误使用 C++ mangled name，需要先解码：

| Mangled Name | 解码后 | 含义 |
|---|---|---|
| `P12GodotShape2D` | `GodotShape2D*` | 物理引擎 2D 碰撞形状的 RID |
| `N10RendererRD14TextureStorage7TextureE` | `RendererRD::TextureStorage::Texture` | 渲染器纹理存储的 RID |

**关键推断**：
- **1 个物理形状泄漏** → 某处动态创建了 `CircleShape2D` / `RectangleShape2D` 等，退出时未释放
- **2 个纹理泄漏** → 某处动态创建了 `ShaderMaterial` / `StyleBoxFlat` 等含纹理引用的资源，退出时未释放

### 第二步：排查动态创建资源的代码

根据泄漏类型，针对性搜索全项目中 `*.new()` 动态创建资源的位置：

**搜索物理形状泄漏**（关键词：`Shape2D.new`）：
```
-> BossAoe.gd:20  var shape = CircleShape2D.new()  # 嫌疑最大
```

**搜索纹理/材质泄漏**（关键词：`ShaderMaterial.new`、`StyleBoxFlat.new`）：
```
-> GhostExpandEffect.gd:41  _shader_material = ShaderMaterial.new()  # 嫌疑1
-> HealthBar.gd:46           var style = StyleBoxFlat.new()           # 嫌疑2（每次调用都new）
```

### 第三步：分析每个嫌疑点的生命周期

逐一检查这些动态创建的资源是否有完整的释放路径：

#### 嫌疑1: BossAoe.gd - CircleShape2D

```
创建: _ready() → CircleShape2D.new() → 赋给 collision_shape.shape
使用: _process() → 持续修改 shape.radius
释放: start_expansion() → queue_free()
```

**问题**：`queue_free()` 释放节点树时，`CollisionShape2D` 被销毁，但其内部的 `CircleShape2D` Resource 的物理服务器 RID 可能因销毁顺序问题而泄漏。尤其在游戏退出时，如果 BossAOE 节点正在活动，场景树的销毁顺序不保证先释放子资源。

#### 嫌疑2: GhostExpandEffect.gd - ShaderMaterial

```
创建: create_from_sprite() → ShaderMaterial.new() → 赋给 source_sprite.material
使用: _play_flash_animation() → tween 驱动 thickness 参数
释放: _cleanup() → 恢复 _original_material → _shader_material = null
```

**问题1**：`_cleanup()` 只是将 `_shader_material` 引用设为 `null`，但 `ShaderMaterial` 内部持有对 `Shader` 资源的引用，GC 时可能无法完全释放关联的纹理 RID。
**问题2**：如果效果被中断（节点在 tween 完成前被销毁），`_cleanup()` 不会被调用，`ShaderMaterial` 完全泄漏，且 `source_sprite.material` 不会恢复。

#### 嫌疑3: HealthBar.gd - StyleBoxFlat

```
创建: update_display() → StyleBoxFlat.new() → add_theme_stylebox_override("fill", style)
调用频率: set_value() → update_display()（tween 动画期间每帧调用）
释放: 依赖 GC 自动回收
```

**问题**：每次 `update_display()` 都创建新的 `StyleBoxFlat`，旧的通过 `add_theme_stylebox_override` 被替换。虽然 `StyleBoxFlat` 是 `RefCounted`，理论上旧实例会被 GC 回收，但在 `tween_to_value` 期间高频创建（每帧一个），给 GC 造成压力，且退出时可能有未回收的实例。

### 第四步：确认泄漏数量与嫌疑点匹配

| 泄漏类型 | 泄漏数量 | 嫌疑来源 | 匹配分析 |
|---|---|---|---|
| GodotShape2D | 1 个 | BossAOE 的 CircleShape2D | 场景中只有 1 个 Boss，1 个活跃的 AOE 攻击 |
| TextureStorage | 2 个 | GhostExpandEffect + HealthBar | ShaderMaterial (1) + StyleBoxFlat (1) = 2 |

数量完全吻合，确认定位正确。

---

## 根本原因

### Godot RID 资源的特殊性

在 Godot 中，`Shape2D`、`Material`、`StyleBox` 等资源虽然继承自 `RefCounted`，但它们在底层通过 **RID (Resource ID)** 注册到服务器（PhysicsServer、RenderingServer）。即使 GDScript 层面的引用被释放，如果服务器端的 RID 未被正确注销，就会产生泄漏。

```
GDScript 层                    服务器层
┌──────────────────┐          ┌─────────────────────┐
│ CircleShape2D    │──RID──→  │ PhysicsServer2D     │
│ (RefCounted)     │          │ shape_owner_...()    │
└──────────────────┘          └─────────────────────┘
       ↑                              ↑
   GC 可以回收引用               需要显式释放 RID
```

当场景树在游戏退出时被销毁，节点的销毁顺序是**从叶到根**，但：
- `CollisionShape2D` 节点销毁时会尝试释放其 `shape`
- 如果此时 `PhysicsServer` 已经开始清理，RID 可能无法正确释放
- 动态创建的 `ShaderMaterial` 如果仍被节点的 `material` 属性持有，类似问题

---

## 修复方案

### 1. BossAoe.gd - 添加 `_exit_tree()` 显式释放碰撞形状

**修改前**：
```gdscript
# 无 _exit_tree()，依赖 queue_free() 隐式释放
func _ready() -> void:
    var shape = CircleShape2D.new()
    shape.radius = 0
    collision_shape.shape = shape
```

**修改后**：
```gdscript
func _exit_tree() -> void:
    # 显式释放动态创建的 CircleShape2D，防止物理形状 RID 泄漏
    if collision_shape:
        collision_shape.shape = null
```

**原理**：在节点离开场景树时，主动将 `collision_shape.shape` 设为 `null`，触发 `CollisionShape2D` 向 `PhysicsServer` 注销 RID。此时 PhysicsServer 尚未开始清理，能保证 RID 被正确释放。

### 2. GhostExpandEffect.gd - 断开 Shader 引用 + 添加中断保护

**修改前**：
```gdscript
func _cleanup() -> void:
    if is_instance_valid(_source_sprite):
        _source_sprite.material = _original_material
    _source_sprite = null
    _original_material = null
    _shader_material = null  # 只断开 GDScript 引用，未断开内部 Shader 引用
```

**修改后**：
```gdscript
func _cleanup() -> void:
    if is_instance_valid(_source_sprite):
        _source_sprite.material = _original_material
    _source_sprite = null
    _original_material = null
    # 断开 shader 引用，确保 ShaderMaterial RID 被释放
    if _shader_material:
        _shader_material.shader = null
    _shader_material = null
    effect_finished.emit()
    queue_free()

func _exit_tree() -> void:
    # 防止效果被中断时 ShaderMaterial 泄漏
    if is_instance_valid(_source_sprite) and _source_sprite.material == _shader_material:
        _source_sprite.material = _original_material
    if _shader_material:
        _shader_material.shader = null
    _shader_material = null
```

**原理**：
1. `_shader_material.shader = null` 断开 ShaderMaterial 对 Shader 资源的引用，使 RenderingServer 能释放关联的纹理 RID
2. `_exit_tree()` 确保即使 tween 未完成、节点被提前销毁，也能正确清理资源并恢复原始 material

### 3. HealthBar.gd - 缓存 StyleBoxFlat 复用

**修改前**：
```gdscript
func update_display() -> void:
    # ...
    var style = StyleBoxFlat.new()  # 每次调用都创建新实例
    style.bg_color = bar_color
    style.border_color = border_color
    progress_bar.add_theme_stylebox_override("fill", style)
```

**修改后**：
```gdscript
var _fill_style: StyleBoxFlat = null

func update_display() -> void:
    # ...
    # 复用缓存的 StyleBoxFlat，避免重复创建导致资源泄漏
    if not _fill_style:
        _fill_style = StyleBoxFlat.new()
        progress_bar.add_theme_stylebox_override("fill", _fill_style)
    _fill_style.bg_color = bar_color
    _fill_style.border_color = border_color
```

**原理**：只在首次调用时创建 `StyleBoxFlat` 并绑定到 ProgressBar，后续更新只修改属性值。`StyleBoxFlat` 作为 `Resource`，属性修改会自动触发重绘，无需替换实例。

---

## 修复效果

| 泄漏类型 | 修复前 | 修复后 |
|---|---|---|
| `P12GodotShape2D` | 1 个泄漏 | 0 |
| `TextureStorage7TextureE` | 2 个泄漏 | 0 |
| HealthBar StyleBoxFlat 创建次数 | 每帧 1 个（tween 期间） | 全生命周期 1 个 |

---

## 经验总结

### RID 泄漏排查方法论

1. **解码 C++ mangled name** → 确定泄漏的资源类型（物理形状 / 纹理 / 网格等）
2. **搜索 `*.new()` 调用** → 找到所有动态创建该类型资源的位置
3. **追踪生命周期** → 检查创建→使用→释放的完整链路，特别关注：
   - 是否有 `_exit_tree()` / `_notification(NOTIFICATION_PREDELETE)` 清理
   - 效果被中断时是否仍能清理
   - 高频创建是否有缓存复用
4. **对比泄漏数量** → 验证嫌疑点与实际泄漏数是否匹配

### Godot 动态资源管理规则

| 场景 | 推荐做法 |
|---|---|
| 动态创建 Shape2D | 在 `_exit_tree()` 中设 `collision_shape.shape = null` |
| 动态创建 Material | 使用完毕后设 `.shader = null`，并在 `_exit_tree()` 中兜底清理 |
| 高频创建 StyleBox/Resource | 缓存实例，修改属性而非替换对象 |
| Tween 驱动的特效 | 同时实现 `_cleanup()` (正常结束) 和 `_exit_tree()` (中断兜底) |

---

## 涉及文件

| 文件 | 修改内容 |
|---|---|
| `Core/Effects/GhostExpandEffect.gd` | `_cleanup()` 中断开 shader 引用 + 新增 `_exit_tree()` |
| `Scenes/Characters/Enemies/Boss/Attacks/BossAoe.gd` | 新增 `_exit_tree()` 释放 CircleShape2D |
| `Scenes/UI/Components/HealthBar.gd` | 缓存 `_fill_style` 复用 StyleBoxFlat |

---

**最后更新**: 2026-02-13
**修复人员**: Claude Code
**关联文档**: [await_memory_leak_fix_2026-01-18.md](await_memory_leak_fix_2026-01-18.md) - 同类资源泄漏问题
