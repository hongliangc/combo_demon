class_name Princess extends AgentBase

## Princess — fixture AgentBase stub (no combat animations, not used in active levels yet)

func _setup_transitions() -> void:
	_register_rules([
		["*", "death", AIEvents.EV_DIED, "", 100],
	])
