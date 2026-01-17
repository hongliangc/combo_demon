extends "res://Util/StateMachine/CommonStates/wander_state.gd"

## Enemy Wander 状态 - 使用通用 WanderState 模板
## 配置参数以匹配原有行为

func _ready():
	# 随机方向
	random_direction = true

	# 使用 owner 的速度和时间参数
	use_owner_speed = true  # 使用 owner.wander_speed, min_wander_time, max_wander_time

	# 启用玩家检测
	enable_player_detection = true

	# 状态转换
	next_state_on_timeout = "idle"  # 超时后转到 idle
	chase_state_name = "chase"  # 检测到玩家后转到 chase

	# 移动设置
	enable_sprite_flip = true
