extends CharacterBody2D
class_name Hahashin

# 预加载血条场景
const HealthBarScene = preload("res://Scenes/UI/HealthBar.tscn")

var alive: bool = true
var last_face_direction:Vector2 = Vector2.RIGHT
var input_direction: Vector2 = Vector2.RIGHT

# 特殊攻击目标位置和检测到的敌人列表
var special_attack_target_position: Vector2 = Vector2.ZERO
var special_attack_detected_enemies: Array = []

@export_group("Speed")
@export var max_speed: float = 100

@export_group("Health")
@export var max_health:float
@export var health:float

@export_group("Damage")
@export var damage_types : Array[Damage]
@export var current_damage: Damage


var can_move: bool = true

# 血条引用
var health_bar = null

func _ready() -> void:
	# 初始化为默认物理伤害
	if damage_types.size() > 0:
		current_damage = damage_types[0]

	# 连接 Hurtbox 的受伤信号
	var hurtbox = get_node_or_null("Hurtbox")
	if hurtbox and hurtbox.has_signal("damaged"):
		hurtbox.damaged.connect(on_damaged)

	# 初始化血条
	setup_health_bar()

## 设置血条UI
func setup_health_bar() -> void:
	# 实例化血条
	if HealthBarScene:
		health_bar = HealthBarScene.instantiate()
		add_child(health_bar)

		# 设置血条位置（在角色上方）
		health_bar.position = Vector2(-100, -80)

		# 初始化血条数值
		health_bar.set_max_value(max_health)
		health_bar.set_value(health)
		health_bar.bar_color = Color(0.2, 0.8, 0.2)  # 绿色
		health_bar.show_text = true

## 更新血条显示
func update_health_bar() -> void:
	if health_bar:
		health_bar.tween_to_value(health, 0.2)

# 接收伤害处理
func on_damaged(damage: Damage, attacker_position: Vector2) -> void:
	if !alive:
		return

	# 扣除生命值
	var damage_amount = damage.amount
	health -= damage_amount

	# 更新血条
	update_health_bar()

	# 显示伤害数字
	var damage_anchor = get_node_or_null("DamageNumbersAnchor")
	if damage_anchor:
		DamageNumbers.display_number(damage_amount, damage_anchor.global_position)

	# 应用特效（击退、击飞等）- 使用通用特效系统
	for effect in damage.effects:
		if effect != null:
			# 检查是否有 apply_effect 方法（鸭子类型，支持通用特效）
			if effect.has_method("apply_effect"):
				effect.apply_effect(self, attacker_position)
			# 兼容旧的特效属性
			elif "knockback_force" in effect:
				var direction = (global_position - attacker_position).normalized()
				velocity = direction * effect.knockback_force
			elif "launch_force" in effect:
				velocity.y = -effect.launch_force

	# 调试打印
	#DebugConfig.info("Player 受到伤害: %d 剩余生命: %d" % [damage_amount, health], "", "combat")

	# 检查死亡
	if health <= 0:
		die()

# 获取用户输入，控制方向
func _process(delta: float) -> void:
	if alive:
		input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

# 控制移动
func _physics_process(delta: float) -> void:
	if alive:
		# 根据输入更新速度
		if can_move:
			velocity = input_direction * max_speed

		# 移动状态才有方向
		if velocity:
			last_face_direction = velocity.normalized()

		move_and_slide()

func switch_to_physical() -> void:
	current_damage = damage_types[0]

func switch_to_knockup() -> void:
	current_damage = damage_types[1]

func switch_to_special_attack() -> void:
	if damage_types.size() > 2:
		current_damage = damage_types[2]
		DebugConfig.debug("特殊攻击: 切换到特殊攻击伤害配置", "", "combat")

## 玩家死亡处理
func die() -> void:
	if !alive:
		return

	alive = false

	# 调试打印
	DebugConfig.error("Player 死亡!", "", "player")

	# 隐藏玩家
	visible = false

	# 禁用碰撞
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	# 显示游戏结束UI
	show_game_over_ui()

## 显示游戏结束UI
func show_game_over_ui() -> void:
	# 加载游戏结束UI场景
	var game_over_scene = load("res://Scenes/UI/GameOverUI.tscn")
	if game_over_scene:
		var game_over_ui = game_over_scene.instantiate()
		get_tree().root.add_child(game_over_ui)
	else:
		push_error("无法加载 GameOverUI 场景")

