extends Node
class_name SkillManager

## 自治技能管理组件 - 参考 BaseState 设计模式
## 自动处理特殊攻击的完整流程：
##   残影放大+心跳+漩涡 -> 子弹时间 -> 镜头切换聚集 -> 子弹时间结束 -> 残影冲刺 -> 攻击动画
## 子类可重载相关方法实现自定义逻辑

# ============ 预加载 ============
const AfterImageEffectScript = preload("res://Core/Effects/AfterImageEffect.gd")
const GhostExpandEffectScript = preload("res://Core/Effects/GhostExpandEffect.gd")
const VortexEffectScript = preload("res://Core/Effects/VortexEffect.gd")

# ============ 信号 ============
## 特殊攻击准备完成
signal special_attack_prepared(target_position: Vector2, enemy_count: int)
## 特殊攻击执行完成
signal special_attack_executed()
## 特殊攻击取消（未检测到敌人）
signal special_attack_cancelled()

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
@export var after_image_color: Color = Color(0.5, 0.7, 1.0, 1.0)

@export_group("Skill Effects")
## 聚集位置距离（hahashin前方多少像素）
@export var gather_distance: float = 200.0
## 心跳音效（可选）
@export var heartbeat_sound: AudioStream = null
## 残影放大倍数
@export var ghost_expand_scale: float = 2.5

@export_group("Integration")
## 特殊攻击技能名称
@export var special_attack_skill_name: String = "atk_sp"
## 是否自动处理特殊攻击（监听 CombatComponent 信号）
@export var auto_handle_special_attack: bool = true

# ============ 运行时变量 ============
## 特殊攻击的目标位置
var special_attack_target_position: Vector2 = Vector2.ZERO
## 特殊攻击检测到的敌人列表
var special_attack_detected_enemies: Array = []
## 当前漩涡特效实例
var _current_vortex: Node2D = null
## 聚集位置（hahashin前方100像素）
var _gather_position: Vector2 = Vector2.ZERO


# ============ 节点引用（组件间通信）============
var owner_node: Node = null
var combat_component: CombatComponent = null
var movement_component: MovementComponent = null
var animation_component: AnimationComponent = null
var camera_manager: Node = null  # CameraManager 类型，使用 Node 避免循环依赖

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

	# 查找 CombatComponent
	combat_component = owner_node.get_node_or_null("CombatComponent")
	if combat_component and auto_handle_special_attack:
		# 连接技能开始信号
		if not combat_component.is_connected("skill_started", _on_combat_skill_started):
			combat_component.skill_started.connect(_on_combat_skill_started)

	# 查找 MovementComponent
	movement_component = owner_node.get_node_or_null("MovementComponent")

	# 查找 AnimationComponent
	animation_component = owner_node.get_node_or_null("AnimationComponent")

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

# ============ 信号回调 ============
func _on_combat_skill_started(skill_name: String) -> void:
	# 只处理特殊攻击技能
	if skill_name != special_attack_skill_name:
		return

	# 自动执行特殊攻击完整流程
	_execute_special_attack_flow()

