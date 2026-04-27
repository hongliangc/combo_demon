# Core/Buffs/effects/HealEffectBuff.gd
class_name HealEffectBuff extends BuffEffect

## HoT — periodic heal routed through pipeline as is_heal=true.

@export var amount: float = 5.0
@export var tick_interval: float = 0.5

func _init() -> void:
	effect_on = EffectOn.TICK

func execute(ctx: BuffEffectContext) -> void:
	if ctx.owner == null:
		return
	var pipe: DamagePipeline = ctx.owner.get_node_or_null(^"DamagePipeline")
	if pipe == null:
		return
	var dc := DamageContext.new()
	dc.target = ctx.owner
	dc.is_heal = true
	dc.raw_amount = amount
	dc.amount = amount
	pipe.process(dc)