## 调试打印玩家状态信息
func debug_print() -> void:
	print("========== Player 状态信息 ==========")
	print("存活状态: ", alive)
	print("生命值: ", health, "/", max_health)
	print("可移动: ", can_move)
	print("速度: ", velocity, " (最大速度: ", max_speed, ")")
	print("面对方向: ", last_face_direction)
	print("输入方向: ", input_direction)
	if current_damage:
		current_damage.debug_print()
	else:
		print("当前伤害: null")
	print("====================================")

## 检测并准备特殊攻击：检测前方是否有敌人
## 如果有敌人，返回 true 并记录第一个敌人位置和所有检测到的敌人，否则返回 false
func prepare_special_attack() -> bool:
	var detection_radius = 300.0  # 检测半径
	var detection_angle = 45.0  # 检测角度（上下各45度）

	# 检测前方范围内的敌人
	var enemies_in_range = _detect_enemies_in_cone(detection_radius, detection_angle)

	if enemies_in_range.is_empty():
		DebugConfig.debug("特殊攻击: 前方无敌人", "", "combat")
		special_attack_detected_enemies.clear()
		return false

	# 记录第一个敌人位置作为移动目标
	var first_enemy = enemies_in_range[0]
	special_attack_target_position = first_enemy.global_position

	# 保存所有检测到的敌人，用于后续聚集
	special_attack_detected_enemies = enemies_in_range.duplicate()

	DebugConfig.info("特殊攻击: 检测到 %d 个敌人 -> %v" % [enemies_in_range.size(), special_attack_target_position], "", "combat")
	return true

## 执行特殊攻击移动：将角色移动到第一个敌人位置
## 在动画开始前调用（由 animation_handler 触发）
func execute_special_attack_movement() -> void:
	DebugConfig.info("=== 开始特殊攻击移动 ===", "", "combat")

	# 使用 Tween 快速移动到目标位置
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUAD)

	var move_duration = 0.2  # 移动时间
	tween.tween_property(self, "global_position", special_attack_target_position, move_duration)

	# 等待移动完成
	await tween.finished

	DebugConfig.info("特殊攻击移动完成，当前位置 = %v" % global_position, "", "combat")

## 特殊攻击：在动画的攻击帧中调用，聚集所有检测到的敌人
## 此方法在动画 0.4s 时调用，在 Hitbox 启用（0.4329s）之前
func perform_special_attack() -> void:
	if special_attack_detected_enemies.is_empty():
		DebugConfig.debug("特殊攻击: 无敌人需要聚集", "", "combat")
		return

	DebugConfig.info("特殊攻击: 聚集 %d 个敌人到 %v" % [special_attack_detected_enemies.size(), global_position], "", "combat")

	# 聚集所有检测到的敌人到玩家当前位置
	for enemy in special_attack_detected_enemies:
		if is_instance_valid(enemy):
			# 创建聚集特效
			var gather_effect = GatherEffect.new()
			gather_effect.set_gather_position(global_position)
			gather_effect.gather_duration = 0.3
			gather_effect.show_debug_info = true

			# 应用聚集特效（不 await，并行执行）
			gather_effect.apply_effect(enemy, global_position)

	# 清空检测列表
	special_attack_detected_enemies.clear()

## 检测扇形范围内的敌人
## @param radius: 检测半径
## @param angle_degrees: 扇形角度（上下各angle_degrees度）
## @return: 敌人数组，按距离排序
func _detect_enemies_in_cone(radius: float, angle_degrees: float) -> Array:
	var enemies_found = []
	var all_enemies = get_tree().get_nodes_in_group("enemy")

	for enemy in all_enemies:
		if not is_instance_valid(enemy):
			continue

		# 检查距离
		var distance = global_position.distance_to(enemy.global_position)
		if distance > radius:
			continue

		# 计算方向向量和角度差
		var direction_to_enemy = (enemy.global_position - global_position).normalized()
		var angle_to_enemy = rad_to_deg(last_face_direction.angle_to(direction_to_enemy))

		# 检查是否在扇形角度范围内
		if abs(angle_to_enemy) <= angle_degrees:
			enemies_found.append({
				"enemy": enemy,
				"distance": distance,
				"angle": angle_to_enemy
			})
			DebugConfig.debug("检测: %s 距离:%.1f 角度:%.1f°" % [enemy.name, distance, angle_to_enemy], "", "combat")

	# 按距离排序（最近的在前面）
	enemies_found.sort_custom(func(a, b): return a["distance"] < b["distance"])

	# 返回敌人节点数组
	return enemies_found.map(func(data): return data["enemy"])
