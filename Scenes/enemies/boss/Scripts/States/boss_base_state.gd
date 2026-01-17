extends BaseState
class_name BossState

## Boss 状态基类 - 直接继承 BaseState
## Boss 特有逻辑：第三阶段不会被击晕

# Boss 特有的 on_damaged 实现：第三阶段不会被击晕
func on_damaged(_damage: Damage):
	if owner_node is Boss:
		var boss = owner_node as Boss
		if boss.current_phase != Boss.Phase.PHASE_3:  # 第三阶段不会被击晕
			transitioned.emit(self, "stun")
