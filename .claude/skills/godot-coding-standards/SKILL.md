---
name: godot-coding-standards
description: Godot 4.x 核心架构原则。当设计、审查 Godot 组件和系统时使用。关注：组件模式、信号通信、Resource设计、系统架构。触发词：godot, 组件, 信号, 架构, 设计。
---

# Godot 4.x 核心架构原则

为 Godot 4.x 项目设计的核心原则，确保代码的**通用性、模块化、可复用性、简洁性**。

## 核心设计原则

### 1. 通用性优先
- 使用 `@export` 暴露可配置参数，避免硬编码
- 组件应该能在不同场景中复用，不依赖特定父节点
- 通过配置而非代码修改来调整行为

### 2. 模块化设计
- **单一职责**：每个组件只做一件事（Health、Movement、Attack）
- **组件化思维**：用小组件组合出复杂行为，避免巨型类
- **信号松耦合**：通过信号通信，避免直接调用和硬依赖

### 3. 可复用性
- **Resource 类**：用于存储配置数据（Damage、SkillData）
- **清晰接口**：公共方法定义清晰，private方法用 `_` 前缀
- **独立性**：组件可以独立测试和使用

### 4. 简洁实用
- 注重实用性，避免过度设计
- 不为未来需求预先设计
- 代码自解释，复杂逻辑才加注释

### 5. 继承与钩子方法
- **通用逻辑放基类**：所有可复用逻辑在基类实现
- **提供钩子方法**：基类提供可重写的钩子方法，让子类定制行为
- **子类最小化重写**：子类只重写必要的钩子方法，不复制基类代码
- **信号连接在基类**：信号连接只在基类 `_ready()` 中进行，子类不要重复连接
- **避免覆盖 _ready()**：子类尽量不覆盖 `_ready()`，如需覆盖必须调用 `super()`

## 组件模式示例

### 基础组件模板
```gdscript
extends Node
class_name Health

## 可复用的生命值组件
## 通过信号通知状态变化，不依赖特定父节点

signal health_changed(current: float, maximum: float)
signal died()

@export var max_health: float = 100.0

var health: float = max_health:
    set(val):
        health = clamp(val, 0, max_health)
        health_changed.emit(health, max_health)
        if health <= 0:
            died.emit()

func take_damage(amount: float) -> void:
    health -= amount

func heal(amount: float) -> void:
    health += amount
```

### Resource 数据类
```gdscript
extends Resource
class_name Damage

## 伤害数据配置类
## 可在编辑器中创建 .tres 资源文件

@export var base_damage: float = 10.0
@export var damage_type: String = "physical"
@export_group("Effects")
@export var knockback_force: float = 0.0
@export var stun_duration: float = 0.0
```

### 钩子方法模式
```gdscript
# 基类 - 提供钩子方法
class_name HitBoxComponent
extends Area2D

## 钩子方法：子类可重写以定制伤害获取逻辑
func update_attack() -> void:
    if damage:
        damage.randomize_damage()

## 钩子方法：子类可重写以返回正确的攻击者位置
func get_attacker_position() -> Vector2:
    return global_position

## 通用逻辑在基类实现，调用钩子方法
func _on_hitbox_area_entered_(area: Area2D) -> void:
    update_attack()
    if area is HurtBoxComponent:
        area.take_damage(damage, get_attacker_position())
```

```gdscript
# 子类 - 只重写钩子方法
class_name PlayerHitbox
extends HitBoxComponent

@onready var player: Hahashin = get_owner()

## 重写：从 CombatComponent 获取伤害
func update_attack() -> void:
    damage = player.combat_component.current_damage

## 重写：返回玩家位置
func get_attacker_position() -> Vector2:
    return player.global_position
```

### 6. 编辑器配置优先原则
- **所有 Node 派生对象优先在编辑器中创建和配置**，而非在代码中 `new()` 后 `add_child()`
- **编辑器负责**：节点层级结构、节点属性默认值、节点间连接关系（AnimationTree 节点连接、信号连接等）
- **代码负责**：运行时参数驱动（`set()`）、状态切换触发（`travel()`）、条件判断逻辑
- **禁止在代码中**：创建节点对象再挂载到场景树，除非是确实需要动态生成的场景（如子弹、特效、敌人生成等运行时实例化场景）
- **动态生成的正确方式**：通过 `preload` / `load` 加载 `.tscn` 场景后 `instantiate()`，而非手动 `new()` + 逐个设置属性
- **好处**：可视化直观、易于调试、避免硬编码路径错误、减少代码复杂度

