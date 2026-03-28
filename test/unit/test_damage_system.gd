extends GutTest

## Damage Resource 单元测试
## 验证伤害创建、效果组合、范围随机化

func test_damage_creation_with_amount() -> void:
	var dmg = Damage.new()
	dmg.amount = 25.0
	assert_eq(dmg.amount, 25.0, "Damage amount should match")

func test_damage_default_effects_empty() -> void:
	var dmg = Damage.new()
	assert_eq(dmg.effects.size(), 0, "Default effects should be empty")

func test_damage_has_effect_with_stun() -> void:
	var dmg = Damage.new()
	var stun = StunEffect.new()
	dmg.effects.append(stun)
	assert_true(dmg.has_effect("StunEffect"), "Should detect StunEffect")

func test_damage_has_effect_without_effect() -> void:
	var dmg = Damage.new()
	assert_false(dmg.has_effect("StunEffect"), "Should not detect missing effect")

func test_damage_has_effect_multiple() -> void:
	var dmg = Damage.new()
	dmg.effects.append(StunEffect.new())
	dmg.effects.append(KnockBackEffect.new())
	assert_true(dmg.has_effect("StunEffect"), "Should detect StunEffect")
	assert_true(dmg.has_effect("KnockBackEffect"), "Should detect KnockBackEffect")
	assert_false(dmg.has_effect("KnockUpEffect"), "Should not detect missing KnockUpEffect")

func test_damage_randomize_in_range() -> void:
	var dmg = Damage.new()
	dmg.min_amount = 10.0
	dmg.max_amount = 20.0
	for i in range(10):
		dmg.randomize_damage()
		assert_between(dmg.amount, 10.0, 20.0, "Randomized damage should be in range")

func test_damage_effects_description_empty() -> void:
	var dmg = Damage.new()
	assert_eq(dmg.get_effects_description(), "无特效", "Empty effects should return '无特效'")

func test_damage_effects_description_with_effects() -> void:
	var dmg = Damage.new()
	dmg.effects.append(StunEffect.new())
	var desc = dmg.get_effects_description()
	assert_ne(desc, "无特效", "Should have effect description")
