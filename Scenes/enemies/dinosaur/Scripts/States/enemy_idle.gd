extends EnemyStates

var idle_timer: Timer


func enter():
	idle_timer = Timer.new()
	idle_timer.wait_time = 1.0
	idle_timer.autostart = true
	idle_timer.timeout.connect(on_timeout)
	add_child(idle_timer)

func physics_process_state(delta) -> void:
	try_chase()


func exit():
	idle_timer.stop()
	idle_timer.timeout.disconnect(self.on_timeout)
	idle_timer.queue_free()
	idle_timer = null
	
	
func on_timeout():
	transitioned.emit(self, "wander")
