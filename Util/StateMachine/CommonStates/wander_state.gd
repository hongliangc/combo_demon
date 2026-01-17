extends BaseState

## 通用 Wander（巡游）状态
## 适用于所有需要随机巡游的敌人

## 动画设置
@export var wander_animation := "walk"

## 速度设置
@export var wander_speed := 50.0
@export var use_owner_speed := true  # 优先使用 owner.wander_speed

## 时间设置
@export var min_wander_time := 2.0
@export var max_wander_time := 5.0
@export var use_fixed_time := false  # 使用固定时间而非随机

## 检测设置
@export var detection_radius := 100.0  # 检测玩家的半径
@export var enable_player_detection := true  # 是否启用玩家检测

## 方向设置
@export var random_direction := true  # 随机方向
@export var use_fixed_direction := false  # 使用固定方向
@export var fixed_direction := Vector2.RIGHT  # 固定方向（如果启用）

## 状态转换设置
@export var next_state_on_timeout := "idle"  # 超时后的状态
@export var chase_state_name := "chase"  # 检测到玩家时的状态

## 移动设置
@export var enable_sprite_flip := true  # 是否翻转精灵

var wander_direction: Vector2
var wander_timer: Timer

func enter() -> void:
	# 设置方向
	if use_fixed_direction:
		wander_direction = fixed_direction.normalized()
	elif random_direction:
		wander_direction = Vector2.UP.rotated(deg_to_rad(randf_range(0, 360)))
	else:
		wander_direction = Vector2.RIGHT  # 默认向右

	# 设置定时器
	wander_timer = Timer.new()
	if use_fixed_time:
		wander_timer.wait_time = min_wander_time
	else:
		# 使用 owner 的时间参数（如果有）
		var min_time = min_wander_time
		var max_time = max_wander_time
		if use_owner_speed and "min_wander_time" in owner_node:
			min_time = owner_node.min_wander_time
		if use_owner_speed and "max_wander_time" in owner_node:
			max_time = owner_node.max_wander_time
		wander_timer.wait_time = randf_range(min_time, max_time)

	wander_timer.autostart = true
	wander_timer.timeout.connect(_on_timer_finished)
	add_child(wander_timer)

	# 播放动画
	if owner_node and owner_node.has_method("play_animation"):
		owner_node.play_animation(wander_animation)


func physics_process_state(_delta: float) -> void:
	# 检测玩家
	if enable_player_detection:
		var chase_radius = detection_radius
		if use_owner_speed and "detection_radius" in owner_node:
			chase_radius = owner_node.detection_radius

		if is_target_alive() and is_target_in_range(chase_radius):
			transitioned.emit(self, chase_state_name)
			return

	# 移动
	if owner_node is CharacterBody2D:
		var body = owner_node as CharacterBody2D

		# 使用 owner 的速度属性（如果有且启用）
		var speed = wander_speed
		if use_owner_speed and "wander_speed" in owner_node:
			speed = owner_node.wander_speed

		body.velocity = wander_direction * speed
		body.move_and_slide()

		# 翻转精灵（如果有且启用）
		if enable_sprite_flip and "sprite" in owner_node and owner_node.sprite is Sprite2D:
			var sprite = owner_node.sprite as Sprite2D
			sprite.flip_h = wander_direction.x < 0


func exit() -> void:
	if wander_timer:
		wander_timer.stop()
		wander_timer.timeout.disconnect(_on_timer_finished)
		wander_timer.queue_free()
		wander_timer = null


func _on_timer_finished() -> void:
	if next_state_on_timeout != "" and state_machine.states.has(next_state_on_timeout):
		transitioned.emit(self, next_state_on_timeout)
