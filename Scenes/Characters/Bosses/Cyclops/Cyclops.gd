class_name Cyclops extends AgentBase

## Cyclops Boss — ranged multi-phase boss (AgentBase + AIController + SkillSet).
##
## Migrated from the legacy BossBase / CyclopsStateMachine architecture:
##   - Phase progression: HP-ratio thresholds → blackboard sync → EV_PHASE_CHANGED
##     (patterned on BladeKeeper).
##   - 8-direction sprite rotation preserved as an _update_facing() override.
##   - Attack selection is data-driven via SkillSet (skill_resources) + transition
##     table; the old CyclopsAttackManager / state files are removed.

# ============ Phase ============
enum Phase { PHASE_1 = 1, PHASE_2 = 2, PHASE_3 = 3 }
const PHASE_HP_THRESHOLD := { Phase.PHASE_2: 0.66, Phase.PHASE_3: 0.33 }
const PHASE_SPEED := {
	Phase.PHASE_1: 1.0,
	Phase.PHASE_2: 1.3,
	Phase.PHASE_3: 1.5,
}

# ============ Config ============
@export_group("Movement")
@export var base_move_speed: float = 150.0
@export var rotation_speed: float = 5.0

@export_group("Detection")
@export var detection_radius: float = 800.0
@export var attack_range: float = 300.0
@export var min_distance: float = 150.0

# ============ 8-direction constants ============
const SQRT2_INV := 0.7071067811865476  # 1 / sqrt(2)
const DIRECTIONS_8 := [
	Vector2(1, 0),                    # 0: right
	Vector2(SQRT2_INV, -SQRT2_INV),   # 1: up-right
	Vector2(0, -1),                   # 2: up
	Vector2(-SQRT2_INV, -SQRT2_INV),  # 3: up-left
	Vector2(-1, 0),                   # 4: left
	Vector2(-SQRT2_INV, SQRT2_INV),   # 5: down-left
	Vector2(0, 1),                    # 6: down
	Vector2(SQRT2_INV, SQRT2_INV),    # 7: down-right
]

# ============ Runtime ============
var current_phase: int = Phase.PHASE_1
var circle_direction: int = 1  # 1 = CW, -1 = CCW

# Patrol path (collected from scene markers; used by Wander-style states / future use)
var patrol_points: Array[Vector2] = []
var current_patrol_index: int = 0

var move_speed: float:
	get: return base_move_speed * PHASE_SPEED.get(current_phase, 1.0)

# ============ Lifecycle ============
func _ready() -> void:
	super._ready()
	if health_comp:
		health_comp.health_changed.connect(_on_health_changed)
	setup_patrol_points()

# ============ AgentBase hooks ============
func _setup_blackboard() -> void:
	super._setup_blackboard()
	var bb := _get_blackboard()
	if bb:
		bb.bind_var(&"current_phase", self, &"current_phase")
		bb.set_var(&"detection_radius", detection_radius)
		bb.set_var(&"attack_range", attack_range)
		bb.set_var(&"min_distance", min_distance)
		bb.set_var(&"chase_speed", move_speed)
		bb.set_var(&"circle_radius", (attack_range + min_distance) / 2.0)

func _setup_transitions() -> void:
	_register_rules([
		# from,      to,            event,                       guard,                   priority
		# detect / chase
		["idle",     "chase",       "",                          "_guard_detected",        10],
		["chase",    "idle",        "",                          "_guard_target_lost",      0],

		# kiting: orbit when in range, otherwise chase
		["chase",    "circle",      "",                          "_guard_should_circle",   15],
		["circle",   "chase",       "",                          "_guard_leave_circle",     5],

		# attack dispatch (from either chase or circle)
		["chase",    "dispatcher",  "",                          "_guard_can_attack",      20],
		["circle",   "dispatcher",  "",                          "_guard_can_attack",      20],

		# attack finished → back to chase / idle
		["*",        "chase",       AIEvents.EV_ATTACK_FINISHED, "_guard_target_alive",     5],
		["*",        "idle",        AIEvents.EV_ATTACK_FINISHED, "",                        0],

		# phase transition reaction
		["*",        "phasetransition", AIEvents.EV_PHASE_CHANGED, "",                     90],

		# hit / death
		["*",        "death",       AIEvents.EV_DIED,            "",                      100],
		["*",        "hit",         AIEvents.EV_DAMAGED,         "_guard_can_interrupt",   10],
		["hit",      "chase",       AIEvents.EV_HIT_RECOVERED,   "_guard_target_alive",    10],
		["hit",      "idle",        AIEvents.EV_HIT_RECOVERED,   "",                        0],
	])

# ============ Guard methods ============
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

func _guard_should_circle() -> bool:
	var bb := _get_blackboard()
	if bb == null or not bb.get_var(&"target_alive", false):
		return false
	return bb.get_var(&"distance", INF) <= attack_range

func _guard_leave_circle() -> bool:
	var bb := _get_blackboard()
	if bb == null or not bb.get_var(&"target_alive", false):
		return true
	return bb.get_var(&"distance", INF) > attack_range * 1.2

func _guard_can_attack() -> bool:
	var bb := _get_blackboard()
	if bb == null:
		return false
	if not bb.get_var(&"target_alive", false):
		return false
	if bb.get_var(&"global_cooldown", 0.0) > 0:
		return false
	var skill: Skill = skill_set.pick(self, bb)
	if skill == null:
		return false
	bb.set_var(&"pending_skill", skill)
	return true

func _guard_can_interrupt() -> bool:
	return state_controller.current_skill == null or state_controller.current_skill.interruptible

# ============ Phase progression (HP-ratio driven) ============
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
		var bb := _get_blackboard()
		if bb:
			bb.set_var(&"chase_speed", move_speed)
		controller.dispatch(AIEvents.EV_PHASE_CHANGED)

# ============ Patrol point setup ============
func setup_patrol_points() -> void:
	var markers := get_tree().get_nodes_in_group(&"boss_patrol_points")
	for marker in markers:
		if marker is Marker2D:
			patrol_points.append((marker as Marker2D).global_position)
	# Default rectangular path if no markers placed.
	if patrol_points.is_empty():
		var center := global_position
		for i in range(4):
			var angle := i * PI / 2.0
			patrol_points.append(center + Vector2(cos(angle), sin(angle)) * 200.0)

func get_next_patrol_point() -> Vector2:
	if patrol_points.is_empty():
		return global_position
	var point := patrol_points[current_patrol_index]
	current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
	return point

# ============ 8-direction facing override ============
func _update_facing() -> void:
	if velocity.length() < 10.0:
		return
	if not sprite:
		return
	var angle := velocity.normalized().angle()
	var direction_index := int(round(angle / (PI / 4.0))) % 8
	if direction_index < 0:
		direction_index += 8
	var target_rotation: float = DIRECTIONS_8[direction_index].angle()
	sprite.rotation = lerp_angle(sprite.rotation, target_rotation,
		rotation_speed * get_physics_process_delta_time())
