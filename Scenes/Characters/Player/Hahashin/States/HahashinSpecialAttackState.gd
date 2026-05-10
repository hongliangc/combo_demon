class_name HahashinSpecialAttackState extends AIState

## 特殊攻击状态：播放 atk_sp 动画，命中走 HitBoxComponent configure。

func enter() -> void:
	var hh := agent as Hahashin
	if hh and hh.movement_component:
		hh.movement_component.can_move = false
	if agent.hitbox is HitBoxComponent:
		(agent.hitbox as HitBoxComponent).configure_from_skill_id(&"atk_sp")
	agent.anim_player.play(&"atk_sp")
	if not agent.anim_player.animation_finished.is_connected(_on_anim_done):
		agent.anim_player.animation_finished.connect(_on_anim_done)

func _on_anim_done(_anim_name: StringName) -> void:
	dispatch(AIEvents.EV_ATTACK_FINISHED)

func exit() -> void:
	var hh := agent as Hahashin
	if hh and hh.movement_component:
		hh.movement_component.can_move = true
	if agent.anim_player.animation_finished.is_connected(_on_anim_done):
		agent.anim_player.animation_finished.disconnect(_on_anim_done)
