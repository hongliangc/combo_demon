# Core/Buffs/BuffEffectContext.gd
class_name BuffEffectContext extends RefCounted

## Per-effect execution context. Filled by BuffController._exec_effect.

var owner: Node = null                  # buff 持有者
var instance: BuffInstance = null       # 当前 buff 实例
var trigger: int = 0                    # 当前 EffectOn 位
var damage_ctx: DamageContext = null    # 仅 ON_DAMAGED/ON_ATTACK/ON_HEAL 时填
var delta: float = 0.0                  # 仅 TICK 时填
