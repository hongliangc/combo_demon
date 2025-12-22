# Combo Demon - 编码规范

> **目的**: 确保代码一致性、可维护性和最佳性能
> **适用于**: Godot 4.4.1 GDScript

---

## 📐 GDScript 编码规范

### 命名约定

```gdscript
# ✅ 正确示例

# 类名: PascalCase
class_name PlayerController

# 常量: UPPER_SNAKE_CASE
const MAX_HEALTH: int = 100
const DAMAGE_MULTIPLIER: float = 1.5

# 变量: snake_case
var player_speed: float = 200.0
var is_alive: bool = true
var enemy_count: int = 0

# 私有变量: _snake_case (下划线前缀)
var _internal_timer: float = 0.0

# 函数: snake_case
func calculate_damage(base_damage: float) -> float:
    return base_damage * DAMAGE_MULTIPLIER

# 信号: snake_case
signal health_changed(new_health: int)
signal enemy_defeated(enemy_name: String)

# 枚举: PascalCase for type, UPPER_CASE for values
enum DamageType {
    PHYSICAL,
    MAGICAL,
    TRUE_DAMAGE
}
```

### 类型提示

**强制要求**: 所有函数参数和返回值必须有类型提示

```gdscript
# ✅ 正确
func apply_damage(target: CharacterBody2D, damage: float) -> void:
    target.health -= damage

func get_player_position() -> Vector2:
    return global_position

# ❌ 错误 - 缺少类型提示
func apply_damage(target, damage):
    target.health -= damage
```

### 变量声明

```gdscript
# ✅ 推荐: 使用类型推断
var speed := 100.0  # float
var count := 0      # int
var name := "Player"  # String

# ✅ 也可以: 显式类型
var speed: float = 100.0
var count: int = 0
var name: String = "Player"

# ✅ 导出变量必须有类型
@export var max_health: float = 100.0
@export var move_speed: float = 200.0
```

---

## 🏗️ 架构模式

### 组件化设计

**原则**: 每个组件负责单一职责

```gdscript
# ✅ 好的组件设计
# Util/Components/health.gd
extends Node
class_name HealthComponent

signal health_changed(current: float, maximum: float)
signal died

@export var max_health: float = 100.0
var current_health: float

func _ready() -> void:
    current_health = max_health

func take_damage(amount: float) -> void:
    current_health = max_health(0, current_health - amount)
    health_changed.emit(current_health, max_health)
    if current_health <= 0:
        died.emit()

func heal(amount: float) -> void:
    current_health = min(max_health, current_health + amount)
    health_changed.emit(current_health, max_health)
```

### Resource 数据管理

**用途**: 配置、技能、道具等数据

```gdscript
# ✅ 使用 Resource 管理数据
# Util/Classes/skill_data.gd
extends Resource
class_name SkillData

@export var skill_name: String = ""
@export var cooldown: float = 1.0
@export var damage: float = 10.0
@export var mana_cost: int = 10
@export_multiline var description: String = ""
```

### AutoLoad 单例模式

**用途**: 全局管理器（音效、事件、对象池）

```gdscript
# ✅ AutoLoad 单例
# Util/AutoLoad/skill_manager.gd
extends Node

var active_skills: Dictionary = {}

func register_skill(skill_id: String, skill: SkillData) -> void:
    active_skills[skill_id] = skill

func use_skill(skill_id: String, caster: Node) -> bool:
    if skill_id in active_skills:
        var skill = active_skills[skill_id]
        # 执行技能逻辑
        return true
    return false
```

---

## ⚡ 性能优化规范

### 对象池模式

```gdscript
# ✅ 使用对象池管理频繁创建的对象
# Util/AutoLoad/bullet_pool.gd
extends Node

const POOL_SIZE = 50
var bullet_scene: PackedScene = preload("res://Weapons/bullet/base_bullet.tscn")
var pool: Array[Node] = []

func _ready() -> void:
    for i in POOL_SIZE:
        var bullet = bullet_scene.instantiate()
        bullet.visible = false
        add_child(bullet)
        pool.append(bullet)

func get_bullet() -> Node:
    for bullet in pool:
        if not bullet.visible:
            bullet.visible = true
            return bullet
    # 池已满，创建新对象
    var new_bullet = bullet_scene.instantiate()
    add_child(new_bullet)
    pool.append(new_bullet)
    return new_bullet

func return_bullet(bullet: Node) -> void:
    bullet.visible = false
    bullet.global_position = Vector2.ZERO
```

### 避免在循环中创建对象

