## 2025.12.13

### 统一伤害系统重构

#### 重构目标

统一玩家和敌人的伤害管理系统，让所有 Hitbox 都使用相同的 `Damage` 类，支持通过编辑器 export 配置伤害参数。

#### 核心改进

##### 1. Damage 类新增随机伤害生成

在 [Util/Classes/Damage.gd:63-67](Util/Classes/Damage.gd#L63-L67) 添加：
```gdscript
## 随机数生成器（静态共享，避免重复创建）
static var _rng: RandomNumberGenerator = null

func randomize_damage() -> void:
    if _rng == null:
        _rng = RandomNumberGenerator.new()
        _rng.randomize()
    amount = _rng.randf_range(min_amount, max_amount)
```

**优势**：
- 将伤害计算逻辑归属于 `Damage` 类（单一职责原则）
- 使用静态 RNG，所有实例共享，避免重复创建对象
- 使用 `randf_range` 支持浮点数伤害，避免类型转换

##### 2. Hitbox 基类支持 export 配置

在 [Util/Components/hitbox.gd](Util/Components/hitbox.gd) 重构：

```gdscript
@export_group("伤害配置")
@export var damage: Damage = null           # 可配置预设 Damage 资源
@export var min_damage: float = 10.0        # 最小伤害（无资源时使用）
@export var max_damage: float = 50.0        # 最大伤害（无资源时使用）
@export_enum("Physical", "KnockUp", "KnockBack") var damage_type: String = "Physical"

func _ready() -> void:
    # 如果没有配置 damage 资源，创建默认的
    if damage == null:
        damage = Damage.new()
        damage.min_amount = min_damage
        damage.max_amount = max_damage
        damage.type = damage_type
    area_entered.connect(_on_hitbox_area_entered_)

func update_attack():
    if damage:
        damage.randomize_damage()
```

**配置方式**：
1. **简单配置**：在编辑器中直接设置 `min_damage` 和 `max_damage`
2. **高级配置**：拖入预先配置的 `.tres` Damage 资源（支持复杂特效）

##### 3. 简化所有子类代码

移除所有子弹/武器 Hitbox 中的重复代码：

**改前**（[Weapons/bullet/fire/hitbox.gd](Weapons/bullet/fire/hitbox.gd)）：
```gdscript
extends Hitbox

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
    damage.max_amount = 50
    damage.min_amount = 10
    rng.randomize()
    super._ready()

func update_attack():
    damage.amount = rng.randi_range(damage.min_amount, damage.max_amount)
```

**改后**：
```gdscript
extends Hitbox

## 火焰子弹的碰撞处理
## 在编辑器中配置 min_damage=10, max_damage=50
```

**影响的文件**：
- [Weapons/bullet/bubble/hitbox.gd](Weapons/bullet/bubble/hitbox.gd) - 移除 7 行重复代码
- [Weapons/bullet/fire/hitbox.gd](Weapons/bullet/fire/hitbox.gd) - 移除 7 行重复代码
- [Weapons/slash/claw/hitbox.gd](Weapons/slash/claw/hitbox.gd) - 移除 7 行，修复 Bug

##### 4. Bug 修复

在 [Weapons/slash/claw/hitbox.gd](Weapons/slash/claw/hitbox.gd) 修复：
```gdscript
# 错误：damage.min_amount = 5
# 正确：damage.max_amount = 5

# 错误：area.damage(damage)
# 正确：area.take_damage(damage)
```

##### 5. 玩家 Hitbox 优化

[Scenes/charaters/hitbox.gd](Scenes/charaters/hitbox.gd) 使用玩家的动态伤害：
```gdscript
func update_attack():
    # 玩家的伤害从角色节点获取，支持动态切换技能
    damage = player.current_damage
```

**特点**：
- 不使用随机伤害，而是使用玩家配置的 `damage_types` 数组
- 支持通过 `switch_to_physical()` / `switch_to_knockup()` 动态切换技能
- 自动应用玩家当前技能的所有特效

#### 使用指南

##### 在编辑器中配置（推荐）

1. 选择 Hitbox 节点
2. 在 Inspector 的"伤害配置"组设置：
   - **简单模式**：设置 `Min Damage` 和 `Max Damage`
   - **高级模式**：拖入 `.tres` Damage 资源

##### 添加攻击特效

1. 创建 Damage 资源（右键 > 新建资源 > Damage）
2. 配置 `effects` 数组，添加 `KnockUpEffect`、`KnockBackEffect` 等
3. 拖入到 Hitbox 的 `damage` 属性

##### 迁移旧代码

- 删除子类中的 `rng` 变量
- 删除 `_ready()` 中的伤害配置代码
- 删除 `update_attack()` 方法
- 在编辑器的 Inspector 中配置参数

#### 架构优势

1. ✅ **消除重复代码** - 每个子类减少 5-10 行重复逻辑
2. ✅ **单一职责** - 伤害计算归属 `Damage` 类，Hitbox 只负责碰撞检测
3. ✅ **编辑器友好** - 策划可以在编辑器中直接调整伤害，无需改代码
4. ✅ **性能优化** - 静态 RNG 避免重复创建对象
5. ✅ **统一管理** - 玩家和敌人使用相同的伤害系统
6. ✅ **易于扩展** - 通过 Damage 资源可以附加各种特效

#### 文件修改清单

**修改的核心文件**：
- [Util/Classes/Damage.gd](Util/Classes/Damage.gd) - 添加 `randomize_damage()` 方法
- [Util/Components/hitbox.gd](Util/Components/hitbox.gd) - 添加 export 配置支持

**简化的子类**：
- [Scenes/charaters/hitbox.gd](Scenes/charaters/hitbox.gd) - 使用玩家动态伤害
- [Weapons/bullet/bubble/hitbox.gd](Weapons/bullet/bubble/hitbox.gd) - 移除重复代码
- [Weapons/bullet/fire/hitbox.gd](Weapons/bullet/fire/hitbox.gd) - 移除重复代码
- [Weapons/slash/claw/hitbox.gd](Weapons/slash/claw/hitbox.gd) - 移除重复代码并修复 Bug

#### 后续建议

1. 在场景文件（.tscn）中配置 Hitbox 的 `min_damage` 和 `max_damage` 参数
2. 为敌人攻击创建 Damage 资源文件，支持更复杂的特效组合
3. 可以扩展 `damage_type` 枚举，添加更多伤害类型（冰冻、燃烧等）

---

### 击飞特效系统实现总结

#### 项目概述

在 8 方向俯视地图的 Godot 游戏中成功实现了完整的击飞特效系统，让敌人被击中时能够飞起并沿抛物线回落到原位。

#### 核心设计理念

在 8 方向俯视地图中，不使用真实的物理重力系统，而是通过**模拟垂直偏移**来实现击飞效果：
- 记录敌人的原始 Y 坐标
- 使用独立的垂直速度变量模拟抛物线运动
- 最终让敌人回到原始位置

#### 系统架构

##### 1. 伤害数据类 ([Damage.gd](Util/Classes/Damage.gd))
- 存储伤害值和伤害类型
- 包含 `effects` 数组，支持附加多种攻击特效
- 提供 `apply_effects()` 方法统一应用所有特效
- 提供 `has_effect()` 方法检查是否包含特定特效

##### 2. 攻击特效基类 ([AttackEffect.gd](Util/Classes/AttackEffect.gd))
- 所有特效的抽象基类
- 定义 `apply_effect()` 接口供子类实现
- 包含特效名称、持续时间等通用属性

##### 3. 击飞特效类 ([KnockUpEffect.gd](Util/Classes/KnockUpEffect.gd))
- 继承 `AttackEffect` 基类
- 配置击飞力度 `knockup_force` (默认 300.0)
- 可选横向力度 `horizontal_force`
- **关键设计**：不在特效中设置 `enemy.stunned`，交由状态机管理

##### 4. 敌人眩晕状态 ([enemy_stun.gd](Scenes/enemies/dinosaur/Scripts/States/enemy_stun.gd))
- 使用 `original_y` 记录原始 Y 坐标
- 使用 `vertical_offset` 模拟垂直偏移
- 使用 `vertical_velocity` 模拟垂直速度
- 模拟重力加速度 `gravity = 980.0`
- **关键设计**：分离 Y 轴位置和 velocity，避免与状态机的其他状态冲突

#### 关键问题及解决方案

##### 问题 1：击飞特效完全不生效
**原因**：`EnemyHealth.on_damaged()` 缺少 `enemy.on_damaged()` 调用，导致特效系统完全不工作
**解决**：在 [enemy_health.gd:26](Scenes/enemies/dinosaur/Scripts/enemy_health.gd#L26) 添加调用链

##### 问题 2：敌人直接掉到地图最下方
**原因**：8 方向俯视地图不应使用物理引擎的 `is_on_floor()` 检测
**解决**：重写 stun 状态，使用独立的 `vertical_offset` 模拟抛物线运动

##### 问题 3：状态机被连续触发两次
**原因**：多段攻击导致重复切换状态，第二次进入时 velocity 被清零
**解决**：在 [enemy_base_state.gd:59](Scenes/enemies/dinosaur/Scripts/States/enemy_base_state.gd#L59) 添加 `if not enemy.stunned` 检查

##### 问题 4：KnockUpEffect 设置 stunned 导致状态切换失败
**原因**：特效在状态切换之前就设置了 `stunned = true`
**解决**：移除 `KnockUpEffect` 中的 `enemy.stunned = true`，让 stun 状态的 `enter()` 方法管理

##### 问题 5：多段攻击全部命中时不击飞
**原因**：在 stun 状态中再次受到击飞伤害时，没有更新速度和重置定时器
**解决**：在 [enemy_stun.gd:73](Scenes/enemies/dinosaur/Scripts/States/enemy_stun.gd#L73) 覆盖 `on_damaged()` 方法，支持空中连击

#### 文件修改清单

**新增文件**：
- [Util/Classes/AttackEffect.gd](Util/Classes/AttackEffect.gd) - 攻击特效基类
- [Util/Classes/KnockUpEffect.gd](Util/Classes/KnockUpEffect.gd) - 击飞特效实现
- [Util/Classes/KnockBackEffect.gd](Util/Classes/KnockBackEffect.gd) - 击退特效（预留）

**修改文件**：
- [Util/Classes/Damage.gd](Util/Classes/Damage.gd) - 添加特效系统支持
- [Scenes/enemies/dinosaur/Scripts/enemy_health.gd](Scenes/enemies/dinosaur/Scripts/enemy_health.gd) - 添加关键调用链
- [Scenes/enemies/dinosaur/Scripts/enemy.gd](Scenes/enemies/dinosaur/Scripts/enemy.gd) - 特效应用逻辑
- [Scenes/enemies/dinosaur/Scripts/States/enemy_stun.gd](Scenes/enemies/dinosaur/Scripts/States/enemy_stun.gd) - 重写物理处理逻辑
- [Scenes/enemies/dinosaur/Scripts/States/enemy_base_state.gd](Scenes/enemies/dinosaur/Scripts/States/enemy_base_state.gd) - 添加状态切换保护
- [Util/Data/SkillBook/KnockUp.tres](Util/Data/SkillBook/KnockUp.tres) - 配置击飞特效

#### 关键经验总结

1. **调用链完整性至关重要**：确保伤害 → 特效 → 状态机的完整调用链，缺少任何一环都会导致功能失效
2. **状态机设计要考虑重入**：多段攻击、连续技能等场景下需要防止重复进入同一状态或正确处理状态内的更新
3. **8 方向地图的特殊性**：俯视视角的地图不能直接使用物理引擎的重力和地面检测，需要自己模拟
4. **执行顺序很重要**：`apply_effects()` 和 `damaged.emit()` 的顺序会影响状态机的行为
5. **调试输出是最好的工具**：在复杂系统中，详细的调试输出比盲目修改代码更有效

#### 扩展性设计

添加新特效的步骤：
1. 创建新的特效类继承 `AttackEffect`
2. 实现 `apply_effect()` 方法
3. 在 `.tres` 资源文件中配置特效
4. 如果需要特殊状态处理，在对应状态中覆盖 `on_damaged()`

#### 最终效果

- 单段攻击：敌人被击飞约 48 像素高度，沿抛物线回落，整个过程流畅自然
- 多段攻击：支持空中连击，每次击中都会重置击飞效果和眩晕时间

---

## 2025.1130

### 1. 击飞特效实现

#### 目标

需要在AnimationPlayer中的atk_3动画1.5s处开启攻击后添加击飞效果，敌人如果命中后会被击飞控制1s。

#### 当前想到的策略：

在atk_3 1.5s处Add Track添加调用方法记录该次攻击为击飞特性，保存到Damage 对象中，然后enemy击中后查看Damage中是否有击飞特效，如果有则enemy被击飞

#### 建议

你可以想下是否可以做的简单通用，后面可以支持更多攻击特效



### ❓ 需要确认的问题

1. **攻击者位置获取** ：击飞方向需要知道伤害来源位置，我计划通过修改 `Hitbox`传递玩家位置，这样可行吗？
2. **动画配置方式** ：你更倾向于：

* A) 在AnimationPlayer添加Method Call轨道动态切换？
* B) 为atk_3直接配置专用的Damage资源？

1. **特效优先级** ：如果同时有击飞+击退，应该如何处理？（当前设计是按数组顺序依次应用）
2. **视觉效果** ：击飞时是否需要添加粒子特效或动画？我可以扩展 `KnockUpEffect`支持。

请确认这个方案是否符合你的需求，我将继续实施！

Answer:
1. 可以添加玩家位置，但是这里的击飞是y轴向上就可以了
2. 动画配置 给出A/B优缺点，那种更加简单容易维护
3. 按照数组顺序
4. 暂时不需要
总体实现需要简洁，高效，通用，便于维护
