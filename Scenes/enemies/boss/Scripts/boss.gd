extends CharacterBody2D
class_name Boss

## Boss 基类 - 支持多阶段战斗、8方位移动、高级AI

# 预加载血条场景
const HealthBarScene = preload("res://Scenes/UI/HealthBar.tscn")

# ============ 信号 ============
signal damaged(damage: Damage)
signal health_changed(current: float, maximum: float)
signal phase_changed(new_phase: int)
signal boss_defeated()

# ============ 配置参数 ============
@export_group("Textures")
@export var textures: Array[Texture2D] = []

@export_group("Health")
@export var max_health := 1000
@export var health := 1000

@export_group("Movement")
@export var base_move_speed := 150.0  # 基础移动速度
@export var rotation_speed := 5.0

# 阶段速度倍率
const PHASE_1_SPEED_MULT = 1.0    # 正常速度
const PHASE_2_SPEED_MULT = 1.3    # 1.3倍速度
const PHASE_3_SPEED_MULT = 1.5    # 1.5倍速度

# 当前有效移动速度（根据阶段动态计算）
var move_speed: float:
	get:
		match current_phase:
			Phase.PHASE_1:
				return base_move_speed * PHASE_1_SPEED_MULT
			Phase.PHASE_2:
				return base_move_speed * PHASE_2_SPEED_MULT
			Phase.PHASE_3:
				return base_move_speed * PHASE_3_SPEED_MULT
			_:
				return base_move_speed

@export_group("Detection")
@export var detection_radius := 800.0
@export var attack_range := 300.0
@export var min_distance := 150.0  # 保持最小距离

@export_group("Phase Settings")
@export var phase_2_health_percent := 0.66  # 第二阶段触发血量
@export var phase_3_health_percent := 0.33  # 第三阶段触发血量

# ============ 8方位方向常量 ============
# 预计算的归一化向量（避免运行时计算）
const SQRT2_INV = 0.7071067811865476  # 1 / sqrt(2)
const DIRECTIONS_8 = [
	Vector2(1, 0),                    # 0: 右
	Vector2(SQRT2_INV, -SQRT2_INV),   # 1: 右上
	Vector2(0, -1),                   # 2: 上
	Vector2(-SQRT2_INV, -SQRT2_INV),  # 3: 左上
	Vector2(-1, 0),                   # 4: 左
	Vector2(-SQRT2_INV, SQRT2_INV),   # 5: 左下
	Vector2(0, 1),                    # 6: 下
	Vector2(SQRT2_INV, SQRT2_INV)     # 7: 右下
]

# ============ 阶段枚举 ============
enum Phase {
	PHASE_1,  # 第一阶段
	PHASE_2,  # 第二阶段（更激进）
	PHASE_3   # 第三阶段（狂暴）
}

# ============ 运行时变量 ============
var current_phase: Phase = Phase.PHASE_1
var stunned := false
var alive := true
var is_invincible := false  # 无敌状态（阶段转换时使用）

# 攻击冷却
var attack_cooldown := 0.0
var special_attack_cooldown := 0.0

# 移动相关
var circle_direction := 1  # 1=顺时针, -1=逆时针
var patrol_points: Array[Vector2] = []
var current_patrol_index := 0

# 血条引用
var health_bar = null

# ============ 节点引用 ============
@onready var sprite: Sprite2D = $Sprite2D
@onready var damage_numbers_anchor: Node2D = $DamageNumbersAnchor
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	if not textures.is_empty():
		sprite.texture = textures.pick_random()

	setup_patrol_points()

	# 连接 Hurtbox 信号
	var hurtbox = get_node_or_null("Hurtbox")
	if hurtbox and hurtbox.has_signal("damaged"):
		hurtbox.damaged.connect(on_damaged)

	# 初始化血条
	setup_health_bar()

func _physics_process(delta: float) -> void:
	# 更新攻击冷却
	if attack_cooldown > 0:
		attack_cooldown -= delta
	if special_attack_cooldown > 0:
		special_attack_cooldown -= delta

	# 应用移动
	move_and_slide()

	# 更新朝向（8方位）
	update_facing_direction()

