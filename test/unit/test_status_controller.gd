extends GutTest

## StatusController unit tests — only non-obvious branch logic.
## Cross-layer behavior is covered by test_buff_pipeline_integration.gd.

var _actor: Node
var _bc: BuffController
var _sc: StatusController
var _pipe: DamagePipeline

func before_each() -> void:
	_actor = Node.new()
	_pipe = DamagePipeline.new(); _pipe.name = "DamagePipeline"; _actor.add_child(_pipe)
	_bc = BuffController.new(); _bc.name = "BuffController"; _actor.add_child(_bc)
	_sc = StatusController.new(); _sc.name = "StatusController"; _actor.add_child(_sc)
	add_child_autofree(_actor)

func test_apply_lock_longest_wins() -> void:
	# Re-applying a shorter duration must NOT shrink an existing longer timer.
	_sc.apply_lock(LegalAction.ATTACK, 0.5)
	_sc.apply_lock(LegalAction.ATTACK, 1.0)
	_sc.apply_lock(LegalAction.ATTACK, 0.3)   # shorter — ignored
	assert_almost_eq(_sc._action_timers[LegalAction.ATTACK], 1.0, 0.01)

func test_lock_decays_to_zero() -> void:
	# Timer-decay branch in _process must clear the bit and restore the action.
	_sc.apply_lock(LegalAction.HURTABLE, 0.1)
	_sc._process(0.2)
	assert_true(_sc.can_be_hit())
