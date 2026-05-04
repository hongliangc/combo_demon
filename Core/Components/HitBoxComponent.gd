extends Area2D
class_name HitBoxComponent

## Attack collision area. On HurtBox overlap, builds a DamageContext and
## drives the victim's DamagePipeline.

@export_group("伤害配置")
@export var damage: Damage = null

func _ready() -> void:
	if damage == null:
		damage = Damage.new()
	if not area_entered.is_connected(_on_hitbox_area_entered_):
		area_entered.connect(_on_hitbox_area_entered_)

func update_attack() -> void:
	if damage:
		damage.randomize_damage()

func get_attacker_position() -> Vector2:
	return global_position

func _on_hitbox_area_entered_(target: Area2D) -> void:
	update_attack()
	if not (target is HurtBoxComponent):
		return
	var attacker: Node = get_owner()
	var victim: Node = target.get_owner()
	if attacker == null or victim == null:
		return
	var pipe: DamagePipeline = victim.get_node_or_null(^"DamagePipeline")
	if pipe == null:
		return

	var ctx := DamageContext.new()
	ctx.source = attacker
	ctx.target = victim
	ctx.raw_amount = damage.amount
	ctx.amount = damage.amount
	ctx.tags = damage.tags
	ctx.attached_buffs = damage.effects.duplicate()
	DebugConfig.debug("[HitBox] %s→%s buffs=%d amt=%.1f" % [attacker.name, victim.name, ctx.attached_buffs.size(), ctx.amount], "", "combat")
	ctx.source_pos = get_attacker_position()

	var atk_bc: BuffController = attacker.get_node_or_null(^"BuffController")
	if atk_bc and (ctx.tags & DamageTags.TRUE) == 0:
		ctx.amount *= atk_bc.get_modifier(StatIds.OUTGOING_DAMAGE)

	pipe.process(ctx)
