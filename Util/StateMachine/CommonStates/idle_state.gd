extends BaseState

## 通用 Idle 状态
## 适用于所有需要待机状态的实体
## 可通过导出参数自定义行为

## 动画设置
@export var idle_animation := "idle"

## 时间设置
@export var min_idle_time := 1.0
@export var max_idle_time := 3.0
@export var use_fixed_time := false  # 使用固定时间而非随机

## 检测设置
@export var detection_radius := 100.0  # 检测玩家的半径
@export var enable_player_detection := true  # 是否启用玩家检测

## 状态转换设置
@export var next_state_on_timeout := "wander"  # 超时后转换的状态 (如果为空则重新待机)
@export var chase_state_name := "chase"  # 检测到玩家时转换的状态

## 移动设置
@export var stop_movement := true  # 是否停止移动
@export var deceleration_rate := 5.0  # 减速率 (如果不立即停止)

var idle_timer := 0.0

func enter() -> void:
	# 设置待机时间
	if use_fixed_time:
		idle_timer = min_idle_time
	else:
		idle_timer = randf_range(min_idle_time, max_idle_time)

	# 播放动画（如果 owner 有动画播放器）
	if owner_node and owner_node.has_method("play_animation"):
		owner_node.play_animation(idle_animation)

	# 停止移动
	if stop_movement and owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO


func physics_process_state(delta: float) -> void:
	# 确保停止移动
	if owner_node is CharacterBody2D:
		var body = owner_node as CharacterBody2D

		if not stop_movement:
			# 渐进减速（如果不是立即停止）
			body.velocity = body.velocity.lerp(Vector2.ZERO, deceleration_rate * delta)
		else:
			# 立即停止：每帧强制设置velocity为ZERO，防止外部因素（如重力）修改velocity
			body.velocity = Vector2.ZERO

		# 调用 move_and_slide() 来应用速度变化
		body.move_and_slide()


func process_state(delta: float) -> void:
	idle_timer -= delta

	# 检测玩家
	if enable_player_detection and is_target_alive() and is_target_in_range(detection_radius):
		transitioned.emit(self, chase_state_name)
		return

	# 待机时间结束
	if idle_timer <= 0:
		if next_state_on_timeout != "" and state_machine.states.has(next_state_on_timeout):
			transitioned.emit(self, next_state_on_timeout)
		else:
			# 如果没有指定下一个状态，重新待机
			if use_fixed_time:
				idle_timer = min_idle_time
			else:
				idle_timer = randf_range(min_idle_time, max_idle_time)
