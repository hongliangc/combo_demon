extends BaseState
class_name BossState

## Boss 状态基类 - 直接继承 BaseState
## 提供 Boss 通用功能：攻击管理器访问、阶段判断、受伤响应

func _init():
	# 默认为行为层，子类可覆盖
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true
	animation_state = "idle"

## 获取 Boss 的攻击管理器（子类共用）
func get_attack_manager() -> BossAttackManager:
	if owner_node is Boss:
		for child in (owner_node as Boss).get_children():
			if child is BossAttackManager:
				return child
	return null

## 获取当前 Boss 引用（便捷方法）
func get_boss() -> Boss:
	return owner_node as Boss if owner_node is Boss else null

## Boss 特有的 on_damaged 实现：第三阶段不会被击晕
func on_damaged(_damage: Damage, _attacker_position: Vector2 = Vector2.ZERO) -> void:
	var boss = get_boss()
	if boss and boss.current_phase != Boss.Phase.PHASE_3:
		transitioned.emit(self, "stun")
