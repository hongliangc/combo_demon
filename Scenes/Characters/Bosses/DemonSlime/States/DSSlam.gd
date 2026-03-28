extends BossState

## DemonSlime Slam 状态 — 圆形冲击波（共用 cleave 动画）

var _anim_tree_ref: AnimationTree

func _init() -> void:
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true

func enter() -> void:
	var boss := get_boss()
	if boss:
		boss.velocity = Vector2.ZERO
		boss.attack_cooldown = get_attack_manager().get_cooldown() if get_attack_manager() else 2.0

	_anim_tree_ref = get_anim_tree()
	enter_control_state("cleave")  # 共用 cleave 动画
	if _anim_tree_ref:
		_anim_tree_ref.animation_finished.connect(_on_slam_finished)

func _on_slam_finished(_anim_name: StringName) -> void:
	var mgr := get_attack_manager() as DSAttackManager
	var boss := get_boss()
	if mgr and boss:
		mgr.spawn_ring_shockwave(boss.global_position)

	exit_control_state()
	var next := evaluate_combat_transition(false)
	transitioned.emit(self, next)

func exit() -> void:
	if _anim_tree_ref and _anim_tree_ref.animation_finished.is_connected(_on_slam_finished):
		_anim_tree_ref.animation_finished.disconnect(_on_slam_finished)
