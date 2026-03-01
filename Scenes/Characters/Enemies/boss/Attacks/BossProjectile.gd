extends Area2D
class_name BossProjectile

## Boss 弹幕 - 使用 HitBoxComponent 组件系统

@export var speed := 300.0
@export var lifetime := 5.0
@export var damage_config: Damage  # 可以在编辑器中配置伤害

var direction := Vector2.RIGHT
var velocity := Vector2.ZERO

@onready var hitbox: HitBoxComponent = $HitBoxComponent
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# 设置自动销毁
	var timer = get_tree().create_timer(lifetime)
	timer.timeout.connect(_on_lifetime_expired)

	# 如果有配置的伤害，应用到 HitBoxComponent
	if damage_config and hitbox:
		hitbox.damage = damage_config

func _physics_process(delta: float) -> void:
	velocity = direction * speed
	position += velocity * delta

## 设置弹幕方向
func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()
	rotation = direction.angle()

## 生命周期结束
func _on_lifetime_expired() -> void:
	queue_free()

## HitBoxComponent 碰撞到 HurtBoxComponent 后的回调
func _on_hitbox_hit() -> void:
	# 弹幕命中后销毁
	queue_free()
