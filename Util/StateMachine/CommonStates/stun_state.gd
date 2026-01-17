extends BaseState

## 通用 Stun（眩晕）状态
## 所有可被击晕的实体共用
## 注意：此状态不包含复杂物理模拟（击飞/击退），仅用于简单眩晕

## 动画设置
@export var stun_animation := "stun"

## 眩晕设置
@export var stun_duration := 0.5
@export var reset_on_damage := true  # 受伤时重置眩晕时间

## 检测设置
@export var detection_radius := 150.0  # 恢复后检测玩家的半径

## 移动设置
@export var stop_movement := true  # 是否立即停止
@export var deceleration_rate := 5.0  # 减速率（如果不立即停止）

## 状态转换设置
@export var chase_state_name := "chase"  # 检测到玩家时的状态
@export var idle_state_name := "idle"  # 未检测到玩家时的状态
@export var custom_recovery_logic := false  # 使用自定义恢复逻辑（子类重载）

var stun_timer := 0.0

func enter() -> void:
	stun_timer = stun_duration

	# 标记为眩晕状态（如果 owner 有此属性）
	if "stunned" in owner_node:
		owner_node.stunned = true

	# 播放眩晕动画
	if owner_node and owner_node.has_method("play_animation"):
		owner_node.play_animation(stun_animation)

	# 停止移动
	if stop_movement and owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO


func physics_process_state(delta: float) -> void:
	# 渐进减速（如果不是立即停止）
	if not stop_movement and owner_node is CharacterBody2D:
		var body = owner_node as CharacterBody2D
		body.velocity = body.velocity.lerp(Vector2.ZERO, deceleration_rate * delta)


func process_state(delta: float) -> void:
	stun_timer -= delta

	if stun_timer <= 0:
		# 眩晕结束，决定下一个状态
		if custom_recovery_logic:
			# 子类可以重载 on_stun_end() 方法
			on_stun_end()
		else:
			# 默认逻辑：检测玩家
			if is_target_alive() and is_target_in_range(detection_radius):
				transitioned.emit(self, chase_state_name)
			else:
				transitioned.emit(self, idle_state_name)


func exit() -> void:
	# 清除眩晕标记
	if "stunned" in owner_node:
		owner_node.stunned = false


func on_damaged(_damage: Damage) -> void:
	# 眩晕期间再次受伤，重置眩晕时间（如果启用）
	if reset_on_damage:
		stun_timer = stun_duration


## 虚方法 - 子类可重载以实现自定义恢复逻辑
func on_stun_end() -> void:
	# 默认实现与 process_state 中的逻辑相同
	if is_target_alive() and is_target_in_range(detection_radius):
		transitioned.emit(self, chase_state_name)
	else:
		transitioned.emit(self, idle_state_name)
