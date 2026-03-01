extends "res://Core/StateMachine/CommonStates/ChaseState.gd"

## ForestBoar Chase 状态 - 地面追击（仅水平移动）

func _init():
	super._init()
	enable_sprite_flip = false  # 由主脚本 _physics_process 处理

func physics_process_state(_delta: float) -> void:
	if not is_target_alive():
		transition_to(default_state_name)
		return

	var give_up_range: float = get_owner_property("chase_radius", default_give_up_range)
	var attack_range: float = get_owner_property("follow_radius", default_attack_range)
	var speed: float = get_owner_property("chase_speed", default_chase_speed)
	var distance = get_distance_to_target()

	if distance > give_up_range:
		transition_to(give_up_state_name)
		return

	if distance <= attack_range:
		transition_to(attack_state_name)
		return

	# 只设置水平速度，重力由主脚本处理
	if owner_node is CharacterBody2D:
		var body = owner_node as CharacterBody2D
		var direction = get_direction_to_target()
		body.velocity.x = sign(direction.x) * speed
		body.move_and_slide()

		# 更新动画
		var blend_x = sign(direction.x) if abs(direction.x) > 0.1 else 0.0
		var blend_y = minf(abs(body.velocity.x) / speed, 1.0)
		set_locomotion(Vector2(blend_x, blend_y))
