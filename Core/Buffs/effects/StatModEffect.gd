# Core/Buffs/effects/StatModEffect.gd
class_name StatModEffect extends BuffEffect

## Adjusts a multiplicative stat modifier on the owner's BuffController.
## Default effect_on = APPLY|EXPIRE — net-zero pairing.

@export var stat_id: StringName = StatIds.INCOMING_DAMAGE
@export var multiplier: float = 1.0

func _init() -> void:
	effect_on = EffectOn.APPLY | EffectOn.EXPIRE

func execute(ctx: BuffEffectContext) -> void:
	var bc: BuffController = ctx.owner.get_node_or_null(^"BuffController") if ctx.owner else null
	if bc == null:
		return
	if ctx.trigger == EffectOn.APPLY:
		bc.add_stat_modifier(stat_id, multiplier)
	elif ctx.trigger == EffectOn.EXPIRE:
		bc.remove_stat_modifier(stat_id, multiplier)
