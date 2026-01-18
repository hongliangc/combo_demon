extends AttackEffect
class_name ForceStunEffect

## 强制眩晕特效 - 强制敌人进入 stun 状态
## 用于特殊技能：在攻击过程中锁定敌人，使其无法移动

@export_group("眩晕参数")
## 眩晕持续时间
@export var stun_duration: float = 3.0

## 是否停止敌人移动
@export var stop_movement: bool = true

func _init():
	effect_name = "强制眩晕"
	duration = 3.0

func apply_effect(target: CharacterBody2D, damage_source_position: Vector2) -> void:
	super.apply_effect(target, damage_source_position)

	# 停止移动
	if stop_movement:
		target.velocity = Vector2.ZERO

	# 禁用敌人移动控制
	if "can_move" in target:
		target.can_move = false

	# 标记为眩晕状态
	if "stunned" in target:
		target.stunned = true

	# 强制切换到 stun 状态（如果有状态机）
	var state_machine = _find_state_machine(target)
	if state_machine:
		# 获取 stun 状态并配置眩晕时间
		var stun_state = state_machine.states.get("stun")
		if stun_state:
			# 设置眩晕时间
			if "stun_duration" in stun_state:
				stun_state.stun_duration = stun_duration

			# 禁用击飞效果（强制眩晕不应该有击飞）
			if "vertical_velocity" in stun_state:
				stun_state.vertical_velocity = 0.0

		# 强制切换到 stun 状态
		if state_machine.has_method("force_transition"):
			state_machine.force_transition("stun")

		# 切换到 stun 状态后，再次确保 velocity 为0（避免碰撞推挤）
		target.velocity = Vector2.ZERO

		if show_debug_info:
			DebugConfig.info("强制眩晕: %s %.1fs" % [target.name, stun_duration], "", "effect")

	# 注意：眩晕恢复由 StunState 的定时器控制，不在这里创建定时器

## 查找目标的状态机节点
func _find_state_machine(target: Node) -> Node:
	# 查找状态机节点（通常命名为 StateMachine 或继承自 BaseStateMachine）
	for child in target.get_children():
		if child is BaseStateMachine or child.name == "StateMachine":
			return child
	return null

func get_description() -> String:
	return "强制眩晕 - 持续: %.1f秒" % stun_duration
