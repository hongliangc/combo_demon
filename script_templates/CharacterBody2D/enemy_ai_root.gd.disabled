# meta-description: Enemy/Boss root script with AI wiring
extends EnemyBase  # Change to BossBase for bosses

@onready var ai: AIController = $AIController
@onready var health_comp: HealthComponent = $HealthComponent

func _ready() -> void:
	super._ready()
	_setup_blackboard()
	_setup_transitions()
	_setup_signals()

func _setup_blackboard() -> void:
	var bb := ai.blackboard
	bb.bind_var(&"health", health_comp, &"health")
	bb.bind_var(&"max_health", health_comp, &"max_health")

func _setup_transitions() -> void:
	var idle: AIState = ai.get_state(&"idle")
	var chase: AIState = ai.get_state(&"chase")
	var hit: AIState = ai.get_state(&"hit")
	var death: AIState = ai.get_state(&"death")
	# Behavior
	ai.add_transition(idle, chase, &"", _guard_detected)
	ai.add_transition(chase, idle, &"", _guard_target_lost)
	# Reactions
	ai.add_transition(ai.ANYSTATE, hit, AIEvents.EV_DAMAGED, Callable(), 10)
	ai.add_transition(hit, chase, AIEvents.EV_HIT_RECOVERED, _guard_target_alive, 10)
	ai.add_transition(hit, idle, AIEvents.EV_HIT_RECOVERED, Callable(), 0)
	ai.add_transition(ai.ANYSTATE, death, AIEvents.EV_DIED, Callable(), 100)

func _setup_signals() -> void:
	if health_comp:
		health_comp.damaged.connect(_on_damaged)
		health_comp.died.connect(_on_died)

func _on_damaged(damage: Damage, attacker_pos: Vector2) -> void:
	var bb := ai.blackboard
	bb.set_var(&"last_damage", damage)
	bb.set_var(&"last_attacker_pos", attacker_pos)
	bb.set_var(&"recently_hit", true)
	ai.dispatch(AIEvents.EV_DAMAGED)

func _on_died() -> void:
	ai.dispatch(AIEvents.EV_DIED)

func _guard_detected() -> bool:
	var bb := ai.blackboard
	return bb.get_var(&"target_alive", false) and bb.get_var(&"distance", INF) < 300.0

func _guard_target_lost() -> bool:
	var bb := ai.blackboard
	return not bb.get_var(&"target_alive", false) or bb.get_var(&"distance", INF) > 400.0

func _guard_target_alive() -> bool:
	return ai.blackboard.get_var(&"target_alive", false)
