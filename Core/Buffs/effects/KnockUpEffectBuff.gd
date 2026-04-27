# Core/Buffs/effects/KnockUpEffectBuff.gd
class_name KnockUpEffectBuff extends BuffEffect

## Sets vertical velocity (upward) and a horizontal push on a CharacterBody2D.
@export var vertical_force: float = -500.0
@export var horizontal_force: float = 200.0

func _init() -> void:
	effect_on = EffectOn.APPLY

func execute(ctx: BuffEffectContext) -> void:
	var t: Node = ctx.owner
	if not (t is CharacterBody2D):
		return
	var src_pos: Vector2 = ctx.instance.source_pos
	if ctx.damage_ctx:
		src_pos = ctx.damage_ctx.source_pos
	var dir_x := signf((t as Node2D).global_position.x - src_pos.x)
	if dir_x == 0.0:
		dir_x = 1.0
	(t as CharacterBody2D).velocity = Vector2(dir_x * horizontal_force, vertical_force)
