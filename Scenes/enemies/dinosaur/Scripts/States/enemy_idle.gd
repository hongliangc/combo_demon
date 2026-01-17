extends "res://Util/StateMachine/CommonStates/idle_state.gd"

## Enemy Idle 状态 - 使用通用 IdleState 模板
## 配置参数以匹配原有行为

func _ready():
	# 配置固定 1.0 秒待机时间
	min_idle_time = 1.0
	use_fixed_time = true

	# 启用玩家检测
	enable_player_detection = true

	# 状态转换
	next_state_on_timeout = "wander"  # 超时后转到 wander
	chase_state_name = "chase"  # 检测到玩家后转到 chase

	# 移动设置
	stop_movement = true


func process_state(delta: float) -> void:
	idle_timer -= delta

	# 使用 owner.detection_radius 进行玩家检测
	if owner_node is Enemy and enable_player_detection:
		var enemy = owner_node as Enemy
		var distance = get_distance_to_target()

		if is_target_alive() and distance <= enemy.detection_radius:
			transitioned.emit(self, chase_state_name)
			return

	# 待机时间结束
	if idle_timer <= 0:
		if next_state_on_timeout != "" and state_machine.states.has(next_state_on_timeout):
			transitioned.emit(self, next_state_on_timeout)
		else:
			# 重新待机
			idle_timer = min_idle_time
