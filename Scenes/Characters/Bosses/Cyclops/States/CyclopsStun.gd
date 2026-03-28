extends "res://Core/StateMachine/CommonStates/StunState.gd"

## Boss 特定的眩晕状态
## 继承自 StunState，重载恢复逻辑以支持 Boss 的智能状态选择

## 眩晕恢复后的免疫时间（防止 stunlock）
@export var stun_immunity_duration := 1.5

func exit() -> void:
	super.exit()
	if owner_node is BossBase:
		(owner_node as BossBase).stun_immunity = stun_immunity_duration

## 重载：Boss 眩晕结束后的智能状态选择
## 使用 BossState.evaluate_combat_transition() 统一距离决策
func decide_next_state() -> void:
	# BossStun 继承 StunState（非 BossState），需要手动查找 BossAttack 来访问决策逻辑
	# 但我们可以直接内联简化版决策，因为 StunState 不继承 BossState
	if owner_node is not BossBase:
		super.decide_next_state()
		return

	var boss := owner_node as BossBase

	if not is_target_alive():
		transition_to("patrol")
		return

	var distance := get_distance_to_target()

	if distance > boss.detection_radius:
		transition_to("patrol")
	elif distance < boss.min_distance:
		transition_to("retreat")
	elif distance <= boss.attack_range and boss.attack_cooldown <= 0:
		transition_to("attack")
	elif distance <= boss.attack_range:
		transition_to("circle")
	elif distance <= boss.detection_radius:
		transition_to("chase")
	else:
		transition_to("idle")
