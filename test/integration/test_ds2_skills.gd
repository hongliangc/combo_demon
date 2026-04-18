# test/integration/test_ds2_skills.gd
extends GutTest

## DS2 Skill System 集成测试
## 验证 SkillSet + AIController + 转换表 协同工作

var _owner: CharacterBody2D
var _ai: AIController
var _ss: SkillSet
var _bb: AIBlackboard

func before_each() -> void:
	_owner = CharacterBody2D.new()
	_owner.name = "TestDS2"
	add_child_autofree(_owner)

	_ai = AIController.new()
	_ai.name = "AIController"
	_ai.initial_state_name = &"idle"
	_owner.add_child(_ai)
	_ai.set_owner(_owner)

	var sm := Node.new()
	sm.name = "StateMachine"
	_ai.add_child(sm)

	for sn in ["Idle", "Chase", "Hit", "Death", "Dispatcher", "GenericAttack", "Combo"]:
		var s := AIState.new()
		s.name = sn
		sm.add_child(s)

	await get_tree().process_frame
	await get_tree().process_frame

	_bb = _ai.blackboard
	_bb.set_var(&"current_phase", 0)
	_bb.set_var(&"distance", 150.0)
	_bb.set_var(&"target_alive", true)
	_bb.set_var(&"global_cooldown", 0.0)
	_bb.set_var(&"damage_recent", 0.0)

	_ss = SkillSet.new()
	var cleave := Skill.new()
	cleave.id = &"cleave"
	cleave.state_name = &"genericattack"
	cleave.cooldown = 1.5
	cleave.weight = 5
	cleave.max_range = 250.0

	var slam := Skill.new()
	slam.id = &"slam"
	slam.state_name = &"genericattack"
	slam.cooldown = 3.0
	slam.weight = 3
	slam.min_phase = 1
	slam.max_range = 180.0

	var combo := ComboSkill.new()
	combo.id = &"combo_2hit"
	combo.cooldown = 5.0
	combo.weight = 2
	combo.min_phase = 1
	combo.max_range = 200.0
	var sub1 := Skill.new(); sub1.id = &"step1"; sub1.params = { &"animation": &"cleave" }
	var sub2 := Skill.new(); sub2.id = &"step2"; sub2.params = { &"animation": &"cleave" }
	combo.sequence = [sub1, sub2]

	_ss.setup([cleave, slam, combo])

# ============ Phase 0: only cleave ============

func test_phase0_picks_cleave() -> void:
	_bb.set_var(&"current_phase", 0)
	var picked := _ss.pick(_owner, _bb)
	assert_not_null(picked)
	assert_eq(picked.id, &"cleave")

func test_phase0_cleave_repeats_after_cooldown() -> void:
	_bb.set_var(&"current_phase", 0)
	var p1 := _ss.pick(_owner, _bb)
	assert_eq(p1.id, &"cleave")
	_ss.start_cooldown(&"cleave")
	assert_null(_ss.pick(_owner, _bb), "on cooldown")
	_ss.tick(2.0)
	var p2 := _ss.pick(_owner, _bb)
	assert_not_null(p2, "cooldown expired, can pick again")
	assert_eq(p2.id, &"cleave", "cleave repeats — no last_action bug")

# ============ Phase 1: cleave + slam ============

func test_phase1_unlocks_slam() -> void:
	_bb.set_var(&"current_phase", 1)
	_bb.set_var(&"distance", 150.0)
	var found_slam := false
	for i in 50:
		var p := _ss.pick(_owner, _bb)
		if p and p.id == &"slam":
			found_slam = true
			break
	assert_true(found_slam, "slam should appear at phase 1")

# ============ ComboSkill ============

func test_combo_unlocks_at_phase1() -> void:
	_bb.set_var(&"current_phase", 1)
	_bb.set_var(&"distance", 150.0)
	var found_combo := false
	for i in 80:
		var p := _ss.pick(_owner, _bb)
		if p and p.id == &"combo_2hit":
			found_combo = true
			assert_true(p is ComboSkill, "combo should be ComboSkill")
			assert_false(p.interruptible, "combo defaults to non-interruptible")
			assert_eq((p as ComboSkill).sequence.size(), 2)
			break
	assert_true(found_combo, "combo_2hit should appear at phase 1")

func test_combo_locked_at_phase0() -> void:
	_bb.set_var(&"current_phase", 0)
	_bb.set_var(&"distance", 150.0)
	for i in 30:
		var p := _ss.pick(_owner, _bb)
		assert_ne(p.id, &"combo_2hit", "combo should not appear at phase 0")

# ============ Interrupt check ============

func test_non_interruptible_blocks_damaged() -> void:
	var skill := Skill.new()
	skill.interruptible = false
	_ai.current_skill = skill

	var hit := _ai.get_state(&"hit")
	_ai.add_transition(null, hit, AIEvents.EV_DAMAGED)
	_ai.dispatch(AIEvents.EV_DAMAGED)
	assert_eq(_ai.get_current_state_name(), &"idle", "blocked by non-interruptible")

func test_non_interruptible_allows_died() -> void:
	var skill := Skill.new()
	skill.interruptible = false
	_ai.current_skill = skill

	var death := _ai.get_state(&"death")
	_ai.add_transition(null, death, AIEvents.EV_DIED)
	_ai.dispatch(AIEvents.EV_DIED)
	assert_eq(_ai.get_current_state_name(), &"death", "EV_DIED penetrates")

# ============ Distance filter ============

func test_out_of_range_no_attack() -> void:
	_bb.set_var(&"distance", 500.0)
	assert_null(_ss.pick(_owner, _bb), "too far for any attack")

# ============ Cooldown isolation ============

func test_per_skill_cooldown_isolation() -> void:
	_bb.set_var(&"current_phase", 1)
	_bb.set_var(&"distance", 150.0)
	_ss.start_cooldown(&"cleave")
	# 50 picks: cleave must never appear; slam and combo are both valid picks
	for i in 50:
		var picked := _ss.pick(_owner, _bb)
		assert_not_null(picked, "non-cleave skill should be available")
		assert_ne(picked.id, &"cleave", "cleave is on cooldown")
