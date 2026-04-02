# 重构指南 — Combo Demon

重构、优化、架构调整的模式库。每个模式包含：触发条件、步骤、验证方法、注意事项。

---

## 1. God Object 拆分

### 触发条件
- 单文件超过 300 行
- 一个类承担 3+ 个不相关职责
- 已知案例: SkillManager (~460行), BaseState (~459行)

### 拆分步骤
1. **职责分析**: 列出类中所有方法，按职责分组
2. **依赖图**: 找出组间依赖（哪些方法互相调用）
3. **切割点**: 选择依赖最少的组作为第一个提取目标
4. **提取**: 创建新类，移动方法和相关属性
5. **委托**: 原类通过组合持有新类引用，转发调用
6. **信号迁移**: 如果提取的方法涉及信号，在新类中重新连接

### 验证
- 所有原有功能可正常运行
- 新类可独立测试
- 原类行数显著减少

### 示例: BaseState 拆分思路
```
BaseState (459行) → 拆分为:
  BaseState (~200行): 生命周期 + 状态转换 + 优先级
  AnimationHelper (~150行): set_locomotion, enter_control_state, fire_attack, time_scale
  MovementHelper (~100行): move_toward_target, move_away_from_target, get_distance_to_target
```

---

## 2. 信号解耦

### 触发条件
- 组件直接调用另一个组件的方法（非通过信号）
- 子类直接引用兄弟节点（如 State 直接引用 AttackComponent）
- 修改一个组件需要同时修改另一个不相关组件

### 步骤
1. **识别耦合**: 搜索直接方法调用 `$SiblingNode.method()`
2. **定义信号**: 在调用方定义信号，携带必要参数
3. **连接**: 在父节点的 `_ready()` 中连接信号
4. **替换**: 将直接调用改为 `signal.emit(params)`

### Godot 信号模式
```gdscript
# BAD: 直接耦合
func perform_attack():
    $"../AttackComponent".fire(damage)

# GOOD: 信号解耦
signal attack_requested(damage: Damage)

func perform_attack():
    attack_requested.emit(damage)

# 在父节点连接
func _ready():
    state_machine.attack_requested.connect(attack_component.fire)
```

### 注意
- 不要过度解耦：同一组件内部的方法调用不需要信号
- 编辑器中能看到的信号连接优于代码中的 `.connect()`

---

## 3. Resource 迁移（硬编码 → .tres）

### 触发条件
- 攻击参数直接写在代码中（数值、攻击池列表）
- Boss 阶段配置散落在多个方法中
- 修改数值需要改代码而不是改资源文件

### 步骤
1. **识别硬编码值**: 搜索魔法数字和内联配置
2. **设计 Resource 类**: 创建 `extends Resource` 脚本，用 @export 暴露属性
3. **创建 .tres 文件**: 在 `Resources/` 子目录中创建实例
4. **注入**: 在角色/状态中用 `@export var config: MyResource` 引用
5. **替换**: 将硬编码值改为从 Resource 读取

### 目录规范
```
Scenes/Characters/Bosses/{BossName}/Resources/  — Boss 专用资源
Scenes/Characters/Enemies/{EnemyName}/Resources/ — Enemy 专用资源
Core/Data/ — 通用数据资源
```

### 示例: Boss 攻击池迁移
```gdscript
# BEFORE: 硬编码在 BossAttack.gd
var phase_1_attacks = ["projectile", "aoe", "laser"]
var phase_1_cooldown = 1.5

# AFTER: BossPhaseConfig Resource
# res://Scenes/Characters/Bosses/Cyclops/Resources/Phase1Config.tres
@export var attacks: Array[String] = ["projectile", "aoe", "laser"]
@export var cooldown: float = 1.5
@export var speed_multiplier: float = 1.0
```

---

## 4. 命名规范化

### 触发条件
- 变量名与实际语义不匹配（如 `follow_radius` 实际是攻击激活半径）
- 同一概念在不同文件中用不同名称
- 字符串状态名散落各处

