extends BossState

## Boss 追击状态

@export var chase_attack_cooldown := 1.2  # 追击时的攻击冷却

# 追击时攻击冷却计时器
var chase_attack_timer := 0.0

func enter():
	DebugConfig.debug("Boss: 进入追击状态", "", "ai")
	chase_attack_timer = 0.0

func physics_process_state(delta: float) -> void:
	if not is_target_alive():
		transitioned.emit(self, "patrol")
		return

	if owner_node is not Boss:
		return

	var boss = owner_node as Boss
	var distance = get_distance_to_target()
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
	var direction = get_direction_to_target()
	var random_offset = Vector2(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))
	direction = (direction + random_offset).normalized()

	boss.velocity = direction * boss.move_speed

	# 追击时发动攻击（边追边打）
	if chase_attack_timer <= 0:
		_perform_chase_attack()
		chase_attack_timer = chase_attack_cooldown

func _perform_chase_attack():
	"""追击时发动攻击"""
	if owner_node is not Boss:
		return

	var boss = owner_node as Boss
	DebugConfig.debug("Boss 追击时发动攻击", "", "ai")

	var attack_manager = get_attack_manager()
	if not attack_manager:
		return

	# 根据阶段使用不同的追击攻击
	match boss.current_phase:
		Boss.Phase.PHASE_1:
			# 第一阶段：单发追踪弹
			if target_node:
				attack_manager.fire_single_projectile((target_node as Node2D).global_position)
		Boss.Phase.PHASE_2:
			# 第二阶段：小扇形弹幕
			attack_manager.fire_projectiles(3, PI / 8)
		Boss.Phase.PHASE_3:
			# 第三阶段：固定使用扇形弹幕
			attack_manager.fire_projectiles(5, PI / 4)

func exit():
	pass
