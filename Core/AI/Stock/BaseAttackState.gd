# Core/AI/Stock/BaseAttackState.gd
extends AIState
class_name BaseAttackState

## 攻击/组合状态公共基类：方向解析 + 收尾流程

func _finish() -> void:
	var gcd: float = 0.3
	if ai.current_skill:
		gcd = ai.current_skill.params.get(&"global_cooldown", 0.3)
	bb.set_var(&"global_cooldown", gcd)
	ai.current_skill = null
	dispatch(AIEvents.EV_ATTACK_FINISHED)

func _resolve_direction(dir_key: StringName) -> float:
	if not owner_node is Node2D:
		return 0.0
	match dir_key:
		&"forward":
			if "sprite" in owner_node and owner_node.sprite and "flip_h" in owner_node.sprite:
				return -1.0 if owner_node.sprite.flip_h else 1.0
			return 1.0
		&"backward":
			if "sprite" in owner_node and owner_node.sprite and "flip_h" in owner_node.sprite:
				return 1.0 if owner_node.sprite.flip_h else -1.0
			return -1.0
		&"toward_target":
			var tp: Vector2 = bb.get_var(&"target_position", (owner_node as Node2D).global_position)
			return sign(tp.x - (owner_node as Node2D).global_position.x)
		&"away_from_target":
			var tp: Vector2 = bb.get_var(&"target_position", (owner_node as Node2D).global_position)
			return -sign(tp.x - (owner_node as Node2D).global_position.x)
	return 0.0
