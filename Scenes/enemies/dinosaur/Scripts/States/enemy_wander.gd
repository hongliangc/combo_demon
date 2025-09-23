extends EnemyStates

var wander_timer: Timer
var wander_direction: Vector2

func enter():
	wander_direction = Vector2.UP.rotated(deg_to_rad(randf_range(0, 360)))
	wander_timer = Timer.new()
	wander_timer.wait_time = randf_range(enemy.min_wander_time, enemy.max_wander_time)
	wander_timer.autostart = true
	wander_timer.timeout.connect(self.on_timer_finished)
	add_child(wander_timer)

func physics_process_state(delta) -> void:
	enemy.velocity = wander_direction * enemy.wander_speed
	enemy.move_and_slide()
	
	#print("enemy wander velocity:{0}, chase_speed:{1} ,enemy global pos:{2}".format([enemy.velocity, enemy.chase_speed, enemy.global_position]))
	try_chase()

func exit():
	wander_timer.stop()
	wander_timer.timeout.disconnect(self.on_timer_finished)
	wander_timer.queue_free()
	wander_timer = null
	
	
func on_timer_finished():
	transitioned.emit(self, "Idle")
