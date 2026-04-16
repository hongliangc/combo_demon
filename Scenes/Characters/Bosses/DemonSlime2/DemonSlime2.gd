class_name DemonSlime2 extends AgentAIBase

## DemonSlime2 — 新 AI 架构试点 Boss

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

func _setup_blackboard() -> void:
	super._setup_blackboard()
	var bb := ai.blackboard
	bb.bind_var(&"current_phase", self, &"current_phase")
	bb.set_var(&"detection_radius", detection_radius)
	bb.set_var(&"attack_range", attack_range)
	bb.set_var(&"attack_cooldown", 0.0)
	bb.set_var(&"global_cooldown", 0.0)
	bb.set_var(&"last_action", &"")
	bb.set_var(&"recently_hit", false)
	bb.set_var(&"chase_speed", base_move_speed)

func _setup_transitions() -> void:
	_register_rules([
		# [from,    to,       event,                       guard,               priority]
		["idle",    "chase",  "",                          "_guard_detected",    10],
		["wander",  "chase",  "",                          "_guard_detected",    10],
		["chase",   "idle",   "",                          "_guard_target_lost", 0],
		["chase",   "slam",   "",                          "_guard_can_slam",    20],
		["chase",   "cleave", "",                          "_guard_can_cleave",  10],
		["cleave",  "chase",  AIEvents.EV_ATTACK_FINISHED, "",                   0],
		["slam",    "chase",  AIEvents.EV_ATTACK_FINISHED, "",                   0],
		["*",       "death",  AIEvents.EV_DIED,            "",                   100],
		["*",       "hit",    AIEvents.EV_DAMAGED,         "",                   10],
		["hit",     "chase",  AIEvents.EV_HIT_RECOVERED,   "_guard_target_alive", 10],
		["hit",     "idle",   AIEvents.EV_HIT_RECOVERED,   "",                   0],
	])

# ---- Guard methods ----
func _guard_detected() -> bool:
	var bb := ai.blackboard
	return bb.get_var(&"target_alive", false) and bb.get_var(&"distance", INF) < detection_radius

func _guard_target_lost() -> bool:
	var bb := ai.blackboard
	return not bb.get_var(&"target_alive", false) or bb.get_var(&"distance", INF) > 700.0

func _guard_target_alive() -> bool:
	return ai.blackboard.get_var(&"target_alive", false)

func _guard_can_cleave() -> bool:
	var bb := ai.blackboard
	if bb.get_var(&"attack_cooldown", 1.0) > 0: return false
	if bb.get_var(&"global_cooldown", 1.0) > 0: return false
	if bb.get_var(&"distance", INF) > attack_range: return false
	if bb.get_var(&"last_action") == &"cleave": return false
	return true

func _guard_can_slam() -> bool:
	var bb := ai.blackboard
	if bb.get_var(&"attack_cooldown", 1.0) > 0: return false
	if bb.get_var(&"global_cooldown", 1.0) > 0: return false
	if bb.get_var(&"distance", INF) > 180.0: return false
	if bb.get_var(&"current_phase", 0) < 1: return false
	return true

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
		ai.blackboard.set_var(&"chase_speed", move_speed)
		ai.dispatch(AIEvents.EV_PHASE_CHANGED)
