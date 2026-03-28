extends Area2D
class_name BKSwordProjectile

## 剑气投射物 — 直线飞行，命中消失

@export var speed := 400.0
@export var lifetime := 4.0
@export var damage_config: Damage

var _direction := Vector2.RIGHT
var _lifetime_timer: SceneTreeTimer

func _ready() -> void:
	_lifetime_timer = get_tree().create_timer(lifetime)
	_lifetime_timer.timeout.connect(queue_free)

func set_direction(dir: Vector2) -> void:
	_direction = dir.normalized()
	rotation = dir.angle()

func _physics_process(delta: float) -> void:
	position += _direction * speed * delta
