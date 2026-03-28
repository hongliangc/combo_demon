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

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true
	animation_state = "retreat"

func enter():
	retreat_timer = 0.0
	retreat_attack_timer = 0.0

func physics_process_state(delta: float) -> void:
	if not _boss:
		return

	if not is_target_alive():
		transitioned.emit(self, "patrol")
		return

	var distance := get_distance_to_target()
	retreat_timer += delta
	retreat_attack_timer -= delta
	escape_skill_cooldown -= delta

	# 已经拉开距离，使用统一决策选择下一个状态
	if distance >= _boss.min_distance * 1.5:
		var next := evaluate_combat_transition()
		transitioned.emit(self, next)
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
		var direction := (_boss.global_position - (target_node as Node2D).global_position).normalized()
		var cyclops := _boss as Cyclops
		_boss.velocity = direction * (cyclops.move_speed if cyclops else 150.0) * retreat_speed_multiplier

	# 撤退时发动攻击（边退边打）
	if retreat_attack_timer <= 0:
		_perform_retreat_attack()
		retreat_attack_timer = retreat_attack_cooldown

func handle_cornered_situation() -> void:
	if not _boss:
		return

	# 设置脱困技能CD，防止无限触发
	escape_skill_cooldown = ESCAPE_SKILL_CD

	# 根据阶段选择不同的脱困策略
	match _boss.current_phase:
		BossBase.Phase.PHASE_1:
			# 第一阶段：使用击退技能
			_use_knockback_skill()
			transitioned.emit(self, "circle")
		BossBase.Phase.PHASE_2, BossBase.Phase.PHASE_3:
			# 第二、三阶段：使用闪现技能
			_use_teleport_skill()
			transitioned.emit(self, "attack")

func _use_knockback_skill() -> void:
	var attack_manager := get_attack_manager()
	if attack_manager:
		attack_manager.fire_knockback_wave()

func _use_teleport_skill() -> void:
	if not _boss:
		return

	var safe_position := find_safe_teleport_position()
	if safe_position != Vector2.ZERO:
		# 起点特效
		_create_teleport_effect(_boss.global_position)

		# 传送
		_boss.global_position = safe_position
		_boss.velocity = Vector2.ZERO

		# 终点特效
		_create_teleport_effect(_boss.global_position)

## 撤退时发动攻击（从 phase_configs 的 retreat_attacks 池中随机选取）
func _perform_retreat_attack() -> void:
	var attack_manager := get_attack_manager()
	if not attack_manager:
		return

	var config = _get_phase_config()
	if not config:
		return

	var entry = config.pick_retreat_attack()
	if entry.is_empty():
		return

	_dispatch_attack(attack_manager, entry)

func exit():
	pass

# ============ 传送与地图工具方法 ============

func find_safe_teleport_position() -> Vector2:
	if not target_node or not _boss:
		return Vector2.ZERO

	var player_pos := (target_node as Node2D).global_position
	var map_bounds := get_map_bounds()

	# 尝试10次找到安全位置
	for i in range(10):
		var random_pos := Vector2(
			randf_range(map_bounds.position.x, map_bounds.position.x + map_bounds.size.x),
			randf_range(map_bounds.position.y, map_bounds.position.y + map_bounds.size.y)
		)

		if not map_bounds.has_point(random_pos):
			continue

		var dist_to_player := random_pos.distance_to(player_pos)
		if dist_to_player < 200:
			continue

		if _is_position_valid(random_pos):
			return random_pos

	# 备用策略：在玩家附近找一个安全位置
	for angle in range(0, 360, 45):
		var rad := deg_to_rad(angle)
		var offset := Vector2(cos(rad), sin(rad)) * 250
		var candidate_pos := player_pos + offset

		candidate_pos.x = clamp(candidate_pos.x, map_bounds.position.x, map_bounds.position.x + map_bounds.size.x)
		candidate_pos.y = clamp(candidate_pos.y, map_bounds.position.y, map_bounds.position.y + map_bounds.size.y)

		if _is_position_valid(candidate_pos):
			return candidate_pos

	# 最后的备用方案：当前位置
	return _boss.global_position

func _is_position_valid(pos: Vector2) -> bool:
	if not _boss:
		return false

	var space_state := _boss.get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collision_mask = 1  # 墙壁层
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var results := space_state.intersect_point(query, 1)

	if results.is_empty():
		return true

	for result in results:
		var collider = result.collider
		if collider is TileMapLayer or collider.is_in_group("wall"):
			return false

	return true

func get_map_bounds() -> Rect2:
	var tilemap = get_tree().get_first_node_in_group("tilemap")
	if not tilemap:
		tilemap = get_tree().root.get_node_or_null("Main/TileMap/World")

	if tilemap and tilemap is TileMapLayer:
		var tml := tilemap as TileMapLayer
		var used_rect := tml.get_used_rect()
		var tile_size := Vector2(tml.tile_set.tile_size)

		var bounds_pos := tml.map_to_local(used_rect.position)
		var bounds_size := Vector2(used_rect.size) * tile_size

		var margin := 100.0
		return Rect2(
			bounds_pos.x + margin,
			bounds_pos.y + margin,
			bounds_size.x - margin * 2,
			bounds_size.y - margin * 2
		)

	return Rect2(-500, -500, 1000, 1000)

## 创建闪现特效（VFX 添加到场景根节点，不受状态切换影响）
func _create_teleport_effect(pos: Vector2) -> void:
	var teleport_vfx_scene = preload("res://Effects/TeleportVfx.tscn")
	var vfx = teleport_vfx_scene.instantiate()

	get_tree().root.add_child(vfx)
	vfx.global_position = pos
	vfx.emitting = true

	# await 在 VFX 节点上下文中安全（不依赖状态生命周期）
	await get_tree().create_timer(vfx.lifetime).timeout
	if is_instance_valid(vfx):
		vfx.queue_free()

func is_near_map_boundary() -> bool:
	if not _boss:
		return false

	var map_bounds := get_map_bounds()
	var margin := 50.0

	return (_boss.global_position.x <= map_bounds.position.x + margin or
			_boss.global_position.x >= map_bounds.position.x + map_bounds.size.x - margin or
			_boss.global_position.y <= map_bounds.position.y + margin or
			_boss.global_position.y >= map_bounds.position.y + map_bounds.size.y - margin)

func is_stuck() -> bool:
	if not _boss:
		return false
	return _boss.velocity.length() < 10.0 and retreat_timer > 0.5
