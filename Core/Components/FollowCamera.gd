extends Camera2D
class_name FollowCamera

## 统一相机组件 - 跟随、震动、聚焦、缩放
## 自动跟随目标（默认跟随 "player" 组的第一个节点）
## 提供震动、聚焦目标、多目标序列切换、高亮等通用相机操作
##
## 使用方式：
##   var cam = get_tree().get_first_node_in_group("camera") as FollowCamera
##   cam.shake(15.0, 0.3)
##   cam.focus_on_target(enemy, 0.2)

# ============ 预加载 ============
const EnemyHighlightEffectScript = preload("res://Core/Effects/EnemyHighlightEffect.gd")

# ============ 信号 ============
## 镜头聚焦开始
signal camera_focus_started(target: Node2D)
## 镜头聚焦完成（单个目标）
signal camera_focus_finished()
## 镜头序列完成（所有目标切换完成）
signal camera_sequence_finished()
## 镜头恢复到跟随目标
signal camera_restored()
## 镜头震动开始
signal camera_shake_started()
## 镜头震动结束
signal camera_shake_finished()

# ============ 配置参数 ============
@export_group("Follow Settings")
## 跟随目标所在的组名
@export var target_group: String = "player"
## 跟随偏移（用于调整角色在画面中的位置）
@export var follow_offset: Vector2 = Vector2(0, -100)
## 跟随平滑速度（lerp 系数，0~1，越大越快）
@export_range(0.01, 1.0, 0.01) var follow_smoothing: float = 0.1

@export_group("Shake Settings")
## 默认震动强度（像素）
@export var default_shake_strength: float = 10.0
## 默认震动持续时间（秒）
@export var default_shake_duration: float = 0.2
## 默认震动衰减系数（每帧乘以此值，0~1，越小衰减越快）
@export_range(0.0, 1.0, 0.01) var default_shake_decay: float = 0.8

@export_group("Focus Settings")
## 切换到目标的持续时间
@export var focus_duration: float = 0.15
## 在目标上停留的时间
@export var hold_duration: float = 0.1
## 恢复到原始目标的持续时间
@export var restore_duration: float = 0.2
## 缩放效果（聚焦时的缩放）
@export var focus_zoom: Vector2 = Vector2(1.2, 1.2)
## 是否启用缩放效果
@export var enable_zoom_effect: bool = true

@export_group("Highlight Effect")
## 是否启用目标高亮效果
@export var enable_highlight: bool = true
## 高亮闪烁次数
@export var highlight_flash_count: int = 2

# ============ 运行时变量 ============
## 跟随目标
var _follow_target: Node2D = null

## 是否正在执行镜头过渡（过渡期间暂停跟随）
var is_transitioning: bool = false:
	set(value):
		_is_transitioning = value
	get:
		return _is_transitioning
var _is_transitioning: bool = false

## 震动状态
var _shake_strength: float = 0.0
var _shake_duration_remaining: float = 0.0
var _shake_decay: float = 0.8
var _shake_offset: Vector2 = Vector2.ZERO
var _is_shaking: bool = false

## 聚焦恢复状态
var _saved_zoom: Vector2 = Vector2.ONE
var _saved_position: Vector2 = Vector2.ZERO
var _saved_follow_target: Node2D = null

# ============ 生命周期 ============
func _ready() -> void:
	# 加入 "camera" 组，方便全局查找
	add_to_group("camera")
	# 延迟一帧等待目标生成
	await get_tree().process_frame
	_find_target()


func _physics_process(delta: float) -> void:
	# 跟随逻辑（仅在非过渡模式下执行）
	if not _is_transitioning:
		if _follow_target and is_instance_valid(_follow_target):
			var target_pos = _follow_target.global_position + follow_offset
			global_position = global_position.lerp(target_pos, follow_smoothing)
			# 应用 Camera2D limit 约束（手动 lerp 会绕过内置限制）
			_clamp_to_limits()
		else:
			_find_target()

	# 震动逻辑（始终执行，即使在过渡模式下）
	_process_shake(delta)


# ============ 跟随 API ============
## 手动设置跟随目标
func set_follow_target(target: Node2D) -> void:
	_follow_target = target


## 手动设置跟随偏移
func set_follow_offset(new_offset: Vector2) -> void:
	follow_offset = new_offset


## 检查是否正在过渡
func is_camera_transitioning() -> bool:
	return _is_transitioning


# ============ 震动 API ============
## 触发摄像机震动
## @param strength: 震动强度（像素），-1 使用默认值
## @param duration: 震动持续时间（秒），-1 使用默认值
## @param decay: 衰减系数，-1 使用默认值
func shake(strength: float = -1.0, duration: float = -1.0, decay: float = -1.0) -> void:
	_shake_strength = strength if strength > 0 else default_shake_strength
	_shake_duration_remaining = duration if duration > 0 else default_shake_duration
	_shake_decay = decay if decay > 0 else default_shake_decay

	if not _is_shaking:
		_is_shaking = true
		camera_shake_started.emit()

	DebugConfig.debug("FollowCamera: 震动 强度=%.1f 时长=%.2f" % [_shake_strength, _shake_duration_remaining], "", "camera")


## 立即停止震动
func stop_shake() -> void:
	_shake_strength = 0.0
	_shake_duration_remaining = 0.0
	_shake_offset = Vector2.ZERO
	offset = Vector2.ZERO
	if _is_shaking:
		_is_shaking = false
		camera_shake_finished.emit()


