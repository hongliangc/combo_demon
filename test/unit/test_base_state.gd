extends GutTest
const H = preload("res://test/base/test_helper.gd")

## BaseState 独立单元测试
## 验证 on_damaged 路由、evaluate_transition、距离工具方法

# ============ 优先级枚举 ============

func test_priority_ordering() -> void:
	assert_true(BaseState.StatePriority.CONTROL > BaseState.StatePriority.REACTION)
	assert_true(BaseState.StatePriority.REACTION > BaseState.StatePriority.BEHAVIOR)

func test_default_priority_is_behavior() -> void:
	var state = BaseState.new()
	assert_eq(state.priority, BaseState.StatePriority.BEHAVIOR)

func test_default_can_be_interrupted() -> void:
	var state = BaseState.new()
	assert_true(state.can_be_interrupted)

# ============ 距离/方向工具 ============

func test_get_distance_to_target_no_target() -> void:
	var state = BaseState.new()
	state.owner_node = CharacterBody2D.new()
	state.target_node = null
	assert_eq(state.get_distance_to_target(), INF)

func test_get_distance_to_target_same_position() -> void:
	var owner = CharacterBody2D.new()
	var target = CharacterBody2D.new()
	add_child_autofree(owner)
	add_child_autofree(target)
	owner.global_position = Vector2(100, 100)
	target.global_position = Vector2(100, 100)

	var state = BaseState.new()
	state.owner_node = owner
	state.target_node = target
	assert_almost_eq(state.get_distance_to_target(), 0.0, 0.01)

func test_get_direction_to_target() -> void:
	var owner = CharacterBody2D.new()
	var target = CharacterBody2D.new()
	add_child_autofree(owner)
	add_child_autofree(target)
	owner.global_position = Vector2.ZERO
	target.global_position = Vector2(100, 0)

	var state = BaseState.new()
	state.owner_node = owner
	state.target_node = target
	var dir = state.get_direction_to_target()
	assert_true(dir.distance_to(Vector2.RIGHT) <= 0.001, "Direction should be approximately RIGHT")

func test_is_target_in_range_true() -> void:
	var owner = CharacterBody2D.new()
	var target = CharacterBody2D.new()
	add_child_autofree(owner)
	add_child_autofree(target)
	owner.global_position = Vector2.ZERO
	target.global_position = Vector2(50, 0)

	var state = BaseState.new()
	state.owner_node = owner
	state.target_node = target
	assert_true(state.is_target_in_range(100.0))

func test_is_target_in_range_false() -> void:
	var owner = CharacterBody2D.new()
	var target = CharacterBody2D.new()
	add_child_autofree(owner)
	add_child_autofree(target)
	owner.global_position = Vector2.ZERO
	target.global_position = Vector2(200, 0)

	var state = BaseState.new()
	state.owner_node = owner
	state.target_node = target
	assert_false(state.is_target_in_range(100.0))

# ============ is_target_alive ============

func test_is_target_alive_with_alive_property() -> void:
	var state = BaseState.new()
	var target = CharacterBody2D.new()
	# CharacterBody2D 没有 alive 属性，所以默认返回 true
	state.target_node = target
	assert_true(state.is_target_alive())

func test_is_target_alive_no_target() -> void:
	var state = BaseState.new()
	state.target_node = null
	assert_true(state.is_target_alive())

# ============ get_owner_property ============

func test_get_owner_property_exists() -> void:
	var state = BaseState.new()
	var owner = CharacterBody2D.new()
	state.owner_node = owner
	# CharacterBody2D 有 velocity 属性
	var result = state.get_owner_property("velocity", Vector2(999, 999))
	assert_eq(result, Vector2.ZERO)

func test_get_owner_property_missing_returns_default() -> void:
	var state = BaseState.new()
	var owner = CharacterBody2D.new()
	state.owner_node = owner
	var result = state.get_owner_property("nonexistent_prop", 42)
	assert_eq(result, 42)

# ============ transition_to ============

func test_transition_to_emits_signal() -> void:
	var state = BaseState.new()
	# 模拟一个有 "idle" 状态的状态机
	var sm = BaseStateMachine.new()
	var idle = BaseState.new()
	idle.name = "idle"
	sm.add_child(idle)
	sm.states["idle"] = idle
	state.state_machine = sm

	watch_signals(state)
	var result = state.transition_to("idle")
	assert_true(result)
	assert_signal_emitted(state, "transitioned")

func test_transition_to_nonexistent_returns_false() -> void:
	var state = BaseState.new()
	var sm = BaseStateMachine.new()
	sm.states = {}
	state.state_machine = sm

	var result = state.transition_to("nonexistent")
	assert_false(result)
