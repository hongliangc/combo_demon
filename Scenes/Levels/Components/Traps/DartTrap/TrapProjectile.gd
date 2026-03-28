extends Area2D
class_name TrapProjectile

## 机关抛射物 — 供 DartTrap 等发射类机关使用

var direction: Vector2 = Vector2.LEFT
var speed: float = 300.0
var damage: Damage = null
var lifetime: float = 5.0

var _timer: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_timer += delta
	if _timer >= lifetime:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerBase:
		var hurt_box: HurtBoxComponent = body.get_node_or_null("HurtBoxComponent")
		if hurt_box and damage:
			hurt_box.take_damage(damage, global_position)
	queue_free()
