class_name HahashinCombatState extends AIState

## Hahashin 战斗状态：播放攻击动画、支持 atk_1→atk_2→atk_3 连招缓冲。

func enter() -> void:
	var hh := agent as Hahashin
	if hh:
		hh.can_move = false
	var skill_id := hh.pending_skill_id
	hh.pending_skill_id = &""
	if skill_id == &"":
		dispatch(AIEvents.EV_ATTACK_FINISHED)
		return
	if not agent.anim.action_finished.is_connected(_on_anim_done):
		agent.anim.action_finished.connect(_on_anim_done)
	_play_skill(skill_id)

func _play_skill(skill_id: StringName) -> void:
	if agent.hitbox is HitBoxComponent:
		(agent.hitbox as HitBoxComponent).configure_from_skill_id(skill_id)
	agent.anim.play_action(skill_id, 2.0)

func physics_update(_delta: float) -> void:
	var hh := agent as Hahashin
	if Input.is_action_just_pressed(&"atk_1"):
		hh.pending_skill_id = &"atk_1"
	elif Input.is_action_just_pressed(&"atk_2"):
		hh.pending_skill_id = &"atk_2"
	elif Input.is_action_just_pressed(&"atk_3"):
		hh.pending_skill_id = &"atk_3"

func _on_anim_done(_action_id: StringName) -> void:
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
		hh.can_move = true
	if agent.anim.action_finished.is_connected(_on_anim_done):
		agent.anim.action_finished.disconnect(_on_anim_done)
	agent.anim.stop_action()
