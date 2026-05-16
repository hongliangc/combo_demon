class_name HahashinSpecialAttackState extends AIState

## 特殊攻击状态：播放 atk_sp 动画，命中走 HitBoxComponent configure。

func enter() -> void:
	var hh := agent as Hahashin
	if hh:
		hh.can_move = false
		hh.velocity.x = 0.0  # 技能期间锁住水平移动
	if agent.hitbox is HitBoxComponent:
		(agent.hitbox as HitBoxComponent).configure_from_skill_id(&"atk_sp")
	agent.anim.action_finished.connect(_on_anim_done, CONNECT_ONE_SHOT)
	agent.anim.play_action(&"atk_sp")

func _on_anim_done(_action_id: StringName) -> void:
	dispatch(AIEvents.EV_ATTACK_FINISHED)

func exit() -> void:
	var hh := agent as Hahashin
	if hh:
		hh.can_move = true
	if agent.anim.action_finished.is_connected(_on_anim_done):
		agent.anim.action_finished.disconnect(_on_anim_done)
