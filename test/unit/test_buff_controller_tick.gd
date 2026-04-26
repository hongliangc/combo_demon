extends GutTest

const CounterEffect = preload("res://test/fixtures/CounterEffect.gd")

var _actor: Node
var _bc: BuffController

func before_each() -> void:
    _actor = Node.new()
    var pipe := DamagePipeline.new(); pipe.name = "DamagePipeline"; _actor.add_child(pipe)
    _bc = BuffController.new(); _bc.name = "BuffController"; _actor.add_child(_bc)
    add_child_autofree(_actor)

func _make_buff_with_interval(interval: float) -> BuffEntity:
    var b := BuffEntity.new()
    b.id = &"y"
    b.duration = 5.0
    b.stacking = BuffEntity.Stacking.REFRESH
    var c := CounterEffect.new()
    c.tick_interval = interval
    c.effect_on = BuffEffect.EffectOn.TICK
    b.effects = [c]
    return b

func test_tick_zero_interval_runs_each_frame() -> void:
    _bc.apply(_make_buff_with_interval(0.0), null, Vector2.ZERO)
    _bc._physics_process(0.016)
    _bc._physics_process(0.016)
    var inst := _bc.active[0]
    assert_eq(inst.tick_accums.get("counter_2", 0), 2)

func test_tick_interval_accumulates() -> void:
    _bc.apply(_make_buff_with_interval(0.5), null, Vector2.ZERO)
    _bc._physics_process(0.2)
    var inst := _bc.active[0]
    assert_eq(inst.tick_accums.get("counter_2", 0), 0, "below threshold")
    _bc._physics_process(0.4)
    assert_eq(inst.tick_accums.get("counter_2", 0), 1, "0.6 >= 0.5 fires once")
