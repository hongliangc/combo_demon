# test/unit/test_skill_set.gd
extends GutTest

## SkillSet 单元测试

var _boss: Node
var _bb: AIBlackboard
var _ss: SkillSet

# ---- helpers ----

func _make_skill(id: StringName, overrides: Dictionary = {}) -> Skill:
	var s := Skill.new()
	s.id = id
	s.state_name = overrides.get("state_name", &"generic_attack")
	s.cooldown = overrides.get("cooldown", 1.5)
	s.weight = overrides.get("weight", 1)
	s.min_phase = overrides.get("min_phase", 0)
	s.max_phase = overrides.get("max_phase", -1)
	s.min_range = overrides.get("min_range", 0.0)
	s.max_range = overrides.get("max_range", 0.0)
	var raw_tags: Array = overrides.get("tags", [])
	var typed_tags: Array[StringName] = []
	for t in raw_tags:
		typed_tags.append(t)
	s.tags = typed_tags
	s.precondition_method = overrides.get("precondition_method", &"")
	s.interruptible = overrides.get("interruptible", true)
	return s

func before_each() -> void:
	_boss = Node.new()
	add_child_autofree(_boss)
	_bb = AIBlackboard.new()
	_bb.set_var(&"current_phase", 0)
	_bb.set_var(&"distance", 100.0)
	_ss = SkillSet.new()

# ============ setup ============

func test_setup_initializes_cooldowns() -> void:
	var cleave := _make_skill(&"cleave")
	var slam := _make_skill(&"slam")
	_ss.setup([cleave, slam])
	assert_eq(_ss.get_cooldown(&"cleave"), 0.0)
	assert_eq(_ss.get_cooldown(&"slam"), 0.0)

# ============ pick: phase filter ============

func test_pick_filters_by_phase() -> void:
	var cleave := _make_skill(&"cleave", { "min_phase": 0 })
	var slam := _make_skill(&"slam", { "min_phase": 1 })
	_ss.setup([cleave, slam])
	_bb.set_var(&"current_phase", 0)
	var picked := _ss.pick(_boss, _bb)
	assert_eq(picked.id, &"cleave", "phase 0 should only pick cleave")

func test_pick_phase_unlocks() -> void:
	var cleave := _make_skill(&"cleave", { "min_phase": 0 })
	var slam := _make_skill(&"slam", { "min_phase": 1, "weight": 100 })
	_ss.setup([cleave, slam])
	_bb.set_var(&"current_phase", 1)
	var slam_count := 0
	for i in 50:
		var p := _ss.pick(_boss, _bb)
		if p.id == &"slam":
			slam_count += 1
	assert_gt(slam_count, 40, "slam (weight=100) should dominate")

func test_pick_max_phase_locks() -> void:
	var early := _make_skill(&"early", { "min_phase": 0, "max_phase": 0 })
	var late := _make_skill(&"late", { "min_phase": 1 })
	_ss.setup([early, late])
	_bb.set_var(&"current_phase", 1)
	var picked := _ss.pick(_boss, _bb)
	assert_eq(picked.id, &"late", "early skill locked out at phase 1")

# ============ pick: distance filter ============

func test_pick_filters_by_max_range() -> void:
	var cleave := _make_skill(&"cleave", { "max_range": 250.0 })
	_ss.setup([cleave])
	_bb.set_var(&"distance", 300.0)
	assert_null(_ss.pick(_boss, _bb), "too far for cleave")
	_bb.set_var(&"distance", 200.0)
	assert_not_null(_ss.pick(_boss, _bb), "in range")

func test_pick_filters_by_min_range() -> void:
	var proj := _make_skill(&"proj", { "min_range": 200.0 })
	_ss.setup([proj])
	_bb.set_var(&"distance", 100.0)
	assert_null(_ss.pick(_boss, _bb), "too close for projectile")
	_bb.set_var(&"distance", 300.0)
	assert_not_null(_ss.pick(_boss, _bb), "far enough")

