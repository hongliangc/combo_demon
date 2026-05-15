class_name HahashinHitState extends AIState

## Hahashin 受击状态：播放 take_hit 动画，支持连续受击重置（reentrant）。

func _init() -> void:
	reentrant = true

func enter() -> void:
	var hh := agent as Hahashin
	if hh and hh.movement_component:
		hh.movement_component.can_move = false
	agent.anim.action_finished.connect(_on_anim_done, CONNECT_ONE_SHOT)
	agent.anim.play_action(&"take_hit")

func _on_anim_done(_action_id: StringName) -> void:
	dispatch(AIEvents.EV_HIT_RECOVERED)

func exit() -> void:
	var hh := agent as Hahashin
	if hh and hh.movement_component:
		hh.movement_component.can_move = true
	if agent.anim.action_finished.is_connected(_on_anim_done):
		agent.anim.action_finished.disconnect(_on_anim_done)
