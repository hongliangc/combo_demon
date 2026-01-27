extends BossState

## Boss 撤退状态 - 当玩家太近时保持安全距离

@export var retreat_speed_multiplier := 1.2
@export var retreat_attack_cooldown := 0.8  # 撤退时的攻击冷却

# 撤退计时器 - 防止长时间撤退
var retreat_timer := 0.0
const MAX_RETREAT_TIME := 2.0  # 最多撤退2秒

# 边撤退边攻击冷却
var retreat_attack_timer := 0.0

# 脱困技能冷却（防止无限触发）
var escape_skill_cooldown := 0.0
const ESCAPE_SKILL_CD := 3.0  # 脱困技能3秒CD

func enter():
	#print("Boss: 进入撤退状态")
	retreat_timer = 0.0
	retreat_attack_timer = 0.0

func physics_process_state(delta: float) -> void:
	if not is_target_alive():
		transitioned.emit(self, "patrol")
		return

	if owner_node is not Boss:
		return

	var boss = owner_node as Boss
	var distance = get_distance_to_target()
	retreat_timer += delta
	retreat_attack_timer -= delta
	escape_skill_cooldown -= delta

	# 已经拉开距离，可以转为其他状态
	if distance >= boss.min_distance * 1.5:
		# 如果在攻击范围内且冷却好了，攻击
		if distance <= boss.attack_range and boss.attack_cooldown <= 0:
			transitioned.emit(self, "attack")
		else:
			transitioned.emit(self, "circle")
		return

	# 撤退时间过长，说明可能被逼入角落（需要CD检查）
	if retreat_timer >= MAX_RETREAT_TIME and escape_skill_cooldown <= 0:
		handle_cornered_situation()
		return

	# 检测是否被逼到地图边缘或角落（需要CD检查）
	if (is_near_map_boundary() or is_stuck()) and escape_skill_cooldown <= 0:
		handle_cornered_situation()
		return

	# 远离玩家
	if target_node:
		var direction = (boss.global_position - (target_node as Node2D).global_position).normalized()
		boss.velocity = direction * boss.move_speed * retreat_speed_multiplier

	# 撤退时发动攻击（边退边打）
	if retreat_attack_timer <= 0:
		perform_retreat_attack()
		retreat_attack_timer = retreat_attack_cooldown

func handle_cornered_situation():
	"""处理被逼入角落的情况"""
	if owner_node is not Boss:
		return

	#print("Boss 被逼入角落！")

	# 设置脱困技能CD，防止无限触发
	escape_skill_cooldown = ESCAPE_SKILL_CD

	# 根据阶段选择不同的脱困策略
	var boss = owner_node as Boss
	match boss.current_phase:
		Boss.Phase.PHASE_1:
			# 第一阶段：使用击退技能
			use_knockback_skill()
			transitioned.emit(self, "circle")
		Boss.Phase.PHASE_2, Boss.Phase.PHASE_3:
			# 第二、三阶段：使用闪现技能
			use_teleport_skill()
			transitioned.emit(self, "attack")

func use_knockback_skill():
	"""使用击退技能推开玩家"""
	#print("Boss 使用击退技能！")
	var attack_manager = get_attack_manager()
	if attack_manager and attack_manager.has_method("fire_knockback_wave"):
		attack_manager.fire_knockback_wave()
	else:
		# 如果没有击退技能，使用AOE替代
		if attack_manager and attack_manager.has_method("fire_aoe"):
			attack_manager.fire_aoe()

func use_teleport_skill():
	"""闪现到地图内随机安全位置"""
	if owner_node is not Boss:
		return

	#print("Boss 使用闪现技能！")

	var boss = owner_node as Boss
	var safe_position = find_safe_teleport_position()
	if safe_position != Vector2.ZERO:
		# 闪现特效（可选）
		create_teleport_effect(boss.global_position)  # 起点特效

		# 传送
		boss.global_position = safe_position
		boss.velocity = Vector2.ZERO

		# 终点特效（可选）
		create_teleport_effect(boss.global_position)

		#print("Boss 闪现到位置: ", safe_position)

func find_safe_teleport_position() -> Vector2:
	"""寻找安全的闪现位置（确保在地图wall内且不碰撞）"""
	if not target_node:
		return Vector2.ZERO

	if owner_node is not Boss:
		return Vector2.ZERO

	var boss = owner_node as Boss
	var player_pos = (target_node as Node2D).global_position

	# 获取地图边界
	var map_bounds = get_map_bounds()

	# 尝试10次找到安全位置（增加尝试次数以提高成功率）
	for i in range(10):
		var random_pos = Vector2(
			randf_range(map_bounds.position.x, map_bounds.position.x + map_bounds.size.x),
			randf_range(map_bounds.position.y, map_bounds.position.y + map_bounds.size.y)
		)

		# 检查是否在地图边界内
		if not map_bounds.has_point(random_pos):
			continue

		# 检查距离玩家足够远（至少200像素）
		var dist_to_player = random_pos.distance_to(player_pos)
		if dist_to_player < 200:
			continue

		# 检查该位置是否有墙壁碰撞
		if is_position_valid(random_pos):
			#print("找到有效闪现位置: ", random_pos)
			return random_pos

	# 如果找不到完美位置，尝试在玩家附近找一个安全位置
	#print("未找到完美位置，尝试备用策略")
	for angle in range(0, 360, 45):
		var rad = deg_to_rad(angle)
		var offset = Vector2(cos(rad), sin(rad)) * 250
		var candidate_pos = player_pos + offset

		# 确保在地图边界内
		candidate_pos.x = clamp(candidate_pos.x, map_bounds.position.x, map_bounds.position.x + map_bounds.size.x)
		candidate_pos.y = clamp(candidate_pos.y, map_bounds.position.y, map_bounds.position.y + map_bounds.size.y)

		if is_position_valid(candidate_pos):
			return candidate_pos

	# 最后的备用方案：当前位置
	#print("警告：无法找到有效闪现位置，保持原位")
	return boss.global_position

