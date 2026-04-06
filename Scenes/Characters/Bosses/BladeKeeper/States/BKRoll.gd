extends BossState

## BladeKeeper Roll 状态 — 侧向闪避

@export var roll_speed := 250.0

var _roll_direction := Vector2.ZERO
var _anim_tree_ref: AnimationTree

func _init() -> void:
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = false

func enter() -> void:
	var boss := get_boss()
	if not boss or not target_node:
		transitioned.emit(self, "idle")
		return

	boss.velocity = Vector2.ZERO
	boss.can_move = false
	_face_player()

	_anim_tree_ref = get_anim_tree()

	# 向后闪避（背离玩家）
	_roll_direction = (boss.global_position - target_node.global_position).normalized()

	enter_control_state("roll")
	if _anim_tree_ref:
		_anim_tree_ref.animation_finished.connect(_on_roll_finished)

func physics_process_state(_delta: float) -> void:
	var boss := get_boss()
	if boss:
		boss.velocity = _roll_direction * roll_speed

func _on_roll_finished(anim_name: StringName) -> void:
	if anim_name != &"roll":
		return
	var boss := get_boss()
	if boss:
		boss.velocity = Vector2.ZERO
	exit_control_state()
	var next := evaluate_combat_transition()
	transitioned.emit(self, next)

func _face_player() -> void:
	if not target_node or not owner_node:
		return
	var sprite := owner_node.get_node_or_null("AnimatedSprite2D") as Node2D
	if sprite and "flip_h" in sprite:
		sprite.flip_h = owner_node.global_position.x > target_node.global_position.x

func exit() -> void:
	exit_control_state()
	if _anim_tree_ref and _anim_tree_ref.animation_finished.is_connected(_on_roll_finished):
		_anim_tree_ref.animation_finished.disconnect(_on_roll_finished)
	var boss := get_boss()
	if boss:
		boss.velocity = Vector2.ZERO
		boss.can_move = true
