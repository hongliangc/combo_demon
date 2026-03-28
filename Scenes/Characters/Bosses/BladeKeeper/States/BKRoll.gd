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

	_anim_tree_ref = get_anim_tree()

	# 侧向闪避（垂直于面向玩家的方向）
	var to_player := (target_node.global_position - boss.global_position).normalized()
	_roll_direction = Vector2(-to_player.y, to_player.x)
	if randf() > 0.5:
		_roll_direction = -_roll_direction

	enter_control_state("roll")
	if _anim_tree_ref:
		_anim_tree_ref.animation_finished.connect(_on_roll_finished)

func physics_process_state(_delta: float) -> void:
	var boss := get_boss()
	if boss:
		boss.velocity = _roll_direction * roll_speed

func _on_roll_finished(_anim_name: StringName) -> void:
	var boss := get_boss()
	if boss:
		boss.velocity = Vector2.ZERO
	exit_control_state()
	var next := evaluate_combat_transition()
	transitioned.emit(self, next)

func exit() -> void:
	exit_control_state()
	if _anim_tree_ref and _anim_tree_ref.animation_finished.is_connected(_on_roll_finished):
		_anim_tree_ref.animation_finished.disconnect(_on_roll_finished)
	var boss := get_boss()
	if boss:
		boss.velocity = Vector2.ZERO
