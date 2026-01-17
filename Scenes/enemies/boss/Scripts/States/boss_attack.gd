extends BossState

## Boss 攻击状态 - 执行基础攻击

@export var attack_duration := 1.0  # 攻击动作持续时间

var attack_timer := 0.0
var has_attacked := false

func enter():
	print("Boss: 进入攻击状态")
	attack_timer = attack_duration
	has_attacked = false

	if owner_node is not Boss:
		return

	# 停止移动，准备攻击
	var boss = owner_node as Boss
	boss.velocity = Vector2.ZERO

func process_state(delta: float) -> void:
	attack_timer -= delta

	# 在攻击动作中途执行攻击
	if not has_attacked and attack_timer <= attack_duration * 0.5:
		perform_attack()
		has_attacked = true

	# 攻击结束
	if attack_timer <= 0:
		if owner_node is not Boss:
			return

		# 设置攻击冷却
		set_attack_cooldown()

		# 根据距离决定下一个状态
		if is_target_alive():
			var boss = owner_node as Boss
			var distance = get_distance_to_target()
			if distance < boss.min_distance:
				transitioned.emit(self, "retreat")
			elif distance > boss.attack_range:
				transitioned.emit(self, "chase")
			else:
				transitioned.emit(self, "circle")
		else:
			transitioned.emit(self, "idle")

func physics_process_state(delta: float) -> void:
	if owner_node is not Boss:
		return

	# 攻击时缓慢减速
	var boss = owner_node as Boss
	boss.velocity = boss.velocity.lerp(Vector2.ZERO, 10.0 * delta)

func perform_attack():
	if owner_node is not Boss:
		return

	print("Boss 执行攻击！")

	var boss = owner_node as Boss

	# 根据阶段决定攻击模式
	match boss.current_phase:
		Boss.Phase.PHASE_1:
			attack_pattern_phase_1()
		Boss.Phase.PHASE_2:
			attack_pattern_phase_2()
		Boss.Phase.PHASE_3:
			attack_pattern_phase_3()

	# 播放攻击动画
	if boss.anim_player and boss.anim_player.has_animation("attack"):
		boss.anim_player.play("attack")

func attack_pattern_phase_1():
	# 第一阶段：保守策略 - 随机使用基础攻击或简单连击
	var attack_manager = get_attack_manager()
	if not attack_manager:
		return

	var attack_choice = randi() % 3
	match attack_choice:
		0:
			# Fan Spread - 3发扇形弹幕
			print("阶段1攻击：扇形弹幕 (3发)")
			attack_manager.fire_projectiles(3, PI / 6)
		1:
			# Rapid Fire - 快速单发射击
			print("阶段1攻击：快速射击")
			if target_node:
				attack_manager.fire_single_projectile((target_node as Node2D).global_position)
			# 0.1秒后再发射两发
			await get_tree().create_timer(0.1).timeout
			if is_instance_valid(attack_manager) and target_node:
				attack_manager.fire_single_projectile((target_node as Node2D).global_position)
			await get_tree().create_timer(0.1).timeout
			if is_instance_valid(attack_manager) and target_node:
				attack_manager.fire_single_projectile((target_node as Node2D).global_position)
		2:
			# Combo - 三连击
			print("阶段1攻击：三连击")
			var combo = BossComboAttack.create_triple_shot()
			attack_manager.execute_combo(combo)

func attack_pattern_phase_2():
	# 第二阶段：激进策略 - 更强攻击 + 螺旋弹幕 + 连击
	var attack_manager = get_attack_manager()
	if not attack_manager:
		return

	var attack_choice = randi() % 5
	match attack_choice:
		0:
			# Fan Spread - 5发扇形弹幕（更密集）
			print("阶段2攻击：密集扇形弹幕 (5发)")
			attack_manager.fire_projectiles(5, PI / 4)
		1:
			# Spiral Barrage - 16方向螺旋弹幕
			print("阶段2攻击：螺旋弹幕 (16发)")
			attack_manager.fire_spiral_projectiles(16)
		2:
			# Laser Sweep - 激光扫射
			print("阶段2攻击：激光扫射")
			if attack_manager.laser_scene and target_node:
				attack_manager.fire_laser_at_player()
		3:
			# Combo - 扇形 + 螺旋
			print("阶段2攻击：扇形螺旋连击")
			var combo = BossComboAttack.create_fan_spiral()
			attack_manager.execute_combo(combo)
		4:
			# Combo - 激光 + 冲击波
			print("阶段2攻击：激光冲击波连击")
			var combo = BossComboAttack.create_laser_shockwave()
			attack_manager.execute_combo(combo)

func attack_pattern_phase_3():
	# 第三阶段：狂暴模式 - 多重攻击组合 + 高级连击
	var attack_manager = get_attack_manager()
	if not attack_manager:
		return

	var attack_choice = randi() % 6
	match attack_choice:
		0:
			# Fan Spread - 8发大范围弹幕
			print("阶段3攻击：超密集弹幕 (8发)")
			attack_manager.fire_projectiles(8, PI / 3)
		1:
			# Spiral Barrage + AOE - 螺旋弹幕 + 冲击波
			print("阶段3攻击：螺旋弹幕 + 冲击波组合")
			attack_manager.fire_spiral_projectiles(16)
			await get_tree().create_timer(0.3).timeout
			if is_instance_valid(attack_manager) and attack_manager.aoe_scene:
				attack_manager.fire_aoe()
		2:
			# Rapid Laser + Projectiles - 激光 + 弹幕组合
			print("阶段3攻击：激光弹幕组合")
			if attack_manager.laser_scene and target_node:
				attack_manager.fire_laser_at_player()
			await get_tree().create_timer(0.2).timeout
			if is_instance_valid(attack_manager):
				attack_manager.fire_projectiles(6, PI / 4)
		3:
			# Shockwave - AOE冲击波
			print("阶段3攻击：冲击波")
			if attack_manager.aoe_scene:
				attack_manager.fire_aoe()
		4:
			# Combo - 终极连击（螺旋 + 扇形 + AOE + 激光）
			print("阶段3攻击：终极连击")
			var combo = BossComboAttack.create_ultimate_combo()
			attack_manager.execute_combo(combo)
		5:
			# Combo - 双重螺旋
			print("阶段3攻击：双重螺旋连击")
			var combo = BossComboAttack.create_double_spiral()
			attack_manager.execute_combo(combo)

func get_attack_manager() -> BossAttackManager:
	# 从Boss节点查找攻击管理器
	if owner_node is Boss:
		for child in (owner_node as Boss).get_children():
			if child is BossAttackManager:
				return child
	return null

func set_attack_cooldown():
	if owner_node is not Boss:
		return

	# 根据阶段设置不同的攻击冷却
	var boss = owner_node as Boss
	match boss.current_phase:
		Boss.Phase.PHASE_1:
			boss.attack_cooldown = 1.5
		Boss.Phase.PHASE_2:
			boss.attack_cooldown = 1.0
		Boss.Phase.PHASE_3:
			boss.attack_cooldown = 0.7

func exit():
	pass

# 攻击状态下仍然可以被打断
func on_damaged(_damage: Damage):
	if owner_node is not Boss:
		return

	# 只有在非第三阶段才会被打断
	var boss = owner_node as Boss
	if boss.current_phase != Boss.Phase.PHASE_3:
		transitioned.emit(self, "stun")
