extends GutTest

## Phase 7 — Heal flow integration through DamagePipeline + BuffController.
## Covers: immediate heal via HealthComponent, no damaged signal on heal,
##         HoT periodic heal, HEAL_RECEIVED stat modifier multiplier.

const H = preload("res://test/base/test_helper.gd")

var _actor: CharacterBody2D
var _hc: HealthComponent
var _bc: BuffController

func before_each() -> void:
	_actor = H.build_actor_with_pipeline()
	add_child_autofree(_actor)
	_hc = _actor.get_node(^"HealthComponent")
	_hc.health = 50.0
	_bc = _actor.get_node(^"BuffController")

func test_immediate_heal_via_hc() -> void:
	_hc.heal(20.0)
	assert_eq(_hc.health, 70.0)

func test_heal_does_not_emit_damaged() -> void:
	watch_signals(_hc)
	_hc.heal(10.0)
	assert_signal_not_emitted(_hc, "damaged")

func test_hot_ticks() -> void:
	var e := HealEffectBuff.new()
	e.amount = 8.0
	e.tick_interval = 1.0
	e.effect_on = BuffEffect.EffectOn.TICK
	_bc.apply(H.create_buff_entity(&"hot", 3.0, [e]), null, _actor.global_position)
	_bc._physics_process(1.0)
	assert_eq(_hc.health, 58.0)
	_bc._physics_process(1.0)
	assert_eq(_hc.health, 66.0)

func test_heal_received_modifier_applies() -> void:
	var hr := StatModEffect.new()
	hr.stat_id = StatIds.HEAL_RECEIVED
	hr.multiplier = 0.5
	_bc.apply(H.create_buff_entity(&"hr_debuff", 10.0, [hr]), null, _actor.global_position)
	_hc.heal(20.0)
	assert_eq(_hc.health, 60.0, "10 healed at half rate")
