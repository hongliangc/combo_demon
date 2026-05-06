class_name HahashinSpecialAttackState extends AIState

## 特殊攻击状态 — 1.4a 占位桩，暂时 no-op。
## 1.4a 将替换为 V-skill VFX 流程。

func enter() -> void:
	push_warning("HahashinSpecialAttackState: stub — no-op until 1.4a")
	dispatch(AIEvents.EV_ATTACK_FINISHED)
