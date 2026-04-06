extends BaseCharacter
class_name BossBase

## Boss 基类 - 继承 BaseCharacter
## 提供通用 Boss 功能：阶段系统、巡逻点、攻击冷却、死亡处理
##
## 架构:
##   BaseCharacter → BossBase → Boss (具体Boss实现)
##   - BaseCharacter: 生命系统、伤害信号、HurtBox连接
##   - BossBase: 阶段系统、检测参数、冷却管理、死亡逻辑
##   - Boss: 8方位移动、巡逻路径、纹理选择、旋转逻辑

# ============ 信号 ============
signal phase_changed(new_phase: int)
signal boss_defeated()

# ============ 阶段枚举 ============
enum Phase {
	PHASE_1,  # 第一阶段
	PHASE_2,  # 第二阶段（更激进）
	PHASE_3   # 第三阶段（狂暴）
}

# ============ 常量 ============
const PHASE_KNOCKBACK_RADIUS := 200.0
const PHASE_KNOCKBACK_FORCE := 500.0

# ============ 行为配置（可选）============
@export var behavior_config: BehaviorConfig = null

# ============ 配置参数 ============
@export_group("Detection")
@export var detection_radius := 800.0
@export var attack_range := 300.0
@export var min_distance := 150.0  # 保持最小距离
@export var is_melee := false       ## 近战 Boss 不使用 min_distance 撤退机制

@export_group("Physics")
@export var has_gravity := false
@export var gravity := 800.0

@export_group("Phase Settings")
@export var phase_2_health_percent := 0.66  # 第二阶段触发血量
@export var phase_3_health_percent := 0.33  # 第三阶段触发血量

@export_group("Evasion")
@export var evasion_enabled := false         ## 是否启用受击闪避机制
@export var evasion_chance_per_phase: Dictionary = {} ## {Phase: 概率}

@export_group("Poise / Counter")
@export var poise_enabled := false          ## 是否启用韧性反击系统
@export var max_poise := 5                  ## 默认韧性值
@export var poise_per_phase: Dictionary = {} ## 可选：{Phase.PHASE_2: 4, Phase.PHASE_3: 3}
@export var poise_immunity_time := 1.5      ## 反击后免疫窗口

# ============ 运行时变量 ============
var current_phase: Phase = Phase.PHASE_1
var stunned := false
var can_move := true  # 用于技能聚集时强制停止移动

# 攻击冷却
var attack_cooldown := 0.0

# 眩晕免疫冷却（防止 stunlock）
var stun_immunity := 0.0

# 韧性（Poise）
var current_poise: int = 0
var poise_immunity: float = 0.0

# 巡逻相关
var patrol_points: Array[Vector2] = []
var current_patrol_index := 0

# ============ 节点引用 ============
@onready var anim_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var anim_tree: AnimationTree = $AnimationTree if has_node("AnimationTree") else null

func _on_character_ready() -> void:
	# 应用行为配置（如果有）
	if behavior_config and behavior_config.is_boss:
		detection_radius = behavior_config.detection_radius
		attack_range = behavior_config.attack_range
		min_distance = behavior_config.min_distance

	# 初始化韧性
	if poise_enabled:
		current_poise = max_poise

	# 监听生命值变化以检查阶段转换
	if health_component:
		health_component.health_changed.connect(_on_health_changed)

	# 调用子类钩子
	_on_boss_ready()

func _physics_process(delta: float) -> void:
	# 应用重力（如果启用）
	if has_gravity:
		if not is_on_floor():
			velocity.y += gravity * delta
		elif velocity.y > 0:
			velocity.y = 0
			
	# 更新攻击冷却
	if attack_cooldown > 0:
		attack_cooldown -= delta
	if stun_immunity > 0:
		stun_immunity -= delta
	if poise_immunity > 0:
		poise_immunity -= delta

	# 应用移动
	move_and_slide()

	# 更新朝向（由子类实现）
	_update_facing()

# ============ 生命值与阶段转换 ============

## 生命值变化时检查阶段转换
func _on_health_changed(current: float, _maximum: float) -> void:
	# 同步本地 health 变量
	health = int(current)

	# 检查阶段转换
	check_phase_transition()

## 检查并触发阶段转换
func check_phase_transition() -> void:
	var health_percent = float(health) / float(max_health)

	if health_percent <= phase_3_health_percent and current_phase != Phase.PHASE_3:
		change_phase(Phase.PHASE_3)
	elif health_percent <= phase_2_health_percent and current_phase == Phase.PHASE_1:
		change_phase(Phase.PHASE_2)

## 执行阶段转换
func change_phase(new_phase: Phase) -> void:
	if current_phase == new_phase:
		return

	current_phase = new_phase

	# 阶段转换特效：短暂无敌 + 击退周围敌人
	activate_phase_transition_effect()

	phase_changed.emit(new_phase)

	# 调用子类钩子
	_on_phase_transition()

# ============ 阶段转换特效 ============

## 阶段转换时的特效：短暂无敌 + 击退周围单位
func activate_phase_transition_effect() -> void:
	DebugConfig.debug("激活阶段转换特效：无敌 + 击退", "", "combat")

	# 1. 开启短暂无敌（1秒）- 使用 HealthComponent 的无敌功能
	if health_component:
		health_component.set_invincible(true, 1.0)

	# 2. 击退周围的所有单位（玩家和敌人）
	knockback_nearby_units()

	# 3. 可选：播放视觉特效
	if anim_player and anim_player.has_animation("phase_transition"):
		anim_player.play("phase_transition")

## 击退周围的单位
func knockback_nearby_units() -> void:
	var knockback_radius := PHASE_KNOCKBACK_RADIUS
	var knockback_force := PHASE_KNOCKBACK_FORCE

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

# ============ 韧性系统 ============

## 扣减韧性，返回是否触发反击
func take_poise_hit() -> bool:
	if not poise_enabled or poise_immunity > 0:
		return false
	current_poise -= 1
	return current_poise <= 0

## 反击后重置韧性
func reset_poise() -> void:
	var phase_poise: int = poise_per_phase.get(current_phase, max_poise)
	current_poise = phase_poise
	poise_immunity = poise_immunity_time

# ============ 死亡处理 ============

func _handle_death() -> void:
	boss_defeated.emit()
	await super._handle_death()

# ============ 巡逻点工具方法 ============

## 获取下一个巡逻点
func get_next_patrol_point() -> Vector2:
	if patrol_points.is_empty():
		return global_position

	var point = patrol_points[current_patrol_index]
	current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
	return point

## 判断是否到达目标位置
func is_at_position(target_pos: Vector2, threshold: float = 20.0) -> bool:
	return global_position.distance_to(target_pos) < threshold

# ============ 子类钩子 ============

## 子类初始化钩子（在 _on_character_ready 之后调用）
func _on_boss_ready() -> void:
	pass  # 子类可覆盖

## 子类阶段转换钩子（在 change_phase 之后调用）
func _on_phase_transition() -> void:
	# 阶段切换时更新韧性
	if poise_enabled:
		var phase_poise: int = poise_per_phase.get(current_phase, max_poise)
		current_poise = phase_poise

## 子类朝向更新钩子（在 _physics_process 中调用）
func _update_facing() -> void:
	pass  # 子类可覆盖（Boss 实现8方位，其他可能实现 flip_h）