# ============ 核心方法（子类可重载）============
## 执行特殊攻击完整流程（内部方法）
## 流程：
##   1. 残影放大（基于sprite中心锚点）+ 心跳音效 + 漩涡生成（前方200px）
##   2. 检测敌人
##   3. 镜头固定在漩涡位置，逐个聚集敌人（敌人进入stun状态，timer停止）
##   4. 所有敌人聚集完毕后，镜头切换回玩家
##   5. 玩家残影冲刺到漩涡位置
##   6. 播放攻击动画
##   7. 解除敌人stun状态，隐藏漩涡，恢复玩家移动
func _execute_special_attack_flow() -> void:
	if not owner_node is CharacterBody2D:
		return

	var body = owner_node as CharacterBody2D

	# 获取面朝方向（限制为四个方向：0, 90, 180, 270度）
	var face_direction = Vector2.RIGHT
	if movement_component:
		face_direction = _snap_to_cardinal_direction(movement_component.last_face_direction)

	# ========== 阶段1: 技能释放特效 ==========
	# 1.1 禁用移动
	if movement_component:
		movement_component.can_move = false

	# 1.2 创建残影放大效果（基于sprite的全局位置）
	var sprite = body.get_node_or_null("AnimatedSprite2D")
	if sprite:
		GhostExpandEffectScript.create(sprite, sprite.global_position, body)
		DebugConfig.debug("特殊攻击: 残影放大效果已创建于 %v" % sprite.global_position, "", "effect")
	else:
		DebugConfig.debug("特殊攻击: 未找到 AnimatedSprite2D", "", "effect")

	# 1.3 播放心跳音效
	if heartbeat_sound:
		SoundManager.play_sound(heartbeat_sound)
	DebugConfig.debug("特殊攻击: 心跳音效", "", "sound")

	# 1.4 计算漩涡位置,也是聚集的位置（前方200像素）并创建漩涡特效
	_gather_position = body.global_position + face_direction * gather_distance

	_current_vortex = VortexEffectScript.new()
	# 使用 call_deferred 避免 "Parent node is busy" 错误
	body.get_parent().call_deferred("add_child", _current_vortex)
	await owner_node.get_tree().process_frame
	_current_vortex.global_position = _gather_position
	_current_vortex.show_vortex()
	DebugConfig.debug("特殊攻击: 漩涡特效 ，聚集位置 %v" % [_gather_position], "", "effect")

	# 等待漩涡出现动画
	await owner_node.get_tree().create_timer(0.2).timeout

	# ========== 阶段2: 检测敌人 ==========
	if not _prepare_special_attack(body.global_position, face_direction):
		# 没有敌人，取消技能并清理
		DebugConfig.debug("特殊攻击: 前方无敌人，取消", "", "combat")
		if _current_vortex:
			_current_vortex.hide_vortex()
			_current_vortex = null
		if movement_component:
			movement_component.can_move = true
		special_attack_cancelled.emit()
		return

	# ========== 阶段3: 镜头切换 + 聚集到漩涡位置 ==========
	# 镜头逐个切换到敌人和漩涡中间，同时聚集敌人到漩涡位置
	if enable_camera_effects and camera_manager and special_attack_detected_enemies.size() > 0:
		DebugConfig.debug("特殊攻击: 开始镜头切换并聚集到漩涡 %v" % _gather_position, "", "combat")
		await _perform_camera_and_gather_sequence(special_attack_detected_enemies.duplicate(), _gather_position)

	# 等待所有聚集完成
	await owner_node.get_tree().create_timer(gather_duration).timeout
	DebugConfig.debug("特殊攻击: 聚集完成", "", "combat")

	# ========== 阶段4: 残影冲刺到漩涡位置 ==========
	special_attack_target_position = _gather_position
	await _execute_movement_with_after_image(body)

	# 注意：漩涡在技能结束后才隐藏（在阶段6）

	# 清空检测列表
	special_attack_detected_enemies.clear()

	# 发出信号
	special_attack_executed.emit()

	# ========== 阶段5: 播放攻击动画 ==========
	await _play_attack_animation_and_wait()

	# ========== 阶段6: 清理和恢复 ==========
	# 隐藏漩涡（技能结束后）
	if _current_vortex:
		_current_vortex.hide_vortex()
		_current_vortex = null

	# 恢复所有被眩晕的敌人
	_unstun_all_enemies()

	if movement_component:
		movement_component.can_move = true

	DebugConfig.debug("特殊攻击完成，恢复移动", "", "combat")

## 准备特殊攻击：检测敌人（内部方法）
func _prepare_special_attack(player_position: Vector2, face_direction: Vector2) -> bool:
	# 检测前方范围内的敌人
	var enemies_in_range = _detect_enemies_in_cone(
		player_position,
		detection_radius,
		detection_angle,
		face_direction
	)

	if enemies_in_range.is_empty():
		special_attack_detected_enemies.clear()
		return false

	# 记录第一个敌人位置作为移动目标
	var first_enemy = enemies_in_range[0]
	special_attack_target_position = first_enemy.global_position

	# 保存所有检测到的敌人，用于后续聚集
	special_attack_detected_enemies = enemies_in_range.duplicate()

	DebugConfig.info("特殊攻击: 检测到 %d 个敌人 -> %v" % [enemies_in_range.size(), special_attack_target_position], "", "combat")

	# 发出信号
	special_attack_prepared.emit(special_attack_target_position, enemies_in_range.size())

	return true