# ============ 聚焦 API ============
## 聚焦到单个目标
func focus_on_target(target: Node2D, duration: float = -1.0) -> void:
	if not is_instance_valid(target):
		return

	if duration < 0:
		duration = focus_duration

	_is_transitioning = true
	save_state()

	camera_focus_started.emit(target)

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)

	# 移动到目标
	tween.tween_property(self, "global_position", target.global_position, duration)

	# 缩放效果
	if enable_zoom_effect:
		tween.parallel().tween_property(self, "zoom", focus_zoom, duration)

	await tween.finished

	camera_focus_finished.emit()


## 聚焦到多个目标（逐个切换）
## @param targets: 目标数组
## @param per_target_hold: 每个目标停留时间（-1 使用默认值）
## @param auto_restore: 完成后自动恢复
func focus_on_targets_sequence(targets: Array, per_target_hold: float = -1.0, auto_restore: bool = true) -> void:
	if targets.is_empty():
		camera_sequence_finished.emit()
		return

	if per_target_hold < 0:
		per_target_hold = hold_duration

	_is_transitioning = true
	save_state()

	DebugConfig.info("FollowCamera: 开始镜头序列，%d 个目标" % targets.size(), "", "camera")

	for i in range(targets.size()):
		var target = targets[i]
		if not is_instance_valid(target):
			continue

		camera_focus_started.emit(target)

		# 计算切换时间（第一个目标用更长时间）
		var move_duration = focus_duration if i == 0 else focus_duration * 0.7

		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_QUAD)

		# 移动到目标
		tween.tween_property(self, "global_position", target.global_position, move_duration)

		# 第一个目标时应用缩放
		if i == 0 and enable_zoom_effect:
			tween.parallel().tween_property(self, "zoom", focus_zoom, move_duration)

		await tween.finished

		# 触发目标高亮效果
		if enable_highlight:
			highlight_target(target)

		camera_focus_finished.emit()

		# 停留一段时间
		if per_target_hold > 0:
			await get_tree().create_timer(per_target_hold).timeout

	camera_sequence_finished.emit()
	DebugConfig.info("FollowCamera: 镜头序列完成", "", "camera")

	# 自动恢复
	if auto_restore:
		await restore_camera()


## 恢复相机到原始状态/目标
func restore_camera(restore_target: Node2D = null) -> void:
	var target_position: Vector2
	if restore_target and is_instance_valid(restore_target):
		target_position = restore_target.global_position
	elif _saved_follow_target and is_instance_valid(_saved_follow_target):
		target_position = _saved_follow_target.global_position
	else:
		target_position = _saved_position

	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUAD)

	# 恢复位置
	tween.tween_property(self, "global_position", target_position, restore_duration)

	# 恢复缩放
	if enable_zoom_effect:
		tween.parallel().tween_property(self, "zoom", _saved_zoom, restore_duration)

	await tween.finished

	_is_transitioning = false
	camera_restored.emit()
	DebugConfig.debug("FollowCamera: 相机已恢复", "", "camera")


## 保存当前相机状态（位置、缩放、跟随目标）
func save_state() -> void:
	_saved_zoom = zoom
	_saved_position = global_position
	_saved_follow_target = _follow_target


## 获取保存的缩放值
func get_saved_zoom() -> Vector2:
	return _saved_zoom


## 对目标应用高亮闪烁效果
func highlight_target(target: Node2D) -> void:
	if not is_instance_valid(target):
		return

	var effect = EnemyHighlightEffectScript.new()
	effect.flash_count = highlight_flash_count
	target.add_child(effect)
	effect.apply(target)
	DebugConfig.debug("FollowCamera: 高亮目标 %s" % target.name, "", "camera")


# ============ 内部方法 ============
## 自动查找跟随目标
func _find_target() -> void:
	var tree = get_tree()
	if tree:
		_follow_target = tree.get_first_node_in_group(target_group)


## 将相机位置约束在 limit 范围内
## 手动设置 global_position 会绕过 Camera2D 内置的 limit，需要手动 clamp
func _clamp_to_limits() -> void:
	var viewport_size = get_viewport_rect().size / zoom
	var half_w = viewport_size.x * 0.5
	var half_h = viewport_size.y * 0.5
	# 仅在 limit 有实际值时约束（默认值为 ±10000000）
	var default_limit = 10000000
	if limit_left > -default_limit:
		global_position.x = maxf(global_position.x, limit_left + half_w)
	if limit_right < default_limit:
		global_position.x = minf(global_position.x, limit_right - half_w)
	if limit_top > -default_limit:
		global_position.y = maxf(global_position.y, limit_top + half_h)
	if limit_bottom < default_limit:
		global_position.y = minf(global_position.y, limit_bottom - half_h)


## 处理震动逻辑
func _process_shake(delta: float) -> void:
	if _shake_duration_remaining > 0:
		_shake_duration_remaining -= delta
		# 随机偏移
		_shake_offset = Vector2(
			randf_range(-_shake_strength, _shake_strength),
			randf_range(-_shake_strength, _shake_strength)
		)
		# 衰减强度
		_shake_strength *= _shake_decay
		offset = _shake_offset
	elif _is_shaking:
		# 震动结束，清零
		_shake_offset = Vector2.ZERO
		offset = Vector2.ZERO
		_is_shaking = false
		camera_shake_finished.emit()
