extends "res://Core/StateMachine/CommonStates/AttackState.gd"

## Enemy Attack 状态 - 使用通用 AttackState 模板
## 简化版：AttackState 现在自动从 owner 获取参数（follow_radius）

func _init():
	super._init()
	# 攻击设置
	attack_interval = 3.0
	attack_name = "slash_attack"

	# 使用 AttackComponent
	use_attack_component = true
	attack_anchor_path = "../../AttackAnchor"

	# 移动设置
	stop_on_attack = false  # 攻击时不立即停止
	deceleration_rate = 10.0

	# 恢复后状态
	default_state_name = "wander"
