extends GutTest

## Phase 4 — concrete BuffEffect subclasses exercised through the real
## DamagePipeline + BuffController + StatusController + HealthComponent chain.

const H = preload("res://test/base/test_helper.gd")

var _actor: CharacterBody2D
var _pipe: DamagePipeline
var _bc: BuffController
var _sc: StatusController
var _hc: HealthComponent

func before_each() -> void:
	_actor = H.build_actor_with_pipeline()
	_pipe = _actor.get_node(^"DamagePipeline")
	_bc = _actor.get_node(^"BuffController")
	_sc = _actor.get_node(^"StatusController")
	_hc = _actor.get_node(^"HealthComponent")
	add_child_autofree(_actor)

# ============ StatModEffect ============

func test_stat_mod_effect_drives_modifier_via_buff() -> void:
	var e := StatModEffect.new()
	e.stat_id = StatIds.INCOMING_DAMAGE
	e.multiplier = 0.5
	var buff := H.create_buff_entity(&"defense", 1.0, [e])
	_bc.apply(buff, null, Vector2.ZERO)

	# APPLY branch: 50% damage taken → 25 dealt, hp 75.
	_pipe.process(H.create_damage_ctx(_actor, 50.0))
	assert_eq(_hc.health, 75.0, "modifier active during APPLY phase halves damage")

	# Tick past expiry to fire EXPIRE.
	_bc._physics_process(2.0)

	# EXPIRE branch: modifier removed → full 50 dealt, hp 25.
	_pipe.process(H.create_damage_ctx(_actor, 50.0))
	assert_eq(_hc.health, 25.0, "modifier removed on EXPIRE — full damage lands")

# ============ DamageEffectBuff (DoT) ============

func test_dot_damages_owner_per_tick() -> void:
	var sentinel := Node.new()
	sentinel.name = "DotSource"
	add_child_autofree(sentinel)

	var e := DamageEffectBuff.new()
	e.amount = 10.0
	e.tick_interval = 0.5
	var buff := H.create_buff_entity(&"poison", 5.0, [e])
	_bc.apply(buff, sentinel, Vector2.ZERO)

	# One physics tick at 0.5s exactly — fires one TICK.
	_bc._physics_process(0.5)
	assert_eq(_hc.health, 90.0, "one DoT tick deals 10 damage")

# ============ HealEffectBuff (HoT) ============

func test_hot_heals_owner_per_tick() -> void:
	# Bring hp to 40.
	_pipe.process(H.create_damage_ctx(_actor, 60.0))
	assert_eq(_hc.health, 40.0, "precondition: hp at 40")

	var e := HealEffectBuff.new()
	e.amount = 15.0
	e.tick_interval = 0.5
	var buff := H.create_buff_entity(&"regen", 5.0, [e])
	_bc.apply(buff, null, Vector2.ZERO)

	watch_signals(_hc)
	_bc._physics_process(0.5)
	assert_eq(_hc.health, 55.0, "HoT tick heals 15 (40 + 15)")
	assert_signal_not_emitted(_hc, "damaged")

# ============ KnockBackEffectBuff ============

func test_knockback_sets_horizontal_velocity_on_apply() -> void:
	_actor.global_position = Vector2(100, 0)

	var e := KnockBackEffectBuff.new()
	e.force = 300.0
	var buff := H.create_buff_entity(&"knockback", 0.0, [e])

	# Source at (0,0) → actor at (100,0): direction = right.
	_bc.apply(buff, null, Vector2(0, 0))

	assert_almost_eq(_actor.velocity.x, 300.0, 1.0, "horizontal velocity pushed right by force")
	assert_eq(_actor.velocity.y, 0.0, "KnockBack does not touch vertical velocity")

# ============ KnockUpEffectBuff ============

func test_knockup_sets_vertical_and_horizontal_velocity_on_apply() -> void:
	_actor.global_position = Vector2(100, 0)

	var e := KnockUpEffectBuff.new()
	e.vertical_force = -500.0
	e.horizontal_force = 200.0
	var buff := H.create_buff_entity(&"knockup", 0.0, [e])

	_bc.apply(buff, null, Vector2(0, 0))

	assert_eq(_actor.velocity.y, -500.0, "vertical force applied (upward)")
	assert_almost_eq(_actor.velocity.x, 200.0, 1.0, "horizontal force pushed right")

# ============ DamageEffectBuff (thorns / ON_DAMAGED reflection) ============

func test_thorns_reflects_damage_to_attacker() -> void:
	# Two actors: attacker hits defender; defender has thorns buff that reflects damage back.
	var attacker := H.build_actor_with_pipeline()
	add_child_autofree(attacker)
	var defender := _actor  # already built + added in before_each

	# Build thorns BuffEntity: DamageEffectBuff fires on ON_DAMAGED; trigger derives target = attacker.
	var thorns_eff := DamageEffectBuff.new()
	thorns_eff.amount = 7.0
	thorns_eff.effect_on = BuffEffect.EffectOn.ON_DAMAGED
	var thorns := H.create_buff_entity(&"thorns", 10.0, [thorns_eff])
	_bc.apply(thorns, null, Vector2.ZERO)

	# Attacker hits defender for 10 damage through pipeline.
	var dc := H.create_damage_ctx(defender, 10.0, attacker)
	_pipe.process(dc)

	# Defender takes 10 damage; attacker takes 7 damage from thorns reflection.
	assert_eq(_hc.health, 90.0, "defender took 10 damage from attacker")
	assert_eq(attacker.get_node(^"HealthComponent").health, 93.0,
			"attacker took 7 reflected damage from thorns")
