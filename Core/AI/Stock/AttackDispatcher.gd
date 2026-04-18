# Core/AI/Stock/AttackDispatcher.gd
extends AIState

## 路由状态：读取 pending_skill → 设 current_skill → 跳转目标状态
## 生命周期极短（1帧内跳走）

func enter() -> void:
	var skill: Skill = bb.get_var(&"pending_skill")
	if not skill:
		dispatch(AIEvents.EV_ATTACK_FINISHED)
		return
	ai.current_skill = skill
	if owner_node.has_method(&"_on_skill_start"):
		owner_node._on_skill_start(skill)
	if owner_node.get(&"skill_set"):
		owner_node.skill_set.start_cooldown(skill.id)
	ai.goto(skill.state_name)
