extends BossState

## BladeKeeper Trap 状态 — 放置地面陷阱

var _anim_tree_ref: AnimationTree

func _init() -> void:
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true

func enter() -> void:
	var boss := get_boss()
	if boss:
		boss.velocity = Vector2.ZERO
		boss.can_move = false
	_face_player()
	_anim_tree_ref = get_anim_tree()
	enter_control_state("trap_cast")
	if _anim_tree_ref:
		_anim_tree_ref.animation_finished.connect(_on_cast_finished)

func _on_cast_finished(anim_name: StringName) -> void:
	if anim_name != &"trap_cast":
		return
	var mgr := get_attack_manager() as BKAttackManager
	if mgr and target_node:
		mgr.place_trap(target_node.global_position)
	exit_control_state()
	var next := evaluate_combat_transition(false)
	transitioned.emit(self, next)

func _face_player() -> void:
	if not target_node or not owner_node:
		return
	var sprite := owner_node.get_node_or_null("AnimatedSprite2D") as Node2D
	if sprite and "flip_h" in sprite:
		sprite.flip_h = owner_node.global_position.x > target_node.global_position.x

func exit() -> void:
	exit_control_state()
	if _anim_tree_ref and _anim_tree_ref.animation_finished.is_connected(_on_cast_finished):
		_anim_tree_ref.animation_finished.disconnect(_on_cast_finished)
	var boss := get_boss()
	if boss:
		boss.can_move = true
