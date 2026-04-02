extends BossStateMachine
class_name BKStateMachine

## BladeKeeper 状态机 — 阶段路由

func _get_phase_route(new_phase: int) -> String:
	match new_phase:
		BossBase.Phase.PHASE_2:
			return "chase"
		BossBase.Phase.PHASE_3:
			return "attack"
	return ""
