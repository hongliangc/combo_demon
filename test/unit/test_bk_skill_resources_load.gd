extends GutTest

## BK skill .tres resource load tests

func test_bk_atk_basic_loads() -> void:
	var s := load("res://Scenes/Characters/Bosses/BladeKeeper/skills/bk_atk_basic.tres") as Skill
	assert_not_null(s, "bk_atk_basic.tres should load")
	if s:
		assert_eq(s.id, &"bk_atk_basic")
		assert_eq(s.state_name, &"generic_attack")
		assert_eq(s.weight, 10)
		assert_eq(s.params.get(&"animation"), &"atk_1")

func test_bk_atk_heavy_loads() -> void:
	var s := load("res://Scenes/Characters/Bosses/BladeKeeper/skills/bk_atk_heavy.tres") as Skill
	assert_not_null(s, "bk_atk_heavy.tres should load")
	if s:
		assert_eq(s.id, &"bk_atk_heavy")
		assert_eq(s.weight, 6)
		assert_eq(s.min_phase, 2)
		assert_eq(s.params.get(&"animation"), &"atk_2")

func test_bk_dash_approach_loads() -> void:
	var s := load("res://Scenes/Characters/Bosses/BladeKeeper/skills/bk_dash_approach.tres") as Skill
	assert_not_null(s, "bk_dash_approach.tres should load")
	if s:
		assert_eq(s.id, &"bk_dash_approach")
		assert_eq(s.state_name, &"approach")
		assert_eq(s.weight, 4)
		assert_eq(s.min_range, 200.0)
		assert_eq(s.max_range, 600.0)
		assert_eq(s.params.get(&"animation"), &"roll")

func test_bk_throw_sword_loads() -> void:
	var s := load("res://Scenes/Characters/Bosses/BladeKeeper/skills/bk_throw_sword.tres") as Skill
	assert_not_null(s, "bk_throw_sword.tres should load")
	if s:
		assert_eq(s.id, &"bk_throw_sword")
		assert_eq(s.state_name, &"generic_attack")
		assert_eq(s.weight, 3)
		assert_eq(s.min_range, 200.0)
		assert_eq(s.max_range, 800.0)
		assert_eq(s.params.get(&"animation"), &"projectile_cast")
		assert_not_null(s.params.get(&"projectile_scene"), "projectile_scene should be set")

func test_bk_place_trap_loads() -> void:
	var s := load("res://Scenes/Characters/Bosses/BladeKeeper/skills/bk_place_trap.tres") as Skill
	assert_not_null(s, "bk_place_trap.tres should load")
	if s:
		assert_eq(s.id, &"bk_place_trap")
		assert_eq(s.state_name, &"generic_attack")
		assert_eq(s.weight, 2)
		assert_eq(s.min_phase, 2)
		assert_eq(s.min_range, 0.0)
		assert_eq(s.max_range, 300.0)
		assert_eq(s.params.get(&"animation"), &"trap_cast")
		assert_not_null(s.params.get(&"spawn_scene"), "spawn_scene should be set")

func test_bk_dodge_back_loads() -> void:
	var s := load("res://Scenes/Characters/Bosses/BladeKeeper/skills/bk_dodge_back.tres") as Skill
	assert_not_null(s, "bk_dodge_back.tres should load")
	if s:
		assert_eq(s.id, &"bk_dodge_back")
		assert_eq(s.state_name, &"generic_attack")
		assert_eq(s.cooldown, 3.0)
		assert_eq(s.min_phase, 1)
		assert_eq(s.precondition_method, &"_precond_under_pressure")
		assert_eq(s.params.get(&"animation"), &"roll")

func test_bk_defend_buff_loads() -> void:
	var s := load("res://Scenes/Characters/Bosses/BladeKeeper/skills/bk_defend_buff.tres") as Skill
	assert_not_null(s, "bk_defend_buff.tres should load")
	if s:
		assert_eq(s.id, &"bk_defend_buff")
		assert_eq(s.state_name, &"generic_attack")
		assert_eq(s.cooldown, 8.0)
		assert_eq(s.min_phase, 1)
		assert_eq(s.precondition_method, &"_precond_under_pressure")
		assert_eq(s.params.get(&"animation"), &"defend")
		assert_eq(s.params.get(&"method"), &"apply_defense_buff")
		assert_eq(s.params.get(&"method_arg"), 3.0)

func test_bk_heal_self_loads() -> void:
	var s := load("res://Scenes/Characters/Bosses/BladeKeeper/skills/bk_heal_self.tres") as Skill
	assert_not_null(s, "bk_heal_self.tres should load")
	if s:
		assert_eq(s.id, &"bk_heal_self")
		assert_eq(s.state_name, &"generic_attack")
		assert_eq(s.cooldown, 12.0)
		assert_eq(s.min_phase, 2)
		assert_eq(s.precondition_method, &"_precond_under_pressure")
		assert_eq(s.params.get(&"animation"), &"defend")
		assert_eq(s.params.get(&"method"), &"heal_self")
		assert_eq(s.params.get(&"method_arg"), 20.0)

func test_bk_combo_basic_loads() -> void:
	var s := load("res://Scenes/Characters/Bosses/BladeKeeper/skills/bk_combo_basic.tres") as ComboSkill
	assert_not_null(s, "bk_combo_basic.tres should load")
	if s:
		assert_eq(s.id, &"bk_combo_basic")
		assert_eq(s.state_name, &"combo")
		assert_eq(s.cooldown, 2.0)
		assert_eq(s.min_phase, 1)
		assert_eq(s.max_phase, -1)
		assert_eq(s.sequence.size(), 3)
		assert_eq(s.sequence[0].params.get(&"animation"), &"atk_1")
		assert_eq(s.gap, 0.1)

func test_bk_combo_finisher_p2_loads() -> void:
	var s := load("res://Scenes/Characters/Bosses/BladeKeeper/skills/bk_combo_finisher_p2.tres") as ComboSkill
	assert_not_null(s, "bk_combo_finisher_p2.tres should load")
	if s:
		assert_eq(s.id, &"bk_combo_finisher_p2")
		assert_eq(s.state_name, &"combo")
		assert_eq(s.cooldown, 4.0)
		assert_eq(s.min_phase, 2)
		assert_eq(s.max_phase, 2)
		assert_eq(s.sequence.size(), 4)
		assert_eq(s.sequence[0].params.get(&"animation"), &"atk_1")
		assert_eq(s.sequence[3].params.get(&"animation"), &"sp_atk")
		assert_eq(s.gap, 0.1)

func test_bk_combo_finisher_p3_loads() -> void:
	var s := load("res://Scenes/Characters/Bosses/BladeKeeper/skills/bk_combo_finisher_p3.tres") as ComboSkill
	assert_not_null(s, "bk_combo_finisher_p3.tres should load")
	if s:
		assert_eq(s.id, &"bk_combo_finisher_p3")
		assert_eq(s.state_name, &"combo")
		assert_eq(s.cooldown, 3.5)
		assert_eq(s.min_phase, 3)
		assert_eq(s.max_phase, -1)
		assert_eq(s.sequence.size(), 4)
		assert_eq(s.sequence[0].params.get(&"animation"), &"atk_1")
		assert_eq(s.sequence[3].params.get(&"animation"), &"sp_atk")
		assert_eq(s.gap, 0.1)
