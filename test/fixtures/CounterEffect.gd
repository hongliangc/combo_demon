# test/fixtures/CounterEffect.gd
class_name CounterEffect extends BuffEffect

## Test fixture — increments a counter on its instance metadata.
## effect_on defaults to APPLY+TICK+EXPIRE for visibility.
@export var tick_interval: float = 0.0
@export var counter_key: StringName = &"counter"

func _init() -> void:
	effect_on = BuffEffect.EffectOn.APPLY | BuffEffect.EffectOn.TICK | BuffEffect.EffectOn.EXPIRE

func execute(ctx: BuffEffectContext) -> void:
	var key := String(counter_key) + "_" + str(ctx.trigger)
	var v: int = ctx.instance.tick_accums.get(key, 0)
	ctx.instance.tick_accums[key] = v + 1
