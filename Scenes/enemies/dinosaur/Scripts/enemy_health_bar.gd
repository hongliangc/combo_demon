extends ProgressBar

var max_health := 0.0

func on_health_changed(new_health: float) -> void:
	if max_health > 0:
		value = new_health / max_health
		


func on_max_health_changed(new_max_health: float) -> void:
	max_health = new_max_health
	#await  get_tree().process_frame
