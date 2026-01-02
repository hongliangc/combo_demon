# Godot 4.x 编码规范 - 完整参考

## 文件组织规范

```
Project/
├── Scenes/           # 场景文件
│   ├── characters/   # 角色相关
│   ├── enemies/      # 敌人相关
│   └── ui/           # UI界面
├── Util/             # 工具类和组件
│   ├── Components/   # 可复用组件
│   ├── Classes/      # 数据类/Resource类
│   └── AutoLoad/     # 单例/自动加载
├── Weapons/          # 武器系统
├── Art/              # 美术资源
└── project.godot
```

## 命名规范详解

### 文件和类名
```gdscript
# ✅ 推荐：PascalCase，与类名一致
class_name Health
# 文件名：health.gd

class_name AttackComponent
# 文件名：attack_component.gd
```

### 变量和函数
```gdscript
# ✅ 推荐：snake_case
var max_health: float = 100.0
var current_damage: Damage
var is_alive: bool = true

func apply_damage(damage: Damage) -> void:
    pass

func get_health_percent() -> float:
    return health / max_health
```

### 常量和枚举
```gdscript
# ✅ 推荐：UPPER_SNAKE_CASE
const MAX_SPEED = 200.0
const DEFAULT_GRAVITY = 980.0

enum State {
    IDLE,
    WALKING,
    ATTACKING,
    DEAD
}

enum Phase {
    PHASE_1,
    PHASE_2,
    PHASE_3
}
```

### 信号
```gdscript
# ✅ 推荐：snake_case，使用过去式表示事件
signal health_changed(current: float, maximum: float)
signal damaged(damage: Damage)
signal died()
signal phase_changed(new_phase: int)
```

## 类型注解规范

```gdscript
# ✅ 推荐：使用明确的类型注解
extends CharacterBody2D
class_name Player

# 变量类型注解
var max_health: float = 100.0
var velocity_direction: Vector2 = Vector2.ZERO
var damage_types: Array[Damage] = []
var current_state: State = State.IDLE

# 函数类型注解
func take_damage(damage: Damage, attacker_position: Vector2 = Vector2.ZERO) -> void:
    health -= damage.amount
    health = max(0, health)

func get_damage_percent() -> float:
    return damage / max_damage

# ❌ 避免：省略类型注解
var health = 100  # 不清楚是int还是float
func calculate(a, b):  # 不清楚参数和返回值类型
    return a + b
```

## Export 变量规范

```gdscript
# ✅ 推荐：使用 @export_group 组织相关变量
@export_group("Health")
@export var max_health: float = 100.0
@export var regeneration_rate: float = 5.0

@export_group("Movement")
@export var move_speed: float = 150.0
@export var rotation_speed: float = 5.0

@export_group("Detection")
@export var detection_radius: float = 500.0
@export var attack_range: float = 200.0

# ✅ 推荐：使用具体的类型注解
@export var damage_effect: AttackEffect
@export var textures: Array[Texture2D] = []
@export_enum("Physical", "Magic", "Fire") var damage_type: String = "Physical"

# ❌ 避免：无分组的大量变量
@export var max_health = 100
@export var move_speed = 150
@export var attack_range = 200
```

## 信号使用规范

```gdscript
# ✅ 推荐：在文件顶部声明所有信号，使用类型注解
class_name Health
extends Node

signal health_changed(current: float, maximum: float)
signal max_health_changed(new_max: float)
signal died()

# ✅ 推荐：连接信号时使用方法引用
func _ready() -> void:
    if hurtbox:
        hurtbox.damaged.connect(on_damaged)
    health_changed.connect(_on_health_changed)

# ✅ 推荐：信号处理函数使用 on_ 前缀
func on_damaged(damage: Damage, attacker_position: Vector2) -> void:
    health -= damage.amount
    health_changed.emit(health, max_health)

# ❌ 避免：使用字符串连接信号（Godot 3风格）
hurtbox.connect("damaged", self, "_on_damaged")
```

## 组件化设计规范

### 组件类示例
```gdscript
# health.gd - 可复用的生命值组件
extends Node
class_name Health

## 生命值组件 - 处理生命值和伤害逻辑
## 可附加到任何需要生命值的节点

signal health_changed(current: float, maximum: float)
signal died()

@export var hurtbox: Hurtbox
@export var max_health: float = 100.0

var health: float = max_health:
    set(val):
        health = clamp(val, 0, max_health)
        health_changed.emit(health, max_health)
        if health <= 0:
            died.emit()

func _ready() -> void:
    if hurtbox:
        hurtbox.damaged.connect(on_damaged)

func on_damaged(damage: Damage, attacker_position: Vector2) -> void:
    health -= damage.amount

func heal(amount: float) -> void:
    health += amount
```

### 使用组件
```gdscript
# player.gd
extends CharacterBody2D
class_name Player

@onready var health_component: Health = $Health
@onready var attack_component: AttackComponent = $AttackComponent

func _ready() -> void:
    health_component.died.connect(on_death)

func on_death() -> void:
    queue_free()
```

## Resource 类规范

```gdscript
# damage.gd - 数据资源类
extends Resource
class_name Damage

## 伤害数据类 - 可在编辑器中创建和配置

@export_group("Damage Config")
@export var min_amount: float = 1.0
@export var max_amount: float = 50.0
@export var amount: float = 10.0

@export_group("Effects")
@export var effects: Array[AttackEffect] = []

## 应用所有特效到目标
func apply_effects(target: Node2D, source_position: Vector2) -> void:
    for effect in effects:
        if effect and effect.has_method("apply_effect"):
            effect.apply_effect(target, source_position)

## 随机化伤害值
func randomize_damage() -> void:
    amount = randf_range(min_amount, max_amount)
```

## 注释和文档规范

