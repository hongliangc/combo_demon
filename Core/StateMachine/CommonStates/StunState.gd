extends BaseState
class_name StunState

## 通用 Stun（眩晕）状态 - 包含击飞/击退物理模拟
## 支持 8 方向地图的抛物线击飞效果
## 所有可被击晕的实体（Enemy、Boss）共用此基类

# ============ 眩晕基础设置 ============
@export_group("眩晕设置")
## 眩晕持续时间
@export var stun_duration := 1.0
## 受伤时是否重置眩晕时间
@export var reset_on_damage := true

# ============ 物理模拟设置 ============
@export_group("物理模拟")
## 重力加速度（像素/秒²）- 用于击飞抛物线
@export var gravity := 980.0
## 横向摩擦力系数（0-1），0=无摩擦，1=立即停止
@export var friction := 0.1

# ============ 状态转换设置 ============
@export_group("状态转换")
## 恢复后检测玩家的半径
@export var detection_radius := 150.0
## 检测到玩家时切换的状态名
@export var chase_state_name := "chase"
## 未检测到玩家时切换的状态名
@export var wander_state_name := "wander"

# ============ 内部变量 ============
var stun_timer: Timer

func enter() -> void:
	if owner_node is not CharacterBody2D:
		return

	# 创建眩晕定时器
	stun_timer = Timer.new()
	stun_timer.wait_time = stun_duration
	stun_timer.autostart = true
	stun_timer.timeout.connect(on_timeout)
	add_child(stun_timer)

	# 标记为眩晕状态
	if owner_node is Enemy:
		var enemy = owner_node as Enemy
		enemy.stunned = true

	DebugConfig.debug("眩晕: %s 开始" % owner_node.name, "", "state_machine")


func physics_process_state(_delta: float) -> void:
	if owner_node is not CharacterBody2D:
		return

	var body = owner_node as CharacterBody2D

	# 检查是否允许横向移动（ForceStunEffect 会设置 can_move = false）
	var can_move = true
	if "can_move" in owner_node:
		can_move = owner_node.can_move

	# 如果不允许移动，直接停止横向速度
	if not can_move:
		body.velocity.x = 0
		return

	# 仅处理横向移动逻辑
	body.move_and_slide()


func exit() -> void:
	# 清理定时器
	if stun_timer:
		stun_timer.stop()
		stun_timer.timeout.disconnect(on_timeout)
		stun_timer.queue_free()
		stun_timer = null

	# 清除眩晕标记
	if owner_node is Enemy:
		var enemy = owner_node as Enemy
		enemy.stunned = false

	DebugConfig.debug("眩晕: %s 结束" % owner_node.name, "", "state_machine")


func on_timeout() -> void:
	# 眩晕结束，根据玩家距离决定下一个状态
	if is_target_alive() and get_distance_to_target() <= detection_radius:
		transitioned.emit(self, chase_state_name)
	else:
		transitioned.emit(self, wander_state_name)


## 受到伤害时的回调 - 更新击飞/击退速度并重置定时器
func on_damaged(damage: Damage, attacker_position: Vector2) -> void:
	if owner_node is not CharacterBody2D:
		return

	var body = owner_node as CharacterBody2D
	var effects_applied = []

	# 检查是否包含击飞特效
	if damage.has_effect("KnockUpEffect"):
		#damage.apply_effect(owner_node, damage_source_position)
		effects_applied.append("击飞")
		# 重置定时器
		if stun_timer and reset_on_damage:
			stun_timer.start()

	# 检查是否包含击退特效
	if damage.has_effect("KnockBackEffect"):
		#damage.apply_effect(owner_node, damage_source_position)
		effects_applied.append("击退")
		# 重置定时器
		if stun_timer and reset_on_damage:
			stun_timer.start()

	if effects_applied.size() > 0:
		DebugConfig.debug("眩晕中受伤: %s %s v:%v" % [owner_node.name, ", ".join(effects_applied), body.velocity], "", "state_machine")
