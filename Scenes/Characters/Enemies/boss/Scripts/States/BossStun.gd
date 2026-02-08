extends "res://Core/StateMachine/CommonStates/StunState.gd"

## Boss 特定的眩晕状态
## 继承自 StunState，重载恢复逻辑以支持 Boss 的智能状态选择

## 重载：Boss 眩晕结束后的智能状态选择
## 根据距离、攻击冷却决定下一个状态
func decide_next_state() -> void:
	if owner_node is not Boss:
		super.decide_next_state()
		return

	var boss = owner_node as Boss

	# 眩晕结束，根据距离智能决定下一个状态
	if is_target_alive() and is_target_in_range(boss.detection_radius):
		var distance = get_distance_to_target()

		# 太近了，后退保持距离
		if distance < boss.min_distance:
			transition_to("retreat")
		# 在攻击范围内且冷却完毕，可以攻击
		elif distance <= boss.attack_range and boss.attack_cooldown <= 0:
			transition_to("attack")
		# 距离适中，绕圈移动
		elif distance <= boss.attack_range:
			transition_to("circle")
		# 太远了，追击
		else:
			transition_to("chase")
	else:
		transition_to("idle")