```gdscript
extends CharacterBody2D
class_name Boss

## Boss 基类 - 支持多阶段战斗、8方位移动、高级AI
##
## 用法示例：
## [codeblock]
## var boss = Boss.new()
## boss.change_phase(Boss.Phase.PHASE_2)
## [/codeblock]

# ============ 信号 ============
signal damaged(damage: Damage)
signal phase_changed(new_phase: Phase)

# ============ 常量 ============
const SQRT2_INV = 0.7071067811865476  # 1 / sqrt(2)

# ============ 枚举 ============
enum Phase {
    PHASE_1,  # 第一阶段
    PHASE_2,  # 第二阶段（更激进）
    PHASE_3   # 第三阶段（狂暴）
}

# ============ Export 变量 ============
@export_group("Health")
@export var max_health: int = 1000

# ============ 公共方法 ============
## 切换到指定阶段
## @param new_phase: 目标阶段
func change_phase(new_phase: Phase) -> void:
    if current_phase == new_phase:
        return
    current_phase = new_phase
    phase_changed.emit(new_phase)

# ============ 私有方法 ============
## 内部使用：检查阶段转换条件
func _check_phase_transition() -> void:
    var health_percent = float(health) / float(max_health)
    # 实现逻辑...
```

## 性能优化规范

```gdscript
# ✅ 推荐：缓存节点引用
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
    # 使用缓存的引用，避免重复查找
    sprite.texture = load("res://textures/player.png")

# ✅ 推荐：使用静态变量避免重复创建
class_name Damage
static var _rng: RandomNumberGenerator = null

func randomize_damage() -> void:
    if _rng == null:
        _rng = RandomNumberGenerator.new()
        _rng.randomize()
    amount = _rng.randf_range(min_amount, max_amount)

# ✅ 推荐：预计算常量
const SQRT2_INV = 0.7071067811865476  # 1 / sqrt(2)
const DIRECTIONS_8 = [
    Vector2(1, 0),
    Vector2(SQRT2_INV, -SQRT2_INV),
    # ...
]

# ❌ 避免：在循环中查找节点
func _process(delta: float) -> void:
    for i in range(100):
        get_node("Sprite2D").modulate = Color.RED  # 每次都查找！
```

## 错误处理规范

```gdscript
# ✅ 推荐：检查节点是否存在
func _ready() -> void:
    var hurtbox = get_node_or_null("Hurtbox")
    if hurtbox and hurtbox.has_signal("damaged"):
        hurtbox.damaged.connect(on_damaged)

# ✅ 推荐：检查数组和资源
func apply_effects(target: Node2D, source: Vector2) -> void:
    for effect in effects:
        if effect == null:
            continue
        if effect.has_method("apply_effect"):
            effect.apply_effect(target, source)

# ✅ 推荐：使用断言检查前置条件（仅调试模式）
func set_health(value: float) -> void:
    assert(value >= 0, "Health cannot be negative!")
    health = value
```

## 完整组件示例

```gdscript
extends Node
class_name AttackComponent

## 攻击组件 - 处理攻击逻辑、冷却和伤害应用
##
## 可附加到任何需要攻击功能的角色或敌人
## 通过配置 damage 资源和 hitbox 节点即可使用

# ============ 信号 ============
signal attack_started()
signal attack_finished()
signal hit_target(target: Node2D)

# ============ Export 变量 ============
@export_group("Attack Config")
## 攻击伤害配置（Resource）
@export var damage: Damage
## 攻击间隔（秒）
@export var attack_cooldown: float = 1.0
## 攻击持续时间（秒）
@export var attack_duration: float = 0.3

@export_group("References")
## 攻击判定区域
@export var hitbox: Hitbox

# ============ 运行时变量 ============
var can_attack: bool = true
var is_attacking: bool = false

# ============ 节点引用 ============
@onready var cooldown_timer: Timer = $CooldownTimer
@onready var duration_timer: Timer = $DurationTimer

# ============ 内置回调 ============
func _ready() -> void:
    if not cooldown_timer:
        cooldown_timer = Timer.new()
        add_child(cooldown_timer)
        cooldown_timer.one_shot = true
        cooldown_timer.timeout.connect(_on_cooldown_finished)

    if not duration_timer:
        duration_timer = Timer.new()
        add_child(duration_timer)
        duration_timer.one_shot = true
        duration_timer.timeout.connect(_on_attack_finished)

    if hitbox:
        hitbox.monitoring = false
        hitbox.area_entered.connect(_on_hitbox_area_entered)

# ============ 公共方法 ============
## 执行攻击
## @return: 是否成功触发攻击
func attack() -> bool:
    if not can_attack or is_attacking:
        return false
    _start_attack()
    return true

## 取消当前攻击
func cancel_attack() -> void:
    if is_attacking:
        _finish_attack()

## 重置冷却（立即可以再次攻击）
func reset_cooldown() -> void:
    can_attack = true
    if cooldown_timer.time_left > 0:
        cooldown_timer.stop()

# ============ 私有方法 ============
func _start_attack() -> void:
    is_attacking = true
    can_attack = false
    if hitbox:
        hitbox.monitoring = true
    duration_timer.start(attack_duration)
    attack_started.emit()

func _finish_attack() -> void:
    is_attacking = false
    if hitbox:
        hitbox.monitoring = false
    cooldown_timer.start(attack_cooldown)
    attack_finished.emit()

# ============ 信号处理 ============
func _on_cooldown_finished() -> void:
    can_attack = true

func _on_attack_finished() -> void:
    _finish_attack()

func _on_hitbox_area_entered(area: Area2D) -> void:
    if not area.owner:
        return
    if area is Hurtbox:
        var attacker_position = global_position
        area.take_damage(damage, attacker_position)
        hit_target.emit(area.owner)
```
