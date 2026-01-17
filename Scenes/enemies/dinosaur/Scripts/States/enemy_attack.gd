extends "res://Util/StateMachine/CommonStates/attack_state.gd"

## Enemy Attack 状态 - 使用通用 AttackState 模板
## 配置参数以匹配原有行为

func _ready():
	# 攻击设置
	attack_interval = 3.0
	attack_name = "slash_attack"

	# 使用 AttackComponent
	use_attack_component = true
	attack_anchor_path = "../../AttackAnchor"

	# 距离设置
	use_owner_range = true  # 使用 owner.follow_radius

	# 状态转换
	chase_state_name = "chase"
	idle_state_name = "wander"

	# 移动设置
	stop_movement = false  # 攻击时不立即停止
	deceleration_rate = 10.0
