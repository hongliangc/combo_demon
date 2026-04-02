extends BossState

## DemonSlime Cleave 状态 — 扇形冲击波

var _anim_tree_ref: AnimationTree

func _init() -> void:
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true

func enter() -> void:
	var boss := get_boss()
	if boss:
		boss.velocity = Vector2.ZERO
		boss.attack_cooldown = get_attack_manager().get_cooldown() if get_attack_manager() else 2.5

	_anim_tree_ref = get_anim_tree()
	enter_control_state("cleave")
	if _anim_tree_ref:
		_anim_tree_ref.animation_finished.connect(_on_cleave_finished)

func _on_cleave_finished(_anim_name: StringName) -> void:
	# 生成扇形冲击波
	var mgr := get_attack_manager() as DSAttackManager
	var boss := get_boss()
	if mgr and boss and target_node:
		var facing: Vector2 = (target_node.global_position - boss.global_position).normalized()
		mgr.spawn_fan_shockwave(boss.global_position, facing)

	exit_control_state()
	var next := evaluate_combat_transition(false)
	transitioned.emit(self, next)

func exit() -> void:
	if _anim_tree_ref and _anim_tree_ref.animation_finished.is_connected(_on_cleave_finished):
		_anim_tree_ref.animation_finished.disconnect(_on_cleave_finished)
