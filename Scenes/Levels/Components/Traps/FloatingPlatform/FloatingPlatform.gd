extends AnimatableBody2D
class_name FloatingPlatform

## 浮动平台 — 上下或左右循环移动
## 难度：★☆☆ | 无伤害，纯移动挑战

@export_group("移动配置")
## 相对起点的移动偏移量
@export var move_offset: Vector2 = Vector2(0, -80)
## 移动速度（像素/秒）
@export var move_speed: float = 50.0
## 到达端点后等待时长
@export var wait_time: float = 1.0

var _origin: Vector2

func _ready() -> void:
	sync_to_physics = true
	_origin = position
	_start_loop()

func _start_loop() -> void:
	var target := _origin + move_offset
	var duration := move_offset.length() / move_speed
	while is_inside_tree():
		var t1 := create_tween()
		t1.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await t1.finished
		if not is_inside_tree():
			return
		await get_tree().create_timer(wait_time).timeout
		if not is_inside_tree():
			return
		var t2 := create_tween()
		t2.tween_property(self, "position", _origin, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await t2.finished
		if not is_inside_tree():
			return
		await get_tree().create_timer(wait_time).timeout
		if not is_inside_tree():
			return
