extends Node
class_name SkillManager

## V 技能特效服务
## 提供 V 技能各阶段的特效方法，由 PlayerSpecialAttackState 调用
## 自身不监听信号、不处理输入，纯粹执行特效逻辑
##
## 流程：
##   Phase 1: 残影放大 + 心跳 + 漩涡
##   Phase 2: 扇形检测敌人
##   Phase 3: 镜头切换 + 子弹时间 + 聚集敌人到漩涡
##   Phase 4: 残影冲刺到漩涡位置
##   Phase 5: 状态机驱动攻击动画（由 PlayerSpecialAttackState 控制）
##   Phase 6: 清理（unstun 敌人、隐藏漩涡）

# ============ 预加载 ============
const AfterImageEffectScript = preload("res://Core/Effects/AfterImageEffect.gd")
const GhostExpandEffectScript = preload("res://Core/Effects/GhostExpandEffect.gd")
const VortexEffectScript = preload("res://Core/Effects/VortexEffect.gd")

# ============ 信号 ============
## 特殊攻击准备完成（检测到敌人后发出）
signal special_attack_prepared(target_position: Vector2, enemy_count: int)

# ============ 配置参数 ============
@export_group("Special Attack")
## 检测半径
@export var detection_radius: float = 300.0
## 检测角度（扇形的半角，实际范围是上下各这么多度）
@export var detection_angle: float = 45.0
## 移动到目标的持续时间
@export var move_duration: float = 0.2
## 聚集敌人的持续时间
@export var gather_duration: float = 0.3

@export_group("Camera Effects")
## 是否启用镜头切换特效
@export var enable_camera_effects: bool = true
## 每个敌人的镜头停留时间
@export var camera_hold_per_enemy: float = 0.6
## 镜头聚焦时的缩放
@export var camera_focus_zoom: Vector2 = Vector2(1.3, 1.3)
## 镜头移动到漩涡的时间（秒）
@export var camera_to_vortex_duration: float = 0.4
## 镜头从漩涡切换到玩家的时间（秒）
@export var camera_to_player_duration: float = 0.5

@export_group("Bullet Time")
## 是否启用子弹时间（聚集敌人时）
@export var enable_bullet_time: bool = true
## 子弹时间的时间缩放（0.3 = 30% 速度）
@export var bullet_time_scale: float = 0.3
## 每个敌人聚集的总耗时（秒，实际时间，不受子弹时间影响）
@export var gather_time_per_enemy: float = 1.0

@export_group("After Image")
## 是否启用残影效果
@export var enable_after_image: bool = true
## 残影颜色
@export var after_image_color: Color = Color(1.0, 0.84, 0.0, 1.0)

@export_group("Skill Effects")
## 聚集位置距离（hahashin前方多少像素）
@export var gather_distance: float = 200.0
## 心跳音效（可选）
@export var heartbeat_sound: AudioStream = null
## 攻击音效
@export var attack_sound: AudioStream = preload("res://Assets/Sound/face_the_wind.mp3")

# ============ 运行时变量 ============
## 特殊攻击的目标位置
var special_attack_target_position: Vector2 = Vector2.ZERO
## 特殊攻击检测到的敌人列表
var special_attack_detected_enemies: Array = []
## 当前漩涡特效实例
var _current_vortex: Node2D = null
## 聚集位置（hahashin前方指定距离）
var _gather_position: Vector2 = Vector2.ZERO

# ============ 节点引用 ============
var owner_node: Node = null
## MovementComponent 引用（用于获取朝向）
var movement_component: MovementComponent = null
## CameraManager 引用（使用 Node 避免循环依赖）
var camera_manager: Node = null

# ============ 生命周期 ============
func _ready() -> void:
	# 依赖注入：自动获取 owner 节点
	owner_node = get_parent()
	# 查找其他组件（延迟到下一帧，确保所有组件都已 ready）
	call_deferred("_find_components")

