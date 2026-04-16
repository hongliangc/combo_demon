extends GutTest
const H = preload("res://test/base/test_helper.gd")

## BaseStateMachine + BaseState 单元测试
## 验证状态注册、转换、优先级、信号

# ============ 辅助方法 ============

## 创建一个最小状态机场景：
## CharacterBody2D → BaseStateMachine → [states...]
func _create_state_machine(state_names: Array[String] = ["idle", "chase", "hit"]) -> Dictionary:
	var owner_node = CharacterBody2D.new()
	owner_node.name = "TestEnemy"

	var sm = BaseStateMachine.new()
	sm.name = "StateMachine"
	sm.owner_node_group = ""
	sm.target_node_group = ""

	var states: Dictionary = {}
	for sname in state_names:
		var state = BaseState.new()
		state.name = sname
		# 设置优先级
		match sname:
			"idle", "wander", "chase", "attack":
				state.priority = BaseState.StatePriority.BEHAVIOR
			"hit":
				state.priority = BaseState.StatePriority.REACTION
			"control_test":
				state.priority = BaseState.StatePriority.CONTROL
		sm.add_child(state)
		states[sname] = state

	# 设置初始状态
	if states.has("idle"):
		sm.init_state = states["idle"]

	owner_node.add_child(sm)
	# 手动设置 owner，因为不通过 scene tree
	sm.set_owner(owner_node)
	add_child_autofree(owner_node)

	# 等待 _ready
	await wait_frames(1)

	return {"owner": owner_node, "sm": sm, "states": states}


# ============ 状态注册 ============

func test_states_registered() -> void:
	var setup = await _create_state_machine()
	var sm: BaseStateMachine = setup.sm
	assert_eq(sm.states.size(), 3)
	assert_true(sm.states.has("idle"))
	assert_true(sm.states.has("chase"))
	assert_true(sm.states.has("hit"))

func test_initial_state_set() -> void:
	var setup = await _create_state_machine()
	var sm: BaseStateMachine = setup.sm
	assert_eq(sm.current_state.name, "idle")

func test_get_current_state_name() -> void:
	var setup = await _create_state_machine()
	var sm: BaseStateMachine = setup.sm
	assert_eq(sm.get_current_state_name(), "idle")

func test_is_in_state() -> void:
	var setup = await _create_state_machine()
	var sm: BaseStateMachine = setup.sm
	assert_true(sm.is_in_state("idle"))
	assert_false(sm.is_in_state("chase"))

# ============ 状态转换 ============

func test_transition_behavior_to_behavior() -> void:
	var setup = await _create_state_machine()
	var sm: BaseStateMachine = setup.sm
	var idle: BaseState = setup.states["idle"]
	# idle → chase（同优先级，idle.can_be_interrupted = true）
	idle.transitioned.emit(idle, "chase")
	assert_eq(sm.current_state.name, "chase")

func test_transition_behavior_to_reaction() -> void:
	var setup = await _create_state_machine()
	var sm: BaseStateMachine = setup.sm
	var idle: BaseState = setup.states["idle"]
	idle.transitioned.emit(idle, "hit")
	assert_eq(sm.current_state.name, "hit")

func test_transition_behavior_to_control() -> void:
	var setup = await _create_state_machine(["idle", "chase", "hit", "control_test"])
	var sm: BaseStateMachine = setup.sm
	var idle: BaseState = setup.states["idle"]
	idle.transitioned.emit(idle, "control_test")
	assert_eq(sm.current_state.name, "control_test")

func test_transition_rejected_from_non_current_state() -> void:
	var setup = await _create_state_machine()
	var sm: BaseStateMachine = setup.sm
	var chase: BaseState = setup.states["chase"]
	# chase 不是当前状态，它的转换请求应被忽略
	chase.transitioned.emit(chase, "hit")
	assert_eq(sm.current_state.name, "idle", "Only current state can request transition")

func test_transition_to_nonexistent_state_ignored() -> void:
	var setup = await _create_state_machine()
	var sm: BaseStateMachine = setup.sm
	var idle: BaseState = setup.states["idle"]
	idle.transitioned.emit(idle, "nonexistent")
	assert_eq(sm.current_state.name, "idle", "Nonexistent state should be ignored")

# ============ 优先级阻断 ============

