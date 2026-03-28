extends BaseTrap
class_name SpinBlade

## 旋转刀刃 — 围绕中心点旋转的带刺转盘
## 难度：★★☆ | 效果：伤害 + 击飞

@export_group("旋转配置")
## 旋转速度（弧度/秒）
@export var rotation_speed: float = 2.0
## 刀刃数量
@export var blade_count: int = 2
## 刀刃长度（像素）
@export var blade_length: float = 48.0
## 刀刃宽度（像素）
@export var blade_width: float = 8.0

@onready var _pivot: Node2D = $Pivot

var _blades: Array[Node2D] = []

func _on_trap_ready() -> void:
	_create_blades()

func _process(delta: float) -> void:
	super._process(delta)
	if is_active:
		_pivot.rotation += rotation_speed * delta

func _create_blades() -> void:
	# 清除模板刀刃（场景中预留的）
	for child in _pivot.get_children():
		child.queue_free()

	var angle_step := TAU / blade_count
	for i in blade_count:
		var blade := Node2D.new()
		blade.rotation = angle_step * i
		_pivot.add_child(blade)

		# 视觉
		var visual := ColorRect.new()
		visual.size = Vector2(blade_length, blade_width)
		visual.position = Vector2(0, -blade_width * 0.5)
		visual.color = Color(0.9, 0.8, 0.1, 1.0)
		blade.add_child(visual)

		# 伤害区域
		var damage_zone := Area2D.new()
		damage_zone.collision_layer = 0
		damage_zone.collision_mask = 2
		blade.add_child(damage_zone)

		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(blade_length, blade_width)
		shape.shape = rect
		shape.position = Vector2(blade_length * 0.5, 0)
		damage_zone.add_child(shape)

		damage_zone.body_entered.connect(_on_blade_body_entered)
		_blades.append(blade)

func _on_blade_body_entered(body: Node2D) -> void:
	_apply_damage_to(body)
