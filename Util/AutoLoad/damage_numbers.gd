extends Node

var rng := RandomNumberGenerator.new()
func _ready() -> void:
	rng.randomize()
	print("damage_numbers _ready")

func display_number(value: int, position: Vector2, is_critical: bool = false):
	var number :Label = Label.new()
	number.text = str(value)
	number.z_index = 5
	number.label_settings = LabelSettings.new()
	
	var color = "#FFF" # 白色
	if is_critical:
		color = "#B22"  # 红色
	if value == 0:
		color = "#FFF8" # 
		
	number.label_settings.font_size = 10
	number.label_settings.font_color = color
	number.label_settings.outline_color = "#000" # 黑色
	number.label_settings.outline_size = 1
	
	call_deferred("add_child", number)
	await number.resized
	number.pivot_offset = number.size / 2
	number.global_position = position - number.size / 2
	
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	var random_pos = Vector2(
		number.position.x + rng.randi_range(-12, 12), 
		number.position.y- 24
	)
	tween.tween_property(
		number, "position",random_pos , 0.25
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		number, "position", number.position , 0.25
	).set_ease(Tween.EASE_IN).set_delay(0.25)
	tween.tween_property(
		number, "scale", Vector2.ZERO, 0.25
	).set_ease(Tween.EASE_IN).set_delay(0.5)
	
	await tween.finished
	number.queue_free()
