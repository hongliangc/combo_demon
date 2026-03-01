extends BaseStateMachine

## Boss 状态机 - 继承自 BaseStateMachine
## 添加了 Boss 特有的阶段转换逻辑

# 阶段转换标志 - 防止阶段转换期间被打断
var is_transitioning_phase := false

# 重写信号设置，添加 Boss 特有的信号
func _setup_signals() -> void:
	super._setup_signals()  # 调用基类方法

	# Boss 特有的 phase_changed 信号
	if owner_node and owner_node.has_signal("phase_changed"):
		if not owner_node.is_connected("phase_changed", _on_phase_changed):
			owner_node.phase_changed.connect(_on_phase_changed)

# 重写 damaged 处理，添加阶段转换期间的无敌判断
func _on_owner_damaged(damage: Damage, attacker_position: Vector2 = Vector2.ZERO) -> void:
	# 阶段转换期间不接受伤害导致的状态切换
	if is_transitioning_phase:
		return

	# 调用基类方法
	super._on_owner_damaged(damage, attacker_position)

# 阶段改变时的回调
func _on_phase_changed(new_phase: int):
	#print("Boss 阶段改变回调: Phase %d" % (new_phase + 1))

	# 设置阶段转换标志，防止被伤害打断
	is_transitioning_phase = true

	# 根据阶段智能切换状态
	if owner_node is BossBase and target_node is PlayerBase:
		var boss = owner_node as BossBase
		var player = target_node as PlayerBase

		match new_phase:
			BossBase.Phase.PHASE_2:
				# 第二阶段：根据当前距离选择合适的战斗状态
				if player and player.alive:
					var distance = boss.global_position.distance_to(player.global_position)
					if distance <= boss.attack_range:
						# 距离合适，进入绕圈或攻击
						if states.has("circle"):
							force_transition("circle")
					else:
						# 距离较远，进入追击
						if states.has("chase"):
							force_transition("chase")
			BossBase.Phase.PHASE_3:
				# 第三阶段立即进入狂暴状态
				if states.has("enrage"):
					force_transition("enrage")

	# 短暂延迟后清除标志，防止阶段转换瞬间的状态冲突
	await get_tree().create_timer(0.1).timeout
	is_transitioning_phase = false
