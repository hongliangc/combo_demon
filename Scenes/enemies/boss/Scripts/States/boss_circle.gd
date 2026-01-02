extends BossState

## Boss 绕圈移动状态 - 保持距离并寻找攻击机会

@export var circle_speed_multiplier := 0.8

func enter():
	print("Boss: 进入绕圈状态")

func physics_process_state(delta: float) -> void:
	if not player or not player.alive:
		transitioned.emit(self, "patrol")
		return

	var distance = get_distance_to_player()

	# 离开检测范围
	if distance > boss.detection_radius:
		transitioned.emit(self, "patrol")
		return

	# 太近了，撤退
	if distance < boss.min_distance:
		transitioned.emit(self, "retreat")
		return

	# 攻击冷却完毕，可以攻击
	if boss.attack_cooldown <= 0:
		transitioned.emit(self, "attack")
		return

	# 绕圈移动逻辑
	var to_player = player.global_position - boss.global_position
	var desired_distance = (boss.attack_range + boss.min_distance) / 2

	# 计算切向（绕圈方向）
	var tangent = to_player.rotated(PI / 2 * boss.circle_direction).normalized()

	# 计算径向（接近或远离）
	var radial = to_player.normalized()
	var distance_factor = (distance - desired_distance) / 100.0

	# 组合切向和径向运动
	boss.velocity = (tangent + radial * distance_factor).normalized() * boss.move_speed * circle_speed_multiplier

	# 随机改变绕圈方向
	if randf() < 0.01:
		boss.circle_direction *= -1

func exit():
	pass
