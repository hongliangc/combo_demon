extends PlayerBaseState
class_name PlayerHitState

## 受击状态：播放 take_hit 动画，动画结束后恢复
## priority = CONTROL(2), can_be_interrupted = false

func _init() -> void:
	priority = StatePriority.CONTROL
	can_be_interrupted = false

func enter() -> void:
	enter_control_state("take_hit")

	# 禁用移动
	var movement = get_movement()
	if movement:
		movement.can_move = false

	# 监听动画结束
	var tree = get_anim_tree()
	if tree and not tree.is_connected("animation_finished", _on_animation_finished):
		tree.animation_finished.connect(_on_animation_finished)

func exit() -> void:
	exit_control_state()
	var movement = get_movement()
	if movement:
		movement.can_move = true

	var tree = get_anim_tree()
	if tree and tree.is_connected("animation_finished", _on_animation_finished):
		tree.animation_finished.disconnect(_on_animation_finished)

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "take_hit":
		return_to_locomotion()

## 受击时直接进入此状态（由 BaseState.on_damaged 调用 transitioned）
func on_damaged(_damage: Damage, _attacker_position: Vector2) -> void:
	# 已在 hit 状态中，重新播放动画（重置受击）
	enter_control_state("take_hit")
