extends AttackEffect
class_name StunEffect

## 眩晕特效 - 触发敌人的眩晕状态和动画
## 与 ForceStunEffect 不同：
## - 不强制停止移动
## - 仅触发眩晕状态和动画
## - 用于普通攻击的眩晕效果

@export_group("眩晕参数")
## 眩晕持续时间
@export var stun_duration: float = 1.5

func _init():
	effect_name = "眩晕"
	duration = 1.5

func apply_effect(target: CharacterBody2D, _damage_source_position: Vector2) -> void:
	super.apply_effect(target, _damage_source_position)

	# 标记为眩晕状态
	if "stunned" in target:
		target.stunned = true

	# 触发眩晕状态（如果有状态机）
	var state_machine = _find_state_machine(target)
	if state_machine:
		# 获取 stun 状态并配置眩晕时间
		var stun_state = state_machine.states.get("stun")
		if stun_state:
			# 设置眩晕时间
			if "stun_duration" in stun_state:
				stun_state.stun_duration = stun_duration

		# 强制转换到 stun 状态（使用 force_transition 忽略优先级检查）
		if state_machine.has_method("force_transition"):
			state_machine.force_transition("stun")

		if show_debug_info:
			DebugConfig.info("眩晕: %s %.1fs" % [target.name, stun_duration], "", "effect")

## 查找目标的状态机节点
func _find_state_machine(target: Node) -> Node:
	# 查找状态机节点（通常命名为 StateMachine 或 EnemyStateMachine）
	for child in target.get_children():
		if child is BaseStateMachine or "StateMachine" in child.name:
			return child
	return null

func get_description() -> String:
	return "眩晕 - 持续: %.1f秒" % stun_duration
