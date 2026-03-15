extends Area2D
class_name TreasureChest

## 宝箱组件 - 可开启的宝箱，触发奖励
##
## 功能：
## - 玩家接近时可交互
## - 开箱动画
## - 解锁条件系统
## - 奖励配置
## - 通知LevelManager收集宝箱

signal opened()
signal unlock_condition_failed(condition: String)

@export_enum("small", "big") var chest_size: String = "small"
@export var interaction_hint: String = "Press E to open"

@export_group("Rewards")
@export var reward_gold: int = 10
@export var reward_items: Array[String] = []  # 未来扩展：装备等

@export_group("Unlock Condition")
@export var is_locked: bool = false
@export var unlock_condition: String = ""  # 例如: "defeat_boars_region2"
@export var unlock_hint: String = "This chest is locked"

var is_opened: bool = false
var player_in_range: bool = false
var _unlock_condition_met: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_setup_sprite()

	# 如果有解锁条件，检查初始状态
	if is_locked and not unlock_condition.is_empty():
		_check_unlock_condition()


func _setup_sprite() -> void:
	if sprite:
		# 宝箱纹理包含2帧：0=关闭，1=打开
		sprite.hframes = 2
		sprite.frame = 0  # 初始显示关闭状态

		if chest_size == "big":
			sprite.texture = preload("res://Assets/Art/Ninja_Adventure/Items/Treasure/BigTreasureChest.png")
		else:
			sprite.texture = preload("res://Assets/Art/Ninja_Adventure/Items/Treasure/LittleTreasureChest.png")


func _input(event: InputEvent) -> void:
	if is_opened or not player_in_range:
		return

	if event.is_action_pressed("interact"):
		if is_locked and not _unlock_condition_met:
			_show_locked_message()
			unlock_condition_failed.emit(unlock_condition)
		else:
			open_chest()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		_show_interaction_hint()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		_hide_interaction_hint()


func _show_interaction_hint() -> void:
	if not is_opened:
		UIManager.show_toast(interaction_hint, 1.5, "info")


func _hide_interaction_hint() -> void:
	pass


## 开启宝箱
func open_chest() -> void:
	if is_opened:
		return

	is_opened = true
	opened.emit()

	# 禁用碰撞
	if collision:
		collision.set_deferred("disabled", true)

	# 播放开箱动画
	_play_open_animation()

	# 通知LevelManager
	LevelManager.collect_item("treasure")

	# 生成奖励特效
	await _spawn_reward_effect()

	# 开箱后完全移除宝箱
	await get_tree().create_timer(0.5).timeout
	queue_free()


func _play_open_animation() -> void:
	if animation_player and animation_player.has_animation("open"):
		animation_player.play("open")
	else:
		# 切换到打开状态（第2帧）
		if sprite:
			sprite.frame = 1

		# 简单的缩放和消失动画
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)  # 完全透明


func _spawn_reward_effect() -> void:
	# 简单的粒子效果（如果有的话）
	var particles = GPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 8
	particles.lifetime = 0.5
	particles.global_position = global_position
	get_tree().current_scene.add_child(particles)

	# 生成金币奖励
	if reward_gold > 0:
		LevelManager.collected_coins += reward_gold
		UIManager.show_toast("+%d Gold" % reward_gold, 1.5, "success")

	# 自动清理
	await get_tree().create_timer(1.0).timeout
	particles.queue_free()


## 检查解锁条件
func _check_unlock_condition() -> void:
	"""检查解锁条件是否满足"""
	if unlock_condition.is_empty():
		_unlock_condition_met = true
		return

	# 根据条件类型检查
	match unlock_condition:
		"defeat_boars_region2":
			# 这个需要通过信号或事件系统来触发
			_unlock_condition_met = false
		"defeat_dinosaur":
			_unlock_condition_met = false
		_:
			# 未知条件，默认解锁
			_unlock_condition_met = true


## 手动解锁宝箱（由外部调用）
func unlock() -> void:
	"""解锁宝箱"""
	if not is_locked:
		return

	_unlock_condition_met = true
	is_locked = false

	# 播放解锁特效
	_play_unlock_effect()

	DebugConfig.info("Chest unlocked: %s" % name, "", "level")


func _play_unlock_effect() -> void:
	"""播放解锁特效"""
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(1, 1, 0, 1), 0.2)
		tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.2)


func _show_locked_message() -> void:
	"""显示宝箱锁定提示"""
	if not unlock_hint.is_empty():
		UIManager.show_toast(unlock_hint, 2.0, "warning")
	else:
		UIManager.show_toast("This chest is locked!", 2.0, "warning")
