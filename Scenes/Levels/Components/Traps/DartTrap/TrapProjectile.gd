extends Area2D
class_name TrapProjectile

## 机关抛射物 — 供 DartTrap 等发射类机关使用

var direction: Vector2 = Vector2.LEFT
var speed: float = 300.0
var damage_amount: float = 0.0
var attached_buffs: Array[BuffEntity] = []
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
	if body.is_in_group(&"player"):
		# v2 伤害路径: 经受击者的 DamagePipeline (旧 HurtBox.take_damage 已废弃)
		var pipe: DamagePipeline = body.get_node_or_null(^"DamagePipeline")
		if pipe:
			var ctx := DamageContext.new()
			ctx.source = self
			ctx.target = body
			ctx.raw_amount = damage_amount
			ctx.amount = damage_amount
			ctx.tags = DamageTags.PHYSICAL
			ctx.source_pos = global_position
			ctx.attached_buffs = attached_buffs
			pipe.process(ctx)
	queue_free()
