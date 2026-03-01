extends BaseCharacter
class_name EnemyBase

## 所有标准敌人的基类
## 在 BaseCharacter 基础上增加：AI参数、状态机集成、精灵管理、死亡动画
##
## 使用方法:
##   1. 继承此类或使用 EnemyBase.tscn 模板场景
##   2. 在 Inspector 中配置 AI 参数（或使用 EnemyData 资源）
##   3. 重写 _on_enemy_ready() 进行敌人特定初始化
##   4. 精灵自动查找 Sprite2D 或 AnimatedSprite2D
##
## 节点要求:
##   必需: HealthComponent, HurtBoxComponent, AnimationPlayer
##   可选: AnimationTree, EnemyStateMachine, HealthBar, DamageNumbersAnchor

# ============ 数据驱动配置（可选）============
@export var enemy_data: EnemyData = null

# ============ AI 配置参数 ============
@export_group("Wander")
@export var min_wander_time := 2.5
@export var max_wander_time := 10.0
@export var wander_speed := 50.0

@export_group("Chase")
@export var detection_radius := 100.0
@export var chase_radius := 200.0
@export var follow_radius := 25.0
@export var chase_speed := 75

@export_group("Physics")
@export var has_gravity := false
@export var gravity := 800.0

@export_group("Animation")
@export var use_animation_tree := true

# ============ 运行时变量 ============
var stunned: bool = false
var can_move: bool = true  # 用于技能聚集时强制停止移动

# ============ 节点引用 ============
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var anim_tree: AnimationTree = $AnimationTree

## 精灵节点（自动查找 Sprite2D 或 AnimatedSprite2D）
var sprite: Node2D

func _on_character_ready() -> void:
	# 应用数据资源（如果配置了）
	if enemy_data:
		_apply_enemy_data()

	# 查找精灵节点
	_find_sprite()

	# 激活 AnimationTree（可通过 use_animation_tree 关闭）
	if anim_tree and use_animation_tree:
		anim_tree.active = true

	# 子类钩子
	_on_enemy_ready()

func _physics_process(delta: float) -> void:
	# 应用重力（如果启用）
	if has_gravity:
		if not is_on_floor():
			velocity.y += gravity * delta
		elif velocity.y > 0:
			velocity.y = 0

	# 自动翻转精灵朝向
	_update_sprite_facing()

## 死亡处理：停止状态机 → 通过 AnimationTree 播放死亡动画 → 删除节点
func _handle_death() -> void:
	# 停止状态机
	var state_machine = get_node_or_null("EnemyStateMachine")
	if state_machine:
		state_machine.set_physics_process(false)
		state_machine.set_process(false)

	# 通过 AnimationTree 播放死亡动画（而不是使用 AnimationPlayer）
	if anim_tree:
		# 切换到 death 状态（在 control_sm 状态机中）
		anim_tree.set("parameters/control_sm/transition_request", "death")

		# 等待动画结束
		if anim_player:
			await anim_player.animation_finished
		else:
			await get_tree().create_timer(0.3).timeout
		queue_free()
	else:
		# 没有 AnimationTree 时，直接删除
		await get_tree().create_timer(0.3).timeout
		queue_free()

# ============ 精灵管理 ============
## 自动查找精灵节点（优先 AnimatedSprite2D，其次 Sprite2D）
func _find_sprite() -> void:
	sprite = get_node_or_null("AnimatedSprite2D")
	if not sprite:
		sprite = get_node_or_null("Sprite2D")

## 根据移动方向翻转精灵（子类可重写）
func _update_sprite_facing() -> void:
	if not sprite or not alive or velocity.x == 0:
		return

	# 注意：velocity.x > 0 表示向右移动，此时翻转精灵
	# 这是因为敌人精灵资源默认朝向左边
	if sprite is Sprite2D:
		(sprite as Sprite2D).flip_h = velocity.x > 0
	elif sprite is AnimatedSprite2D:
		(sprite as AnimatedSprite2D).flip_h = velocity.x > 0

# ============ 数据驱动 ============
## 从 EnemyData 资源加载配置
func _apply_enemy_data() -> void:
	if not enemy_data:
		return

	max_health = enemy_data.max_health
	health = enemy_data.health
	min_wander_time = enemy_data.min_wander_time
	max_wander_time = enemy_data.max_wander_time
	wander_speed = enemy_data.wander_speed
	detection_radius = enemy_data.detection_radius
	chase_radius = enemy_data.chase_radius
	follow_radius = enemy_data.follow_radius
	chase_speed = enemy_data.chase_speed
	has_gravity = enemy_data.has_gravity
	gravity = enemy_data.gravity

# ============ 子类钩子 ============
## 敌人特定初始化（在 _on_character_ready 末尾调用）
func _on_enemy_ready() -> void:
	pass
