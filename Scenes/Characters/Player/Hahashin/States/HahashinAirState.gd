class_name HahashinAirState extends AIState

## Hahashin 空中状态：j_up/j_down 动画、双段跳轮询、落地检测、空中攻击输入轮询。

func enter() -> void:
	var hh := agent as Hahashin
	if hh and hh.movement_component:
		hh.movement_component.can_move = true
	agent.anim.play_action(&"j_up" if agent.velocity.y < 0 else &"j_down")

func physics_update(_delta: float) -> void:
	var hh := agent as Hahashin
	if agent.is_on_floor():
		dispatch(AIEvents.EV_LANDED)
		return
	if agent.velocity.y > 0 and agent.anim.current_action() == &"j_up":
		agent.anim.play_action(&"j_down")
	if Input.is_action_just_pressed(&"jump") and hh and hh.movement_component:
		if hh.movement_component.can_air_jump():
			hh.movement_component.perform_jump(true)
			agent.anim.play_action(&"j_up")
	if Input.is_action_just_pressed(&"atk_1") or Input.is_action_just_pressed(&"atk_2") or Input.is_action_just_pressed(&"atk_3"):
		hh.pending_skill_id = &"atk_air"
		dispatch(AIEvents.EV_INPUT_ATTACK)
