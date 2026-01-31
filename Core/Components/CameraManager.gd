extends Node
class_name CameraManager

## 相机管理组件 - 处理镜头切换和特效
## 支持：聚焦目标、逐个切换多个目标、平滑过渡、恢复跟随、目标高亮

# ============ 预加载 ============
const EnemyHighlightEffectScript = preload("res://Core/Effects/EnemyHighlightEffect.gd")

# ============ 信号 ============
## 镜头切换开始
signal camera_focus_started(target: Node2D)
## 镜头切换完成
signal camera_focus_finished()
## 镜头序列完成（所有目标切换完成）
signal camera_sequence_finished()
## 镜头恢复到原始目标
signal camera_restored()

# ============ 配置参数 ============
@export_group("Camera Settings")
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
## 相机引用
var camera: Camera2D = null
## 原始缩放
var original_zoom: Vector2 = Vector2.ONE
## 原始位置
var original_position: Vector2 = Vector2.ZERO
## 原始跟随目标
var original_follow_target: Node2D = null
## 是否正在执行镜头切换
var is_transitioning: bool = false

# ============ 节点引用 ============
var owner_node: Node = null

# ============ 生命周期 ============
func _ready() -> void:
	owner_node = get_parent()
	call_deferred("_find_camera")

# ============ 初始化方法 ============
func _find_camera() -> void:
	# 尝试多种方式找到 Camera2D
	# 1. 从场景树中查找
	var cameras = get_tree().get_nodes_in_group("camera")
	if not cameras.is_empty():
		camera = cameras[0]
		DebugConfig.debug("CameraManager: 找到相机 (通过group)", "", "camera")
		return

	# 2. 从根节点向下查找
	camera = _find_camera_in_tree(get_tree().current_scene)
	if camera:
		DebugConfig.debug("CameraManager: 找到相机 (通过遍历)", "", "camera")
		return

	push_warning("CameraManager: 未找到 Camera2D")

func _find_camera_in_tree(node: Node) -> Camera2D:
	if node is Camera2D:
		return node
	for child in node.get_children():
		var found = _find_camera_in_tree(child)
		if found:
			return found
	return null

# ============ 公共 API ============
## 设置相机引用（手动设置）
func set_camera(cam: Camera2D) -> void:
	camera = cam

## 聚焦到单个目标
func focus_on_target(target: Node2D, duration: float = -1.0) -> void:
	if not camera or not is_instance_valid(target):
		return

	if duration < 0:
		duration = focus_duration

	is_transitioning = true
	_save_camera_state()

	camera_focus_started.emit(target)

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)

	# 移动到目标
	tween.tween_property(camera, "global_position", target.global_position, duration)

	# 缩放效果
	if enable_zoom_effect:
		tween.parallel().tween_property(camera, "zoom", focus_zoom, duration)

	await tween.finished

	camera_focus_finished.emit()

## 聚焦到多个目标（逐个切换）
## targets: 目标数组
## per_target_hold: 每个目标停留时间（-1 使用默认值）
## return: 完成后自动恢复
func focus_on_targets_sequence(targets: Array, per_target_hold: float = -1.0, auto_restore: bool = true) -> void:
	if not camera or targets.is_empty():
		camera_sequence_finished.emit()
		return

	if per_target_hold < 0:
		per_target_hold = hold_duration

	is_transitioning = true
	_save_camera_state()

	DebugConfig.info("CameraManager: 开始镜头序列，%d 个目标" % targets.size(), "", "camera")

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
		tween.tween_property(camera, "global_position", target.global_position, move_duration)

		# 第一个目标时应用缩放
		if i == 0 and enable_zoom_effect:
			tween.parallel().tween_property(camera, "zoom", focus_zoom, move_duration)

		await tween.finished

		# 触发目标高亮效果
		if enable_highlight:
			highlight_target(target)

		camera_focus_finished.emit()

		# 停留一段时间
		if per_target_hold > 0:
			await get_tree().create_timer(per_target_hold).timeout

	camera_sequence_finished.emit()
	DebugConfig.info("CameraManager: 镜头序列完成", "", "camera")

	# 自动恢复
	if auto_restore:
		await restore_camera()

## 恢复相机到原始状态/目标
func restore_camera(restore_target: Node2D = null) -> void:
	if not camera:
		is_transitioning = false
		camera_restored.emit()
		return

	var target_position: Vector2
	if restore_target and is_instance_valid(restore_target):
		target_position = restore_target.global_position
	elif original_follow_target and is_instance_valid(original_follow_target):
		target_position = original_follow_target.global_position
	else:
		target_position = original_position

	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUAD)

	# 恢复位置
	tween.tween_property(camera, "global_position", target_position, restore_duration)

	# 恢复缩放
	if enable_zoom_effect:
		tween.parallel().tween_property(camera, "zoom", original_zoom, restore_duration)

	await tween.finished

	is_transitioning = false
	camera_restored.emit()
	DebugConfig.debug("CameraManager: 相机已恢复", "", "camera")

## 设置原始跟随目标（用于恢复时参考）
func set_follow_target(target: Node2D) -> void:
	original_follow_target = target

## 检查是否正在切换
func is_camera_transitioning() -> bool:
	return is_transitioning

## 对目标应用高亮闪烁效果
## @param target: 目标节点
func highlight_target(target: Node2D) -> void:
	if not is_instance_valid(target):
		return

	# 使用预加载的脚本创建效果实例
	var effect = EnemyHighlightEffectScript.new()
	effect.flash_count = highlight_flash_count
	target.add_child(effect)
	effect.apply(target)
	DebugConfig.debug("CameraManager: 高亮目标 %s" % target.name, "", "camera")

# ============ 内部方法 ============
func _save_camera_state() -> void:
	if camera:
		original_zoom = camera.zoom
		original_position = camera.global_position
