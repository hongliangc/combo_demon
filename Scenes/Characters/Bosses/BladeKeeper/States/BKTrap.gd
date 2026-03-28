extends BossState

## BladeKeeper Trap 状态 — 放置地面陷阱

var _anim_tree_ref: AnimationTree

func _init() -> void:
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true

func enter() -> void:
	_anim_tree_ref = get_anim_tree()
	enter_control_state("trap_cast")
	if _anim_tree_ref:
		_anim_tree_ref.animation_finished.connect(_on_cast_finished)

func _on_cast_finished(_anim_name: StringName) -> void:
	var mgr := get_attack_manager() as BKAttackManager
	if mgr and target_node:
		mgr.place_trap(target_node.global_position)
	exit_control_state()
	var next := evaluate_combat_transition(false)
	transitioned.emit(self, next)

func exit() -> void:
	if _anim_tree_ref and _anim_tree_ref.animation_finished.is_connected(_on_cast_finished):
		_anim_tree_ref.animation_finished.disconnect(_on_cast_finished)
