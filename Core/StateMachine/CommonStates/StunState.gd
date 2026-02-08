extends BaseState
class_name StunState

## 通用 Stun（眩晕）状态
## 控制层最高优先级，不可被打断
## 支持眩晕期间的物理模拟

func _init():
	priority = StatePriority.CONTROL
	can_be_interrupted = false
	animation_state = "stunned"
	# 眩晕恢复后默认进入 wander
	default_state_name = "wander"

# ============ 眩晕设置 ============
@export_group("眩晕设置")
## 眩晕持续时间
@export var stun_duration := 1.0
## 眩晕动画播放速度（1.0=正常, 0.5=半速慢放, 2.0=两倍速）
@export var stun_anim_speed := 1.0
## 受伤时是否重置眩晕时间
@export var reset_on_damage := true


func enter() -> void:
	start_timer(stun_duration)

	# 检查是否有击退速度（由 KnockBackEffect 在状态转换前设置）
	# 如果有击退，保留速度让 physics_process_state 处理减速
	# 如果没有击退，立即停止移动
	if owner_node is CharacterBody2D:
		var body = owner_node as CharacterBody2D
		var has_knockback = body.velocity.length() > 10.0
		if not has_knockback:
			stop_movement()

	# 进入控制层状态：stunned
	enter_control_state("stunned")

	# 设置眩晕动画播放速度
	set_control_time_scale(stun_anim_speed)

	# 标记为眩晕状态
	if "stunned" in owner_node:
		owner_node.stunned = true

	DebugConfig.debug("眩晕: %s 开始" % owner_node.name, "", "state_machine")


## 击退减速率（每秒减速的比例）
@export var knockback_friction := 8.0

func physics_process_state(delta: float) -> void:
	if owner_node is not CharacterBody2D:
		return

	var body = owner_node as CharacterBody2D

	# 眩晕期间保持静止（除非有击退效果正在应用）
	# 检查是否有击退速度（由 KnockBackEffect 设置）
	var has_knockback = body.velocity.length() > 10.0
	if has_knockback:
		# 应用摩擦力让击退自然减速
		body.velocity = body.velocity.lerp(Vector2.ZERO, knockback_friction * delta)
	else:
		body.velocity = Vector2.ZERO

	body.move_and_slide()


func exit() -> void:
	stop_timer()

	# 退出控制状态，返回到正常行为
	exit_control_state()

	# 恢复动画播放速度
	set_control_time_scale(1.0)

	# 清除眩晕标记
	if "stunned" in owner_node:
		owner_node.stunned = false

	DebugConfig.debug("眩晕: %s 结束" % owner_node.name, "", "state_machine")


## 受到伤害时的回调 - 重置眩晕时间
func on_damaged(damage: Damage, _attacker_position: Vector2) -> void:
	# 检查是否包含击飞/击退特效，重置定时器
	if damage.has_effect("KnockUpEffect") or damage.has_effect("KnockBackEffect"):
		if reset_on_damage:
			reset_timer()
		DebugConfig.debug("眩晕中受伤: %s" % owner_node.name, "", "state_machine")