## 执行移动到目标位置（带残影效果）
func _execute_movement_with_after_image(body: CharacterBody2D) -> void:
	DebugConfig.info("=== 开始特殊攻击移动（残影冲刺）===", "", "combat")

	# 创建残影效果
	var after_image_effect: Node = null
	if enable_after_image:
		# 找到角色的 AnimatedSprite2D
		var sprite = body.get_node_or_null("AnimatedSprite2D")
		if sprite:
			after_image_effect = AfterImageEffectScript.new()
			after_image_effect.color_tint = after_image_color
			after_image_effect.spawn_interval = 0.02  # 更密集的残影
			after_image_effect.fade_duration = 0.25
			body.add_child(after_image_effect)
			after_image_effect.start(sprite)
			DebugConfig.debug("残影效果已启动", "", "effect")

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
		DebugConfig.debug("子弹时间: 使用备用方案 (Engine.time_scale)", "", "time")

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
		DebugConfig.debug("子弹时间结束: 使用备用方案 (Engine.time_scale)", "", "time")

## 播放攻击动画并等待完成（内部方法）
func _play_attack_animation_and_wait() -> void:
	# 获取技能配置
	var config = {}
	if combat_component:
		config = combat_component.get_skill_config(special_attack_skill_name)

	# 播放音效
	var sound_effect = config.get("sound_effect")
	if sound_effect:
		SoundManager.play_sound(sound_effect)

	if not animation_component:
		# 没有动画组件时，使用固定时间等待
		DebugConfig.debug("播放特殊攻击动画（无动画组件，使用超时）", "", "combat")
		await owner_node.get_tree().create_timer(0.5).timeout
		return

	# 播放动画
	var time_scale = config.get("time_scale", 1.0)
	animation_component.play(special_attack_skill_name, time_scale)

	DebugConfig.debug("播放特殊攻击动画", "", "combat")

	# 直接 await AnimationComponent 的 animation_finished 信号
	await animation_component.animation_finished

	DebugConfig.debug("特殊攻击动画完成", "", "combat")

# ============ 公共 API（供动画事件调用）============
## 特殊攻击回调（已废弃）
## 注意：聚集逻辑已移动到 _execute_special_attack_flow() 中，在动画播放前执行
## 保留此方法以兼容旧的动画事件调用，但不执行任何操作
func perform_special_attack() -> void:
	# 聚集已在动画播放前完成，此处无需操作
	DebugConfig.debug("perform_special_attack() 被调用（已废弃，聚集在动画前完成）", "", "combat")

## 执行镜头切换序列（内部方法）
func _perform_camera_sequence(enemies: Array, player: CharacterBody2D) -> void:
	if not camera_manager:
		return

	# 设置跟随目标为玩家，用于恢复时使用
	camera_manager.set_follow_target(player)

	# 执行镜头序列：逐个切换到敌人 -> 恢复到玩家
	await camera_manager.focus_on_targets_sequence(enemies, camera_hold_per_enemy, true)

	DebugConfig.debug("特殊攻击镜头切换完成", "", "camera")