```gdscript
# ✅ 正确：编辑器配置节点，代码只控制参数
func set_locomotion(blend_position: Vector2) -> void:
    anim_tree.set("parameters/locomotion/blend_position", blend_position)

# ✅ 正确：动态生成通过实例化场景
var projectile = preload("res://Scenes/Projectile.tscn").instantiate()
get_tree().current_scene.add_child(projectile)

# ❌ 错误：代码中手动创建节点
var sprite = Sprite2D.new()
sprite.texture = load("res://icon.png")
add_child(sprite)
```

## 状态机 + AnimationTree BlendTree 规范

### 统一 BlendTree 架构

所有角色（Enemy、Player、Boss）的 AnimationTree 统一使用 BlendTree 根节点，结构如下：

```
AnimationNodeBlendTree (root)  ← 编辑器配置
├── locomotion  → loco_timescale → control_blend[0]
├── control_sm  → ctrl_timescale → control_blend[1]
└── control_blend → output
```

- **locomotion**: 移动动画层（BlendSpace2D 或 StateMachine）
- **control_sm**: 控制动画层（攻击、受击、眩晕、死亡等一次性/打断动画）
- **control_blend** (Blend2): `blend_amount` 控制两层混合（0=locomotion, 1=control）
- **loco_timescale / ctrl_timescale**: 各层独立的动画速度控制

### 编辑器 vs 代码职责划分

| 编辑器配置（.tscn） | 代码控制（.gd） |
|-------------------|----------------|
| BlendTree 节点创建与连接 | `parameters/control_blend/blend_amount` 切换 |
| locomotion / control_sm 内部状态和过渡 | `playback.travel()` / `playback.start()` |
| 过渡条件（advance_mode, switch_mode） | `parameters/*/scale` 动画速度 |
| 动画资源绑定 | `animation_finished` 信号监听 |
| 状态机子节点 + 脚本绑定 + 优先级 | 状态 enter/exit 逻辑 |

```gdscript
# ✅ 正确：编辑器配置 BlendTree 结构，代码只切换参数
func enter_control_state(state_name: String) -> void:
    tree.set("parameters/control_blend/blend_amount", 1.0)
    tree.get("parameters/control_sm/playback").start(state_name, true)

# ✅ 正确：locomotion 用 StateMachine 时通过 travel 切换
func set_locomotion_state(state_name: String) -> void:
    tree.set("parameters/control_blend/blend_amount", 0.0)
    tree.get("parameters/locomotion/playback").travel(state_name)

# ❌ 错误：代码中创建 AnimationNode 对象
var sm = AnimationNodeStateMachine.new()
sm.add_node("idle", AnimationNodeAnimation.new())  # 应在编辑器中配置
```

### 状态脚本规范

1. **继承 BaseState**：所有状态继承 `BaseState`，使用内置 helper 控制动画
2. **不直接操作 AnimationTree**：通过 `set_locomotion()` / `enter_control_state()` / `exit_control_state()` 等 helper
3. **优先级三层**: `BEHAVIOR(0)` < `REACTION(1)` < `CONTROL(2)`
4. **动画完成检测**: connect `animation_finished` 信号，在 `exit()` 中必须 disconnect
5. **状态机定义在模板场景**: PlayerBase.tscn / EnemyBase.tscn 中配置，角色场景继承

### locomotion 两种模式

| 模式 | 节点类型 | 调用方法 | 适用场景 |
|------|---------|---------|---------|
| 多维混合 | BlendSpace2D | `set_locomotion(Vector2)` | Enemy（方向+速度） |
| 二元切换 | StateMachine | `set_locomotion_state("idle"/"run")` | Player（只有 idle/run） |

> 详细架构文档: [Player状态机与AnimationTree](../../DevLog/architecture/08_player_statemachine_architecture.md)

## 架构检查要点

- **通用性**：是否使用 `@export` 配置化？能否跨场景复用？
- **模块化**：是否单一职责？是否用信号解耦？
- **可复用性**：是否有清晰接口？Resource 类是否正确使用？
- **简洁性**：是否避免过度设计？代码是否自解释？
- **继承设计**：基类是否提供钩子方法？子类是否只重写必要方法？
- **信号连接**：子类是否重复连接了基类已连接的信号？是否遗漏 `super()` 调用？
- **编辑器优先**：是否有在代码中 `new()` Node 派生对象的情况？是否应该改为编辑器配置或场景实例化？
- **状态机规范**：状态是否继承 BaseState？是否使用内置 helper 而非直接操作 AnimationTree？animation_finished 信号是否在 exit() 中断开？
- **BlendTree 规范**：AnimationTree 是否使用统一 BlendTree 结构（locomotion + control_sm + control_blend）？节点结构是否在编辑器中配置？
