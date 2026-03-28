extends BossState

## Boss 绕圈移动状态 - 保持距离并寻找攻击机会

@export var circle_speed_multiplier := 0.8

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true
	animation_state = "circle"

func enter():
	pass

func physics_process_state(_delta: float) -> void:
	if not _boss or target_node is not Node2D:
		return

	# 统一距离决策
	var next := evaluate_combat_transition()
	if next != "circle":
		transitioned.emit(self, next)
		return

	var cyclops := _boss as Cyclops
	if not cyclops:
		return

	# 绕圈移动逻辑
	var player_pos := (target_node as Node2D).global_position
	var to_player := player_pos - _boss.global_position
	var desired_distance := (_boss.attack_range + _boss.min_distance) / 2.0
	var distance := get_distance_to_target()

	# 计算切向（绕圈方向）
	var tangent := to_player.rotated(PI / 2.0 * cyclops.circle_direction).normalized()

	# 计算径向（接近或远离）
	var radial := to_player.normalized()
	var distance_factor := (distance - desired_distance) / 100.0

	# 组合切向和径向运动
	_boss.velocity = (tangent + radial * distance_factor).normalized() * cyclops.move_speed * circle_speed_multiplier

	# 随机改变绕圈方向
	if randf() < 0.01:
		cyclops.circle_direction *= -1

func exit():
	pass
