extends BossState

## Boss 追击状态

@export var chase_attack_cooldown := 1.2  # 追击时的攻击冷却

# 追击时攻击冷却计时器
var chase_attack_timer := 0.0

func enter():
	print("Boss: 进入追击状态")
	chase_attack_timer = 0.0

func physics_process_state(delta: float) -> void:
	if not player or not player.alive:
		transitioned.emit(self, "patrol")
		return

	var distance = get_distance_to_player()
	chase_attack_timer -= delta

	# 离开检测范围，返回巡逻
	if distance > boss.detection_radius:
		transitioned.emit(self, "patrol")
		return

	# 进入攻击范围，准备攻击
	if distance <= boss.attack_range:
		transitioned.emit(self, "attack")
		return

	# 太近了，保持距离
	if distance < boss.min_distance:
		transitioned.emit(self, "retreat")
		return

	# 追击玩家，添加一些随机性避免直线追击
	var direction = get_direction_to_player()
	var random_offset = Vector2(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))
	direction = (direction + random_offset).normalized()

	# 根据阶段调整速度
	var speed_multiplier = 1.0
	match boss.current_phase:
		Boss.Phase.PHASE_2:
			speed_multiplier = 1.3
		Boss.Phase.PHASE_3:
			speed_multiplier = 1.5

	boss.velocity = direction * boss.move_speed * speed_multiplier

	# 追击时发动攻击（边追边打）
	if chase_attack_timer <= 0:
		perform_chase_attack()
		chase_attack_timer = chase_attack_cooldown

func perform_chase_attack():
	"""追击时发动攻击"""
	print("Boss 追击时发动攻击")

	var attack_manager = get_attack_manager()
	if not attack_manager:
		return

	# 根据阶段使用不同的追击攻击
	match boss.current_phase:
		Boss.Phase.PHASE_1:
			# 第一阶段：单发追踪弹
			if player:
				attack_manager.fire_single_projectile(player.global_position)
		Boss.Phase.PHASE_2:
			# 第二阶段：小扇形弹幕（移除双发追踪弹避免await）
			attack_manager.fire_projectiles(3, PI / 8)
		Boss.Phase.PHASE_3:
			# 第三阶段：固定使用扇形弹幕（避免await）
			attack_manager.fire_projectiles(5, PI / 4)

func get_attack_manager() -> BossAttackManager:
	if boss:
		for child in boss.get_children():
			if child is BossAttackManager:
				return child
	return null

func exit():
	pass
