# Core/Damage/DamagePipeline.gd
class_name DamagePipeline extends Node

## Signal hub for damage / heal flow.
## Stages emit in order: pre_calc → pre_apply → apply → post_apply → react.
## Any subscriber may set ctx.blocked = true to short-circuit before apply.

signal pre_calc(ctx: DamageContext)
signal pre_apply(ctx: DamageContext)
signal apply(ctx: DamageContext)
signal post_apply(ctx: DamageContext)
signal react(ctx: DamageContext)

func process(ctx: DamageContext) -> void:
	if ctx == null:
		return
	pre_calc.emit(ctx)
	if ctx.blocked: return
	pre_apply.emit(ctx)
	if ctx.blocked: return
	apply.emit(ctx)
	post_apply.emit(ctx)
	react.emit(ctx)
