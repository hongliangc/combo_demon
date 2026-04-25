extends GutTest

## Minimal CharacterBody2D stub
class _StubBody:
	extends CharacterBody2D
	var anim_player = null
	var sprite = null

class _StubAI:
	extends Node
	var current_skill: Skill = null
	var current_skill_finished: bool = false
	func goto(_n: StringName) -> void:
		pass

func _make_state(body: CharacterBody2D, skill: Skill, distance: float) -> Node:
	var state = load("res://Core/AI/Stock/ApproachState.gd").new()
	state.name = "Approach"
	var ai := _StubAI.new()
	ai.current_skill = skill
	state.ai = ai
	state.owner_node = body
	state.bb = AIBlackboard.new()
	state.bb.set_var(&"distance", distance)
	return state

func test_physics_update_sets_velocity_toward_target() -> void:
	var body := _StubBody.new()
	add_child_autofree(body)
	var skill := Skill.new()
	skill.params = { &"speed": 350.0, &"direction": &"toward_target", &"stop_distance": 100.0 }
	var state = _make_state(body, skill, 500.0)
	state.bb.set_var(&"target_position", Vector2(800, 0))
	body.global_position = Vector2(0, 0)
	state.physics_update(0.016)
	assert_eq(body.velocity.x, 350.0)

func test_physics_update_finishes_when_within_stop_distance() -> void:
	var body := _StubBody.new()
	add_child_autofree(body)
	var skill := Skill.new()
	skill.params = { &"speed": 350.0, &"direction": &"toward_target", &"stop_distance": 100.0 }
	var state = _make_state(body, skill, 80.0)  # already inside stop_distance
	state.bb.set_var(&"target_position", Vector2(80, 0))
	body.global_position = Vector2(0, 0)
	state.physics_update(0.016)
	# _finish() in BaseAttackState clears ai.current_skill; use that as proxy for "finished"
	assert_null(state.ai.current_skill, "current_skill should be cleared by _finish")

func test_physics_update_no_skill_does_nothing() -> void:
	var body := _StubBody.new()
	add_child_autofree(body)
	var state = _make_state(body, null, 500.0)
	state.physics_update(0.016)
	assert_eq(body.velocity.x, 0.0)

func test_on_anim_done_finishes_state() -> void:
	var body := _StubBody.new()
	add_child_autofree(body)
	var skill := Skill.new()
	skill.params = { &"speed": 350.0 }
	var state = _make_state(body, skill, 500.0)
	state._on_anim_done(&"dash")
	assert_null(state.ai.current_skill, "current_skill should be cleared by _finish via _on_anim_done")
