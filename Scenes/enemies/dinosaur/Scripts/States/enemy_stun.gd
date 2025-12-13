extends EnemyStates

var stun_timer: Timer

# 8方向地图专用：记录击飞前的原始Y坐标
var original_y: float
# 模拟的垂直偏移（用于击飞动画）
var vertical_offset: float = 0.0
# 垂直速度（用于模拟抛物线）
var vertical_velocity: float = 0.0
# 重力加速度（像素/秒²）- 用于模拟抛物线
@export var gravity: float = 980.0

func enter():
	# 记录原始Y坐标
	original_y = enemy.global_position.y
	# 从当前velocity获取垂直速度
	vertical_velocity = enemy.velocity.y
	vertical_offset = 0.0

	stun_timer = Timer.new()
	stun_timer.wait_time = 1.0
	stun_timer.autostart = true
	stun_timer.timeout.connect(on_timeout)
	add_child(stun_timer)
	enemy.stunned = true
	print("[Stun State] 进入眩晕状态")
	print("[Stun State] 原始Y坐标: ", original_y)
	print("[Stun State] 初始velocity: ", enemy.velocity)

func physics_process_state(delta: float) -> void:
	# 模拟抛物线：更新垂直偏移和垂直速度
	vertical_offset += vertical_velocity * delta
	vertical_velocity += gravity * delta

	# 如果已经回到或低于原点，停止下落
	if vertical_offset >= 0:
		vertical_offset = 0
		vertical_velocity = 0
		# 着地后逐渐减慢横向速度（摩擦力）
		enemy.velocity.x = lerp(enemy.velocity.x, 0.0, 0.1)

	# 设置实际位置：原始Y + 垂直偏移
	enemy.global_position.y = original_y + vertical_offset

	# 只应用横向移动
	var horizontal_velocity = Vector2(enemy.velocity.x, 0)
	enemy.velocity = horizontal_velocity
	enemy.move_and_slide()

	# 调试输出
	#if abs(vertical_offset) > 1 or abs(enemy.velocity.x) > 10:
		#print("[Stun State] offset: %.1f, v_velocity: %.1f, h_velocity: %.1f" % [vertical_offset, vertical_velocity, enemy.velocity.x])

func exit():
	stun_timer.stop()
	stun_timer.timeout.disconnect(self.on_timeout)
	stun_timer.queue_free()
	stun_timer = null
	enemy.stunned = false
	# 确保回到原始Y坐标
	enemy.global_position.y = original_y
	# 清除速度
	enemy.velocity = Vector2.ZERO
	print("[Stun State] 退出眩晕状态，恢复到Y: ", original_y)


func on_timeout():
	if !try_chase():
		transitioned.emit(self, "chase")

# 在眩晕状态中受到伤害时，更新击飞/击退速度并重置定时器
func on_damaged(damage: Damage):
	print("========================================")
	print("[Stun State] ✨ 眩晕状态的 on_damaged 被调用！")
	print("[Stun State] 在眩晕中再次受伤，检查特效类型")
	print("========================================")

	# 检查是否包含击飞特效
	if damage.has_effect("KnockUpEffect"):
		print("[Stun State] 检测到击飞特效，更新垂直速度")
		vertical_velocity = enemy.velocity.y
		print("[Stun State] 更新后的垂直速度: ", vertical_velocity)
		# 重置定时器
		stun_timer.start()

	# 检查是否包含击退特效
	if damage.has_effect("KnockBackEffect"):
		print("[Stun State] 检测到击退特效，横向速度已更新: ", enemy.velocity.x)
		# 击退不需要特殊处理，velocity.x 已经被 KnockBackEffect 设置
		# 重置定时器
		stun_timer.start()
