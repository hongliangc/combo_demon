class_name HahashinGroundState extends AIState

## Hahashin 地面状态：跳跃检测 + 攻击输入轮询。
## idle/run 动画切换由 AnimationDriver 自动 locomotion 处理。

func enter() -> void:
	var hh := agent as Hahashin
	if hh:
		hh.can_move = true

func physics_update(_delta: float) -> void:
	var hh := agent as Hahashin
	if not agent.is_on_floor():
		dispatch(AIEvents.EV_LEFT_GROUND)
		return
	if Input.is_action_just_pressed(&"atk_1"):
		hh.pending_skill_id = &"atk_1"
		dispatch(AIEvents.EV_INPUT_ATTACK)
	elif Input.is_action_just_pressed(&"atk_2"):
		hh.pending_skill_id = &"atk_2"
		dispatch(AIEvents.EV_INPUT_ATTACK)
	elif Input.is_action_just_pressed(&"atk_3"):
		hh.pending_skill_id = &"atk_3"
		dispatch(AIEvents.EV_INPUT_ATTACK)