### 步骤
1. **建立映射表**: 旧名 → 新名 → 原因
2. **全局搜索**: `grep -r "old_name"` 找所有引用
3. **批量替换**: 代码中的变量/方法名
4. **更新 .tscn**: 场景文件中的 @export 值
5. **更新 .tres**: 资源文件中的属性引用

### 已知命名问题
| 当前名 | 建议改名 | 原因 |
|--------|---------|------|
| `follow_radius` | `attack_activation_radius` | 实际含义是攻击触发距离，不是跟随 |
| `chase_radius` | `chase_abandon_distance` | 实际含义是放弃追击的距离，不是追击范围 |

### 注意
- 修改 @export 变量名会导致 .tscn 中的旧值丢失，需逐个场景检查
- 使用 `StateNames` 常量类代替字符串状态名
- 一次只改一个命名，验证后再改下一个

---

## 5. 状态机重构

### 触发条件
- 自定义状态与 CommonState 高度重复
- 状态间转换逻辑复杂难以追踪
- 新增状态需要修改多个现有状态

### 步骤
1. **画状态流转图**: 列出所有状态和转换条件
2. **识别重复**: 对比自定义状态和 CommonState 的差异
3. **提取差异**: 只保留真正不同的逻辑，其余复用 CommonState
4. **用钩子方法**: 在 CommonState 中提供钩子（`on_custom_attack()`），子类只重写钩子

### 模式: 从自定义状态迁移到 CommonState + 钩子
```gdscript
# BEFORE: 完全自定义的 BearAttackState
class_name BearAttackState extends BaseState
func enter():
    # 50 行重复 AttackState 的逻辑
    # + 5 行 Bear 特有逻辑

# AFTER: 复用 CommonState + 钩子
class_name BearAttackState extends AttackState
func on_custom_attack():
    # 只有 Bear 特有的 5 行逻辑
```

---

## 6. 场景结构优化

### 触发条件
- 场景节点树深度超过 5 层
- 多个场景有大量重复节点结构
- 修改模板需要逐个更新每个场景

### 步骤
1. **提取为子场景**: 重复的节点子树 → 独立 .tscn
2. **使用 Inherited Scene**: 变体场景继承基础场景
3. **@export 暴露差异**: 子场景的差异点用 @export 配置

### 模板场景使用
```
Scenes/Characters/Templates/EnemyBase.tscn  → 所有 Enemy 继承
Scenes/Characters/Templates/BossBase.tscn   → 所有 Boss 继承
```

---

## 7. 性能优化

### 常见优化点
| 问题 | 优化方法 |
|------|---------|
| `get_tree().get_nodes_in_group()` 每帧调用 | 缓存结果，监听 group 变化信号 |
| `get_node()` 在 `_process` 中 | `@onready` 缓存引用 |
| 大量 `is_instance_valid()` 检查 | 用信号在对象销毁时通知，而非每帧检查 |
| 频繁创建/销毁 Node（子弹、特效） | 对象池模式 |
| AnimationTree 参数路径字符串每帧拼接 | 缓存 StringName |

### 对象池模式
```gdscript
# Pool 基本结构
var _pool: Array[Node] = []

func get_instance() -> Node:
    if _pool.is_empty():
        return _template.instantiate()
    return _pool.pop_back()

func return_instance(instance: Node) -> void:
    instance.visible = false
    _pool.append(instance)
```

---

## 通用重构检查清单

- [ ] 影响范围分析完成（列出所有受影响文件）
- [ ] 分步实施（每步可独立验证）
- [ ] 所有引用点已更新（grep 确认无遗留旧引用）
- [ ] .tscn 场景文件中的节点引用/export 值正确
- [ ] .tres 资源文件无断裂引用
- [ ] GUT 测试通过
- [ ] MCP 运行游戏无回归
- [ ] 架构文档已更新（如改变了类结构或数据流）
