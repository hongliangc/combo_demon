extends CharacterBody2D
class_name Boss

## Boss 基类 - 使用组件化架构
## 支持多阶段战斗、8方位移动、高级AI
## 伤害处理由 HealthComponent 负责

# ============ 信号 ============
## 转发给状态机（由 HealthComponent.damaged 触发）
signal damaged(damage: Damage, attacker_position: Vector2)
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
var can_move := true  # 用于技能聚集时强制停止移动
var alive := true

# 攻击冷却
var attack_cooldown := 0.0
var special_attack_cooldown := 0.0

# 移动相关
var circle_direction := 1  # 1=顺时针, -1=逆时针
var patrol_points: Array[Vector2] = []
var current_patrol_index := 0

# ============ 节点引用 ============
@onready var sprite: Sprite2D = $Sprite2D
@onready var damage_numbers_anchor: Node2D = $DamageNumbersAnchor
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var health_component: HealthComponent = $HealthComponent

func _ready() -> void:
	if not textures.is_empty():
		sprite.texture = textures.pick_random()

	setup_patrol_points()
	_setup_signals()

## 设置信号连接
func _setup_signals() -> void:
	# 连接 Hurtbox 到 HealthComponent
	var hurtbox = get_node_or_null("Hurtbox")
	if hurtbox and health_component:
		hurtbox.damaged.connect(health_component.take_damage)

	# 监听 HealthComponent 的信号
	if health_component:
		health_component.damaged.connect(_on_health_component_damaged)
		health_component.health_changed.connect(_on_health_changed)
		health_component.died.connect(on_death)

		# 同步初始生命值到 HealthComponent
		health_component.max_health = max_health
		health_component.health = health

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

# ============ 伤害处理 ============

## HealthComponent 受伤时的回调 - 转发信号给状态机
func _on_health_component_damaged(damage: Damage, attacker_position: Vector2) -> void:
	# 转发信号给状态机
	damaged.emit(damage, attacker_position)

## 生命值变化时检查阶段转换
func _on_health_changed(current: float, _maximum: float) -> void:
	# 同步本地 health 变量
	health = int(current)

	# 检查阶段转换
	check_phase_transition()

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

	# 阶段转换特效：短暂无敌 + 击退周围敌人
	activate_phase_transition_effect()

	phase_changed.emit(new_phase)

	match new_phase:
		Phase.PHASE_2:
			# 重置特殊攻击冷却，立即使用
			special_attack_cooldown = 0
		Phase.PHASE_3:
			special_attack_cooldown = 0

# ============ 阶段转换特效 ============
func activate_phase_transition_effect() -> void:
	"""阶段转换时的特效：短暂无敌 + 击退周围单位"""
	DebugConfig.debug("激活阶段转换特效：无敌 + 击退", "", "combat")

	# 1. 开启短暂无敌（1秒）- 使用 HealthComponent 的无敌功能
	if health_component:
		health_component.set_invincible(true, 1.0)

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

		# 对其他敌人应用击退
		elif collider is CharacterBody2D:
			if "velocity" in collider:
				collider.velocity += direction * strength

# ============ 死亡处理 ============
func on_death() -> void:
	alive = false
	velocity = Vector2.ZERO
	boss_defeated.emit()

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
