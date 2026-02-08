extends StaticBody2D
class_name MazeDoor

## 迷宫门组件 - 需要钥匙开启的门
##
## 功能：
## - 锁定/解锁状态
## - 玩家靠近时检查钥匙
## - 开门动画
## - 碰撞开关

signal unlocked()
signal opened()

@export var requires_key: bool = true
@export var key_count_required: int = 1
@export var auto_open_when_unlocked: bool = true
@export var locked_hint: String = "You need a key to open this door!"
@export var open_hint: String = "Press E to open"

var is_locked: bool = true
var is_open: bool = false
var player_in_range: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var interaction_area: Area2D = $InteractionArea


func _ready() -> void:
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

	_update_visuals()


func _input(event: InputEvent) -> void:
	if is_open or not player_in_range:
		return

	if event.is_action_pressed("interact"):
		try_open()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		_show_hint()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false


func _show_hint() -> void:
	if is_open:
		return

	if is_locked:
		UIManager.show_toast(locked_hint, 2.0, "warning")
	else:
		UIManager.show_toast(open_hint, 1.5, "info")


## 尝试开门
func try_open() -> void:
	if is_open:
		return

	if is_locked:
		if requires_key and LevelManager.has_key():
			# 使用钥匙解锁
			for i in key_count_required:
				if not LevelManager.use_key():
					UIManager.show_toast("Not enough keys!", 2.0, "error")
					return

			unlock()
		else:
			UIManager.show_toast(locked_hint, 2.0, "warning")
			return

	if not is_locked:
		open_door()


## 解锁门（不打开）
func unlock() -> void:
	if not is_locked:
		return

	is_locked = false
	unlocked.emit()
	_update_visuals()
	print("MazeDoor: Unlocked!")

	if auto_open_when_unlocked:
		open_door()


## 打开门
func open_door() -> void:
	if is_open or is_locked:
		return

	is_open = true
	opened.emit()

	# 播放开门动画
	_play_open_animation()

	# 禁用碰撞
	collision.set_deferred("disabled", true)

	print("MazeDoor: Opened!")


## 关闭门
func close_door() -> void:
	if not is_open:
		return

	is_open = false
	collision.set_deferred("disabled", false)
	_update_visuals()


func _play_open_animation() -> void:
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.3, 0.3)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.0, 0.1), 0.3)


func _update_visuals() -> void:
	if sprite:
		if is_locked:
			sprite.modulate = Color(0.8, 0.6, 0.4)  # 棕色锁定
		else:
			sprite.modulate = Color(0.6, 0.8, 0.6)  # 绿色解锁
