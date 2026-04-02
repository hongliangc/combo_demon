extends BossAttackManager
class_name CyclopsAttackManager

## Cyclops Boss 攻击管理器 — 弹幕/激光/AOE/连击

# ============ Combo 工厂查找 ============

## 将字符串工厂名解析为 Callable（Cyclops 专用连击）
static func resolve_combo_factory(factory_name: String) -> Callable:
	match factory_name:
		"create_triple_shot": return BossComboAttack.create_triple_shot
		"create_fan_spiral": return BossComboAttack.create_fan_spiral
		"create_laser_shockwave": return BossComboAttack.create_laser_shockwave
		"create_spiral_aoe": return BossComboAttack.create_spiral_aoe
		"create_laser_barrage": return BossComboAttack.create_laser_barrage
		"create_ultimate_combo": return BossComboAttack.create_ultimate_combo
		"create_double_spiral": return BossComboAttack.create_double_spiral
	return Callable()

@export var projectile_scene: PackedScene
@export var laser_scene: PackedScene
@export var aoe_scene: PackedScene

@export_group("Damage Configs")
@export var projectile_damage: Damage
@export var laser_damage: Damage
@export var aoe_damage: Damage

func _execute_attack(entry: Dictionary, _target_pos: Vector2) -> void:
	var mode: String = entry.get("mode", "")
	var player := get_player()
	match mode:
		"fan_spread":
			fire_projectiles(entry.get("count", 3), entry.get("spread", PI / 6))
		"spiral":
			fire_spiral_projectiles(entry.get("count", 12))
		"laser":
			if player:
				fire_laser_at_player()
		"aoe":
			fire_aoe()
		"rapid_fire":
			if player:
				fire_rapid_projectiles(player, entry.get("count", 3))
		"combo":
			var factory = entry.get("factory")
			var callable: Callable
			if factory is Callable:
				callable = factory
			elif factory is String:
				callable = CyclopsAttackManager.resolve_combo_factory(factory)
			if callable.is_valid():
				var combo: BossComboAttack = callable.call()
				if combo:
					execute_combo(combo)

# ============ 连击攻击 ============

func execute_combo(combo: BossComboAttack) -> void:
	if not combo or combo.get_step_count() == 0:
		push_warning("连击配置为空或无步骤")
		return

	var boss := _get_boss()
	for step in combo.steps:
		if step.delay > 0:
			await get_tree().create_timer(step.delay).timeout
		if not is_instance_valid(boss) or boss.stunned:
			return
		_execute_combo_step(step)

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

func fire_projectiles(count: int, spread_angle: float = PI / 6) -> void:
	var boss := _get_boss()
	if not projectile_scene or not boss:
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

func fire_single_projectile(target_position: Vector2) -> void:
	var boss := _get_boss()
	if not projectile_scene or not boss:
		return
	var direction = (target_position - boss.global_position).normalized()
	spawn_projectile(direction.angle())

func fire_spiral_projectiles(count: int = 16, angle_offset: float = 0.0) -> void:
	var boss := _get_boss()
	if not projectile_scene or not boss:
		return
	for i in range(count):
		var angle = (PI * 2 / count) * i + angle_offset
		spawn_projectile(angle)

func spawn_projectile(angle: float) -> void:
	var boss := _get_boss()
	if not boss:
		return
	var projectile = projectile_scene.instantiate()
	get_tree().root.add_child(projectile)
	projectile.global_position = boss.global_position
	if projectile.has_method("set_direction"):
		var direction = Vector2.RIGHT.rotated(angle)
		projectile.set_direction(direction)
	else:
		projectile.rotation = angle
	if projectile_damage and "damage_config" in projectile:
		projectile.damage_config = projectile_damage.duplicate(true)

# ============ 激光攻击 ============

func fire_laser(target_position: Vector2) -> void:
	var boss := _get_boss()
	if not laser_scene or not boss:
		return
	for child in boss.get_children():
		if child is BossLaser:
			return
	var laser = laser_scene.instantiate()
	boss.add_child(laser)
	laser.position = Vector2.ZERO
	var direction = (target_position - boss.global_position).normalized()
	laser.rotation = direction.angle()
	if laser_damage and "damage_config" in laser:
		laser.damage_config = laser_damage.duplicate(true)

func fire_laser_at_player() -> void:
	var target = get_player()
	if target:
		fire_laser(target.global_position)

# ============ AOE 攻击 ============

func fire_aoe() -> void:
	var boss := _get_boss()
	if not aoe_scene or not boss:
		return
	var aoe = aoe_scene.instantiate()
	get_tree().root.add_child(aoe)
	aoe.global_position = boss.global_position
	if aoe_damage and "damage_config" in aoe:
		aoe.damage_config = aoe_damage.duplicate(true)

func fire_aoe_at(position: Vector2) -> void:
	if not aoe_scene:
		return
	var aoe = aoe_scene.instantiate()
	get_tree().root.add_child(aoe)
	aoe.global_position = position
	if aoe_damage and "damage_config" in aoe:
		aoe.damage_config = aoe_damage.duplicate(true)

# ============ 击退技能 ============

func fire_knockback_wave() -> void:
	var boss := _get_boss()
	if not boss:
		return
	fire_spiral_projectiles(20)
	await get_tree().create_timer(0.1).timeout
	if not is_instance_valid(boss):
		return
	fire_aoe()
	var player = get_player()
	if is_instance_valid(player) and boss.global_position.distance_to(player.global_position) < 200:
		apply_knockback_to_player(player)

func apply_knockback_to_player(player: Node2D) -> void:
	var boss := _get_boss()
	if not player or not boss:
		return
	var knockback_direction = (player.global_position - boss.global_position).normalized()
	var knockback_strength = 500.0
	if "velocity" in player:
		player.velocity = knockback_direction * knockback_strength

# ============ 连续弹幕（异步安全） ============

func fire_rapid_projectiles(target: Node2D, count: int, interval: float = 0.1) -> void:
	var boss := _get_boss()
	for i in count:
		if not is_instance_valid(target) or not is_instance_valid(boss):
			return
		fire_single_projectile(target.global_position)
		if i < count - 1:
			await get_tree().create_timer(interval).timeout
