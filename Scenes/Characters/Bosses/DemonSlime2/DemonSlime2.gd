class_name DemonSlime2 extends AgentBase

## DemonSlime2 — Skill System 试点 Boss

# ---- Boss 特化字段 ----
@export var base_move_speed: float = 80.0
@export var detection_radius: float = 600.0
@export var attack_range: float = 250.0
@export var phase_2_hp_pct: float = 0.66
@export var phase_3_hp_pct: float = 0.33

var current_phase: int = 0

const PHASE_SPEED := { 0: 1.0, 1: 1.3, 2: 1.5 }

var move_speed: float:
	get: return base_move_speed * PHASE_SPEED.get(current_phase, 1.0)

func _ready() -> void:
	sprite = $AnimatedSprite2D
	super._ready()
	if health_comp:
		health_comp.health_changed.connect(_on_health_changed)

# ---- Blackboard ----
func _setup_blackboard() -> void:
	super._setup_blackboard()
	var bb := _get_blackboard()
	if bb:
		bb.bind_var(&"current_phase", self, &"current_phase")
		bb.set_var(&"detection_radius", detection_radius)
		bb.set_var(&"chase_speed", base_move_speed)

# ---- 转换表 ----
func _setup_transitions() -> void:
	_register_rules([
		# from,    to,           event,                       guard,                   priority
		["idle",    "chase",      "",                          "_guard_detected",       10],
		["wander",  "chase",      "",                          "_guard_detected",       10],
		["chase",   "idle",       "",                          "_guard_target_lost",     0],

		# 攻击场景（走 dispatcher）
		["chase",   "dispatcher", "",                          "_guard_can_attack",     10],

		# 攻击完成
		["*",       "chase",      AIEvents.EV_ATTACK_FINISHED, "_guard_target_alive",    0],
		["*",       "idle",       AIEvents.EV_ATTACK_FINISHED, "",                       0],

		# 受击 / 死亡
		["*",       "death",      AIEvents.EV_DIED,            "",                     100],
		["*",       "hit",        AIEvents.EV_DAMAGED,         "_guard_can_interrupt",  10],
		["hit",     "chase",      AIEvents.EV_HIT_RECOVERED,   "_guard_target_alive",   10],
		["hit",     "idle",       AIEvents.EV_HIT_RECOVERED,   "",                       0],
	])

# ---- Guard methods ----
func _guard_detected() -> bool:
	var bb := _get_blackboard()
	return bb != null and bb.get_var(&"target_alive", false) and bb.get_var(&"distance", INF) < detection_radius

func _guard_target_lost() -> bool:
	var bb := _get_blackboard()
	return bb == null or not bb.get_var(&"target_alive", false) or bb.get_var(&"distance", INF) > 700.0

func _guard_target_alive() -> bool:
	var bb := _get_blackboard()
	return bb != null and bb.get_var(&"target_alive", false)

## 普通攻击：先尝试技能池
func _guard_can_attack() -> bool:
	var bb := _get_blackboard()
	if bb == null:
		return false
	if bb.get_var(&"global_cooldown", 0.0) > 0:
		return false
	var skill := skill_set.pick(self, bb)
	if skill:
		bb.set_var(&"pending_skill", skill)
		return true
	return false

## 当前技能是否可被打断
func _guard_can_interrupt() -> bool:
	return state_controller.current_skill == null or state_controller.current_skill.interruptible

# ---- Phase system ----
func _on_health_changed(current: float, maximum: float) -> void:
	var pct := current / maxf(maximum, 1.0)
	var new_phase := current_phase
	if pct <= phase_3_hp_pct:
		new_phase = 2
	elif pct <= phase_2_hp_pct:
		new_phase = 1
	if new_phase != current_phase:
		current_phase = new_phase
		var bb := _get_blackboard()
		if bb:
			bb.set_var(&"chase_speed", move_speed)
		controller.dispatch(AIEvents.EV_PHASE_CHANGED)
