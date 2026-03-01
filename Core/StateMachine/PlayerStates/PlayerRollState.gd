extends PlayerBaseState
class_name PlayerRollState

## 翻滚状态：播放翻滚动画 + 冲刺位移
## priority = REACTION(1), can_be_interrupted = false

@export var roll_speed: float = 400.0

func _init() -> void:
	priority = StatePriority.REACTION
	can_be_interrupted = false

func enter() -> void:
	enter_control_state("roll")
	set_control_time_scale(2.0)

	# 冲刺位移
	var movement = get_movement()
	if movement:
		movement.apply_dash_speed(roll_speed)

	# 监听动画结束
	var tree = get_anim_tree()
	if tree and not tree.is_connected("animation_finished", _on_animation_finished):
		tree.animation_finished.connect(_on_animation_finished)

func exit() -> void:
	set_control_time_scale(1.0)
	exit_control_state()
	var movement = get_movement()
	if movement:
		movement.can_move = true

	var tree = get_anim_tree()
	if tree and tree.is_connected("animation_finished", _on_animation_finished):
		tree.animation_finished.disconnect(_on_animation_finished)

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "roll":
		return_to_locomotion()
