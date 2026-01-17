extends "res://Util/StateMachine/CommonStates/stun_state.gd"

## Boss Stun 状态 - 使用通用 StunState 模板
## 重载恢复逻辑以支持 Boss 的阶段系统和智能状态选择

func _ready():
	# 眩晕时长
	stun_duration = 0.5

	# 受伤重置眩晕时间
	reset_on_damage = true

	# 移动设置
	stop_movement = true
	deceleration_rate = 5.0

	# 启用自定义恢复逻辑
	custom_recovery_logic = true


func enter():
	print("Boss: 进入眩晕状态")
	super.enter()

	# Boss 特有：设置 stunned 标志
	if owner_node is Boss:
		var boss = owner_node as Boss
		boss.stunned = true


func exit():
	# Boss 特有：清除 stunned 标志
	if owner_node is Boss:
		var boss = owner_node as Boss
		boss.stunned = false


## 重载：Boss 眩晕结束后的智能状态选择
## 根据距离、攻击冷却和阶段决定下一个状态
func on_stun_end() -> void:
	if owner_node is not Boss:
		# 回退到默认逻辑
		super.on_stun_end()
		return

	var boss = owner_node as Boss

	# 眩晕结束，根据距离和阶段智能决定下一个状态
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
func on_damaged(damage: Damage):
	super.on_damaged(damage)
	print("Boss 眩晕时间重置")
