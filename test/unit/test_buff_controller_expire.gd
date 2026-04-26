extends GutTest

const CounterEffect = preload("res://test/fixtures/CounterEffect.gd")

var _actor: Node
var _bc: BuffController

func before_each() -> void:
    _actor = Node.new()
    var pipe := DamagePipeline.new(); pipe.name = "DamagePipeline"; _actor.add_child(pipe)
    _bc = BuffController.new(); _bc.name = "BuffController"; _actor.add_child(_bc)
    add_child_autofree(_actor)

func _make_short_buff() -> BuffEntity:
    var b := BuffEntity.new()
    b.id = &"z"
    b.duration = 0.1
    b.stacking = BuffEntity.Stacking.REFRESH
    b.effects = [CounterEffect.new()]
    return b

func test_expire_after_duration() -> void:
    _bc.apply(_make_short_buff(), null, Vector2.ZERO)
    var inst := _bc.active[0]
    _bc._physics_process(0.2)
    assert_eq(_bc.active.size(), 0)
    assert_eq(inst.tick_accums.get("counter_4", 0), 1, "EXPIRE trigger=4 fired once")

func test_clear_all_expires_all() -> void:
    _bc.apply(_make_short_buff(), null, Vector2.ZERO)
    _bc.apply(_make_short_buff(), null, Vector2.ZERO)
    var first := _bc.active[0]
    _bc.clear_all()
    assert_eq(_bc.active.size(), 0)
    assert_eq(first.tick_accums.get("counter_4", 0), 1)
