extends BaseBullet


@onready var sprite_group = $SpriteGroup

func _before_lifespan_expired() -> void:
	var tween : Tween  = get_tree().create_tween()
	tween.tween_property(
		sprite_group,
		"scale",
		Vector2.ZERO,
		lifespan / 4
	).set_delay(lifespan*3/4)
	#tween.connect("finished", Callable(self, "_on_tween_finished"))
	#print("fire bullet _before_lifespan_expired")
#
#func _on_tween_finished() -> void:
	#print("fire bullet _on_tween_finished")
	#queue_free()

func _start_vertical_float(tween) -> void:
	var original_y = position.y
	tween.set_loops()
	var float_distance := 10.0
	var float_duration := 0.3     # 单次浮动时间（越小越快）
	tween.tween_property(self, "position:y", original_y - float_distance, float_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position:y", original_y + float_distance, float_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
