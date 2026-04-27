extends Resource
class_name Damage

## Damage payload — drives DamagePipeline.process via HitBoxComponent.
## v2: effects holds BuffEntity resources; tags is a DamageTags bitmask.

@export_group("伤害配置")
@export var max_amount: float = 50.0
@export var min_amount: float = 1.0
@export var amount: float = 10.0

## DamageTags bitmask (Physical / Magical / DOT / Crit / True)
@export_flags("Physical", "Magical", "DOT", "Crit", "True")
var tags: int = 0

@export_group("Buffs")
## Buffs attached to this hit. Pipeline post_apply step inserts them into target's BuffController.
@export var effects: Array[BuffEntity] = []

static var _rng: RandomNumberGenerator = null

func randomize_damage() -> void:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	amount = _rng.randf_range(min_amount, max_amount)

func debug_print() -> void:
	print("[Damage] amount=", amount, " tags=", tags, " buffs=", effects.size())
