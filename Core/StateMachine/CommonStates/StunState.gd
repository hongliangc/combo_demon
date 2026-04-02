extends BaseState
class_name StunState

## 通用 Stun（眩晕）状态
## 控制层最高优先级，不可被打断
## 支持眩晕期间的物理模拟

const KNOCKBACK_SPEED_THRESHOLD := 10.0

func _init():
	priority = StatePriority.CONTROL
	can_be_interrupted = false
	animation_state = "stunned"
	# 眩晕恢复后默认进入 wander
	default_state_name = StateNames.WANDER

# ============ 眩晕设置 ============
@export_group("眩晕设置")
## 眩晕持续时间
@export var stun_duration := 1.0
## 眩晕动画播放速度（1.0=正常, 0.5=半速慢放, 2.0=两倍速）
@export var stun_anim_speed := 1.0
## 受伤时是否重置眩晕时间
@export var reset_on_damage := true


func enter() -> void:
	var config := _get_config()
	var duration := config.stun_duration if config else stun_duration
	var anim_speed := config.stun_anim_speed if config else stun_anim_speed
	start_timer(duration)

	# 检查是否有击退速度（由 KnockBackEffect 在状态转换前设置）
	# 如果有击退，保留速度让 physics_process_state 处理减速
	# 如果没有击退，立即停止移动
	if owner_node is CharacterBody2D:
		var body = owner_node as CharacterBody2D
		var has_knockback = body.velocity.length() > KNOCKBACK_SPEED_THRESHOLD
		if not has_knockback:
			stop_movement()

	enter_control_state("stunned")
	set_control_time_scale(anim_speed)

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
	var has_knockback = body.velocity.length() > KNOCKBACK_SPEED_THRESHOLD
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

	# 子类钩子（如设置眩晕免疫）
	_on_stun_exit()

	DebugConfig.debug("眩晕: %s 结束" % owner_node.name, "", "state_machine")


## 眩晕退出钩子（子类可重写）
## Boss: 设置眩晕免疫计时器
func _on_stun_exit() -> void:
	if owner_node is BossBase:
		var boss := owner_node as BossBase
		var config := _get_config()
		var immunity := config.stun_immunity_duration if config and config.is_boss else 1.5
		boss.stun_immunity = immunity


## 根据玩家距离决定下一个状态
## Boss: 使用 evaluate_transition() 统一决策
## Enemy: 使用 BaseState 默认行为
func decide_next_state() -> void:
	if owner_node is BossBase:
		var next := evaluate_transition()
		transition_to(next)
		return
	# Enemy 默认
	super.decide_next_state()


## 受到伤害时的回调 - 重置眩晕时间
func on_damaged(damage: Damage, _attacker_position: Vector2) -> void:
	# 检查是否包含击飞/击退特效，重置定时器
	if damage.has_effect("KnockUpEffect") or damage.has_effect("KnockBackEffect"):
		if reset_on_damage:
			reset_timer()
		DebugConfig.debug("眩晕中受伤: %s" % owner_node.name, "", "state_machine")
