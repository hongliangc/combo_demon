extends "res://Core/StateMachine/CommonStates/WanderState.gd"

## ForestBoar Wander 状态 - 地面巡逻（仅水平移动）

func _init():
	super._init()
	random_direction = false
	enable_player_detection = true
	next_state_on_timeout = "idle"
	enable_sprite_flip = false  # 由主脚本 _physics_process 处理

func enter() -> void:
	# 随机选择左或右方向（地面敌人只水平移动）
	wander_direction = Vector2.RIGHT if randf() > 0.5 else Vector2.LEFT

	var min_time = get_owner_property("min_wander_time", min_wander_time)
	var max_time = get_owner_property("max_wander_time", max_wander_time)
	start_timer(randf_range(min_time, max_time), _on_wander_timeout)

	# 设置动画
	var blend_x = sign(wander_direction.x)
	set_locomotion(Vector2(blend_x, 0.5))

func physics_process_state(_delta: float) -> void:
	if enable_player_detection:
		if try_chase():
			return

	if owner_node is CharacterBody2D:
		var body = owner_node as CharacterBody2D
		var speed = get_owner_property("wander_speed", default_wander_speed)

		# 只设置水平速度，重力由主脚本处理
		body.velocity.x = sign(wander_direction.x) * speed
		body.move_and_slide()

		# 碰墙转向
		if body.is_on_wall():
			wander_direction.x *= -1

		# 更新动画
		var blend_x = sign(wander_direction.x)
		var max_speed = get_owner_property("chase_speed", 100.0)
		var blend_y = clampf(speed / max_speed, 0.0, 0.5)
		set_locomotion(Vector2(blend_x, blend_y))
