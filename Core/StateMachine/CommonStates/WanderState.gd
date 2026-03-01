extends BaseState

## 通用 Wander（巡游）状态
## 适用于所有需要随机巡游的敌人

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true
	animation_state = "wander"

# ============ 速度设置 ============
@export_group("速度设置")
## 巡游速度（优先使用 owner.wander_speed）
@export var default_wander_speed := 50.0

# ============ 时间设置 ============
@export_group("时间设置")
## 最小巡游时间
@export var min_wander_time := 2.0
## 最大巡游时间
@export var max_wander_time := 5.0

# ============ 方向设置 ============
@export_group("方向设置")
## 使用随机方向
@export var random_direction := true
## 固定方向（random_direction=false 时使用）
@export var fixed_direction := Vector2.RIGHT

# ============ 检测设置 ============
@export_group("检测设置")
## 是否启用玩家检测
@export var enable_player_detection := true

# ============ 状态转换 ============
@export_group("状态转换")
## 超时后的状态
@export var next_state_on_timeout := "idle"

# ============ 精灵设置 ============
@export_group("精灵设置")
## 是否翻转精灵
@export var enable_sprite_flip := true

var wander_direction: Vector2


func enter() -> void:
	# 设置方向
	if random_direction:
		wander_direction = Vector2.RIGHT.rotated(randf_range(0, TAU))
	else:
		wander_direction = fixed_direction.normalized()

	# 设置定时器
	var min_time = get_owner_property("min_wander_time", min_wander_time)
	var max_time = get_owner_property("max_wander_time", max_wander_time)
	start_timer(randf_range(min_time, max_time), _on_wander_timeout)


func physics_process_state(_delta: float) -> void:
	# 检测玩家
	if enable_player_detection:
		if try_chase():
			return

	# 移动
	if owner_node is CharacterBody2D:
		var body = owner_node as CharacterBody2D
		var speed = get_owner_property("wander_speed", default_wander_speed)

		body.velocity = wander_direction * speed
		body.move_and_slide()

		# 翻转精灵
		if enable_sprite_flip:
			update_sprite_facing()

		# 更新 AnimationTree 的 locomotion 混合
		# Wander 速度较低，blend_y 应在 0.0-0.5 之间（walk 速度）
		var blend_x = sign(wander_direction.x) if abs(wander_direction.x) > 0.1 else 0.0
		# 使用 chase_speed 作为最大速度参考，使 wander 显示为 walk 而不是 run
		var max_speed = get_owner_property("chase_speed", 100.0)
		var blend_y = clampf(speed / max_speed, 0.0, 0.5)  # Wander 限制在 0.5（walk 速度）
		set_locomotion(Vector2(blend_x, blend_y))
		#print("[ANIMATION] Wander: speed=%.1f blend_x=%.1f blend_y=%.2f" % [speed, blend_x, blend_y])


func _on_wander_timeout() -> void:
	transition_to(next_state_on_timeout)


func exit() -> void:
	stop_timer()
