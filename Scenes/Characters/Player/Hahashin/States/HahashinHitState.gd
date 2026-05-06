class_name HahashinHitState extends AIState

## Hahashin 受击状态：播放 take_hit 动画，支持连续受击重置（reentrant）。

func _init() -> void:
	reentrant = true

func enter() -> void:
	var hh := agent as Hahashin
	if hh and hh.movement_component:
		hh.movement_component.can_move = false
	agent.anim_player.play(&"take_hit")
	agent.anim_player.seek(0.0, true)
	if not agent.anim_player.animation_finished.is_connected(_on_anim_done):
		agent.anim_player.animation_finished.connect(_on_anim_done)

func _on_anim_done(_anim_name: StringName) -> void:
	dispatch(AIEvents.EV_HIT_RECOVERED)

func exit() -> void:
	var hh := agent as Hahashin
	if hh and hh.movement_component:
		hh.movement_component.can_move = true
	if agent.anim_player and agent.anim_player.animation_finished.is_connected(_on_anim_done):
		agent.anim_player.animation_finished.disconnect(_on_anim_done)
