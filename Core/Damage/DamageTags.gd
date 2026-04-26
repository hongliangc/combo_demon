# Core/Damage/DamageTags.gd
## Bitmask constants for DamageContext.tags. Combinable with bitwise OR.
class_name DamageTags

const PHYSICAL := 1
const MAGICAL  := 2
const DOT      := 4         # 跳过 HitState reaction
const CRIT     := 8
const TRUE     := 16        # 真伤，无视 INCOMING_DAMAGE 倍率
