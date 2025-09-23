extends EnemyStates

var stun_timer: Timer


func enter():
	stun_timer = Timer.new()
	stun_timer.wait_time = 1.0
	stun_timer.autostart = true
	stun_timer.timeout.connect(on_timeout)
	add_child(stun_timer)
	enemy.stunned = true

func exit():
	stun_timer.stop()
	stun_timer.timeout.disconnect(self.on_timeout)
	stun_timer.queue_free()
	stun_timer = null
	enemy.stunned = false
	
	
func on_timeout():
	if !try_chase():
		transitioned.emit(self, "chase")
