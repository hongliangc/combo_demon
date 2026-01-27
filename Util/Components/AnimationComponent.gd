extends Node
class_name AnimationComponent

## 自治动画组件 - 参考 BaseState 设计模式
## 自动管理 AnimationTree、动画播放、音效
## 子类可重载 on_animation_finished() 等方法实现自定义逻辑

# ============ 信号 ============
## 动画开始播放
signal animation_started(animation_name: String)
## 动画播放完成
signal animation_finished(animation_name: String)
## 动画状态改变
signal animation_state_changed(state_name: String)

# ============ 配置参数 ============
@export_group("Animation Tree")
## AnimationTree 节点路径（相对于 owner）
@export var animation_tree_path: NodePath = ^"AnimationTree"
## StateMachine 参数路径
@export var state_machine_param: String = "parameters/StateMachine/playback"
## TimeScale 参数路径
@export var time_scale_param: String = "parameters/TimeScale/scale"

# ============ 节点引用（由组件自动获取）============
var owner_node: Node = null
var animation_tree: AnimationTree = null
var playback: AnimationNodeStateMachinePlayback = null

# ============ 生命周期 ============
func _ready() -> void:
	# 依赖注入：自动获取 owner 节点
	owner_node = get_parent()
	if not owner_node:
		push_error("AnimationComponent: 无法获取 owner 节点")
		return

	# 获取 AnimationTree
	if animation_tree_path:
		animation_tree = owner_node.get_node_or_null(animation_tree_path)
		if animation_tree:
			animation_tree.active = true
			playback = animation_tree.get(state_machine_param)

			# 连接动画完成信号
			if not animation_tree.is_connected("animation_finished", _on_animation_tree_finished):
				animation_tree.connect("animation_finished", _on_animation_tree_finished)
		else:
			push_warning("AnimationComponent: 未找到 AnimationTree 节点: %s" % animation_tree_path)

# ============ 核心方法 ============
## 播放动画
## @param animation_name: 动画状态名称
## @param time_scale: 播放速度倍率（默认1.0）
## @param blend_time: 混合时间（默认-1，使用默认值）
func play(animation_name: String, time_scale: float = 1.0, blend_time: float = -1.0) -> void:
	if not playback:
		push_warning("AnimationComponent: playback 未初始化")
		return

	# 切换动画状态
	if blend_time >= 0:
		playback.travel(animation_name, blend_time)
	else:
		playback.travel(animation_name)

	# 设置播放速度
	set_time_scale(time_scale)

	# 发射信号
	animation_started.emit(animation_name)

	DebugConfig.debug("播放动画: %s (speed: %.1f)" % [animation_name, time_scale], "", "animation")

## 设置时间缩放
func set_time_scale(scale: float) -> void:
	if animation_tree:
		animation_tree.set(time_scale_param, scale)

## 获取当前动画状态
func get_current_state() -> String:
	if playback:
		return playback.get_current_node()
	return ""

## 检查是否正在播放指定动画
func is_playing(animation_name: String) -> bool:
	return get_current_state() == animation_name

## 检查动画是否正在播放（非 idle 状态）
func is_any_animation_playing() -> bool:
	var current = get_current_state()
	return current != "" and current != "idle"

# ============ 内部回调 ============
func _on_animation_tree_finished(anim_name: String) -> void:
	# 恢复播放速度
	set_time_scale(1.0)

	# 发射信号
	animation_finished.emit(anim_name)

	# 调用可重载方法
	on_animation_finished(anim_name)

	DebugConfig.debug("动画完成: %s" % anim_name, "", "animation")

# ============ 可重载方法 ============
## 动画完成回调（子类可重载）
func on_animation_finished(animation_name: String) -> void:
	pass

# ============ 公共 API ============
## 停止当前动画
func stop() -> void:
	if playback:
		playback.stop()

## 强制跳转到指定状态（不使用混合）
func force_state(state_name: String) -> void:
	if playback:
		playback.start(state_name)
		animation_state_changed.emit(state_name)

## 暂停时保存的时间缩放
var _saved_time_scale: float = 1.0
var _is_paused: bool = false

## 暂停动画
func pause() -> void:
	if animation_tree and not _is_paused:
		_saved_time_scale = animation_tree.get(time_scale_param)
		animation_tree.set(time_scale_param, 0.0)
		_is_paused = true
		DebugConfig.debug("动画暂停", "", "animation")

## 恢复动画
func resume() -> void:
	if animation_tree and _is_paused:
		animation_tree.set(time_scale_param, _saved_time_scale)
		_is_paused = false
		DebugConfig.debug("动画恢复 (speed: %.1f)" % _saved_time_scale, "", "animation")

## 检查是否暂停
func is_paused() -> bool:
	return _is_paused