# ============ 巡逻点设置 ============
func setup_patrol_points() -> void:
	# 从场景中查找巡逻标记点
	var patrol_markers = get_tree().get_nodes_in_group("boss_patrol_points")
	for marker in patrol_markers:
		if marker is Marker2D:
			patrol_points.append(marker.global_position)

	# 如果没有设置，创建默认的矩形巡逻路径
	if patrol_points.is_empty():
		var center = global_position
		for i in range(4):
			var angle = i * PI / 2
			patrol_points.append(center + Vector2(cos(angle), sin(angle)) * 200)

# ============ 血条UI ============

## 设置血条UI
func setup_health_bar() -> void:
	# 实例化血条
	if HealthBarScene:
		health_bar = HealthBarScene.instantiate()
		add_child(health_bar)

		# 设置血条位置（在Boss上方）
		health_bar.position = Vector2(-100, -120)

		# 初始化血条数值
		health_bar.set_max_value(max_health)
		health_bar.set_value(health)
		health_bar.bar_color = Color(0.8, 0.1, 0.1)  # 红色
		health_bar.show_text = true

		# 根据阶段改变血条颜色
		update_health_bar_color()

## 更新血条显示
func update_health_bar() -> void:
	if health_bar:
		health_bar.tween_to_value(health, 0.2)

## 根据阶段更新血条颜色
func update_health_bar_color() -> void:
	if not health_bar:
		return

	match current_phase:
		Phase.PHASE_1:
			health_bar.bar_color = Color(0.8, 0.1, 0.1)  # 红色
		Phase.PHASE_2:
			health_bar.bar_color = Color(0.9, 0.5, 0.1)  # 橙色
		Phase.PHASE_3:
			health_bar.bar_color = Color(0.9, 0.1, 0.5)  # 紫红色（狂暴）

# ============ 8方位朝向更新 ============
func update_facing_direction() -> void:
	if velocity.length() < 10:
		return

	var direction = velocity.normalized()
	var angle = direction.angle()

	# 转换为8方位索引
	var direction_index = int(round(angle / (PI / 4))) % 8
	if direction_index < 0:
		direction_index += 8

	# 平滑旋转到目标方向
	if sprite:
		var target_rotation = DIRECTIONS_8[direction_index].angle()
		sprite.rotation = lerp_angle(sprite.rotation, target_rotation, rotation_speed * get_physics_process_delta_time())

# ============ 伤害处理 ============
func display_damage_number(damage: Damage) -> void:
	var is_critical = false
	if damage.amount > damage.max_amount * 0.8:
		is_critical = true
	DamageNumbers.display_number(damage.amount, damage_numbers_anchor.global_position, is_critical)

func on_damaged(damage: Damage, attacker_position: Vector2 = Vector2.ZERO) -> void:
	print("========== Boss.on_damaged 被调用 ==========")
	print("当前血量: ", health, "/", max_health)

	# 如果无敌，不接受伤害
	if is_invincible:
		print("Boss 处于无敌状态，忽略伤害")
		return

	# 显示伤害数字
	display_damage_number(damage)

	# 扣除生命值
	health -= int(damage.amount)
	health = max(0, health)

	# 更新血条
	update_health_bar()

	health_changed.emit(health, max_health)

	# 应用攻击特效（击飞、击退等）- 使用通用特效系统
	print("特效数量: ", damage.effects.size())
	if damage.effects.size() > 0:
		print("开始应用特效...")
		for effect in damage.effects:
			if effect != null and effect.has_method("apply_effect"):
				effect.apply_effect(self, attacker_position)
				print("应用特效: ", effect.effect_name if "effect_name" in effect else "未知特效")
		print("特效应用完成，当前velocity: ", velocity)

	# 检查阶段转换
	check_phase_transition()

	# 通知状态机切换
	print("发送 damaged 信号到状态机...")
	damaged.emit(damage)

	# 检查死亡
	if health <= 0:
		on_death()

	print("==========================================")

