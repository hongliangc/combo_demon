# Core/Buffs/BuffEffect.gd
class_name BuffEffect extends Resource

## Base for all buff effect strategies.
## Subclasses override execute(ctx). EffectOn bitmask controls when execute runs.

enum EffectOn {
	APPLY      = 1,    # buff 入栈瞬间
	TICK       = 2,    # 每 tick_interval（Effect 自管间隔）
	EXPIRE     = 4,    # buff 移除（duration / dispel / 死亡）
	STACK      = 8,    # 叠层时
	ON_DAMAGED = 16,   # 持有者受击 callback
	ON_ATTACK  = 32,   # 持有者攻击 callback
	ON_HEAL    = 64,   # 持有者受治疗 callback
}

@export_flags("Apply", "Tick", "Expire", "Stack", "OnDamaged", "OnAttack", "OnHeal")
var effect_on: int = EffectOn.APPLY

func execute(_ctx: BuffEffectContext) -> void:
	pass  # 子类实现
