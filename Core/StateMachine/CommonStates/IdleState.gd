extends BaseState

## 通用 Idle 状态
## 适用于所有需要待机状态的实体
## 支持定时转换和玩家检测

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true
	animation_state = "idle"

# ============ 时间设置 ============
@export_group("时间设置")
## 最小待机时间
@export var min_idle_time := 1.0
## 最大待机时间
@export var max_idle_time := 3.0
## 使用固定时间而非随机
@export var use_fixed_time := false

# ============ 检测设置 ============
@export_group("检测设置")
## 是否启用玩家检测
@export var enable_player_detection := true

# ============ 状态转换 ============
@export_group("状态转换")
## 超时后转换的状态
@export var next_state_on_timeout := "wander"

# ============ 移动设置 ============
@export_group("移动设置")
## 是否立即停止移动
@export var stop_immediately := true
## 减速率（如果不立即停止）
@export var deceleration_rate := 5.0


func enter() -> void:
	# 设置待机时间
	var duration = min_idle_time if use_fixed_time else randf_range(min_idle_time, max_idle_time)
	start_timer(duration, _on_idle_timeout)

	# 停止移动
	if stop_immediately:
		stop_movement()

	# 设置动画：idle 位置（0, 0）
	set_locomotion(Vector2.ZERO)


func physics_process_state(delta: float) -> void:
	if owner_node is not CharacterBody2D:
		return

	var body = owner_node as CharacterBody2D

	if stop_immediately:
		body.velocity = Vector2.ZERO
	else:
		decelerate_velocity(deceleration_rate, delta)

	body.move_and_slide()

	# 保持 locomotion 在 idle 位置
	set_locomotion(Vector2.ZERO)


func process_state(_delta: float) -> void:
	# 检测玩家
	if enable_player_detection:
		# 优先检查攻击范围：在攻击范围内直接进入攻击，跳过追击
		if try_attack():
			return
		if try_chase():
			return


func _on_idle_timeout() -> void:
	if next_state_on_timeout != "":
		transition_to(next_state_on_timeout)
	else:
		# 重新开始待机
		var duration = min_idle_time if use_fixed_time else randf_range(min_idle_time, max_idle_time)
		start_timer(duration, _on_idle_timeout)


func exit() -> void:
	stop_timer()
