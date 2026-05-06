class_name HahashinGroundState extends AIState

## Hahashin 地面状态：idle/run 动画、跳跃检测、攻击输入轮询。

func enter() -> void:
	var hh := agent as Hahashin
	if hh and hh.movement_component:
		hh.movement_component.can_move = true
	agent.anim_player.play(&"idle")

func physics_update(_delta: float) -> void:
	var hh := agent as Hahashin
	# 检测离地
	if not agent.is_on_floor():
		dispatch(AIEvents.EV_LEFT_GROUND)
		return
	# idle / run 动画切换
	var moving := absf(agent.velocity.x) > 1.0
	var target_anim: StringName = &"run" if moving else &"idle"
	if agent.anim_player.current_animation != target_anim:
		agent.anim_player.play(target_anim)
	# 攻击输入轮询 (D-2: 直接 poll)
	if Input.is_action_just_pressed(&"atk_1"):
		hh.pending_skill_id = &"atk_1"
		dispatch(AIEvents.EV_INPUT_ATTACK)
	elif Input.is_action_just_pressed(&"atk_2"):
		hh.pending_skill_id = &"atk_2"
		dispatch(AIEvents.EV_INPUT_ATTACK)
	elif Input.is_action_just_pressed(&"atk_3"):
		hh.pending_skill_id = &"atk_3"
		dispatch(AIEvents.EV_INPUT_ATTACK)
