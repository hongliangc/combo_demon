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
	# 从 config 读取 idle 时间（如果可用）
	var config := _get_config()
	var min_t := config.min_idle_time if config else min_idle_time
	var max_t := config.max_idle_time if config else max_idle_time

	var duration = min_t if use_fixed_time else randf_range(min_t, max_t)
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
		_evaluate_idle_transition()


## 评估 Idle 状态中的转换（子类可重写）
## Boss: 使用 attack_range + detection_radius + cooldown 决策
## Enemy: 检查攻击范围 → 检查追击范围
func _evaluate_idle_transition() -> void:
	# Boss 决策路径
	if owner_node is BossBase:
		var boss := owner_node as BossBase
		if not is_target_alive():
			return
		var distance := get_distance_to_target()
		var config := _get_config()
		var atk_range := config.attack_range if config and config.is_boss else boss.attack_range
		var det_radius := config.detection_radius if config and config.is_boss else boss.detection_radius
		if distance <= atk_range and boss.attack_cooldown <= 0:
			transition_to("attack")
		elif distance <= det_radius:
			transition_to("chase")
		return

	# Enemy 默认行为
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