func is_position_valid(position: Vector2) -> bool:
	"""检查位置是否有效（无墙壁碰撞）"""
	if owner_node is not Boss:
		return false

	var boss = owner_node as Boss

	# 使用射线检测检查该位置是否有墙壁
	var space_state = boss.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = position
	query.collision_mask = 1  # 检查第1层（通常是墙壁层）
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var results = space_state.intersect_point(query, 1)

	# 如果没有碰撞，说明位置有效
	if results.is_empty():
		return true

	# 检查碰撞的物体是否是墙壁
	for result in results:
		var collider = result.collider
		# 如果碰撞到TileMap或墙壁，则位置无效
		if collider is TileMapLayer or collider.is_in_group("wall"):
			return false

	return true

func get_map_bounds() -> Rect2:
	"""获取地图边界（从TileMap读取）"""
	# 尝试从场景中获取TileMap节点
	var tilemap = get_tree().get_first_node_in_group("tilemap")
	if not tilemap:
		# 如果没有找到，尝试通过路径查找
		tilemap = get_tree().root.get_node_or_null("Main/TileMap/World")

	if tilemap and tilemap is TileMapLayer:
		# 获取TileMap的使用矩形（包含所有tile的区域）
		var used_rect = tilemap.get_used_rect()
		var tile_size = Vector2(tilemap.tile_set.tile_size)

		# 转换为全局坐标
		var bounds_pos = tilemap.map_to_local(used_rect.position)
		var bounds_size = Vector2(used_rect.size) * tile_size

		# 添加安全边距，防止boss贴边
		var margin = 100.0
		return Rect2(
			bounds_pos.x + margin,
			bounds_pos.y + margin,
			bounds_size.x - margin * 2,
			bounds_size.y - margin * 2
		)

	# 备用方案：返回默认估算值
	#print("警告：未找到TileMap，使用默认地图边界")
	return Rect2(-500, -500, 1000, 1000)

func create_teleport_effect(position: Vector2):
	"""创建闪现特效"""
	var teleport_vfx_scene = preload("res://Scenes/VFX/TeleportVfx.tscn")
	var vfx = teleport_vfx_scene.instantiate()

	# 将特效添加到场景根节点，确保不受boss移动影响
	get_tree().root.add_child(vfx)
	vfx.global_position = position

	# 触发粒子发射
	vfx.emitting = true

	# 等待粒子效果播放完毕后自动删除
	await get_tree().create_timer(vfx.lifetime).timeout
	if is_instance_valid(vfx):
		vfx.queue_free()

func is_near_map_boundary() -> bool:
	"""检测是否靠近地图边缘"""
	if owner_node is not Boss:
		return false

	var boss = owner_node as Boss
	var map_bounds = get_map_bounds()
	var margin = 50.0  # 边缘安全距离

	return (boss.global_position.x <= map_bounds.position.x + margin or
			boss.global_position.x >= map_bounds.position.x + map_bounds.size.x - margin or
			boss.global_position.y <= map_bounds.position.y + margin or
			boss.global_position.y >= map_bounds.position.y + map_bounds.size.y - margin)

func is_stuck() -> bool:
	"""检测是否卡住（速度很小但在尝试移动）"""
	if owner_node is not Boss:
		return false

	var boss = owner_node as Boss
	return boss.velocity.length() < 10.0 and retreat_timer > 0.5

func perform_retreat_attack():
	"""撤退时发动攻击"""
	if owner_node is not Boss:
		return

	#print("Boss 撤退时发动攻击")

	var boss = owner_node as Boss
	var attack_manager = get_attack_manager()
	if not attack_manager:
		return

	# 根据阶段使用不同的撤退攻击
	match boss.current_phase:
		Boss.Phase.PHASE_1:
			# 单发弹幕
			if target_node:
				attack_manager.fire_single_projectile((target_node as Node2D).global_position)
		Boss.Phase.PHASE_2:
			# 小型扇形弹幕
			attack_manager.fire_projectiles(3, PI / 6)
		Boss.Phase.PHASE_3:
			# 螺旋弹幕 + 追踪弹
			attack_manager.fire_spiral_projectiles(8)

func get_attack_manager() -> BossAttackManager:
	if owner_node is Boss:
		for child in (owner_node as Boss).get_children():
			if child is BossAttackManager:
				return child
	return null

func exit():
	pass
