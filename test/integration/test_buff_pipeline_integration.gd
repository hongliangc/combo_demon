extends GutTest

## Buff + DamagePipeline + StatusController + HealthComponent end-to-end flows.
## Each test gets a fresh actor with all four nodes wired via build_actor_with_pipeline().

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

# ============ Damage / Heal end-to-end ============

func test_damage_flow_end_to_end() -> void:
	watch_signals(_hc)
	var ctx := H.create_damage_ctx(_actor, 30.0)
	_pipe.process(ctx)
	assert_eq(_hc.health, 70.0)
	assert_eq(ctx.dealt, 30.0)
	assert_signal_emitted(_hc, "damaged")

func test_heal_flow_end_to_end() -> void:
	_pipe.process(H.create_damage_ctx(_actor, 50.0))
	watch_signals(_hc)
	_hc.heal(20.0)
	assert_eq(_hc.health, 70.0)
	assert_signal_not_emitted(_hc, "damaged")

func test_overkill_clamps_dealt_and_dies() -> void:
	watch_signals(_hc)
	var ctx := H.create_damage_ctx(_actor, 150.0)
	_pipe.process(ctx)
	assert_eq(_hc.health, 0.0)
	assert_eq(ctx.dealt, 100.0)
	assert_false(_hc.is_alive)
	assert_signal_emitted(_hc, "died")

func test_subsequent_damage_after_death_noop() -> void:
	_pipe.process(H.create_damage_ctx(_actor, 150.0))
	_pipe.process(H.create_damage_ctx(_actor, 10.0))
	assert_eq(_hc.health, 0.0)

# ============ Status gating ============

func test_hurtable_lock_blocks_damage() -> void:
	_sc.apply_lock(LegalAction.HURTABLE, 1.0)
	var ctx := H.create_damage_ctx(_actor, 20.0)
	_pipe.process(ctx)
	assert_true(ctx.blocked)
	assert_eq(_hc.health, 100.0)

func test_heal_bypasses_hurtable_lock() -> void:
	_pipe.process(H.create_damage_ctx(_actor, 50.0))
	_sc.apply_lock(LegalAction.HURTABLE, 1.0)
	_hc.heal(10.0)
	assert_eq(_hc.health, 60.0)

# ============ Stat modifier gating ============

func test_incoming_damage_modifier() -> void:
	_bc.add_stat_modifier(StatIds.INCOMING_DAMAGE, 0.5)
	_pipe.process(H.create_damage_ctx(_actor, 50.0))
	assert_eq(_hc.health, 75.0)

func test_true_damage_bypasses_modifier() -> void:
	_bc.add_stat_modifier(StatIds.INCOMING_DAMAGE, 0.5)
	var ctx := H.create_damage_ctx(_actor, 50.0, null, DamageTags.TRUE)
	_pipe.process(ctx)
	assert_eq(_hc.health, 50.0)

# ============ Buff -> StatusController integration ============

func test_buff_legal_action_lock_aggregates() -> void:
	var b := H.create_buff_entity(&"stun", 1.0)
	b.legal_action_locks = LegalAction.ATTACK | LegalAction.MOVE
	_bc.apply(b, null, Vector2.ZERO)
	assert_false(_sc.can_attack())
	assert_false(_sc.can_move())
	assert_true(_sc.can_be_hit())

func test_attached_buffs_propagate_on_post_apply() -> void:
	var mark := H.create_buff_entity(&"mark", 1.0)
	var ctx := H.create_damage_ctx(_actor, 10.0)
	ctx.attached_buffs = [mark]
	_pipe.process(ctx)
	assert_eq(_bc.active.size(), 1)
	assert_eq(_bc.active[0].entity.id, &"mark")
