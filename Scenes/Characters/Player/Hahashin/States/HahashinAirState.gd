class_name HahashinAirState extends AIState

## Hahashin 空中状态：落地检测 + 空中攻击输入轮询。
## j_up/j_down 动画由 AnimationDriver locomotion 自动处理(airborne 分支按 velocity.y 选)。

func enter() -> void:
	var hh := agent as Hahashin
	if hh:
		hh.can_move = true

func physics_update(_delta: float) -> void:
	var hh := agent as Hahashin
	if agent.is_on_floor():
		dispatch(AIEvents.EV_LANDED)
		return
	if Input.is_action_just_pressed(&"atk_1") or Input.is_action_just_pressed(&"atk_2") or Input.is_action_just_pressed(&"atk_3"):
		hh.pending_skill_id = &"atk_air"
		dispatch(AIEvents.EV_INPUT_ATTACK)
