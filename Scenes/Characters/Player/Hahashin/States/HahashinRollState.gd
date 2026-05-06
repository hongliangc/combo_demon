class_name HahashinRollState extends AIState

## Hahashin 翻滚状态：播放 roll 动画 + 冲刺位移，动画结束后返回 ground/air。

@export var roll_speed: float = 400.0

func enter() -> void:
	var hh := agent as Hahashin
	if hh and hh.movement_component:
		hh.movement_component.can_move = false
		hh.movement_component.apply_dash_speed(roll_speed)
	agent.anim_player.play(&"roll")
	agent.anim_player.speed_scale = 2.0
	if not agent.anim_player.animation_finished.is_connected(_on_anim_done):
		agent.anim_player.animation_finished.connect(_on_anim_done)

func _on_anim_done(_anim_name: StringName) -> void:
	dispatch(AIEvents.EV_ATTACK_FINISHED)

func exit() -> void:
	var hh := agent as Hahashin
	if hh and hh.movement_component:
		hh.movement_component.can_move = true
	if agent.anim_player:
		agent.anim_player.speed_scale = 1.0
		if agent.anim_player.animation_finished.is_connected(_on_anim_done):
			agent.anim_player.animation_finished.disconnect(_on_anim_done)
