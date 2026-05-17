class_name Dragon extends AgentBase

## Dragon 敌人 — AgentBase + AIController + SkillSet 架构
## 行为: Idle ↔ Chase → Dispatcher → GenericAttack / DragonBreath; Hit / Death 标准处理
## 无 Wander。普通近战 (dragon_attack) + 火焰吐息特殊技 (dragon_breath, 30% 概率门)。

@export var detection_radius: float = 130.0
@export var chase_speed: float = 65.0

func _setup_blackboard() -> void:
	super._setup_blackboard()
	var bb := _get_blackboard()
	if bb:
		bb.set_var(&"detection_radius", detection_radius)
		bb.set_var(&"chase_speed", chase_speed)

func _setup_transitions() -> void:
	_register_rules([
		# from         to            event                        guard                   priority
		["idle",       "chase",      "",                          "_guard_detected",            10],
		["chase",      "idle",       "",                          "_guard_target_lost",           0],
		["chase",      "dispatcher", "",                          "_guard_can_attack",           20],
		["*",          "chase",      AIEvents.EV_ATTACK_FINISHED, "_guard_target_alive",          5],
		["*",          "idle",       AIEvents.EV_ATTACK_FINISHED, "",                             0],
		["*",          "death",      AIEvents.EV_DIED,            "",                           100],
		["*",          "hit",        AIEvents.EV_DAMAGED,         "_guard_can_interrupt",        10],
		["hit",        "chase",      AIEvents.EV_HIT_RECOVERED,   "_guard_target_alive",         10],
		["hit",        "idle",       AIEvents.EV_HIT_RECOVERED,   "",                             0],
	])

func _guard_detected() -> bool:
	var bb := _get_blackboard()
	return bb != null and bb.get_var(&"target_alive", false) \
		and bb.get_var(&"distance", INF) < detection_radius

func _guard_target_lost() -> bool:
	var bb := _get_blackboard()
	return bb == null or not bb.get_var(&"target_alive", false) \
		or bb.get_var(&"distance", INF) > detection_radius * 1.2

func _guard_target_alive() -> bool:
	var bb := _get_blackboard()
	return bb != null and bb.get_var(&"target_alive", false)

func _guard_can_attack() -> bool:
	var bb := _get_blackboard()
	if bb == null or not bb.get_var(&"target_alive", false):
		return false
	if bb.get_var(&"global_cooldown", 0.0) > 0.0:
		return false
	var skill: Skill = skill_set.pick(self, bb)
	if skill == null:
		return false
	bb.set_var(&"pending_skill", skill)
	return true

func _guard_can_interrupt() -> bool:
	return state_controller.current_skill == null \
		or state_controller.current_skill.interruptible

## Dragon 火焰吐息的 30% 概率门 —— 由 dragon_breath.tres 的 precondition_method 调用
## (旧 DragonBreathState.skill_probability = 0.3 的 faithful 等价)
func _can_dragon_breath() -> bool:
	return randf() < 0.3
