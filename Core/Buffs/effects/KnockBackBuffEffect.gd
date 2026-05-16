# Core/Buffs/effects/KnockBackBuffEffect.gd
class_name KnockBackBuffEffect extends BuffEffect

## Sets horizontal velocity on a CharacterBody2D away from a source position.
## Target is derived from ctx.trigger (see plan amendment A1):
##   APPLY                    → ctx.owner pushed away from buff source_pos.
##   ON_DAMAGED / ON_HEAL     → ctx.damage_ctx.source pushed away from owner.

@export var force: float = 400.0

func _init() -> void:
	effect_on = EffectOn.APPLY

func execute(ctx: BuffEffectContext) -> void:
	var t: Node = _resolve_target(ctx)
	if not (t is CharacterBody2D):
		return
	var src_pos: Vector2 = _resolve_source_pos(ctx)
	var dir := ((t as Node2D).global_position - src_pos).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	(t as CharacterBody2D).velocity = Vector2(dir.x * force, (t as CharacterBody2D).velocity.y)

func _resolve_target(ctx: BuffEffectContext) -> Node:
	match ctx.trigger:
		EffectOn.ON_DAMAGED, EffectOn.ON_HEAL:
			return ctx.damage_ctx.source if ctx.damage_ctx else null
		_:
			return ctx.owner

func _resolve_source_pos(ctx: BuffEffectContext) -> Vector2:
	match ctx.trigger:
		EffectOn.ON_DAMAGED, EffectOn.ON_HEAL:
			# Attacker pushed away from owner (the one who got hit).
			return (ctx.owner as Node2D).global_position if ctx.owner is Node2D else ctx.instance.source_pos
		_:
			# APPLY/TICK/etc. — owner pushed away from buff source position.
			return ctx.instance.source_pos
