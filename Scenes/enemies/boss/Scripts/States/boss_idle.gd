extends "res://Util/StateMachine/CommonStates/idle_state.gd"

## Boss Idle 状态 - 使用通用 IdleState 模板
## 配置参数以匹配原有行为

func _ready():
	# 固定闲置时间 2.0 秒
	min_idle_time = 2.0
	use_fixed_time = true

	# 启用玩家检测
	enable_player_detection = true

	# 移动设置
	stop_movement = true
	deceleration_rate = 5.0

	# 状态转换
	chase_state_name = "chase"
	next_state_on_timeout = "patrol"  # 闲置超时后转到巡逻


func enter():
	DebugConfig.debug("Boss: 进入闲置状态", "", "ai")
	super.enter()


## 重载检测逻辑 - Boss 使用 detection_radius 而不是通用的 detection_radius 参数
func physics_process_state(delta: float) -> void:
	if owner_node is not CharacterBody2D:
		return

	# 减速到停止
	var body = owner_node as CharacterBody2D
	body.velocity = body.velocity.lerp(Vector2.ZERO, deceleration_rate * delta)

	idle_timer -= delta
	if idle_timer <= 0:
		# 闲置结束，检测玩家
		if is_target_alive() and owner_node is Boss:
			var boss = owner_node as Boss
			var distance = get_distance_to_target()
			if distance <= boss.detection_radius:
				transitioned.emit(self, chase_state_name)
			else:
				transitioned.emit(self, next_state_on_timeout)
		else:
			transitioned.emit(self, next_state_on_timeout)
