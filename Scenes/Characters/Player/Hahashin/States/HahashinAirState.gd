class_name HahashinAirState extends AIState

## Hahashin 空中状态：j_up/j_down 动画、双段跳轮询、落地检测、空中攻击输入轮询。

func enter() -> void:
	var hh := agent as Hahashin
	if hh:
		hh.can_move = true
		# AgentBase 已在 jump_started 时切换 j_up; 这里只在进入 air 状态时给一个初始动画.
		if not hh.jump_started.is_connected(_on_jump_started):
			hh.jump_started.connect(_on_jump_started)
	agent.anim.play_action(&"j_up" if agent.velocity.y < 0 else &"j_down")

func exit() -> void:
	var hh := agent as Hahashin
	if hh and hh.jump_started.is_connected(_on_jump_started):
		hh.jump_started.disconnect(_on_jump_started)

func _on_jump_started() -> void:
	# AgentBase 已消费 jump 输入并应用了空中跳; 这里负责动画.
	agent.anim.play_action(&"j_up")

func physics_update(_delta: float) -> void:
	var hh := agent as Hahashin
	if agent.is_on_floor():
		dispatch(AIEvents.EV_LANDED)
		return
	if agent.velocity.y > 0 and agent.anim.current_action() == &"j_up":
		agent.anim.play_action(&"j_down")
	if Input.is_action_just_pressed(&"atk_1") or Input.is_action_just_pressed(&"atk_2") or Input.is_action_just_pressed(&"atk_3"):
		hh.pending_skill_id = &"atk_air"
		dispatch(AIEvents.EV_INPUT_ATTACK)
