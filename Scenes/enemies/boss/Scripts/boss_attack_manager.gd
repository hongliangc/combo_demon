extends Node
class_name BossAttackManager

## Boss 攻击管理器 - 负责生成和管理各种攻击技能

@export var projectile_scene: PackedScene
@export var laser_scene: PackedScene
@export var aoe_scene: PackedScene

# 伤害配置
@export_group("Damage Configs")
@export var projectile_damage: Damage
@export var laser_damage: Damage
@export var aoe_damage: Damage

@onready var boss: Boss = get_owner()

# ============ 连击攻击 ============

## 执行连击攻击
func execute_combo(combo: BossComboAttack) -> void:
	if not combo or combo.get_step_count() == 0:
		push_warning("连击配置为空或无步骤")
		return

	print("Boss 开始连击: ", combo.combo_name)

	for step in combo.steps:
		# 等待延迟
		if step.delay > 0:
			await get_tree().create_timer(step.delay).timeout

		# 执行攻击步骤
		_execute_combo_step(step)

## 执行单个连击步骤
func _execute_combo_step(step: BossComboAttack.AttackStep) -> void:
	match step.type:
		BossComboAttack.AttackStep.AttackType.PROJECTILE:
			var count = step.params.get("count", 1)
			for i in range(count):
				var target = get_player()
				if target:
					fire_single_projectile(target.global_position)

		BossComboAttack.AttackStep.AttackType.PROJECTILE_FAN:
			var count = step.params.get("count", 3)
			var spread = step.params.get("spread", PI / 6)
			fire_projectiles(count, spread)

		BossComboAttack.AttackStep.AttackType.PROJECTILE_SPIRAL:
			var count = step.params.get("count", 16)
			var offset = step.params.get("offset", 0.0)
			fire_spiral_projectiles(count, offset)

		BossComboAttack.AttackStep.AttackType.LASER:
			fire_laser_at_player()

		BossComboAttack.AttackStep.AttackType.AOE:
			fire_aoe()

# ============ 弹幕攻击 ============

## 发射多发弹幕（扇形散射）
func fire_projectiles(count: int, spread_angle: float = PI / 6) -> void:
	if not projectile_scene or not boss:
		push_warning("弹幕场景或Boss引用缺失")
		return

	var target = get_player()
	if not target:
		return

	var direction_to_target = (target.global_position - boss.global_position).normalized()
	var base_angle = direction_to_target.angle()

	var angle_step = spread_angle
	var start_angle = -angle_step * (count - 1) / 2

	for i in range(count):
		var angle = base_angle + start_angle + angle_step * i
		spawn_projectile(angle)

## 发射单发弹幕
func fire_single_projectile(target_position: Vector2) -> void:
	if not projectile_scene or not boss:
		return

	var direction = (target_position - boss.global_position).normalized()
	spawn_projectile(direction.angle())

## 螺旋弹幕（360度全方位）
func fire_spiral_projectiles(count: int = 16, angle_offset: float = 0.0) -> void:
	if not projectile_scene or not boss:
		return

	for i in range(count):
		var angle = (PI * 2 / count) * i + angle_offset
		spawn_projectile(angle)

## 生成单个弹幕
func spawn_projectile(angle: float) -> void:
	var projectile = projectile_scene.instantiate()
	get_tree().root.add_child(projectile)
	projectile.global_position = boss.global_position

	# 设置方向
	if projectile.has_method("set_direction"):
		var direction = Vector2.RIGHT.rotated(angle)
		projectile.set_direction(direction)
	else:
		projectile.rotation = angle

	# 设置伤害（如果有配置）
	if projectile_damage and "damage_config" in projectile:
		projectile.damage_config = projectile_damage.duplicate(true)

# ============ 激光攻击 ============

## 生成激光（朝向目标）
func fire_laser(target_position: Vector2) -> void:
	if not laser_scene or not boss:
		push_warning("激光场景或Boss引用缺失")
		return

	var laser = laser_scene.instantiate()
	# 将激光作为boss的子节点，这样它会跟随boss移动
	boss.add_child(laser)
	laser.position = Vector2.ZERO  # 相对于boss的位置

	# 设置朝向
	var direction = (target_position - boss.global_position).normalized()
	laser.rotation = direction.angle()

	# 设置伤害
	if laser_damage and "damage_config" in laser:
		laser.damage_config = laser_damage.duplicate(true)

## 生成激光（朝向玩家）
func fire_laser_at_player() -> void:
	var target = get_player()
	if target:
		fire_laser(target.global_position)

# ============ AOE 攻击 ============

## 在Boss位置生成AOE
func fire_aoe() -> void:
	if not aoe_scene or not boss:
		push_warning("AOE场景或Boss引用缺失")
		return

	var aoe = aoe_scene.instantiate()
	get_tree().root.add_child(aoe)
	aoe.global_position = boss.global_position

	# 设置伤害
	if aoe_damage and "damage_config" in aoe:
		aoe.damage_config = aoe_damage.duplicate(true)

## 在指定位置生成AOE
func fire_aoe_at(position: Vector2) -> void:
	if not aoe_scene:
		return

	var aoe = aoe_scene.instantiate()
	get_tree().root.add_child(aoe)
	aoe.global_position = position

	# 设置伤害
	if aoe_damage and "damage_config" in aoe:
		aoe.damage_config = aoe_damage.duplicate(true)

# ============ 击退技能 ============

## 发射击退波（推开周围玩家）
func fire_knockback_wave() -> void:
	"""
	发射以Boss为中心的击退波，推开附近玩家
	使用螺旋弹幕 + AOE组合创造击退效果
	"""
	print("Boss 发射击退波！")

	if not boss:
		return

	# 1. 发射密集螺旋弹幕形成冲击波视觉效果
	fire_spiral_projectiles(20)

	# 2. 在Boss位置生成AOE（用于实际击退伤害）
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(boss):
		fire_aoe()

	# 3. 对玩家施加击退力（如果玩家在范围内）
	var player = get_player()
	if player and boss.global_position.distance_to(player.global_position) < 200:
		apply_knockback_to_player(player)

## 对玩家施加击退力
func apply_knockback_to_player(player: Node2D) -> void:
	"""
	计算并施加击退力到玩家
	"""
	if not player or not boss:
		return

	# 计算击退方向（从Boss指向玩家）
	var knockback_direction = (player.global_position - boss.global_position).normalized()

	# 击退力度
	var knockback_strength = 500.0

	# 如果玩家有velocity属性，直接修改
	if "velocity" in player:
		player.velocity = knockback_direction * knockback_strength

	print("玩家被击退！方向: ", knockback_direction)

# ============ 工具方法 ============

func get_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as Node2D