```gdscript
# ❌ 错误 - 在 _process 中创建对象
func _process(delta: float) -> void:
    var temp_vector = Vector2(1, 1)  # 每帧创建新对象
    position += temp_vector * delta

# ✅ 正确 - 复用变量
var _movement_vector := Vector2.ZERO

func _process(delta: float) -> void:
    _movement_vector = Vector2(1, 1)
    position += _movement_vector * delta
```

### 使用 @onready 延迟初始化

```gdscript
# ✅ 正确 - 使用 @onready
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D

# ❌ 错误 - 在 _ready 中获取
var animation_player: AnimationPlayer
func _ready() -> void:
    animation_player = $AnimationPlayer
```

---

## 🎯 错误处理

### 空值检查

```gdscript
# ✅ 正确
func attack_target(target: Node2D) -> void:
    if not is_instance_valid(target):
        push_warning("Attack target is invalid")
        return

    # 执行攻击逻辑
    target.take_damage(damage)
```

### 信号连接检查

```gdscript
# ✅ 正确
func _ready() -> void:
    if not health_component.health_changed.is_connected(_on_health_changed):
        health_component.health_changed.connect(_on_health_changed)
```

---

## 📝 注释规范

### 函数注释

```gdscript
## 对目标造成伤害
##
## 参数:
##   target: 受伤害的目标节点
##   damage_amount: 伤害数值
##   damage_type: 伤害类型 (Physical, Magical, True)
##
## 返回:
##   实际造成的伤害值 (考虑护甲等减免)
func deal_damage(target: CharacterBody2D, damage_amount: float, damage_type: String) -> float:
    var actual_damage := calculate_final_damage(damage_amount, damage_type)
    target.take_damage(actual_damage)
    return actual_damage
```

### TODO 注释

```gdscript
# TODO: 实现技能冷却系统
# FIXME: 修复敌人AI在墙角卡住的问题
# HACK: 临时解决方案，需要重构
# NOTE: 这个值需要和策划确认
```

---

## 🔒 安全性规范

### 输入验证

```gdscript
# ✅ 正确 - 验证输入
func set_health(value: float) -> void:
    if value < 0:
        push_warning("Health cannot be negative, clamping to 0")
        current_health = 0
        return
    if value > max_health:
        push_warning("Health cannot exceed max_health, clamping")
        current_health = max_health
        return
    current_health = value
```

---

## ✅ 代码审查检查清单

### 提交前必查项

- [ ] 所有函数都有类型提示
- [ ] 变量命名符合 snake_case
- [ ] 类名符合 PascalCase
- [ ] 没有在 _process 中创建临时对象
- [ ] 使用了 @onready 延迟节点引用
- [ ] 错误情况有适当的处理
- [ ] 关键逻辑有注释说明
- [ ] 移除了调试用的 print 语句
- [ ] 信号命名清晰且连接正确

### 性能检查

- [ ] 频繁创建的对象使用对象池
- [ ] 避免不必要的节点遍历
- [ ] 使用 @export_flags 而不是多个 bool
- [ ] 大型数据使用 Resource 管理

---

## 🎓 最佳实践示例

### 完整的角色类示例

```gdscript
extends CharacterBody2D
class_name Player

## 玩家角色主类
##
## 负责处理玩家输入、移动和技能释放

# 信号
signal health_changed(current: float, maximum: float)
signal skill_used(skill_name: String)

# 常量
const MAX_SPEED: float = 300.0
const ACCELERATION: float = 1500.0

# 导出变量
@export_group("Stats")
@export var max_health: float = 100.0
@export var current_health: float = 100.0

@export_group("Movement")
@export var move_speed: float = 200.0
@export var dash_speed: float = 500.0

# 私有变量
var _input_direction := Vector2.ZERO
var _is_dashing := false

# 节点引用
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
    current_health = max_health

func _process(delta: float) -> void:
    _input_direction = Input.get_vector(
        "move_left", "move_right",
        "move_up", "move_down"
    )

func _physics_process(delta: float) -> void:
    _handle_movement(delta)
    move_and_slide()

func _handle_movement(delta: float) -> void:
    if _input_direction != Vector2.ZERO:
        velocity = velocity.move_toward(
            _input_direction * move_speed,
            ACCELERATION * delta
        )
    else:
        velocity = velocity.move_toward(
            Vector2.ZERO,
            ACCELERATION * delta
        )

func take_damage(amount: float) -> void:
    current_health = max(0, current_health - amount)
    health_changed.emit(current_health, max_health)

    if current_health <= 0:
        _die()

func _die() -> void:
    queue_free()
```

---

**最后更新**: 2025-12-22
**维护者**: Claude Code AI
