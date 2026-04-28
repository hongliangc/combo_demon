extends GutTest

## Phase 7 — Iframes (HURTABLE lock) gate damage but not heal.
## StatusController._process drives the action-timer countdown.

const H = preload("res://test/base/test_helper.gd")

var _actor: CharacterBody2D
var _hc: HealthComponent
var _sc: StatusController

func before_each() -> void:
	_actor = H.build_actor_with_pipeline()
	add_child_autofree(_actor)
	_hc = _actor.get_node(^"HealthComponent")
	_sc = _actor.get_node(^"StatusController")

func _hit(amount: float) -> DamageContext:
	var pipe: DamagePipeline = _actor.get_node(^"DamagePipeline")
	var ctx := DamageContext.new()
	ctx.target = _actor
	ctx.amount = amount
	pipe.process(ctx)
	return ctx

func test_iframes_block_damage() -> void:
	_sc.apply_lock(LegalAction.HURTABLE, 1.0)
	var ctx := _hit(30.0)
	assert_true(ctx.blocked)
	assert_eq(_hc.health, 100.0)

func test_iframes_expire_restores_hurtable() -> void:
	_sc.apply_lock(LegalAction.HURTABLE, 0.1)
	_sc._process(0.2)
	var ctx := _hit(30.0)
	assert_false(ctx.blocked)
	assert_eq(_hc.health, 70.0)

func test_heal_bypasses_iframes() -> void:
	_hc.health = 50.0
	_sc.apply_lock(LegalAction.HURTABLE, 1.0)
	_hc.heal(20.0)
	assert_eq(_hc.health, 70.0, "heal still goes through")
