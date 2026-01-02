extends BossState

## Boss 特殊攻击状态 - 激光、螺旋弹幕、冲击波等

@export var special_attack_duration := 2.0

var attack_timer := 0.0
var has_attacked := false

func enter():
	print("Boss: 进入特殊攻击状态")
	attack_timer = special_attack_duration
	has_attacked = false

	# 停止移动
	boss.velocity = Vector2.ZERO

func process_state(delta: float) -> void:
	attack_timer -= delta

	# 在中途执行特殊攻击
	if not has_attacked and attack_timer <= special_attack_duration * 0.5:
		perform_special_attack()
		has_attacked = true

	# 攻击结束
	if attack_timer <= 0:
		# 设置特殊攻击冷却
		set_special_attack_cooldown()

		# 返回战斗状态
		if boss.current_phase == Boss.Phase.PHASE_3:
			transitioned.emit(self, "enrage")
		else:
			transitioned.emit(self, "circle")

func physics_process_state(delta: float) -> void:
	# 保持静止或缓慢移动
	boss.velocity = boss.velocity.lerp(Vector2.ZERO, 10.0 * delta)

func perform_special_attack():
	print("Boss 执行特殊攻击！")

	# 根据阶段使用不同的特殊攻击
	match boss.current_phase:
		Boss.Phase.PHASE_1:
			laser_attack()
		Boss.Phase.PHASE_2:
			spiral_attack()
		Boss.Phase.PHASE_3:
			shockwave_attack()

func laser_attack():
	print("特殊攻击：激光扫射")
	var attack_manager = get_attack_manager()
	if attack_manager:
		attack_manager.fire_laser_at_player()

func spiral_attack():
	print("特殊攻击：螺旋弹幕")
	var attack_manager = get_attack_manager()
	if attack_manager:
		attack_manager.fire_spiral_projectiles(16)

func shockwave_attack():
	print("特殊攻击：终极连击冲击波")
	var attack_manager = get_attack_manager()
	if not attack_manager:
		return

	# 第三阶段的特殊攻击：使用终极连击
	var combo_choice = randi() % 2
	match combo_choice:
		0:
			# 终极连击（螺旋 + 扇形 + AOE + 激光）
			print("特殊攻击：终极连击")
			var combo = BossComboAttack.create_ultimate_combo()
			attack_manager.execute_combo(combo)
		1:
			# 双重螺旋 + AOE
			print("特殊攻击：双重螺旋 + 冲击波")
			var combo = BossComboAttack.create_double_spiral()
			attack_manager.execute_combo(combo)
			await get_tree().create_timer(0.5).timeout
			if is_instance_valid(attack_manager):
				attack_manager.fire_aoe()

func get_attack_manager() -> BossAttackManager:
	if boss:
		for child in boss.get_children():
			if child is BossAttackManager:
				return child
	return null

func set_special_attack_cooldown():
	match boss.current_phase:
		Boss.Phase.PHASE_1:
			boss.special_attack_cooldown = 5.0
		Boss.Phase.PHASE_2:
			boss.special_attack_cooldown = 4.0
		Boss.Phase.PHASE_3:
			boss.special_attack_cooldown = 2.0

func exit():
	pass

# 特殊攻击状态可以被打断（除了第三阶段）
func on_damaged(damage: Damage):
	if boss.current_phase != Boss.Phase.PHASE_3:
		transitioned.emit(self, "stun")