# ============ 初始化方法 ============
func _find_components() -> void:
	if not owner_node:
		return

	# 查找 MovementComponent
	movement_component = owner_node.get_node_or_null("MovementComponent")

	# 查找 CameraManager（可能在角色上或场景中）
	camera_manager = owner_node.get_node_or_null("CameraManager")
	if not camera_manager:
		# 尝试从场景中查找
		var managers = owner_node.get_tree().get_nodes_in_group("camera_manager")
		if not managers.is_empty():
			camera_manager = managers[0]

	# 设置 CameraManager 的配置
	if camera_manager and enable_camera_effects:
		camera_manager.focus_zoom = camera_focus_zoom
		camera_manager.hold_duration = camera_hold_per_enemy
		camera_manager.set_follow_target(owner_node)

# ============ Phase 1: 创建特效（残影放大 + 心跳 + 漩涡）============
## 创建技能释放特效：残影放大、心跳音效、漩涡生成
func create_effects(body: CharacterBody2D, face_direction: Vector2) -> void:
	# 1.1 创建残影放大效果（基于sprite的全局位置）
	var sprite = body.get_node_or_null("AnimatedSprite2D")
	if sprite:
		GhostExpandEffectScript.create(sprite, sprite.global_position, body)
		DebugConfig.debug("特殊攻击: 残影放大效果已创建于 %v" % sprite.global_position, "", "effect")

	# 1.2 播放心跳音效
	if heartbeat_sound:
		SoundManager.play_sound(heartbeat_sound)

	# 1.3 计算漩涡位置（前方 gather_distance 像素）并创建漩涡特效
	_gather_position = body.global_position + face_direction * gather_distance
	_current_vortex = VortexEffectScript.new()
	# 使用 call_deferred 避免 "Parent node is busy" 错误
	body.get_parent().call_deferred("add_child", _current_vortex)
	await owner_node.get_tree().process_frame
	_current_vortex.global_position = _gather_position
	_current_vortex.show_vortex()
	DebugConfig.debug("特殊攻击: 漩涡特效，聚集位置 %v" % [_gather_position], "", "effect")

	# 等待漩涡出现动画
	await owner_node.get_tree().create_timer(0.2).timeout

# ============ Phase 2: 检测敌人 ============
## 检测扇形范围内的敌人，返回是否有敌人
func detect_enemies(position: Vector2, face_direction: Vector2) -> bool:
	# 检测前方范围内的敌人
	var enemies_in_range = _detect_enemies_in_cone(
		position, detection_radius, detection_angle, face_direction
	)
	if enemies_in_range.is_empty():
		special_attack_detected_enemies.clear()
		return false

	# 记录第一个敌人位置作为移动目标
	special_attack_target_position = enemies_in_range[0].global_position
	# 保存所有检测到的敌人，用于后续聚集
	special_attack_detected_enemies = enemies_in_range.duplicate()
	DebugConfig.info("特殊攻击: 检测到 %d 个敌人 -> %v" % [enemies_in_range.size(), special_attack_target_position], "", "combat")
	# 发出信号
	special_attack_prepared.emit(special_attack_target_position, enemies_in_range.size())
	return true

# ============ Phase 3: 镜头切换 + 子弹时间 + 聚集敌人 ============
## 镜头固定在漩涡位置 -> 开启子弹时间 -> 逐个聚集敌人 -> 关闭子弹时间 -> 镜头切换到玩家
func gather_enemies() -> void:
	# 镜头逐个切换到敌人和漩涡中间，同时聚集敌人到漩涡位置
	if enable_camera_effects and camera_manager and special_attack_detected_enemies.size() > 0:
		DebugConfig.debug("特殊攻击: 开始镜头切换并聚集到漩涡 %v" % _gather_position, "", "combat")
		await _perform_camera_and_gather_sequence(special_attack_detected_enemies.duplicate(), _gather_position)

	# 等待所有聚集完成
	await owner_node.get_tree().create_timer(gather_duration).timeout
	DebugConfig.debug("特殊攻击: 聚集完成", "", "combat")

