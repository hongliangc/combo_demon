extends BossState

## Boss 巡逻状态

@export var patrol_speed_multiplier := 0.5

var target_patrol_point: Vector2

func enter():
	print("Boss: 进入巡逻状态")
	target_patrol_point = boss.get_next_patrol_point()

func physics_process_state(delta: float) -> void:
	# 检测玩家
	if player and player.alive and is_player_in_range(boss.detection_radius):
		transitioned.emit(self, "chase")
		return

	# 移动到巡逻点
	var direction = (target_patrol_point - boss.global_position).normalized()
	boss.velocity = direction * boss.move_speed * patrol_speed_multiplier

	# 到达巡逻点
	if boss.is_at_position(target_patrol_point):
		target_patrol_point = boss.get_next_patrol_point()
		# 到达后可以进入短暂的闲置
		if randf() < 0.3:  # 30% 概率停留一会
			transitioned.emit(self, "idle")

func exit():
	pass
