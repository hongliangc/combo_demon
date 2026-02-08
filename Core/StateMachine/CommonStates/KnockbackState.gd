extends BaseState
class_name KnockbackState

## 通用 Knockback（击退）状态
## 处理击退物理模拟，速度降低后自动恢复
## 属于反应层，可打断行为层状态

func _init():
	priority = StatePriority.REACTION
	can_be_interrupted = false
	animation_state = "knockback"

# ============ 物理模拟设置 ============
@export_group("物理模拟")
## 摩擦力系数，越大减速越快
@export var friction := 5.0
## 最小速度阈值（低于此值视为停止）
@export var min_velocity := 10.0


func enter() -> void:
	DebugConfig.debug("击退: %s 开始 v:%v" % [owner_node.name, (owner_node as CharacterBody2D).velocity if owner_node is CharacterBody2D else Vector2.ZERO], "", "state_machine")


func physics_process_state(delta: float) -> void:
	if owner_node is not CharacterBody2D:
		return

	var body = owner_node as CharacterBody2D

	# 应用摩擦力减速
	decelerate_velocity(friction, delta)
	body.move_and_slide()

	# 检查是否应该结束击退状态
	if body.velocity.length() < min_velocity or body.is_on_wall():
		decide_next_state()


func exit() -> void:
	stop_movement()
	DebugConfig.debug("击退: %s 结束" % owner_node.name, "", "state_machine")


## 受到伤害时的回调 - 可能切换到更高优先级状态
func on_damaged(damage: Damage, _attacker_position: Vector2) -> void:
	# 检查是否有眩晕效果（切换到控制状态）
	if damage.has_effect("StunEffect") or damage.has_effect("ForceStunEffect"):
		transition_to("stun")
		return
	# 击退中再次被击退：叠加速度（由 Effect 处理）
