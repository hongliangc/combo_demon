class_name BladeKeeper extends AgentAIBase

## BladeKeeper Boss — 快速技巧型剑士（AgentAIBase + SkillSet 架构）

# ---- Phase ----
enum Phase { PHASE_1 = 1, PHASE_2 = 2, PHASE_3 = 3 }
const PHASE_HP_THRESHOLD := { Phase.PHASE_2: 0.66, Phase.PHASE_3: 0.33 }
const PHASE_SPEED := {
	Phase.PHASE_1: 1.0,
	Phase.PHASE_2: 1.3,
	Phase.PHASE_3: 1.5,
}

@export var base_move_speed: float = 180.0
@export var detection_radius: float = 600.0
@export var pressure_threshold: float = 35.0

## 技能资源（在 Inspector 中拖拽 .tres 配置）
@export var skill_resources: Array[Skill] = []

## Buff 资源（library/）
@export var defense_buff: BuffEntity = preload("res://Core/Buffs/library/bk_defense_x05_3s.tres")
@export var heal_buff: BuffEntity = preload("res://Core/Buffs/library/bk_heal_pulse.tres")
@export var reactive_push_buff: BuffEntity = preload("res://Core/Buffs/library/bk_reactive_push.tres")

var current_phase: int = Phase.PHASE_1

var move_speed: float:
	get: return base_move_speed * PHASE_SPEED.get(current_phase, 1.0)

func _ready() -> void:
	super._ready()
	if health_comp:
		health_comp.health_changed.connect(_on_health_changed)
	# 永久反推 buff（PoC 阶段直接挂）
	if buff_controller and reactive_push_buff:
		buff_controller.apply(reactive_push_buff, self, global_position)

# ---- AgentAIBase 钩子 ----
func _setup_skill_set() -> void:
	skill_set = SkillSet.new()
	skill_set.setup(skill_resources)

func _setup_blackboard() -> void:
	super._setup_blackboard()
	var bb := ai.blackboard
	bb.bind_var(&"current_phase", self, &"current_phase")
	bb.set_var(&"detection_radius", detection_radius)
	bb.set_var(&"chase_speed", move_speed)

func _setup_transitions() -> void:
	_register_rules([
		# from,    to,           event,                       guard,                    priority
		# 探测 / 追击
		["idle",    "chase",      "",                          "_guard_detected",        10],
		["chase",   "idle",       "",                          "_guard_target_lost",      0],

		# 攻击调度
		["chase",   "dispatcher", "",                          "_guard_can_attack",      20],

		# 受压打断（反击类 reactive 技能）
		["chase",   "dispatcher", "",                          "_guard_under_pressure",  30],

		# 攻击完成 → 回追击
		["*",       "chase",      AIEvents.EV_ATTACK_FINISHED, "_guard_target_alive",     5],
		["*",       "idle",       AIEvents.EV_ATTACK_FINISHED, "",                        0],

		# 受击 / 死亡
		["*",       "death",      AIEvents.EV_DIED,            "",                      100],
		["*",       "hit",        AIEvents.EV_DAMAGED,         "_guard_can_interrupt",   10],
		["hit",     "chase",      AIEvents.EV_HIT_RECOVERED,   "_guard_target_alive",    10],
		["hit",     "idle",       AIEvents.EV_HIT_RECOVERED,   "",                        0],
	])

# ---- Guard methods ----
func _guard_detected() -> bool:
	var bb := ai.blackboard
	return bb.get_var(&"target_alive", false) and bb.get_var(&"distance", INF) < detection_radius

func _guard_target_lost() -> bool:
	var bb := ai.blackboard
	return not bb.get_var(&"target_alive", false) or bb.get_var(&"distance", INF) > detection_radius * 1.2

func _guard_target_alive() -> bool:
	return ai.blackboard.get_var(&"target_alive", false)

func _guard_can_attack() -> bool:
	if not ai.blackboard.get_var(&"target_alive", false):
		return false
	if ai.blackboard.get_var(&"global_cooldown", 0.0) > 0:
		return false
	var skill: Skill = skill_set.pick(self, ai.blackboard)
	if skill == null:
		return false
	ai.blackboard.set_var(&"pending_skill", skill)
	return true

func _guard_under_pressure() -> bool:
	if ai.blackboard.get_var(&"damage_recent", 0.0) <= pressure_threshold:
		return false
	var skill: Skill = skill_set.pick_tagged(&"reactive", self, ai.blackboard)
	if skill == null:
		return false
	ai.blackboard.set_var(&"pending_skill", skill)
	return true

func _guard_can_interrupt() -> bool:
	return ai.current_skill == null or ai.current_skill.interruptible

# ---- Skill precondition ----
func _precond_under_pressure() -> bool:
	return ai.blackboard.get_var(&"damage_recent", 0.0) > pressure_threshold

# ---- Animation method-call: BuffController 路由 ----
## Animation method-call: 自施防御 buff
func apply_defense_buff(_duration: float = 0.0) -> void:
	if buff_controller and defense_buff:
		buff_controller.apply(defense_buff, self, global_position)

## Animation method-call: 自施回血 buff
func heal_self(_amount: float = 0.0) -> void:
	if buff_controller and heal_buff:
		buff_controller.apply(heal_buff, self, global_position)

# ---- Phase 推进（HP 比例驱动）----
func _on_health_changed(current: float, _maximum: float) -> void:
	if not health_comp:
		return
	var ratio: float = current / float(health_comp.max_health)
	var new_phase: int = current_phase
	if current_phase < Phase.PHASE_3 and ratio <= PHASE_HP_THRESHOLD[Phase.PHASE_3]:
		new_phase = Phase.PHASE_3
	elif current_phase < Phase.PHASE_2 and ratio <= PHASE_HP_THRESHOLD[Phase.PHASE_2]:
		new_phase = Phase.PHASE_2
	if new_phase != current_phase:
		current_phase = new_phase
		ai.blackboard.set_var(&"chase_speed", move_speed)
		ai.dispatch(AIEvents.EV_PHASE_CHANGED)
