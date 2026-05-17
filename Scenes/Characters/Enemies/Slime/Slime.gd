class_name Slime extends AgentBase

## Slime — AgentBase; HP<50% 触发一次分裂(沿用阶段切换的事件机制)
## can_split 由 SlimeSplitState 给 mini Slime 设 false 防递归

@export var detection_radius: float = 100.0
@export var chase_speed: float = 50.0
var can_split: bool = true

func _ready() -> void:
	super._ready()
	var hc: Node = get_node_or_null(^"HealthComponent")
	if hc and hc.has_signal(&"health_changed"):
		hc.health_changed.connect(_on_health_changed)

func _setup_blackboard() -> void:
	super._setup_blackboard()
	var bb := _get_blackboard()
	if bb:
		bb.set_var(&"detection_radius", detection_radius)
		bb.set_var(&"chase_speed", chase_speed)

func _setup_transitions() -> void:
	_register_rules([
		# from         to            event                        guard                   priority
		["idle",       "chase",      "",                          "_guard_detected",          10],
		["chase",      "idle",       "",                          "_guard_target_lost",        0],
		["chase",      "dispatcher", "",                          "_guard_can_attack",        20],
		["*",          "split",      AIEvents.EV_PHASE_CHANGED,   "",                        110],
		["*",          "chase",      AIEvents.EV_ATTACK_FINISHED, "_guard_target_alive",       5],
		["*",          "idle",       AIEvents.EV_ATTACK_FINISHED, "",                          0],
		["*",          "death",      AIEvents.EV_DIED,            "",                        100],
		["*",          "hit",        AIEvents.EV_DAMAGED,         "_guard_can_interrupt",     10],
		["hit",        "chase",      AIEvents.EV_HIT_RECOVERED,   "_guard_target_alive",      10],
		["hit",        "idle",       AIEvents.EV_HIT_RECOVERED,   "",                          0],
	])

func _on_health_changed(current_health: float, max_health: float) -> void:
	if not can_split or max_health <= 0.0:
		return
	if current_health / max_health < 0.5:
		can_split = false
		if state_controller:
			state_controller.dispatch(AIEvents.EV_PHASE_CHANGED)

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
