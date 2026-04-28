extends GutTest

## Phase 7 — DoT integration through DamagePipeline + BuffController + StatusController.
## Covers: TICK damage, DOT tag carried into pipeline, DoT skips react filter,
##         DoT × INCOMING_DAMAGE defense modifier interaction.

const H = preload("res://test/base/test_helper.gd")

var _actor: CharacterBody2D
var _hc: HealthComponent
var _bc: BuffController
var _react_called: bool

func before_each() -> void:
	_actor = H.build_actor_with_pipeline()
	add_child_autofree(_actor)
	_hc = _actor.get_node(^"HealthComponent")
	_bc = _actor.get_node(^"BuffController")
	var pipe: DamagePipeline = _actor.get_node(^"DamagePipeline")
	_react_called = false
	pipe.react.connect(func(ctx):
		if not (ctx.tags & DamageTags.DOT):
			_react_called = true)

func _make_poison() -> BuffEntity:
	var e := DamageEffectBuff.new()
	e.amount = 5.0
	e.tick_interval = 0.5
	e.damage_tags = DamageTags.MAGICAL
	e.effect_on = BuffEffect.EffectOn.TICK
	return H.create_buff_entity(&"poison", 2.0, [e])

func test_dot_drains_hp_each_tick() -> void:
	_bc.apply(_make_poison(), null, _actor.global_position)
	_bc._physics_process(0.5)
	assert_eq(_hc.health, 95.0)
	_bc._physics_process(0.5)
	assert_eq(_hc.health, 90.0)

func test_dot_carries_dot_tag_into_pipeline() -> void:
	var pipe: DamagePipeline = _actor.get_node(^"DamagePipeline")
	# Lambdas in GDScript capture by value — use a one-element array to mutate from the callback.
	var seen_tag: Array[int] = [0]
	pipe.apply.connect(func(ctx): seen_tag[0] = ctx.tags)
	_bc.apply(_make_poison(), null, _actor.global_position)
	_bc._physics_process(0.5)
	assert_true((seen_tag[0] & DamageTags.DOT) != 0)

func test_dot_skips_react_for_hit_state() -> void:
	_bc.apply(_make_poison(), null, _actor.global_position)
	_bc._physics_process(0.5)
	assert_false(_react_called, "DoT should not invoke react listener that filters non-DOT")

func test_dot_benefits_from_defense_buff() -> void:
	var def := StatModEffect.new()
	def.stat_id = StatIds.INCOMING_DAMAGE
	def.multiplier = 0.5
	_bc.apply(H.create_buff_entity(&"def", 10.0, [def]), null, _actor.global_position)
	_bc.apply(_make_poison(), null, _actor.global_position)
	_bc._physics_process(0.5)
	assert_eq(_hc.health, 97.5, "5 * 0.5 = 2.5 dmg")
