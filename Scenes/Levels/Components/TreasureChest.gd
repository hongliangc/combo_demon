extends Area2D
class_name TreasureChest

## 宝箱组件 - 可开启的宝箱，触发奖励
##
## 功能：
## - 玩家接近时可交互
## - 开箱动画
## - 通知LevelManager收集宝箱

signal opened()

@export_enum("small", "big") var chest_size: String = "small"
@export var interaction_hint: String = "Press E to open"

var is_opened: bool = false
var player_in_range: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_setup_sprite()


func _setup_sprite() -> void:
	if sprite:
		if chest_size == "big":
			sprite.texture = preload("res://Assets/Art/Ninja_Adventure/Items/Treasure/BigTreasureChest.png")
		else:
			sprite.texture = preload("res://Assets/Art/Ninja_Adventure/Items/Treasure/LittleTreasureChest.png")


func _input(event: InputEvent) -> void:
	if is_opened or not player_in_range:
		return

	if event.is_action_pressed("interact"):
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

	# 播放开箱动画
	_play_open_animation()

	# 通知LevelManager
	LevelManager.collect_item("treasure")

	# 生成奖励特效
	_spawn_reward_effect()


func _play_open_animation() -> void:
	if animation_player and animation_player.has_animation("open"):
		animation_player.play("open")
	else:
		# 简单的缩放动画
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
		tween.tween_property(sprite, "modulate:a", 0.5, 0.3)


func _spawn_reward_effect() -> void:
	# 简单的粒子效果（如果有的话）
	var particles = GPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 8
	particles.lifetime = 0.5
	particles.global_position = global_position
	get_tree().current_scene.add_child(particles)

	# 自动清理
	await get_tree().create_timer(1.0).timeout
	particles.queue_free()
