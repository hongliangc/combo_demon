extends BossState

## Boss 闲置状态

@export var idle_duration := 2.0

var timer := 0.0

func enter():
	print("Boss: 进入闲置状态")
	timer = idle_duration

func physics_process_state(delta: float) -> void:
	# 减速到停止
	boss.velocity = boss.velocity.lerp(Vector2.ZERO, 5.0 * delta)

	timer -= delta
	if timer <= 0:
		# 闲置结束，尝试寻找玩家
		if player and player.alive:
			var distance = get_distance_to_player()
			if distance <= boss.detection_radius:
				transitioned.emit(self, "chase")
			else:
				transitioned.emit(self, "patrol")
		else:
			transitioned.emit(self, "patrol")

func exit():
	pass
