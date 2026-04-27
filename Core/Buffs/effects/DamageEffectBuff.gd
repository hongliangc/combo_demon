# Core/Buffs/effects/DamageEffectBuff.gd
class_name DamageEffectBuff extends BuffEffect

## Routes a damage hit through the target's DamagePipeline.
## Used for DoT (TICK) and reactive damage (ON_DAMAGED, e.g. thorns).

@export var amount: float = 5.0
@export var tick_interval: float = 0.5
@export var damage_tags: int = 0          # caller may add DOT explicitly
@export var target_kind: int = 0          # 0=self, 1=source (反伤)

func _init() -> void:
	effect_on = EffectOn.TICK

func execute(ctx: BuffEffectContext) -> void:
	var t: Node = _resolve_target(ctx)
	if t == null:
		return
	var pipe: DamagePipeline = t.get_node_or_null(^"DamagePipeline")
	if pipe == null:
		return
	var dc := DamageContext.new()
	dc.target = t
	dc.source = ctx.instance.source_actor
	dc.raw_amount = amount
	dc.amount = amount
	dc.tags = damage_tags
	if ctx.trigger == EffectOn.TICK:
		dc.tags |= DamageTags.DOT
	if ctx.instance.source_actor is Node2D:
		dc.source_pos = (ctx.instance.source_actor as Node2D).global_position
	else:
		dc.source_pos = ctx.instance.source_pos
	pipe.process(dc)

func _resolve_target(ctx: BuffEffectContext) -> Node:
	if target_kind == 1 and ctx.damage_ctx and ctx.damage_ctx.source:
		return ctx.damage_ctx.source
	return ctx.owner
