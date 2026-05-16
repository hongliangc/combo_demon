extends GutTest

## Phase 7 — Callback effect integration: ON_DAMAGED knockback variant.
## Plan amendment A1: target_kind dropped; trigger=ON_DAMAGED → target=ctx.damage_ctx.source.

const H = preload("res://test/base/test_helper.gd")

var _victim: CharacterBody2D
var _attacker: CharacterBody2D
var _victim_bc: BuffController

func before_each() -> void:
	_victim = H.build_actor_with_pipeline()
	_victim.position = Vector2(100, 0)
	add_child_autofree(_victim)
	_attacker = H.build_actor_with_pipeline()
	_attacker.position = Vector2(0, 0)
	add_child_autofree(_attacker)
	_victim_bc = _victim.get_node(^"BuffController")

func test_on_damaged_pushes_attacker() -> void:
	var kb := KnockBackBuffEffect.new()
	kb.force = 300.0
	kb.effect_on = BuffEffect.EffectOn.ON_DAMAGED
	_victim_bc.apply(H.create_buff_entity(&"thorns", 0.0, [kb]), null, _victim.global_position)

	var pipe: DamagePipeline = _victim.get_node(^"DamagePipeline")
	var ctx := H.create_damage_ctx(_victim, 10.0, _attacker)
	pipe.process(ctx)

	assert_almost_eq(_attacker.velocity.x, -300.0, 0.5, "pushed left away from victim at x=100")
