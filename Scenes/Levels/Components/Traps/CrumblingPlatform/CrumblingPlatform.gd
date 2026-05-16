extends AnimatableBody2D
class_name CrumblingPlatform

## 消失平台 — 踩上后抖动，延迟碎裂消失，定时重生
## 难度：★★★ | 无伤害，坠落危险

enum State { SOLID, SHAKING, GONE, RESPAWNING }

@export_group("消失配置")
## 抖动时长
@export var shake_time: float = 0.8
## 抖动幅度（像素）
@export var shake_amplitude: float = 2.0
## 消失后重生时长
@export var respawn_time: float = 4.0

var _state: State = State.SOLID
var _origin: Vector2

@onready var _visual: ColorRect = $Visual
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _detect_zone: Area2D = $DetectZone

func _ready() -> void:
	sync_to_physics = true
	_origin = position
	_detect_zone.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player") and _state == State.SOLID:
		_start_shake()

func _start_shake() -> void:
	_state = State.SHAKING
	# 抖动效果
	var tween := create_tween()
	var shakes := int(shake_time / 0.08)
	for i in shakes:
		var offset := Vector2(randf_range(-shake_amplitude, shake_amplitude), 0)
		tween.tween_property(self, "position", _origin + offset, 0.04)
		tween.tween_property(self, "position", _origin, 0.04)
	await tween.finished
	if not is_inside_tree():
		return
	_crumble()

func _crumble() -> void:
	_state = State.GONE
	_visual.visible = false
	_collision.set_deferred("disabled", true)
	_detect_zone.set_deferred("monitoring", false)
	# 等待重生
	await get_tree().create_timer(respawn_time).timeout
	if not is_inside_tree():
		return
	_respawn()

func _respawn() -> void:
	_state = State.RESPAWNING
	position = _origin
	_collision.set_deferred("disabled", false)
	_detect_zone.set_deferred("monitoring", true)
	# 渐显效果
	_visual.visible = true
	_visual.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_visual, "modulate:a", 1.0, 0.3)
	await tween.finished
	_state = State.SOLID
