extends GutTest

## DemonSlime2 集成测试
## 使用最小场景树验证 AI 转换表逻辑

var _owner: CharacterBody2D
var _ai: AIController
var _hc: HealthComponent

func before_each() -> void:
	_owner = CharacterBody2D.new()
	_owner.name = "TestDS2"
	add_child_autofree(_owner)

	_hc = HealthComponent.new()
	_hc.name = "HealthComponent"
	_hc.max_health = 200.0
	_hc.health = 200.0
	_owner.add_child(_hc)

	_ai = AIController.new()
	_ai.name = "AIController"
	_ai.initial_state_name = &"idle"
	_owner.add_child(_ai)
	_ai.set_owner(_owner)

	var sm := Node.new()
	sm.name = "StateMachine"
	_ai.add_child(sm)

	# Add all states as simple State instances
	for sn in ["Idle", "Chase", "Hit", "Death", "Stun", "Cleave", "Slam", "Counter", "Defend", "Roll"]:
		var s := AIState.new()
		s.name = sn
		sm.add_child(s)

	await get_tree().process_frame
	await get_tree().process_frame

	# Register transitions matching DemonSlime2._setup_transitions
	var idle := _ai.get_state(&"idle")
	var chase := _ai.get_state(&"chase")
	var cleave := _ai.get_state(&"cleave")
	var slam := _ai.get_state(&"slam")
	var hit := _ai.get_state(&"hit")
	var stun := _ai.get_state(&"stun")
	var death := _ai.get_state(&"death")
	var counter := _ai.get_state(&"counter")
	var defend := _ai.get_state(&"defend")
	var roll := _ai.get_state(&"roll")

	var bb := _ai.blackboard
	bb.set_var(&"detection_radius", 600.0)
	bb.set_var(&"attack_range", 250.0)
	bb.set_var(&"attack_cooldown", 0.0)
	bb.set_var(&"global_cooldown", 0.0)
	bb.set_var(&"last_action", &"")
	bb.set_var(&"target_alive", false)
	bb.set_var(&"distance", INF)

	# Conditional
	_ai.add_transition(idle, chase, &"",
		func(): return bb.get_var(&"target_alive", false) and bb.get_var(&"distance", INF) < 600.0)
	_ai.add_transition(chase, idle, &"",
		func(): return not bb.get_var(&"target_alive", false) or bb.get_var(&"distance", INF) > 700.0)
	_ai.add_transition(chase, slam, &"",
		func(): return bb.get_var(&"attack_cooldown", 1.0) <= 0 and bb.get_var(&"distance", INF) < 180.0, 20)
	_ai.add_transition(chase, cleave, &"",
		func(): return bb.get_var(&"attack_cooldown", 1.0) <= 0 and bb.get_var(&"distance", INF) < 250.0 and bb.get_var(&"last_action") != &"cleave", 10)

	# Event
	_ai.add_transition(cleave, chase, AIEvents.EV_ATTACK_FINISHED)
	_ai.add_transition(slam, chase, AIEvents.EV_ATTACK_FINISHED)

	# Reactions
	_ai.add_transition(_ai.ANYSTATE, death, AIEvents.EV_DIED, Callable(), 100)
	_ai.add_transition(_ai.ANYSTATE, hit, AIEvents.EV_DAMAGED, Callable(), 10)

	# Recovery
	_ai.add_transition(hit, chase, AIEvents.EV_HIT_RECOVERED,
		func(): return bb.get_var(&"target_alive", false), 10)
	_ai.add_transition(hit, idle, AIEvents.EV_HIT_RECOVERED, Callable(), 0)

func after_each() -> void:
	_owner = null
	_ai = null
	_hc = null

# ============ Tests ============

func test_initial_state_is_idle() -> void:
	assert_eq(_ai.get_current_state_name(), &"idle")

func test_dispatch_died_goes_to_death() -> void:
	_ai.dispatch(AIEvents.EV_DIED)
	assert_eq(_ai.get_current_state_name(), &"death")

func test_dispatch_damaged_goes_to_hit() -> void:
	_ai.dispatch(AIEvents.EV_DAMAGED)
	assert_eq(_ai.get_current_state_name(), &"hit")

