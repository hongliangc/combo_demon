extends GutTest

## AIController 单元测试

var _owner: CharacterBody2D
var _ai: AIController
var _sm: Node
var _idle: AIState
var _chase: AIState
var _hit: AIState
var _death: AIState

func before_each() -> void:
	_owner = CharacterBody2D.new()
	_owner.name = "TestEnemy"
	add_child_autofree(_owner)

	_ai = AIController.new()
	_ai.name = "AIController"
	_ai.initial_state_name = &"idle"
	_owner.add_child(_ai)
	_ai.set_owner(_owner)

	_sm = Node.new()
	_sm.name = "StateMachine"
	_ai.add_child(_sm)

	_idle = AIState.new()
	_idle.name = "Idle"
	_sm.add_child(_idle)

	_chase = AIState.new()
	_chase.name = "Chase"
	_sm.add_child(_chase)

	_hit = AIState.new()
	_hit.name = "Hit"
	_sm.add_child(_hit)

	_death = AIState.new()
	_death.name = "Death"
	_sm.add_child(_death)

	# Deferred calls need frames to execute
	await get_tree().process_frame
	await get_tree().process_frame

func after_each() -> void:
	_owner = null
	_ai = null

# ============ 初始状态 ============

func test_initial_state() -> void:
	assert_eq(_ai.get_current_state_name(), &"idle")

# ============ 事件式转换 ============

func test_dispatch_event_transition() -> void:
	_ai.add_transition(_idle, _chase, &"detected")
	_ai.dispatch(&"detected")
	assert_eq(_ai.get_current_state_name(), &"chase")

func test_dispatch_no_match_stays() -> void:
	_ai.dispatch(&"unknown_event")
	assert_eq(_ai.get_current_state_name(), &"idle")

# ============ ANYSTATE ============

func test_anystate_transition() -> void:
	_ai.add_transition(_ai.ANYSTATE, _death, AIEvents.EV_DIED)
	_ai.dispatch(AIEvents.EV_DIED)
	assert_eq(_ai.get_current_state_name(), &"death")

func test_anystate_from_any_current() -> void:
	_ai.add_transition(_idle, _chase, &"go")
	_ai.add_transition(_ai.ANYSTATE, _death, AIEvents.EV_DIED)
	_ai.dispatch(&"go")
	assert_eq(_ai.get_current_state_name(), &"chase")
	_ai.dispatch(AIEvents.EV_DIED)
	assert_eq(_ai.get_current_state_name(), &"death")

# ============ Guard ============

func test_guard_blocks_transition() -> void:
	var blocked := [true]  # Array box so lambda captures by reference
	_ai.add_transition(_idle, _chase, &"go", func(): return not blocked[0])
	_ai.dispatch(&"go")
	assert_eq(_ai.get_current_state_name(), &"idle", "guard blocked")
	blocked[0] = false
	_ai.dispatch(&"go")
	assert_eq(_ai.get_current_state_name(), &"chase", "guard passed")

# ============ Priority ============

func test_priority_ordering() -> void:
	_ai.add_transition(_ai.ANYSTATE, _chase, &"x", Callable(), 10)
	_ai.add_transition(_ai.ANYSTATE, _death, &"x", Callable(), 20)
	_ai.dispatch(&"x")
	assert_eq(_ai.get_current_state_name(), &"death", "higher priority wins")

# ============ 条件式转换 ============

func test_conditional_transition_on_tick() -> void:
	var should_go := [false]  # Array box so lambda captures by reference
	_ai.add_transition(_idle, _chase, &"", func(): return should_go[0])
	_ai._evaluate_conditional_transitions()
	assert_eq(_ai.get_current_state_name(), &"idle", "guard false")
	should_go[0] = true
	_ai._evaluate_conditional_transitions()
	assert_eq(_ai.get_current_state_name(), &"chase", "guard true on tick")

# ============ from_state 过滤 ============

func test_from_state_mismatch_ignored() -> void:
	_ai.add_transition(_chase, _hit, &"hit_me")
	_ai.dispatch(&"hit_me")
	assert_eq(_ai.get_current_state_name(), &"idle", "from=chase but current=idle")

# ============ get_state ============

func test_get_state() -> void:
	assert_eq(_ai.get_state(&"idle"), _idle)
	assert_eq(_ai.get_state(&"chase"), _chase)
	assert_null(_ai.get_state(&"nonexistent"))

# ============ goto ============

func test_goto_changes_state() -> void:
	_ai.goto(&"chase")
	assert_eq(_ai.get_current_state_name(), &"chase")

func test_goto_invalid_state_does_nothing() -> void:
	_ai.goto(&"nonexistent")
	assert_eq(_ai.get_current_state_name(), &"idle")

# ============ current_skill interrupt ============

func test_non_interruptible_skill_blocks_dispatch() -> void:
	var skill := Skill.new()
	skill.interruptible = false
	_ai.current_skill = skill
	_ai.add_transition(_ai.ANYSTATE, _hit, AIEvents.EV_DAMAGED)
	_ai.dispatch(AIEvents.EV_DAMAGED)
	assert_eq(_ai.get_current_state_name(), &"idle", "non-interruptible blocks EV_DAMAGED")

func test_non_interruptible_allows_died() -> void:
	var skill := Skill.new()
	skill.interruptible = false
	_ai.current_skill = skill
	_ai.add_transition(_ai.ANYSTATE, _death, AIEvents.EV_DIED)
	_ai.dispatch(AIEvents.EV_DIED)
	assert_eq(_ai.get_current_state_name(), &"death", "EV_DIED always penetrates")

func test_non_interruptible_allows_attack_finished() -> void:
	_ai.add_transition(_idle, _chase, &"go")
	_ai.dispatch(&"go")
	var skill := Skill.new()
	skill.interruptible = false
	_ai.current_skill = skill
	_ai.add_transition(_chase, _idle, AIEvents.EV_ATTACK_FINISHED)
	_ai.dispatch(AIEvents.EV_ATTACK_FINISHED)
	assert_eq(_ai.get_current_state_name(), &"idle", "EV_ATTACK_FINISHED always penetrates")

func test_interruptible_skill_allows_dispatch() -> void:
	var skill := Skill.new()
	skill.interruptible = true
	_ai.current_skill = skill
	_ai.add_transition(_ai.ANYSTATE, _hit, AIEvents.EV_DAMAGED)
	_ai.dispatch(AIEvents.EV_DAMAGED)
	assert_eq(_ai.get_current_state_name(), &"hit", "interruptible allows EV_DAMAGED")

func test_no_skill_allows_dispatch() -> void:
	_ai.current_skill = null
	_ai.add_transition(_ai.ANYSTATE, _hit, AIEvents.EV_DAMAGED)
	_ai.dispatch(AIEvents.EV_DAMAGED)
	assert_eq(_ai.get_current_state_name(), &"hit", "no skill = interruptible")
