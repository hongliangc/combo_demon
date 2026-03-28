# 组件开发指南 (component-guide.md)

## 1. 组件设计原则

| 原则 | 说明 |
|------|------|
| 单一职责 | 每个组件只做一件事（生命值、移动、战斗等） |
| 信号通信 | 组件之间通过信号解耦，不直接引用其他组件 |
| @export 驱动 | 可调参数通过 @export 暴露，支持编辑器配置 |
| 自治运行 | 组件自行管理自身状态，外部通过方法调用交互 |

## 2. 现有组件清单

| 组件 | 基类 | 路径 | 职责 |
|------|------|------|------|
| HealthComponent | Node | `Core/Components/HealthComponent.gd` | 生命值、受伤、死亡、无敌 |
| HitBoxComponent | Area2D | `Core/Components/HitBoxComponent.gd` | 攻击判定区域 |
| HurtBoxComponent | Area2D | `Core/Components/HurtBoxComponent.gd` | 受击判定区域 |
| MovementComponent | Node | `Core/Components/MovementComponent.gd` | 输入、加速/减速、跳跃、朝向 |
| CombatComponent | Node | `Core/Components/CombatComponent.gd` | 技能输入、伤害类型切换 |
| SkillManager | Node | `Core/Components/SkillManager.gd` | 特殊攻击编排 |
| AttackComponent | Node | `Core/Components/AttackComponent.gd` | 攻击状态追踪 |
| FollowCamera | Camera2D | `Core/Components/FollowCamera.gd` | 跟随相机 |

## 3. 新组件开发模板

### 3.1 基础结构

```gdscript
extends Node
class_name MyNewComponent

## 组件描述 - 一句话说明职责
##
## 使用方法:
##   1. 将此组件添加为 CharacterBody2D 的子节点
##   2. 配置 @export 参数
##   3. 连接需要的信号

# ============ 信号 ============
signal my_signal(param: Type)

# ============ 导出参数 ============
@export_group("基础配置")
@export var my_param: float = 1.0

# ============ 内部状态 ============
var _internal_state: bool = false

# ============ 缓存 ============
var _owner_ref: CharacterBody2D = null

# ============ 生命周期 ============
func _ready() -> void:
    _owner_ref = get_parent() as CharacterBody2D
    assert(_owner_ref != null, "%s 必须是 CharacterBody2D 的子节点" % name)

func _process(delta: float) -> void:
    pass  # 或 _physics_process

# ============ 公共 API ============
func do_something(param: float) -> void:
    # 业务逻辑
    my_signal.emit(param)
```

### 3.2 选择基类

| 场景 | 基类 | 说明 |
|------|------|------|
| 纯逻辑组件 | `Node` | 无物理/渲染需求 |
| 碰撞检测 | `Area2D` | 需要 CollisionShape2D |
| 需要位置 | `Node2D` | 需要世界坐标 |
| 相机控制 | `Camera2D` | 继承相机功能 |

## 4. 组件通信模式

### 4.1 信号连接（推荐）

```gdscript
# 在父节点或 BaseCharacter 中自动连接
func _ready() -> void:
    var hurt_box = get_node_or_null("HurtBoxComponent")
    var health = get_node_or_null("HealthComponent")
    if hurt_box and health:
        hurt_box.damaged.connect(health.take_damage)
```

### 4.2 方法调用（状态机 → 组件）

```gdscript
# 状态机中的状态直接调用组件方法
func enter() -> void:
    owner.get_node("MovementComponent").set_can_move(false)
```

### 4.3 懒缓存模式（跨组件引用）

```gdscript
var _cached_health: HealthComponent = null

func _get_health() -> HealthComponent:
    if not is_instance_valid(_cached_health):
        _cached_health = get_parent().get_node_or_null("HealthComponent")
    return _cached_health
```

## 5. @export 分组规范

```gdscript
@export_group("基础配置")
@export var speed: float = 200.0
@export var acceleration: float = 800.0

@export_group("行为配置")
@export var auto_start: bool = true
@export var debug_mode: bool = false

@export_group("视觉效果")
@export var show_particles: bool = true
```

## 6. 组件与场景集成

### 6.1 场景树位置

```
CharacterBody2D (EnemyBase/PlayerBase)
├── Sprite2D / AnimatedSprite2D
├── CollisionShape2D
├── AnimationPlayer / AnimationTree
├── HealthComponent        ← Node 类型组件
├── HurtBoxComponent       ← Area2D 类型组件
│   └── CollisionShape2D
├── HitBoxComponent        ← Area2D 类型组件
│   └── CollisionShape2D
├── MovementComponent      ← Node 类型组件
└── StateMachine           ← 状态机引用组件
```

### 6.2 物理层配置

| 组件 | Layer | Mask | 说明 |
|------|-------|------|------|
| HurtBox (Player) | 2 | 5 | 在 Player 层，检测 Enemy Projectile |
| HurtBox (Enemy) | 4 | 3 | 在 Enemy 层，检测 Player Projectile |
| HitBox (Player Attack) | 3 | 4 | 在 Player Projectile 层，检测 Enemy |
| HitBox (Enemy Attack) | 5 | 2 | 在 Enemy Projectile 层，检测 Player |

## 7. 测试要点

```gdscript
# 组件单元测试模板
extends GutTest

var _component: MyNewComponent

func before_each() -> void:
    _component = MyNewComponent.new()
    _component.my_param = 10.0
    add_child_autofree(_component)

func test_signal_emitted() -> void:
    watch_signals(_component)
    _component.do_something(5.0)
    assert_signal_emitted(_component, "my_signal")

func test_export_defaults() -> void:
    var fresh = MyNewComponent.new()
    assert_eq(fresh.my_param, 1.0, "Default should be 1.0")
    fresh.free()
```
