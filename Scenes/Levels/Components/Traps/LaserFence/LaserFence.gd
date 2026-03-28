extends BaseTrap
class_name LaserFence

## 激光栅栏 — 两点之间周期性开关的能量光束
## 难度：★★★ | 效果：高伤害 + 眩晕

@export_group("激光配置")
## 激光终点（相对于自身位置）
@export var end_point: Vector2 = Vector2(0, -80)
## 激光开启持续时长
@export var on_duration: float = 2.0
## 激光关闭持续时长
@export var off_duration: float = 2.5
## 开启前预警时长（闪烁）
@export var warn_time: float = 0.8
## 激光宽度
@export var laser_width: float = 3.0

@onready var _line: Line2D = $LaserLine
@onready var _damage_zone: Area2D = $DamageZone

func _on_trap_ready() -> void:
	_damage_zone.body_entered.connect(_on_body_entered)
	# 设置激光视觉
	_line.points = PackedVector2Array([Vector2.ZERO, end_point])
	_line.width = laser_width
	_line.default_color = Color(0.3, 0.5, 1.0, 1.0)
	# 设置碰撞形状覆盖激光线段
	_setup_collision()
	_line.visible = false
	_damage_zone.set_deferred("monitoring", false)
	is_active = false
	_start_cycle()

func _on_body_entered(body: Node2D) -> void:
	_apply_damage_to(body)

func _setup_collision() -> void:
	var shape_node: CollisionShape2D = _damage_zone.get_node("CollisionShape2D")
	var rect := RectangleShape2D.new()
	var length := end_point.length()
	rect.size = Vector2(length, laser_width * 2.0)
	shape_node.shape = rect
	shape_node.position = end_point * 0.5
	shape_node.rotation = end_point.angle()

func _start_cycle() -> void:
	while is_inside_tree():
		# 关闭期
		await get_tree().create_timer(off_duration).timeout
		if not is_inside_tree():
			return
		# 预警闪烁
		await _warn_blink()
		if not is_inside_tree():
			return
		# 开启
		_line.visible = true
		_line.default_color = Color(0.3, 0.5, 1.0, 1.0)
		is_active = true
		_damage_zone.set_deferred("monitoring", true)
		await get_tree().create_timer(on_duration).timeout
		if not is_inside_tree():
			return
		# 关闭
		_line.visible = false
		is_active = false
		_damage_zone.set_deferred("monitoring", false)

func _warn_blink() -> void:
	var blinks := int(warn_time / 0.15)
	for i in blinks:
		_line.visible = i % 2 == 0
		_line.default_color = Color(0.3, 0.5, 1.0, 0.4)
		await get_tree().create_timer(0.15).timeout
		if not is_inside_tree():
			return
	_line.visible = false
