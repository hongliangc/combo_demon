extends BossState

## Boss 狂暴状态 - 第三阶段专用，快速接近并连续攻击

@export var enrage_speed_multiplier := 1.8
@export var rapid_attack_cooldown := 0.5

func enter():
	print("Boss: 进入狂暴状态！！！")

func physics_process_state(_delta: float) -> void:
	if not is_target_alive():
		transitioned.emit(self, "patrol")
		return

	if owner_node is not Boss:
		return

	var boss = owner_node as Boss
	var distance = get_distance_to_target()

	# 太近了也会短暂后退（即使是狂暴模式）
	if distance < boss.min_distance * 0.5:  # 第三阶段更贴身，只在很近时后退
		transitioned.emit(self, "retreat")
		return

	# 狂暴模式：直接冲向玩家
	var direction = get_direction_to_target()
	boss.velocity = direction * boss.move_speed * enrage_speed_multiplier

	# 快速攻击
	if boss.attack_cooldown <= 0:
		_perform_rapid_attack()
		boss.attack_cooldown = rapid_attack_cooldown

	# 频繁使用特殊攻击（第三阶段更激进）
	if boss.special_attack_cooldown <= 0 and randf() < 0.3:
		transitioned.emit(self, "specialattack")

func _perform_rapid_attack():
	if owner_node is not Boss:
		return

	var boss = owner_node as Boss
	print("Boss 狂暴快速攻击！")

	var attack_manager = _get_attack_manager()
	if not attack_manager:
		return

	# 狂暴模式：使用多种强力攻击组合
	var attack_pattern = randi() % 4
	match attack_pattern:
		0:
			# 密集扇形弹幕
			print("狂暴攻击：密集扇形弹幕")
			attack_manager.fire_projectiles(6, PI / 3)
		1:
			# 三连发追踪弹
			print("狂暴攻击：三连发追踪弹")
			if target_node:
				var target_pos = (target_node as Node2D).global_position
				attack_manager.fire_single_projectile(target_pos)
				await get_tree().create_timer(0.1).timeout
				if is_instance_valid(attack_manager) and target_node:
					attack_manager.fire_single_projectile((target_node as Node2D).global_position)
				await get_tree().create_timer(0.1).timeout
				if is_instance_valid(attack_manager) and target_node:
					attack_manager.fire_single_projectile((target_node as Node2D).global_position)
		2:
			# 小型螺旋弹幕
			print("狂暴攻击：小型螺旋弹幕")
			attack_manager.fire_spiral_projectiles(12)
		3:
			# 激光 + 弹幕组合
			print("狂暴攻击：激光弹幕组合")
			if target_node:
				attack_manager.fire_laser_at_player()
			await get_tree().create_timer(0.15).timeout
			if is_instance_valid(attack_manager):
				attack_manager.fire_projectiles(4, PI / 4)

	# 播放攻击动画
	if boss.anim_player and boss.anim_player.has_animation("attack"):
		boss.anim_player.play("attack")

func _get_attack_manager() -> BossAttackManager:
	if owner_node is Boss:
		for child in (owner_node as Boss).get_children():
			if child is BossAttackManager:
				return child
	return null

func exit():
	pass

# 狂暴状态不会被击晕
func on_damaged(_damage: Damage):
	print("Boss 狂暴中，无法击晕！")
	# 不会切换到 stun 状态
