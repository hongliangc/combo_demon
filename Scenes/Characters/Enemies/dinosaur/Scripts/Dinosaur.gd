extends CharacterBody2D

## Enemy 基类 - 使用组件化架构
## 伤害处理由 HealthComponent 负责
## 状态机通过监听 damaged 信号响应

# ============ 信号 ============
## 转发给状态机（由 HealthComponent.damaged 触发）
signal damaged(damage: Damage, attacker_position: Vector2)

# ============ 配置参数 ============
@export_group("Textures")
@export var textures: Array[Texture2D] = []

@export_group("Health")
@export var max_health := 100
@export var health := 100

@export_group("Wander")
@export var min_wander_time := 2.5
@export var max_wander_time := 10.0
@export var wander_speed := 50.0

@export_group("Chase")
@export var detection_radius := 100.0
@export var chase_radius := 200.0
@export var follow_radius := 25.0
@export var chase_speed := 75

# ============ 运行时变量 ============
var stunned: bool = false
var can_move: bool = true  # 用于技能聚集时强制停止移动
var alive: bool = true

# ============ 节点引用 ============
@onready var sprite: Sprite2D = $Sprite2D
@onready var damage_numbers_anchor: Node2D = $DamageNumbersAnchor
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var health_component: HealthComponent = $HealthComponent

func _ready() -> void:
	sprite.texture = textures.pick_random()

	# 激活 AnimationTree
	if anim_tree:
		anim_tree.active = true

	_setup_signals()

## 设置信号连接
func _setup_signals() -> void:
	# 连接 Hurtbox 到 HealthComponent
	var hurtbox = get_node_or_null("Hurtbox")
	if hurtbox and health_component:
		hurtbox.damaged.connect(health_component.take_damage)

	# 监听 HealthComponent 的信号
	if health_component:
		health_component.damaged.connect(_on_health_component_damaged)
		health_component.died.connect(on_death)

		# 同步初始生命值到 HealthComponent
		health_component.max_health = max_health
		health_component.health = health

## HealthComponent 受伤时的回调 - 转发 damaged 信号给状态机
func _on_health_component_damaged(damage: Damage, attacker_position: Vector2) -> void:
	# 转发信号给状态机
	damaged.emit(damage, attacker_position)

## 死亡处理
func on_death() -> void:
	alive = false
	velocity = Vector2.ZERO

	# 停止状态机
	var state_machine = get_node_or_null("EnemyStateMachine")
	if state_machine:
		state_machine.set_physics_process(false)
		state_machine.set_process(false)

	# 停止 AnimationTree（避免与 AnimationPlayer 冲突）
	if anim_tree:
		anim_tree.active = false

	# 直接使用 AnimationPlayer 播放死亡动画
	anim_player.play("death")
