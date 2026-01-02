extends BossState

## Boss 眩晕状态 - 受到攻击时进入

@export var stun_duration := 0.5

var stun_timer := 0.0

func enter():
	print("Boss: 进入眩晕状态")
	stun_timer = stun_duration
	boss.stunned = true

func physics_process_state(delta: float) -> void:
	# 减速
	boss.velocity = boss.velocity.lerp(Vector2.ZERO, 5.0 * delta)

	stun_timer -= delta
	if stun_timer <= 0:
		# 眩晕结束，根据距离和阶段智能决定下一个状态
		if player and player.alive and is_player_in_range(boss.detection_radius):
			var distance = get_distance_to_player()

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

func exit():
	boss.stunned = false

# 眩晕状态下再次受伤会重置眩晕时间
func on_damaged(_damage: Damage):
	stun_timer = stun_duration
	print("Boss 眩晕时间重置")
