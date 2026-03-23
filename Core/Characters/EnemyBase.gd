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

## 死亡处理：停止状态机 → 播放死亡动画（优先使用death动画，否则使用白闪效果） → 删除节点
func _handle_death() -> void:
	# 停止状态机
	var state_machine = get_node_or_null("EnemyStateMachine")
	if state_machine:
		state_machine.set_physics_process(false)
		state_machine.set_process(false)

	# 检查是否有 death 动画
	var has_death_animation = false
	if anim_player and anim_player.has_animation("death"):
		has_death_animation = true

	# 方案1：有 death 动画，使用 AnimationTree 播放
	if anim_tree and anim_tree.active and has_death_animation:
		# 切换到 control 层，启动 death 状态
		anim_tree.set("parameters/control_blend/blend_amount", 1.0)
		var playback = anim_tree.get("parameters/control_sm/playback")
		if playback:
			playback.start("death", true)

		# 等待动画结束（使用动画长度定时，避免 AnimationTree 下信号不触发）
		var death_anim = anim_player.get_animation("death")
		var wait_time = death_anim.length if death_anim else 0.5
		await get_tree().create_timer(wait_time).timeout
		queue_free()

	# 方案2：没有 death 动画，使用白闪效果
	else:
		await _play_default_death_animation()
		queue_free()


## 默认死亡动画：白闪3次 + 淡出
func _play_default_death_animation() -> void:
	if not sprite:
		await get_tree().create_timer(0.5).timeout
		return

	var tween = get_tree().create_tween()

	# 白闪3次（每次0.1秒）
	for i in range(3):
		tween.tween_property(sprite, "modulate", Color(10, 10, 10, 1), 0.05)  # 变白
		tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.05)    # 恢复

	# 最后淡出消失
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)

	await tween.finished

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

	# 注意：velocity.x < 0 表示向左移动，此时翻转精灵
	# 这是因为敌人精灵资源默认朝向右边
	if sprite is Sprite2D:
		(sprite as Sprite2D).flip_h = velocity.x < 0
	elif sprite is AnimatedSprite2D:
		(sprite as AnimatedSprite2D).flip_h = velocity.x < 0

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