# ============ Phase 4: 残影冲刺到目标位置 ============
## 执行移动到漩涡位置（带残影效果）
func dash_to_target(body: CharacterBody2D) -> void:
	special_attack_target_position = _gather_position
	DebugConfig.info("=== 开始特殊攻击移动（残影冲刺）===", "", "combat")

	# 创建残影效果
	var after_image_effect: Node = null
	if enable_after_image:
		# 找到角色的 AnimatedSprite2D
		var sprite = body.get_node_or_null("AnimatedSprite2D")
		if sprite:
			after_image_effect = AfterImageEffectScript.new()
			after_image_effect.color_tint = after_image_color
			body.add_child(after_image_effect)
			after_image_effect.start(sprite)

	# 使用 Tween 快速移动到目标位置
	var tween = body.create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(body, "global_position", special_attack_target_position, move_duration)

	# 等待移动完成
	await tween.finished

	# 停止残影效果
	if after_image_effect:
		after_image_effect.stop()
		# 延迟删除，等待残影渐隐完成
		var cleanup_timer = body.get_tree().create_timer(0.3)
		cleanup_timer.timeout.connect(func():
			if is_instance_valid(after_image_effect):
				after_image_effect.queue_free()
		)

	DebugConfig.info("特殊攻击移动完成，当前位置 = %v" % body.global_position, "", "combat")

# ============ Phase 5 helper: 播放攻击音效 ============
## 播放攻击音效（动画由 PlayerSpecialAttackState 通过状态机控制）
func play_attack_sound() -> void:
	if attack_sound:
		SoundManager.play_sound(attack_sound)

# ============ Phase 6: 清理 ============
## 清理特效和恢复敌人状态
## 隐藏漩涡、恢复被眩晕的敌人、清空检测列表
func cleanup() -> void:
	# 隐藏漩涡（技能结束后）
	if _current_vortex:
		_current_vortex.hide_vortex()
		_current_vortex = null

	# 恢复所有被眩晕的敌人
	_unstun_all_enemies()

	# 清空检测列表
	special_attack_detected_enemies.clear()
	special_attack_target_position = Vector2.ZERO

	DebugConfig.debug("特殊攻击清理完成", "", "combat")

