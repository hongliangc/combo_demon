class_name HahashinAirState extends AIState

## Hahashin 空中状态：j_up/j_down 动画、双段跳轮询、落地检测、空中攻击输入轮询。

func enter() -> void:
	var hh := agent as Hahashin
	if hh and hh.movement_component:
		hh.movement_component.can_move = true
	if agent.velocity.y < 0:
		agent.anim_player.play(&"j_up")
	else:
		agent.anim_player.play(&"j_down")

func physics_update(_delta: float) -> void:
	var hh := agent as Hahashin
	# 落地检测
	if agent.is_on_floor():
		dispatch(AIEvents.EV_LANDED)
		return
	# j_up → j_down 切换
	if agent.velocity.y > 0 and agent.anim_player.current_animation == &"j_up":
		agent.anim_player.play(&"j_down")
	# 双段跳
	if Input.is_action_just_pressed(&"jump") and hh and hh.movement_component:
		if hh.movement_component.can_air_jump():
			hh.movement_component.perform_jump(true)
			agent.anim_player.play(&"j_up")
	# 空中攻击输入轮询 (D-2: 直接 poll)
	if Input.is_action_just_pressed(&"atk_1") or Input.is_action_just_pressed(&"atk_2") or Input.is_action_just_pressed(&"atk_3"):
		hh.pending_skill_id = &"atk_air"
		dispatch(AIEvents.EV_INPUT_ATTACK)
