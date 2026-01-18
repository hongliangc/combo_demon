extends "res://Util/StateMachine/CommonStates/stun_state.gd"

## Boss 特定的眩晕状态
## 继承自 StunState，包含击飞/击退物理模拟
## 重载恢复逻辑以支持 Boss 的智能状态选择

## 重载：Boss 眩晕结束后的智能状态选择
## 根据距离、攻击冷却决定下一个状态
func on_timeout() -> void:
	if owner_node is not Boss:
		# 回退到默认逻辑
		super.on_timeout()
		return

	var boss = owner_node as Boss

	# 眩晕结束，根据距离智能决定下一个状态
	if is_target_alive() and is_target_in_range(boss.detection_radius):
		var distance = get_distance_to_target()

		# 太近了，后退保持距离
		if distance < boss.min_distance:
			transitioned.emit(self, "retreat")
		# 在攻击范围内且冷却完毕，可以攻击
		elif distance <= boss.attack_range and boss.attack_cooldown <= 0:
			transitioned.emit(self, "attack")
		# 距离适中，绕圈移动
		elif distance <= boss.attack_range:
			transitioned.emit(self, "circle")
		# 太远了，追击
		else:
			transitioned.emit(self, "chase")
	else:
		transitioned.emit(self, "idle")


## Boss 眩晕时间重置提示
func on_damaged(damage: Damage) -> void:
	super.on_damaged(damage)
	print("[Boss Stun] 眩晕时间重置")