# ============ 内部方法：镜头 + 聚集序列 ============
## 执行镜头切换 + 聚集序列
## 流程：镜头固定在漩涡位置 -> 开启子弹时间 -> 逐个聚集敌人（每个1秒）-> 关闭子弹时间 -> 镜头切换到玩家
func _perform_camera_and_gather_sequence(enemies: Array, vortex_pos: Vector2) -> void:
	if not camera_manager or enemies.is_empty():
		return

	var body = owner_node as CharacterBody2D
	camera_manager.set_follow_target(body)
	camera_manager._save_camera_state()

	# 关键：设置 is_transitioning 标志，阻止 player_spawn 的相机跟随
	camera_manager.is_transitioning = true

	DebugConfig.info("镜头+聚集序列: %d 个敌人 -> %v" % [enemies.size(), vortex_pos], "", "camera")

	# 第一步：镜头平滑移动到漩涡位置（不跟随敌人移动）
	if enemies.size() > 0:
		var initial_tween = camera_manager.create_tween()
		initial_tween.set_ease(Tween.EASE_OUT)
		initial_tween.set_trans(Tween.TRANS_CUBIC)
		initial_tween.tween_property(camera_manager.camera, "global_position", vortex_pos, camera_to_vortex_duration)
		await initial_tween.finished

	# ========== 开启子弹时间 ==========
	if enable_bullet_time:
		_start_bullet_time()

	# 第二步：逐个聚集敌人，镜头停留在漩涡位置
	# 每个敌人聚集耗时 gather_time_per_enemy 秒（实际时间）
	for i in range(enemies.size()):
		var enemy = enemies[i]
		if not is_instance_valid(enemy):
			continue

		# 先眩晕敌人（这样 GatherEffect 完成后不会恢复移动）
		_stun_enemy(enemy)

		# 计算聚集动画时长：由于子弹时间会减慢 tween，需要调整
		# 聚集动画使用游戏内时间，所以需要乘以时间缩放来保持实际1秒
		var actual_gather_duration = gather_time_per_enemy * 0.8  # 80%时间用于聚集动画
		if enable_bullet_time:
			# 子弹时间下，tween 会被减慢，所以需要缩短动画时长
			actual_gather_duration = actual_gather_duration * bullet_time_scale

		# 开始聚集这个敌人到漩涡位置
		var gather_effect = GatherEffect.new()
		gather_effect.set_gather_position(vortex_pos)
		gather_effect.gather_duration = actual_gather_duration
		gather_effect.enable_trail = true
		gather_effect.show_debug_info = true
		gather_effect.apply_effect(enemy, vortex_pos)

		DebugConfig.debug("聚集敌人 %d/%d: %s -> %v" % [i + 1, enemies.size(), enemy.name, vortex_pos], "", "effect")

		# 等待聚集完成（使用 process_always=true 忽略时间缩放，保持实际1秒）
		await owner_node.get_tree().create_timer(gather_time_per_enemy, true, false, true).timeout

	# ========== 关闭子弹时间 ==========
	if enable_bullet_time:
		_end_bullet_time()

	# 所有敌人聚集完成后，镜头从漩涡平滑切换到玩家
	var final_tween = camera_manager.create_tween()
	final_tween.set_ease(Tween.EASE_IN_OUT)
	final_tween.set_trans(Tween.TRANS_CUBIC)
	final_tween.tween_property(camera_manager.camera, "global_position", body.global_position, camera_to_player_duration)
	await final_tween.finished

	# 镜头序列完成
	camera_manager.camera_sequence_finished.emit()

	# 恢复镜头缩放（位置已经在玩家，只恢复缩放）
	if camera_manager.enable_zoom_effect:
		var zoom_tween = camera_manager.create_tween()
		zoom_tween.set_ease(Tween.EASE_OUT)
		zoom_tween.set_trans(Tween.TRANS_QUAD)
		zoom_tween.tween_property(camera_manager.camera, "zoom", camera_manager.original_zoom, 0.2)
		await zoom_tween.finished

	camera_manager.is_transitioning = false
	camera_manager.camera_restored.emit()

# ============ 内部方法：子弹时间 ============
## 开启子弹时间（内部方法）
func _start_bullet_time() -> void:
	# 检查 TimeManager 是否可用（autoload）
	var time_manager = Engine.get_singleton("TimeManager") if Engine.has_singleton("TimeManager") else null
	if not time_manager:
		# 尝试从场景树获取
		time_manager = owner_node.get_node_or_null("/root/TimeManager")

	if time_manager and time_manager.has_method("start_bullet_time"):
		time_manager.start_bullet_time(bullet_time_scale)
	else:
		# 备用方案：直接设置引擎时间缩放
		Engine.time_scale = bullet_time_scale

## 结束子弹时间（内部方法）
func _end_bullet_time() -> void:
	# 检查 TimeManager 是否可用（autoload）
	var time_manager = Engine.get_singleton("TimeManager") if Engine.has_singleton("TimeManager") else null
	if not time_manager:
		# 尝试从场景树获取
		time_manager = owner_node.get_node_or_null("/root/TimeManager")

	if time_manager and time_manager.has_method("end_bullet_time"):
		time_manager.end_bullet_time()
	else:
		# 备用方案：直接恢复引擎时间缩放
		Engine.time_scale = 1.0

