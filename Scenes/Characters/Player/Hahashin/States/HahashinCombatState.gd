class_name HahashinCombatState extends AIState

## Hahashin 战斗状态：播放攻击动画、支持 atk_1→atk_2→atk_3 连招缓冲。

func enter() -> void:
	var hh := agent as Hahashin
	if hh and hh.movement_component:
		hh.movement_component.can_move = false
	var skill_id := hh.pending_skill_id
	hh.pending_skill_id = &""
	if skill_id == &"":
		dispatch(AIEvents.EV_ATTACK_FINISHED)
		return
	_play_skill(skill_id)
	if not agent.anim_player.animation_finished.is_connected(_on_anim_done):
		agent.anim_player.animation_finished.connect(_on_anim_done)
	agent.anim_player.speed_scale = 2.0

func _play_skill(skill_id: StringName) -> void:
	# 通过 HitBoxComponent 应用技能伤害配置
	if agent.hitbox is HitBoxComponent:
		(agent.hitbox as HitBoxComponent).configure_from_skill_id(skill_id)
	agent.anim_player.play(skill_id)

func physics_update(_delta: float) -> void:
	var hh := agent as Hahashin
	# 动画期间缓冲下一次攻击输入 (连招)
	if Input.is_action_just_pressed(&"atk_1"):
		hh.pending_skill_id = &"atk_1"
	elif Input.is_action_just_pressed(&"atk_2"):
		hh.pending_skill_id = &"atk_2"
	elif Input.is_action_just_pressed(&"atk_3"):
		hh.pending_skill_id = &"atk_3"

func _on_anim_done(_anim_name: StringName) -> void:
	var hh := agent as Hahashin
	if hh.pending_skill_id != &"":
		var next_id := hh.pending_skill_id
		hh.pending_skill_id = &""
		_play_skill(next_id)
		return
	dispatch(AIEvents.EV_ATTACK_FINISHED)

func exit() -> void:
	var hh := agent as Hahashin
	if hh:
		hh.pending_skill_id = &""
		if hh.movement_component:
			hh.movement_component.can_move = true
	if agent.anim_player:
		agent.anim_player.speed_scale = 1.0
		if agent.anim_player.animation_finished.is_connected(_on_anim_done):
			agent.anim_player.animation_finished.disconnect(_on_anim_done)
