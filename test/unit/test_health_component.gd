extends GutTest
const H = preload("res://test/base/test_helper.gd")

## HealthComponent 单元测试
## 验证扣血、治疗、死亡、无敌、信号发射

var _health_comp: HealthComponent
var _parent: CharacterBody2D

func before_each() -> void:
	# 创建最小场景树: CharacterBody2D → HealthComponent
	_parent = CharacterBody2D.new()
	_parent.name = "TestCharacter"
	_health_comp = HealthComponent.new()
	_health_comp.name = "HealthComponent"
	_health_comp.max_health = 100.0
	_health_comp.health = 100.0
	_parent.add_child(_health_comp)
	add_child_autofree(_parent)

func after_each() -> void:
	_health_comp = null
	_parent = null

# ============ 初始化 ============

func test_initial_health() -> void:
	assert_eq(_health_comp.health, 100.0)
	assert_eq(_health_comp.max_health, 100.0)
	assert_true(_health_comp.is_alive)

func test_health_percent_full() -> void:
	assert_eq(_health_comp.get_health_percent(), 1.0)

# ============ 受伤 ============

func test_take_damage_reduces_health() -> void:
	var dmg = H.create_damage(30.0)
	_health_comp.take_damage(dmg)
	assert_eq(_health_comp.health, 70.0)

func test_take_damage_emits_damaged_signal() -> void:
	watch_signals(_health_comp)
	var dmg = H.create_damage(10.0)
	_health_comp.take_damage(dmg)
	assert_signal_emitted(_health_comp, "damaged")

func test_take_damage_emits_health_changed() -> void:
	watch_signals(_health_comp)
	var dmg = H.create_damage(25.0)
	_health_comp.take_damage(dmg)
	assert_signal_emitted(_health_comp, "health_changed")

func test_take_damage_health_not_below_zero() -> void:
	var dmg = H.create_damage(999.0)
	_health_comp.take_damage(dmg)
	assert_eq(_health_comp.health, 0.0)

func test_take_damage_when_dead_ignored() -> void:
	_health_comp.is_alive = false
	var dmg = H.create_damage(50.0)
	_health_comp.take_damage(dmg)
	assert_eq(_health_comp.health, 100.0, "Dead character should not take damage")

# ============ 无敌 ============

func test_invincible_blocks_damage() -> void:
	_health_comp.is_invincible = true
	var dmg = H.create_damage(50.0)
	_health_comp.take_damage(dmg)
	assert_eq(_health_comp.health, 100.0, "Invincible character should not take damage")

func test_set_invincible_toggle() -> void:
	_health_comp.set_invincible(true)
	assert_true(_health_comp.is_invincible)
	_health_comp.set_invincible(false)
	assert_false(_health_comp.is_invincible)

# ============ 死亡 ============

func test_lethal_damage_triggers_death() -> void:
	watch_signals(_health_comp)
	var dmg = H.create_damage(100.0)
	_health_comp.take_damage(dmg)
	assert_signal_emitted(_health_comp, "died")
	assert_false(_health_comp.is_alive)

func test_overkill_triggers_death_once() -> void:
	watch_signals(_health_comp)
	var dmg = H.create_damage(200.0)
	_health_comp.take_damage(dmg)
	assert_signal_emit_count(_health_comp, "died", 1)

func test_multiple_hits_trigger_death_once() -> void:
	watch_signals(_health_comp)
	_health_comp.take_damage(H.create_damage(60.0))
	_health_comp.take_damage(H.create_damage(60.0))  # 已死亡，应被忽略
	assert_signal_emit_count(_health_comp, "died", 1)

# ============ 治疗 ============

func test_heal_restores_health() -> void:
	_health_comp.take_damage(H.create_damage(50.0))
	_health_comp.heal(30.0)
	assert_eq(_health_comp.health, 80.0)

func test_heal_does_not_exceed_max() -> void:
	_health_comp.take_damage(H.create_damage(10.0))
	_health_comp.heal(999.0)
	assert_eq(_health_comp.health, 100.0)

func test_heal_emits_health_changed() -> void:
	_health_comp.take_damage(H.create_damage(50.0))
	watch_signals(_health_comp)
	_health_comp.heal(20.0)
	assert_signal_emitted(_health_comp, "health_changed")

func test_heal_when_dead_ignored() -> void:
	_health_comp.is_alive = false
	_health_comp.health = 0.0
	_health_comp.heal(50.0)
	assert_eq(_health_comp.health, 0.0)

# ============ 重置 ============

func test_reset_health_restores_full() -> void:
	_health_comp.take_damage(H.create_damage(80.0))
	_health_comp.reset_health()
	assert_eq(_health_comp.health, 100.0)
	assert_true(_health_comp.is_alive)

# ============ 百分比 ============

func test_health_percent_after_damage() -> void:
	_health_comp.take_damage(H.create_damage(25.0))
	assert_almost_eq(_health_comp.get_health_percent(), 0.75, 0.001)

func test_health_percent_at_zero() -> void:
	_health_comp.take_damage(H.create_damage(100.0))
	assert_eq(_health_comp.get_health_percent(), 0.0)
