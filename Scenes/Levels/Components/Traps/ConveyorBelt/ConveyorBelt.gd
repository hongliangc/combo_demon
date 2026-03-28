extends AnimatableBody2D
class_name ConveyorBelt

## 传送带 — 对站在上面的玩家施加持续推力
## 难度：★★☆ | 效果：强制位移

@export_group("传送带配置")
## 推送方向（归一化）
@export var push_direction: Vector2 = Vector2.RIGHT
## 推力大小（像素/秒²）
@export var push_force: float = 80.0

@onready var _push_zone: Area2D = $PushZone

func _ready() -> void:
	sync_to_physics = true

func _physics_process(_delta: float) -> void:
	for body in _push_zone.get_overlapping_bodies():
		if body is PlayerBase:
			body.velocity += push_direction.normalized() * push_force * _delta
