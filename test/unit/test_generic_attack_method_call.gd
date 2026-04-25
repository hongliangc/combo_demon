extends GutTest

## Stub owner that records method calls
class _StubOwner:
	extends Node
	var calls: Array = []
	func apply_buff(duration: float) -> void:
		calls.append([&"apply_buff", duration])
	func heal_self() -> void:
		calls.append([&"heal_self", null])

## Stub AI exposing current_skill
class _StubAI:
	extends Node
	var current_skill: Skill

func _make_state(owner_node: Node, skill: Skill) -> Node:
	var state = load("res://Core/AI/Stock/GenericAttackState.gd").new()
	state.name = "GenericAttack"
	var ai := _StubAI.new()
	ai.current_skill = skill
	state.ai = ai
	state.owner_node = owner_node
	state.bb = AIBlackboard.new()
	return state

func test_call_skill_method_invokes_owner_method_with_arg() -> void:
	var owner := _StubOwner.new()
	add_child_autofree(owner)
	var skill := Skill.new()
	skill.params = { &"method": &"apply_buff", &"method_arg": 3.0 }
	var state = _make_state(owner, skill)
	state.call_skill_method()
	assert_eq(owner.calls.size(), 1)
	assert_eq(owner.calls[0][0], &"apply_buff")
	assert_eq(owner.calls[0][1], 3.0)

func test_call_skill_method_no_arg_calls_method_without_args() -> void:
	var owner := _StubOwner.new()
	add_child_autofree(owner)
	var skill := Skill.new()
	skill.params = { &"method": &"heal_self" }
	var state = _make_state(owner, skill)
	state.call_skill_method()
	assert_eq(owner.calls.size(), 1)
	assert_eq(owner.calls[0][0], &"heal_self")

func test_call_skill_method_missing_method_silently_skips() -> void:
	var owner := _StubOwner.new()
	add_child_autofree(owner)
	var skill := Skill.new()
	skill.params = { &"method": &"nonexistent_method" }
	var state = _make_state(owner, skill)
	state.call_skill_method()  # should not crash
	assert_eq(owner.calls.size(), 0)

func test_call_skill_method_no_method_param_silently_skips() -> void:
	var owner := _StubOwner.new()
	add_child_autofree(owner)
	var skill := Skill.new()
	skill.params = {}
	var state = _make_state(owner, skill)
	state.call_skill_method()
	assert_eq(owner.calls.size(), 0)

func test_call_skill_method_no_current_skill_silently_skips() -> void:
	var owner := _StubOwner.new()
	add_child_autofree(owner)
	var state = _make_state(owner, null)
	state.call_skill_method()
	assert_eq(owner.calls.size(), 0)
