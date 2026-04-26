extends GutTest

var _actor: Node
var _bc: BuffController

func before_each() -> void:
	_actor = Node.new()
	var pipe := DamagePipeline.new(); pipe.name = "DamagePipeline"; _actor.add_child(pipe)
	_bc = BuffController.new(); _bc.name = "BuffController"; _actor.add_child(_bc)
	add_child_autofree(_actor)

func test_modifier_default_is_one() -> void:
	assert_eq(_bc.get_modifier(StatIds.INCOMING_DAMAGE), 1.0)

func test_add_modifier_multiplies() -> void:
	_bc.add_stat_modifier(StatIds.INCOMING_DAMAGE, 0.5)
	_bc.add_stat_modifier(StatIds.INCOMING_DAMAGE, 0.5)
	assert_eq(_bc.get_modifier(StatIds.INCOMING_DAMAGE), 0.25)

func test_remove_modifier_restores() -> void:
	_bc.add_stat_modifier(StatIds.INCOMING_DAMAGE, 0.5)
	_bc.remove_stat_modifier(StatIds.INCOMING_DAMAGE, 0.5)
	assert_eq(_bc.get_modifier(StatIds.INCOMING_DAMAGE), 1.0)

func test_legal_action_locks_aggregate() -> void:
	var b1 := BuffEntity.new(); b1.id = &"a"; b1.legal_action_locks = LegalAction.MOVE
	var b2 := BuffEntity.new(); b2.id = &"b"; b2.legal_action_locks = LegalAction.ATTACK
	_bc.apply(b1, null, Vector2.ZERO)
	_bc.apply(b2, null, Vector2.ZERO)
	assert_eq(_bc.get_legal_action_locks(), LegalAction.MOVE | LegalAction.ATTACK)
