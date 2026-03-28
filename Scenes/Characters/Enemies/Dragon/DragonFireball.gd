extends Area2D
class_name DragonFireball

## 龙的火球弹射物
## 沿指定方向飞行，命中玩家施加伤害，2 秒后消失

@export var speed := 180.0
@export var damage_amount := 10.0
@export var lifetime := 2.0

var _direction := Vector2.RIGHT
var _hit := false


func setup(direction: Vector2, _attacker_pos: Vector2) -> void:
	_direction = direction.normalized()
	modulate = Color(1.5, 0.5, 0.1, 1.0)


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	# 生命倒计时
	var life_timer := get_tree().create_timer(lifetime)
	life_timer.timeout.connect(queue_free)
	# 精灵帧循环动画
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		var frame_tween := create_tween().set_loops()
		frame_tween.tween_method(func(f: int) -> void: sprite.frame = f, 0, 3, 0.12)


func _physics_process(delta: float) -> void:
	if _hit:
		return
	global_position += _direction * speed * delta
	# 朝飞行方向旋转（视觉对齐）
	rotation = _direction.angle()


func _on_area_entered(area: Area2D) -> void:
	if _hit:
		return
	if area is HurtBoxComponent:
		_hit = true
		var dmg := Damage.new()
		dmg.amount = damage_amount
		dmg.min_amount = damage_amount
		dmg.max_amount = damage_amount
		area.take_damage(dmg, global_position)
		queue_free()