## 执行镜头切换 + 聚集序列（内部方法）
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

	# 优化：镜头先平滑移动到漩涡位置，不跟随敌人移动
	# 第一步：镜头移动到漩涡位置（不发送 focus 信号，避免镜头跟踪敌人）
	if enemies.size() > 0:
		var initial_tween = camera_manager.create_tween()
		initial_tween.set_ease(Tween.EASE_OUT)
		initial_tween.set_trans(Tween.TRANS_CUBIC)
		# 使用配置的镜头移动到漩涡时间
		initial_tween.tween_property(camera_manager.camera, "global_position", vortex_pos, camera_to_vortex_duration)

		await initial_tween.finished
		DebugConfig.debug("镜头已到达漩涡位置: %v" % vortex_pos, "", "camera")

	# ========== 开启子弹时间 ==========
	if enable_bullet_time:
		_start_bullet_time()
		DebugConfig.debug("聚集开始: 开启子弹时间 (%.1f倍速)" % bullet_time_scale, "", "time")

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

		DebugConfig.debug("聚集敌人 %d/%d: %s -> %v (耗时 %.2fs)" % [i + 1, enemies.size(), enemy.name, vortex_pos, gather_time_per_enemy], "", "effect")

		# 等待聚集完成（使用 process_always=true 忽略时间缩放，保持实际1秒）
		await owner_node.get_tree().create_timer(gather_time_per_enemy, true, false, true).timeout

	# ========== 关闭子弹时间 ==========
	if enable_bullet_time:
		_end_bullet_time()
		DebugConfig.debug("聚集完成: 关闭子弹时间", "", "time")

	# 所有敌人聚集完成后，镜头从漩涡平滑切换到 hahashin
	DebugConfig.info("聚集完成，镜头从漩涡 -> hahashin", "", "camera")

	var final_tween = camera_manager.create_tween()
	final_tween.set_ease(Tween.EASE_IN_OUT)
	final_tween.set_trans(Tween.TRANS_CUBIC)
	# 使用配置的镜头切换到玩家时间，实现平滑过渡
	final_tween.tween_property(camera_manager.camera, "global_position", body.global_position, camera_to_player_duration)
	await final_tween.finished

	DebugConfig.debug("镜头已到达玩家位置", "", "camera")

	# 镜头序列完成
	camera_manager.camera_sequence_finished.emit()

	# 恢复镜头缩放（位置已经在 hahashin，只恢复缩放）
	if camera_manager.enable_zoom_effect:
		var zoom_tween = camera_manager.create_tween()
		zoom_tween.set_ease(Tween.EASE_OUT)
		zoom_tween.set_trans(Tween.TRANS_QUAD)
		zoom_tween.tween_property(camera_manager.camera, "zoom", camera_manager.original_zoom, 0.2)
		await zoom_tween.finished

	camera_manager.is_transitioning = false
	camera_manager.camera_restored.emit()

	DebugConfig.debug("镜头+聚集序列完成", "", "camera")

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
		# 强制切换到 stun 状态
		if state_machine.has_method("force_transition"):
			state_machine.force_transition("stun")
			DebugConfig.debug("眩晕敌人: %s 强制切换到stun状态" % enemy.name, "", "effect")

			# 关键：停止stun状态的自动恢复timer，防止敌人在V技能结束前恢复
			# 重新获取stun_state，因为force_transition后状态已经enter()
			var stun_state = state_machine.states.get("stun")
			if stun_state and stun_state.has_method("stop_timer"):
				stun_state.stop_timer()
				DebugConfig.debug("停止 %s 的stun timer，等待V技能结束" % enemy.name, "", "effect")
		else:
			DebugConfig.warning("状态机没有 force_transition 方法: %s" % enemy.name, "", "effect")


	DebugConfig.debug("眩晕敌人: %s (velocity=0, stunned=true, timer停止)" % enemy.name, "", "effect")

## 恢复所有被眩晕的敌人（内部方法）
## 重启 stun timer 让敌人自然恢复
func _unstun_all_enemies() -> void:
	# 获取所有敌人并恢复
	var all_enemies = owner_node.get_tree().get_nodes_in_group("enemy")
	for enemy in all_enemies:
		if not is_instance_valid(enemy):
			continue
		_unstun_enemy(enemy)
	DebugConfig.debug("已恢复所有敌人的移动能力", "", "effect")

## 恢复单个敌人（内部方法）
func _unstun_enemy(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return

	# 查找状态机并调用恢复方法
	var state_machine = _find_state_machine(enemy)
	if state_machine and state_machine.has_method("recover_from_stun"):
		state_machine.recover_from_stun()
		DebugConfig.debug("恢复敌人: %s" % enemy.name, "", "effect")

## 查找目标的状态机节点（用于眩晕控制）
func _find_state_machine(target: Node) -> Node:
	for child in target.get_children():
		if child is BaseStateMachine or child.name == "StateMachine":
			return child
	return null


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

## 检测扇形范围内的敌人
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
			DebugConfig.debug("检测: %s 距离:%.1f 角度:%.1f°" % [enemy.name, distance, angle_to_enemy], "", "combat")

	# 按距离排序（最近的在前面）
	enemies_found.sort_custom(func(a, b): return a["distance"] < b["distance"])

	# 返回敌人节点数组
	return enemies_found.map(func(data): return data["enemy"])

## 清除特殊攻击状态
func clear_special_attack_state() -> void:
	special_attack_detected_enemies.clear()
	special_attack_target_position = Vector2.ZERO
