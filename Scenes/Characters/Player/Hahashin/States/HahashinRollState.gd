class_name HahashinRollState extends AIState

## Hahashin 翻滚状态：播放 roll 动画 + 冲刺位移，动画结束后返回 ground/air。

@export var roll_speed: float = 400.0

func enter() -> void:
	var hh := agent as Hahashin
	if hh:
		hh.can_move = false
		hh.apply_dash_speed(roll_speed)
	agent.anim.action_finished.connect(_on_anim_done, CONNECT_ONE_SHOT)
	agent.anim.play_action(&"roll", 2.0)

func _on_anim_done(_action_id: StringName) -> void:
	dispatch(AIEvents.EV_ATTACK_FINISHED)

func exit() -> void:
	var hh := agent as Hahashin
	if hh:
		hh.can_move = true
	if agent.anim.action_finished.is_connected(_on_anim_done):
		agent.anim.action_finished.disconnect(_on_anim_done)
	agent.anim.stop_action()
