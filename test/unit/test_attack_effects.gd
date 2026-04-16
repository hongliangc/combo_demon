extends GutTest
const H = preload("res://test/base/test_helper.gd")

## AttackEffect 系统单元测试
## 验证各攻击效果的属性默认值、描述文本

# ============ AttackEffect 基类 ============

func test_base_effect_defaults() -> void:
	var effect = AttackEffect.new()
	assert_eq(effect.effect_name, "Base Effect")
	assert_eq(effect.duration, 1.0)
	assert_false(effect.show_debug_info)

func test_base_effect_description() -> void:
	var effect = AttackEffect.new()
	var desc = effect.get_description()
	assert_true(desc.contains("基础特效"), "Description should mention base effect")

# ============ StunEffect ============

func test_stun_effect_defaults() -> void:
	var stun = StunEffect.new()
	assert_eq(stun.effect_name, "眩晕")
	assert_eq(stun.stun_duration, 1.5)

func test_stun_effect_custom_duration() -> void:
	var stun = StunEffect.new()
	stun.stun_duration = 3.0
	assert_eq(stun.stun_duration, 3.0)

func test_stun_effect_description_contains_duration() -> void:
	var stun = StunEffect.new()
	stun.stun_duration = 2.0
	var desc = stun.get_description()
	assert_true(desc.contains("2.0"), "Description should contain duration")

# ============ KnockBackEffect ============

func test_knockback_effect_creation() -> void:
	var kb = KnockBackEffect.new()
	assert_not_null(kb)
	assert_true(kb is AttackEffect, "KnockBackEffect should extend AttackEffect")

# ============ KnockUpEffect ============

func test_knockup_effect_creation() -> void:
	var ku = KnockUpEffect.new()
	assert_not_null(ku)
	assert_true(ku is AttackEffect, "KnockUpEffect should extend AttackEffect")

# ============ GatherEffect ============

func test_gather_effect_creation() -> void:
	var gather = GatherEffect.new()
	assert_not_null(gather)
	assert_true(gather is AttackEffect, "GatherEffect should extend AttackEffect")

# ============ ForceStunEffect ============

func test_force_stun_effect_creation() -> void:
	var fs = ForceStunEffect.new()
	assert_not_null(fs)
	assert_true(fs is AttackEffect, "ForceStunEffect should extend AttackEffect")

# ============ 效果组合 ============

func test_multiple_effects_on_damage() -> void:
	var dmg = Damage.new()
	dmg.effects.append(StunEffect.new())
	dmg.effects.append(KnockBackEffect.new())
	dmg.effects.append(KnockUpEffect.new())
	assert_eq(dmg.effects.size(), 3)
	assert_true(dmg.has_effect("StunEffect"))
	assert_true(dmg.has_effect("KnockBackEffect"))
	assert_true(dmg.has_effect("KnockUpEffect"))
