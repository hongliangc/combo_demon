extends BossState

## Boss 巡逻状态

@export var patrol_speed_multiplier := 0.5

var target_patrol_point: Vector2

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true
	animation_state = "patrol"

func enter():
	if _boss:
		target_patrol_point = _boss.get_next_patrol_point()

func physics_process_state(_delta: float) -> void:
	if not _boss:
		return

	# 检测玩家
	if is_target_alive() and is_target_in_range(_boss.detection_radius):
		transitioned.emit(self, "chase")
		return

	# 移动到巡逻点
	var direction := (target_patrol_point - _boss.global_position).normalized()
	var cyclops := _boss as Cyclops
	_boss.velocity = direction * (cyclops.move_speed if cyclops else 150.0) * patrol_speed_multiplier

	# 到达巡逻点
	if _boss.is_at_position(target_patrol_point):
		target_patrol_point = _boss.get_next_patrol_point()
		# 到达后可以进入短暂的闲置
		if randf() < 0.3:  # 30% 概率停留一会
			transitioned.emit(self, "idle")

func exit():
	pass
