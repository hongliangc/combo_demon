# Core/Buffs/BuffEntity.gd
class_name BuffEntity extends Resource

## Immutable buff configuration. Multiple instances share the same Resource.

enum Stacking { REFRESH, STACK, REPLACE }

@export var id: StringName = &""
@export var duration: float = 0.0          # 0 = 永久
@export var stacking: Stacking = Stacking.REFRESH
@export var max_stacks: int = 99

@export_flags("Physical", "Magical", "Curse", "Bleed", "Poison")
var tags: int = 0

@export_flags("Attack", "Move", "Defend", "Cast", "Hurtable")
var legal_action_locks: int = 0

@export var hit_reaction: StringName = &""
@export var hit_priority: int = 0
@export var hit_lock_duration: float = 0.0

@export var effects: Array[BuffEffect] = []

## Run all effects whose effect_on bitmask matches the given trigger.
func execute_on(trigger: int, ctx: BuffEffectContext) -> void:
	for e in effects:
		if e and (e.effect_on & trigger) != 0:
			ctx.trigger = trigger
			e.execute(ctx)
