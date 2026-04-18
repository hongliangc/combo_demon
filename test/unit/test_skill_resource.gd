extends GutTest

## Skill / ComboSkill Resource 单元测试

func test_skill_default_values() -> void:
	var s := Skill.new()
	assert_eq(s.id, &"")
	assert_eq(s.state_name, &"")
	assert_eq(s.cooldown, 1.5)
	assert_eq(s.weight, 1)
	assert_eq(s.min_phase, 0)
	assert_eq(s.max_phase, -1)
	assert_eq(s.min_range, 0.0)
	assert_eq(s.max_range, 0.0)
	assert_eq(s.tags.size(), 0)
	assert_eq(s.precondition_method, &"")
	assert_true(s.interruptible)
	assert_eq(s.params.size(), 0)

func test_skill_field_assignment() -> void:
	var s := Skill.new()
	s.id = &"cleave"
	s.state_name = &"generic_attack"
	s.cooldown = 2.0
	s.weight = 5
	s.min_phase = 1
	s.max_phase = 2
	s.min_range = 50.0
	s.max_range = 250.0
	s.tags = [&"melee", &"heavy"]
	s.precondition_method = &"_precond_test"
	s.interruptible = false
	s.params = { &"animation": &"cleave", &"speed": 100.0 }

	assert_eq(s.id, &"cleave")
	assert_eq(s.state_name, &"generic_attack")
	assert_eq(s.cooldown, 2.0)
	assert_eq(s.weight, 5)
	assert_eq(s.min_phase, 1)
	assert_eq(s.max_phase, 2)
	assert_eq(s.min_range, 50.0)
	assert_eq(s.max_range, 250.0)
	assert_eq(s.tags.size(), 2)
	assert_true(&"melee" in s.tags)
	assert_false(s.interruptible)
	assert_eq(s.params[&"animation"], &"cleave")
	assert_eq(s.params[&"speed"], 100.0)

func test_combo_skill_defaults() -> void:
	var cs := ComboSkill.new()
	assert_false(cs.interruptible, "combo defaults to non-interruptible")
	assert_eq(cs.state_name, &"combo")
	assert_eq(cs.gap, 0.1)
	assert_eq(cs.sequence.size(), 0)

func test_combo_skill_sequence() -> void:
	var s1 := Skill.new()
	s1.id = &"slash1"
	s1.params = { &"animation": &"slash1" }

	var s2 := Skill.new()
	s2.id = &"slash2"
	s2.params = { &"animation": &"slash2" }

	var cs := ComboSkill.new()
	cs.id = &"combo2"
	cs.sequence = [s1, s2]
	cs.gap = 0.2

	assert_eq(cs.sequence.size(), 2)
	assert_eq(cs.sequence[0].id, &"slash1")
	assert_eq(cs.sequence[1].params[&"animation"], &"slash2")
	assert_eq(cs.gap, 0.2)