# ============ 阶段转换 ============
func check_phase_transition() -> void:
	var health_percent = float(health) / float(max_health)

	if health_percent <= phase_3_health_percent and current_phase != Phase.PHASE_3:
		change_phase(Phase.PHASE_3)
	elif health_percent <= phase_2_health_percent and current_phase == Phase.PHASE_1:
		change_phase(Phase.PHASE_2)

func change_phase(new_phase: Phase) -> void:
	if current_phase == new_phase:
		return

	current_phase = new_phase

	# 更新血条颜色
	update_health_bar_color()

	# 阶段转换特效：短暂无敌 + 击退周围敌人
	activate_phase_transition_effect()

	phase_changed.emit(new_phase)

	print("========== Boss 阶段转换 ==========")
	match new_phase:
		Phase.PHASE_1:
			print("进入第一阶段")
		Phase.PHASE_2:
			print("进入第二阶段 - 更激进的攻击模式！")
			# 重置特殊攻击冷却，立即使用
			special_attack_cooldown = 0
			# 可以添加阶段转换特效
		Phase.PHASE_3:
			print("进入第三阶段 - 狂暴模式！")
			special_attack_cooldown = 0
			# 可以添加狂暴特效
	print("====================================")

# ============ 阶段转换特效 ============
func activate_phase_transition_effect() -> void:
	"""阶段转换时的特效：短暂无敌 + 击退周围单位"""
	print("激活阶段转换特效：无敌 + 击退")

	# 1. 开启短暂无敌（1秒）
	is_invincible = true
	get_tree().create_timer(1.0).timeout.connect(func():
		is_invincible = false
		print("Boss 无敌状态结束")
	)

	# 2. 击退周围的所有单位（玩家和敌人）
	knockback_nearby_units()

	# 3. 可选：播放视觉特效
	if anim_player and anim_player.has_animation("phase_transition"):
		anim_player.play("phase_transition")

func knockback_nearby_units() -> void:
	"""击退周围的单位"""
	var knockback_radius := 200.0  # 击退范围
	var knockback_force := 500.0   # 击退力度

	# 获取范围内的所有物体
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = knockback_radius
	query.shape = shape
	query.transform = Transform2D(0, global_position)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var results = space_state.intersect_shape(query, 32)

	for result in results:
		var collider = result.collider

		# 跳过自己
		if collider == self:
			continue

		# 计算击退方向
		var direction = (collider.global_position - global_position).normalized()
		var distance = global_position.distance_to(collider.global_position)
		var strength = knockback_force * (1.0 - distance / knockback_radius)

		# 对玩家应用击退
		if collider.is_in_group("player") and collider.has_method("apply_knockback"):
			collider.apply_knockback(direction * strength)
			print("击退玩家")

		# 对其他敌人应用击退
		elif collider is CharacterBody2D:
			if "velocity" in collider:
				collider.velocity += direction * strength
				print("击退单位: ", collider.name)

# ============ 死亡处理 ============
func on_death() -> void:
	alive = false
	velocity = Vector2.ZERO
	boss_defeated.emit()

	print("Boss 被击败！")

	if anim_player and anim_player.has_animation("death"):
		anim_player.play("death")
		await anim_player.animation_finished

	queue_free()

# ============ 工具方法 ============
func get_next_patrol_point() -> Vector2:
	if patrol_points.is_empty():
		return global_position

	var point = patrol_points[current_patrol_index]
	current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
	return point

func is_at_position(target_pos: Vector2, threshold: float = 20.0) -> bool:
	return global_position.distance_to(target_pos) < threshold

# ============ 调试绘制 ============
func _draw() -> void:
	if Engine.is_editor_hint() or OS.is_debug_build():
		# 绘制检测范围
		draw_circle(Vector2.ZERO, detection_radius, Color(1, 1, 0, 0.1))
		draw_circle(Vector2.ZERO, attack_range, Color(1, 0, 0, 0.1))
		draw_circle(Vector2.ZERO, min_distance, Color(0, 1, 0, 0.1))
