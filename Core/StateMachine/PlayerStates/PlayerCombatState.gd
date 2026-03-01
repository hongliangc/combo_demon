extends PlayerBaseState
class_name PlayerCombatState

## 战斗状态：播放攻击动画，动画结束后返回 Ground/Air
## priority = REACTION(1), can_be_interrupted = false

var current_skill: String = ""

func _init() -> void:
	priority = StatePriority.REACTION
	can_be_interrupted = false

func enter() -> void:
	current_skill = owner_node.pending_combat_skill if owner_node else ""

	# 进入 control_sm 播放攻击动画
	if current_skill != "":
		enter_control_state(current_skill)

	# 加速攻击动画
	set_control_time_scale(2.0)

	# 禁用移动
	var movement = get_movement()
	if movement:
		movement.can_move = false

	# 监听动画结束
	var tree = get_anim_tree()
	if tree and not tree.is_connected("animation_finished", _on_animation_finished):
		tree.animation_finished.connect(_on_animation_finished)

func exit() -> void:
	# 恢复动画速度和移动
	set_control_time_scale(1.0)
	var movement = get_movement()
	if movement:
		movement.can_move = true

	# 断开信号
	var tree = get_anim_tree()
	if tree and tree.is_connected("animation_finished", _on_animation_finished):
		tree.animation_finished.disconnect(_on_animation_finished)

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == current_skill:
		return_to_locomotion()
