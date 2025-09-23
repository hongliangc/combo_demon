extends EnemyStates

func physics_process_state(delta) -> void:
	if !player or !player.alive:
		transitioned.emit(self, "wander")
		return
	if !enemy.alive:
		return
	var	direction = player.global_position - enemy.global_position
	var distance = direction.length()
	if distance > enemy.chase_radius:
		transitioned.emit(self, "wander")
		return
	
	enemy.velocity = direction.normalized() * enemy.chase_speed
	#print("enemy chase velocity:{0}, chase_speed:{1} ,enemy global pos:{2}".format([enemy.velocity, enemy.chase_speed, enemy.global_position]))
	if distance < enemy.follow_radius || enemy.velocity == Vector2.ZERO:
		transitioned.emit(self, "attack")
	else:
		# CharacterBody2D 调用 move_and_slide()，无论传入的 velocity 是不是 Vector2.ZERO，
		# 它都会被引擎认为是“可移动体”，需要参与物理解算。防止被推动。
		enemy.move_and_slide()
