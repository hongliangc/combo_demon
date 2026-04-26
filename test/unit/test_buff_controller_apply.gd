extends GutTest

const CounterEffect = preload("res://test/fixtures/CounterEffect.gd")

var _actor: Node
var _bc: BuffController

func before_each() -> void:
	_actor = Node.new()
	_actor.name = "Actor"
	var pipe := DamagePipeline.new()
	pipe.name = "DamagePipeline"
	_actor.add_child(pipe)
	_bc = BuffController.new()
	_bc.name = "BuffController"
	_actor.add_child(_bc)
	add_child_autofree(_actor)

func _make_buff(id: StringName, duration: float, stacking: int) -> BuffEntity:
	var b := BuffEntity.new()
	b.id = id
	b.duration = duration
	b.stacking = stacking
	var c := CounterEffect.new()
	b.effects = [c]
	return b

func test_apply_adds_instance() -> void:
	_bc.apply(_make_buff(&"x", 1.0, BuffEntity.Stacking.REFRESH), null, Vector2.ZERO)
	assert_eq(_bc.active.size(), 1)

func test_apply_emits_buffs_changed() -> void:
	watch_signals(_bc)
	_bc.apply(_make_buff(&"x", 1.0, BuffEntity.Stacking.REFRESH), null, Vector2.ZERO)
	assert_signal_emitted(_bc, "buffs_changed")

func test_apply_runs_apply_effects() -> void:
	var b := _make_buff(&"x", 1.0, BuffEntity.Stacking.REFRESH)
	_bc.apply(b, null, Vector2.ZERO)
	var inst := _bc.active[0]
	assert_eq(inst.tick_accums.get("counter_1", 0), 1, "APPLY trigger=1 fired once")

func test_refresh_does_not_re_apply() -> void:
	var b := _make_buff(&"x", 1.0, BuffEntity.Stacking.REFRESH)
	_bc.apply(b, null, Vector2.ZERO)
	_bc.apply(b, null, Vector2.ZERO)
	assert_eq(_bc.active.size(), 1, "still one instance")
	assert_eq(_bc.active[0].tick_accums.get("counter_1", 0), 1, "APPLY only fired once")
	assert_almost_eq(_bc.active[0].remaining, 1.0, 0.01)

func test_replace_expires_old_then_applies_new() -> void:
	var b := _make_buff(&"x", 1.0, BuffEntity.Stacking.REPLACE)
	_bc.apply(b, null, Vector2.ZERO)
	var first := _bc.active[0]
	_bc.apply(b, null, Vector2.ZERO)
	assert_eq(_bc.active.size(), 1)
	assert_ne(_bc.active[0], first, "instance replaced")

func test_stack_creates_independent_instances() -> void:
	var b := _make_buff(&"x", 1.0, BuffEntity.Stacking.STACK)
	_bc.apply(b, null, Vector2.ZERO)
	_bc.apply(b, null, Vector2.ZERO)
	assert_eq(_bc.active.size(), 2)
	assert_ne(_bc.active[0].gen_id, _bc.active[1].gen_id)