# ============ 内部方法：敌人眩晕管理 ============
## 眩晕敌人（内部方法）
## 强制敌人进入stun状态并停止自动恢复timer，直到V技能结束
func _stun_enemy(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return

	# 设置眩晕状态标志
	if "stunned" in enemy:
		enemy.stunned = true
	if "can_move" in enemy:
		enemy.can_move = false

	# 强制停止移动
	if enemy is CharacterBody2D:
		(enemy as CharacterBody2D).velocity = Vector2.ZERO

	# 强制切换到 stun 状态
	var state_machine = _find_state_machine(enemy)
	if state_machine:
		if state_machine.has_method("force_transition"):
			state_machine.force_transition("stun")
			# 关键：停止stun状态的自动恢复timer，防止敌人在V技能结束前恢复
			var stun_state = state_machine.states.get("stun")
			if stun_state and stun_state.has_method("stop_timer"):
				stun_state.stop_timer()

## 恢复所有被眩晕的敌人（内部方法）
## 重启 stun timer 让敌人自然恢复
func _unstun_all_enemies() -> void:
	var all_enemies = owner_node.get_tree().get_nodes_in_group("enemy")
	for enemy in all_enemies:
		if not is_instance_valid(enemy):
			continue
		_unstun_enemy(enemy)

## 恢复单个敌人（内部方法）
func _unstun_enemy(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return

	# 查找状态机并调用恢复方法
	var state_machine = _find_state_machine(enemy)
	if state_machine and state_machine.has_method("recover_from_stun"):
		state_machine.recover_from_stun()

## 查找目标的状态机节点（用于眩晕控制）
func _find_state_machine(target: Node) -> Node:
	for child in target.get_children():
		if child is BaseStateMachine or child.name == "StateMachine":
			return child
	return null

# ============ 内部方法：方向和检测 ============
## 将方向向量限制为四个基本方向（0°, 90°, 180°, 270°）
## 返回最接近的基本方向：RIGHT, LEFT, UP, DOWN
func _snap_to_cardinal_direction(direction: Vector2) -> Vector2:
	if direction == Vector2.ZERO:
		return Vector2.RIGHT  # 默认向右

	# 比较绝对值来确定是水平还是垂直方向
	if abs(direction.x) >= abs(direction.y):
		# 水平方向
		return Vector2.RIGHT if direction.x >= 0 else Vector2.LEFT
	else:
		# 垂直方向
		return Vector2.DOWN if direction.y >= 0 else Vector2.UP

## 获取玩家当前面朝方向（四向限制）
func get_face_direction() -> Vector2:
	if movement_component:
		return _snap_to_cardinal_direction(movement_component.last_face_direction)
	return Vector2.RIGHT

## 检测扇形范围内的敌人
## 返回按距离排序的敌人数组（最近的在前面）
func _detect_enemies_in_cone(
	origin: Vector2,
	radius: float,
	angle_degrees: float,
	direction: Vector2
) -> Array:
	var enemies_found = []
	if not owner_node:
		return enemies_found

	var all_enemies = owner_node.get_tree().get_nodes_in_group("enemy")
	for enemy in all_enemies:
		if not is_instance_valid(enemy):
			continue

		# 检查距离
		var distance = origin.distance_to(enemy.global_position)
		if distance > radius:
			continue

		# 计算方向向量和角度差
		var direction_to_enemy = (enemy.global_position - origin).normalized()
		var angle_to_enemy = rad_to_deg(direction.angle_to(direction_to_enemy))

		# 检查是否在扇形角度范围内
		if abs(angle_to_enemy) <= angle_degrees:
			enemies_found.append({
				"enemy": enemy,
				"distance": distance,
				"angle": angle_to_enemy
			})

	# 按距离排序（最近的在前面）
	enemies_found.sort_custom(func(a, b): return a["distance"] < b["distance"])

	# 返回敌人节点数组
	return enemies_found.map(func(data): return data["enemy"])
