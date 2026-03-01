extends CharacterBody2D
class_name BaseCharacter

## 所有角色（Player / Enemy / Boss）的通用基类
## 提供：生命系统集成、伤害信号转发、HurtBox 自动连接
##
## 使用方法:
##   1. 子类继承此类（EnemyBase, PlayerBase, 或直接继承）
##   2. 场景中添加 HurtBoxComponent、HealthComponent、DamageNumbersAnchor 节点
##   3. 重写 _on_character_ready() 进行子类初始化
##   4. 重写 _handle_death() 实现自定义死亡逻辑
##
## 信号流:
##   HurtBoxComponent.damaged → HealthComponent.take_damage()
##       ├─→ HealthComponent.damaged → BaseCharacter._on_health_component_damaged()
##       │       └─→ BaseCharacter.damaged.emit() → 状态机响应
##       └─→ HealthComponent.died → BaseCharacter._on_died()
##               └─→ _handle_death() (子类实现)

# ============ 信号 ============
## 转发给状态机（由 HealthComponent.damaged 触发）
signal damaged(damage: Damage, attacker_position: Vector2)

# ============ 配置参数 ============
@export_group("Health")
@export var max_health := 100
@export var health := 100

# ============ 运行时变量 ============
var alive: bool = true

# ============ 节点引用 ============
@onready var health_component: HealthComponent = $HealthComponent
@onready var damage_numbers_anchor: Node2D = $DamageNumbersAnchor

func _ready() -> void:
	_setup_health_signals()
	_on_character_ready()

## 设置生命系统信号连接
func _setup_health_signals() -> void:
	# 连接 HurtBoxComponent → HealthComponent
	var hurtbox = get_node_or_null("HurtBoxComponent")
	if hurtbox and health_component:
		if hurtbox.has_signal("damaged"):
			hurtbox.damaged.connect(health_component.take_damage)

	# 监听 HealthComponent 信号
	if health_component:
		health_component.damaged.connect(_on_health_component_damaged)
		health_component.died.connect(_on_died)

		# 同步导出参数到 HealthComponent
		health_component.max_health = max_health
		health_component.health = health

## HealthComponent 受伤回调 - 转发 damaged 信号给状态机
func _on_health_component_damaged(damage_data: Damage, attacker_position: Vector2) -> void:
	damaged.emit(damage_data, attacker_position)

## 死亡处理入口
func _on_died() -> void:
	alive = false
	velocity = Vector2.ZERO
	_handle_death()

# ============ 子类钩子方法（可重写）============
## 角色初始化完成后调用（在 _ready 末尾）
func _on_character_ready() -> void:
	pass

## 自定义死亡逻辑（由 _on_died 调用）
func _handle_death() -> void:
	pass