func test_guard_detected_triggers_chase() -> void:
	_ai.blackboard.set_var(&"target_alive", true)
	_ai.blackboard.set_var(&"distance", 100.0)
	_ai._evaluate_conditional_transitions()
	assert_eq(_ai.get_current_state_name(), &"chase")

func test_guard_target_lost_returns_idle() -> void:
	_ai.blackboard.set_var(&"target_alive", true)
	_ai.blackboard.set_var(&"distance", 100.0)
	_ai._evaluate_conditional_transitions()
	assert_eq(_ai.get_current_state_name(), &"chase")
	_ai.blackboard.set_var(&"distance", 800.0)
	_ai._evaluate_conditional_transitions()
	assert_eq(_ai.get_current_state_name(), &"idle")

func test_chase_to_cleave() -> void:
	_ai.blackboard.set_var(&"target_alive", true)
	_ai.blackboard.set_var(&"distance", 100.0)
	_ai._evaluate_conditional_transitions()
	assert_eq(_ai.get_current_state_name(), &"chase")
	_ai.blackboard.set_var(&"attack_cooldown", 0.0)
	_ai.blackboard.set_var(&"global_cooldown", 0.0)
	_ai.blackboard.set_var(&"distance", 200.0)
	_ai.blackboard.set_var(&"last_action", &"")
	_ai._evaluate_conditional_transitions()
	assert_eq(_ai.get_current_state_name(), &"cleave")

func test_chase_to_slam_priority() -> void:
	_ai.blackboard.set_var(&"target_alive", true)
	_ai.blackboard.set_var(&"distance", 100.0)
	_ai._evaluate_conditional_transitions()
	assert_eq(_ai.get_current_state_name(), &"chase")
	# Both cleave and slam conditions met, slam priority=20 > cleave priority=10
	_ai.blackboard.set_var(&"attack_cooldown", 0.0)
	_ai.blackboard.set_var(&"distance", 150.0)
	_ai.blackboard.set_var(&"last_action", &"")
	_ai._evaluate_conditional_transitions()
	assert_eq(_ai.get_current_state_name(), &"slam", "slam has higher priority")

func test_attack_finished_returns_to_chase() -> void:
	_ai.blackboard.set_var(&"target_alive", true)
	_ai.blackboard.set_var(&"distance", 100.0)
	_ai._evaluate_conditional_transitions()  # idle → chase
	_ai.blackboard.set_var(&"attack_cooldown", 0.0)
	_ai.blackboard.set_var(&"distance", 200.0)
	_ai.blackboard.set_var(&"last_action", &"")
	_ai._evaluate_conditional_transitions()  # chase → cleave
	assert_eq(_ai.get_current_state_name(), &"cleave")
	_ai.dispatch(AIEvents.EV_ATTACK_FINISHED)
	assert_eq(_ai.get_current_state_name(), &"chase")

func test_hit_recovered_with_target_alive() -> void:
	_ai.blackboard.set_var(&"target_alive", true)
	_ai.dispatch(AIEvents.EV_DAMAGED)
	assert_eq(_ai.get_current_state_name(), &"hit")
	_ai.dispatch(AIEvents.EV_HIT_RECOVERED)
	assert_eq(_ai.get_current_state_name(), &"chase")

func test_hit_recovered_without_target() -> void:
	_ai.blackboard.set_var(&"target_alive", false)
	_ai.dispatch(AIEvents.EV_DAMAGED)
	assert_eq(_ai.get_current_state_name(), &"hit")
	_ai.dispatch(AIEvents.EV_HIT_RECOVERED)
	assert_eq(_ai.get_current_state_name(), &"idle")

func test_death_overrides_all() -> void:
	_ai.blackboard.set_var(&"target_alive", true)
	_ai.blackboard.set_var(&"distance", 100.0)
	_ai._evaluate_conditional_transitions()
	assert_eq(_ai.get_current_state_name(), &"chase")
	_ai.dispatch(AIEvents.EV_DIED)
	assert_eq(_ai.get_current_state_name(), &"death")