func test_control_self_transition_to_behavior() -> void:
	var setup = await _create_state_machine(["idle", "chase", "hit", "control_test"])
	var sm: BaseStateMachine = setup.sm
	var idle: BaseState = setup.states["idle"]
	var ctrl: BaseState = setup.states["control_test"]
	ctrl.can_be_interrupted = false

	# 先进入 control_test
	idle.transitioned.emit(idle, "control_test")
	assert_eq(sm.current_state.name, "control_test")

	# control 主动转换到低优先级状态是允许的（自愿结束）
	ctrl.transitioned.emit(ctrl, "idle")
	assert_eq(sm.current_state.name, "idle")

func test_non_current_state_cannot_request_transition() -> void:
	var setup = await _create_state_machine(["idle", "chase", "hit", "control_test"])
	var sm: BaseStateMachine = setup.sm
	var idle: BaseState = setup.states["idle"]
	var ctrl: BaseState = setup.states["control_test"]
	ctrl.can_be_interrupted = false

	# 进入 control_test
	idle.transitioned.emit(idle, "control_test")
	assert_eq(sm.current_state.name, "control_test")

	# hit(REACTION) 从外部尝试打断 — 不是当前状态，请求被忽略
	var hit: BaseState = setup.states["hit"]
	hit.transitioned.emit(hit, "control_test")
	assert_eq(sm.current_state.name, "control_test", "Non-current state cannot request transition")

# ============ 强制转换 ============

func test_force_transition_ignores_priority() -> void:
	var setup = await _create_state_machine(["idle", "chase", "hit", "control_test"])
	var sm: BaseStateMachine = setup.sm
	var idle: BaseState = setup.states["idle"]

	# 先进入 control_test
	idle.transitioned.emit(idle, "control_test")
	assert_eq(sm.current_state.name, "control_test")

	# force_transition 不检查优先级
	sm.force_transition("idle")
	assert_eq(sm.current_state.name, "idle")

func test_force_transition_nonexistent_state() -> void:
	var setup = await _create_state_machine()
	var sm: BaseStateMachine = setup.sm
	# 不存在的状态 → 无变化
	sm.force_transition("teleport")
	assert_eq(sm.current_state.name, "idle")

# ============ 伤害缓存 ============

func test_damage_cached_on_owner_damaged() -> void:
	var setup = await _create_state_machine()
	var sm: BaseStateMachine = setup.sm
	var damage = Damage.new()
	damage.amount = 25.0
	var attacker_pos = Vector2(100, 200)
	sm._on_owner_damaged(damage, attacker_pos)
	assert_eq(sm.last_damage, damage)
	assert_eq(sm.last_attacker_position, attacker_pos)

# ============ BaseState 工具方法 ============

func test_state_owner_node_injected() -> void:
	var setup = await _create_state_machine()
	var idle: BaseState = setup.states["idle"]
	assert_eq(idle.owner_node, setup.owner)

func test_state_machine_ref_injected() -> void:
	var setup = await _create_state_machine()
	var idle: BaseState = setup.states["idle"]
	assert_eq(idle.state_machine, setup.sm)

func test_can_transition_to_higher_priority() -> void:
	var behavior = BaseState.new()
	behavior.priority = BaseState.StatePriority.BEHAVIOR
	var reaction = BaseState.new()
	reaction.priority = BaseState.StatePriority.REACTION
	assert_true(behavior.can_transition_to(reaction))

func test_can_transition_to_same_priority_interruptible() -> void:
	var s1 = BaseState.new()
	s1.priority = BaseState.StatePriority.BEHAVIOR
	s1.can_be_interrupted = true
	var s2 = BaseState.new()
	s2.priority = BaseState.StatePriority.BEHAVIOR
	assert_true(s1.can_transition_to(s2))

func test_cannot_transition_to_same_priority_non_interruptible() -> void:
	var s1 = BaseState.new()
	s1.priority = BaseState.StatePriority.BEHAVIOR
	s1.can_be_interrupted = false
	var s2 = BaseState.new()
	s2.priority = BaseState.StatePriority.BEHAVIOR
	assert_false(s1.can_transition_to(s2))

func test_can_transition_to_lower_priority_voluntary() -> void:
	var control = BaseState.new()
	control.priority = BaseState.StatePriority.CONTROL
	var behavior = BaseState.new()
	behavior.priority = BaseState.StatePriority.BEHAVIOR
	# 当前状态主动转换到低优先级 → 允许
	assert_true(control.can_transition_to(behavior))
