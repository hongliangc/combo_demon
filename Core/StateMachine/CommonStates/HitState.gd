extends BaseState
class_name HitState

## 通用 Hit（受击硬直）状态
## 适用于轻击反应，短暂停顿后恢复
## 属于反应层，可打断行为层状态
##
## 使用基类的 Timer 管理和状态决策方法简化代码

func _init():
	priority = StatePriority.REACTION
	can_be_interrupted = false
	animation_state = "hit"

# ============ 受击设置 ============
@export_group("受击设置")
## 受击硬直持续时间
@export var hit_duration := 0.2
## 受伤时是否重置硬直时间
@export var reset_on_damage := true


func enter() -> void:
	stop_movement()
	print("[HitState] enter: duration=%.2f" % hit_duration)
	start_timer(hit_duration)

	# 进入反应层状态：hit
	enter_control_state("hit")

	DebugConfig.debug("受击硬直: %s 开始" % owner_node.name, "", "state_machine")


func physics_process_state(_delta: float) -> void:
	# 硬直期间保持静止
	stop_movement()


func exit() -> void:
	stop_timer()

	# 退出控制状态，返回到正常行为
	exit_control_state()

	DebugConfig.debug("受击硬直: %s 结束" % owner_node.name, "", "state_machine")


## 受到伤害时的回调 - 重置硬直时间或切换到更高优先级状态
func on_damaged(damage: Damage, _attacker_position: Vector2) -> void:
	# 检查是否有眩晕效果（切换到控制状态）
	if damage.has_effect("StunEffect") or damage.has_effect("ForceStunEffect"):
		transition_to("stun")
		return

	# 检查是否有击退效果（切换到击退状态）
	if damage.has_effect("KnockBackEffect") or damage.has_effect("KnockUpEffect"):
		transition_to("knockback")
		return

	# 普通伤害：重置硬直时间
	if reset_on_damage:
		reset_timer()
