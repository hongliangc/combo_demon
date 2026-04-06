extends Area2D
class_name BKSwordProjectile

## 剑气投射物 — 直线飞行，命中播放 land 动画后消失

@export var speed := 400.0
@export var lifetime := 4.0
@export var damage_config: Damage

var _direction := Vector2.RIGHT
var _lifetime_timer: SceneTreeTimer
var _landed := false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	_sprite.play("throw")
	_lifetime_timer = get_tree().create_timer(lifetime)
	_lifetime_timer.timeout.connect(_play_land)

func set_direction(dir: Vector2) -> void:
	_direction = dir.normalized()
	rotation = dir.angle()

func _physics_process(delta: float) -> void:
	if _landed:
		return
	position += _direction * speed * delta

func _play_land() -> void:
	if _landed:
		return
	_landed = true
	_sprite.play("land")
	_sprite.animation_finished.connect(queue_free)

func _on_hitbox_area_entered(_area: Area2D) -> void:
	_play_land()