# ============ pick: cooldown filter ============

func test_cooldown_blocks_pick() -> void:
	var cleave := _make_skill(&"cleave", { "cooldown": 2.0 })
	_ss.setup([cleave])
	_ss.start_cooldown(&"cleave")
	assert_null(_ss.pick(_boss, _bb), "skill on cooldown")

func test_cooldown_tick_restores() -> void:
	var cleave := _make_skill(&"cleave", { "cooldown": 1.0 })
	_ss.setup([cleave])
	_ss.start_cooldown(&"cleave")
	assert_null(_ss.pick(_boss, _bb), "on cooldown")
	_ss.tick(0.5)
	assert_null(_ss.pick(_boss, _bb), "still on cooldown at 0.5s")
	_ss.tick(0.6)
	assert_not_null(_ss.pick(_boss, _bb), "cooldown expired at 1.1s")

# ============ pick: weight=0 excluded ============

func test_weight_zero_excluded_from_pick() -> void:
	var retreat := _make_skill(&"retreat", { "weight": 0, "tags": [&"defensive"] })
	_ss.setup([retreat])
	assert_null(_ss.pick(_boss, _bb), "weight=0 excluded from normal pick")

# ============ pick_tagged ============

func test_pick_tagged_finds_zero_weight() -> void:
	var retreat := _make_skill(&"retreat", { "weight": 0, "tags": [&"defensive"] })
	_ss.setup([retreat])
	var picked := _ss.pick_tagged(&"defensive", _boss, _bb)
	assert_not_null(picked, "pick_tagged should find weight=0 skill")
	assert_eq(picked.id, &"retreat")

func test_pick_tagged_wrong_tag_returns_null() -> void:
	var retreat := _make_skill(&"retreat", { "weight": 0, "tags": [&"defensive"] })
	_ss.setup([retreat])
	assert_null(_ss.pick_tagged(&"ranged", _boss, _bb), "wrong tag")

func test_pick_tagged_respects_cooldown() -> void:
	var retreat := _make_skill(&"retreat", { "weight": 0, "cooldown": 3.0, "tags": [&"defensive"] })
	_ss.setup([retreat])
	_ss.start_cooldown(&"retreat")
	assert_null(_ss.pick_tagged(&"defensive", _boss, _bb), "on cooldown")

# ============ precondition_method ============

func test_precondition_blocks_pick() -> void:
	var retreat := _make_skill(&"retreat", {
		"weight": 0, "tags": [&"defensive"],
		"precondition_method": &"_precond_heavy_damage"
	})
	_ss.setup([retreat])
	assert_null(_ss.pick_tagged(&"defensive", _boss, _bb), "missing precondition method blocks skill")

func test_precondition_passes() -> void:
	var script := GDScript.new()
	script.source_code = "extends Node\nfunc _precond_heavy_damage() -> bool:\n\treturn true\n"
	script.reload()
	var boss := Node.new()
	boss.set_script(script)
	add_child_autofree(boss)

	var retreat := _make_skill(&"retreat", {
		"weight": 0, "tags": [&"defensive"],
		"precondition_method": &"_precond_heavy_damage"
	})
	_ss.setup([retreat])
	var picked := _ss.pick_tagged(&"defensive", boss, _bb)
	assert_not_null(picked, "precondition returns true → skill available")

# ============ has_available ============

func test_has_available() -> void:
	var cleave := _make_skill(&"cleave")
	_ss.setup([cleave])
	assert_true(_ss.has_available(_boss, _bb))
	_ss.start_cooldown(&"cleave")
	assert_false(_ss.has_available(_boss, _bb))

# ============ tick ============

func test_tick_does_not_go_negative() -> void:
	var cleave := _make_skill(&"cleave", { "cooldown": 0.5 })
	_ss.setup([cleave])
	_ss.start_cooldown(&"cleave")
	_ss.tick(10.0)
	assert_eq(_ss.get_cooldown(&"cleave"), 0.0, "should not go negative")
