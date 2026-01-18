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

# 8方向地图专用：击飞物理模拟
var original_y: float = 0.0  # 记录击飞前的原始Y坐标
var vertical_offset: float = 0.0  # 模拟的垂直偏移（用于击飞动画）
var vertical_velocity: float = 0.0  # 垂直速度（用于模拟抛物线）

func enter() -> void:
	if owner_node is not CharacterBody2D:
		return

	var body = owner_node as CharacterBody2D

	# 记录原始Y坐标
	original_y = body.global_position.y
	# 从当前velocity获取垂直速度（由 KnockUpEffect 设置）
	vertical_velocity = body.velocity.y
	vertical_offset = 0.0

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

	DebugConfig.debug("眩晕: %s 开始 (Y:%.1f, v:%v)" % [owner_node.name, original_y, body.velocity], "", "state_machine")


func physics_process_state(delta: float) -> void:
	if owner_node is not CharacterBody2D:
		return

	var body = owner_node as CharacterBody2D

	# 检查是否允许移动（ForceStunEffect 会设置 can_move = false）
	var can_move = true
	if "can_move" in owner_node:
		can_move = owner_node.can_move

	# 如果被强制眩晕（can_move = false），完全静止，不执行任何物理模拟
	if not can_move:
		body.velocity = Vector2.ZERO
		return

	# ============ 击飞抛物线模拟 ============
	# 更新垂直偏移和垂直速度
	vertical_offset += vertical_velocity * delta
	vertical_velocity += gravity * delta

	# 如果已经回到或低于原点，停止下落
	if vertical_offset >= 0:
		vertical_offset = 0
		vertical_velocity = 0
		# 着地后逐渐减慢横向速度（摩擦力）
		body.velocity.x = lerp(body.velocity.x, 0.0, friction)

	# 设置实际位置：原始Y + 垂直偏移
	body.global_position.y = original_y + vertical_offset

	# ============ 横向移动 ============
	# 只应用横向移动（由 KnockBackEffect 设置）
	var horizontal_velocity = Vector2(body.velocity.x, 0)
	body.velocity = horizontal_velocity
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

	# 确保回到原始Y坐标
	if owner_node is CharacterBody2D:
		var body = owner_node as CharacterBody2D
		body.global_position.y = original_y
		# 清除速度
		body.velocity = Vector2.ZERO

	DebugConfig.debug("眩晕: %s 结束" % owner_node.name, "", "state_machine")


func on_timeout() -> void:
	# 眩晕结束，根据玩家距离决定下一个状态
	if is_target_alive() and get_distance_to_target() <= detection_radius:
		transitioned.emit(self, chase_state_name)
	else:
		transitioned.emit(self, wander_state_name)


## 受到伤害时的回调 - 更新击飞/击退速度并重置定时器
func on_damaged(damage: Damage) -> void:
	if owner_node is not CharacterBody2D:
		return

	var body = owner_node as CharacterBody2D
	var effects_applied = []

	# 检查是否包含击飞特效
	if damage.has_effect("KnockUpEffect"):
		vertical_velocity = body.velocity.y
		effects_applied.append("击飞")
		# 重置定时器
		if stun_timer and reset_on_damage:
			stun_timer.start()

	# 检查是否包含击退特效
	if damage.has_effect("KnockBackEffect"):
		effects_applied.append("击退")
		# 击退不需要特殊处理，velocity.x 已经被 KnockBackEffect 设置
		# 重置定时器
		if stun_timer and reset_on_damage:
			stun_timer.start()

	if effects_applied.size() > 0:
		DebugConfig.debug("眩晕中受伤: %s %s v:%v" % [owner_node.name, ", ".join(effects_applied), body.velocity], "", "state_machine")
