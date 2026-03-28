extends BossStateMachine

## Cyclops Boss 状态机 — 阶段路由逻辑

func _get_phase_route(new_phase: int) -> String:
	if not owner_node is BossBase or not target_node:
		return ""

	var boss := owner_node as BossBase

	match new_phase:
		BossBase.Phase.PHASE_2:
			if target_node and "alive" in target_node and target_node.alive:
				var distance := boss.global_position.distance_to(target_node.global_position)
				if distance <= boss.attack_range:
					return "circle" if states.has("circle") else "attack"
				return "chase"
		BossBase.Phase.PHASE_3:
			return "attack"
	return ""
