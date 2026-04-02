extends Area2D
class_name DSShockwave

## DemonSlime 冲击波 — 支持扇形和圆形模式

@export var damage_config: Damage
@export var shockwave_lifetime := 0.5

var _mode := "ring"  # "fan" or "ring"
var _fan_direction := Vector2.RIGHT
var _fan_angle := deg_to_rad(120)
var _radius := 200.0

func setup_fan(direction: Vector2, angle: float, radius: float) -> void:
	_mode = "fan"
	_fan_direction = direction.normalized()
	_fan_angle = angle
	_radius = radius
	_update_collision()

func setup_ring(radius: float) -> void:
	_mode = "ring"
	_radius = radius
	_update_collision()

func _update_collision() -> void:
	var shape := $CollisionShape2D
	if shape and shape.shape is CircleShape2D:
		(shape.shape as CircleShape2D).radius = _radius

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var timer: SceneTreeTimer = get_tree().create_timer(shockwave_lifetime)
	timer.timeout.connect(queue_free)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	# 扇形模式：检查角度
	if _mode == "fan":
		var to_body := (body.global_position - global_position).normalized()
		var angle_diff: float = absf(_fan_direction.angle_to(to_body))
		if angle_diff > _fan_angle / 2.0:
			return  # 不在扇形范围内

	# 应用伤害（通过 HurtBoxComponent）
	if damage_config:
		for child in body.get_children():
			if child.has_method("take_damage"):
				child.take_damage(damage_config.duplicate(true), global_position)
				break
