extends Node

## 全局UI管理器 - 统一管理所有UI界面的显示、层级和转场
## 注意：此类作为 AutoLoad 单例，不使用 class_name
##
## 核心功能：
## - UI层级管理（6层：Background, Game, Menu, Popup, Tooltip, Loading）
## - 面板打开/关闭/切换
## - 场景转场系统
## - Toast提示和确认对话框
##
## 使用示例：
## ```gdscript
## # 打开面板
## UIManager.open_panel(panel_scene, UIManager.UILayer.MENU)
##
## # 显示提示
## UIManager.show_toast("操作成功！", 2.0)
##
## # 场景转场
## UIManager.transition_to_scene("res://Scenes/main.tscn", "fade")
## ```

# UI层级枚举
enum UILayer {
	BACKGROUND = 0,  ## 背景层（背景图、视差等）
	GAME = 10,       ## 游戏UI层（HUD、血条等）
	MENU = 20,       ## 菜单层（角色选择、设置等）
	POPUP = 30,      ## 弹窗层（对话框、提示框）
	TOOLTIP = 40,    ## 提示层（Tooltip、Toast）
	LOADING = 50     ## 加载层（Loading、Transition）
}

# 信号
signal panel_opened(panel_name: String)
signal panel_closed(panel_name: String)
signal transition_started()
signal transition_completed()

# 私有变量
var _active_panels: Dictionary = {}  # {panel_name: panel_instance}
var _panel_stack: Array[Control] = []
var _layers: Dictionary = {}  # {UILayer: CanvasLayer}


func _ready() -> void:
	_setup_layers()


## 设置UI层级容器
func _setup_layers() -> void:
	var layer_keys := UILayer.keys()
	var layer_values := UILayer.values()

	for i in range(layer_keys.size()):
		var layer_name: String = layer_keys[i]
		var layer_value: int = layer_values[i]

		var container := CanvasLayer.new()
		container.name = layer_name
		container.layer = layer_value
		add_child(container)
		_layers[layer_value] = container


## 打开UI面板
## @param panel_scene: 面板场景或已实例化的面板节点
## @param layer: UI层级
## @param close_others: 是否关闭其他面板
## @return 面板实例
func open_panel(panel: Variant, layer: UILayer = UILayer.MENU, close_others: bool = false) -> Control:
	if close_others:
		close_all_panels()

	# 实例化场景（如果是PackedScene）
	var panel_instance: Control
	if panel is PackedScene:
		panel_instance = panel.instantiate()
	else:
		panel_instance = panel

	_layers[layer].add_child(panel_instance)

	var panel_name := panel_instance.name
	_active_panels[panel_name] = panel_instance
	_panel_stack.append(panel_instance)

	# 播放打开动画（如果有）
	if panel_instance.has_method("play_open_animation"):
		panel_instance.play_open_animation()

	panel_opened.emit(panel_name)
	return panel_instance


## 关闭UI面板
## @param panel_name: 面板名称
func close_panel(panel_name: String) -> void:
	if not panel_name in _active_panels:
		return

	var panel: Control = _active_panels[panel_name]

	# 播放关闭动画（如果有）
	if panel.has_method("play_close_animation"):
		await panel.play_close_animation()

	_panel_stack.erase(panel)
	_active_panels.erase(panel_name)
	panel.queue_free()
	panel_closed.emit(panel_name)


## 关闭所有面板
func close_all_panels() -> void:
	# 使用副本避免修改迭代中的字典
	var panel_names := _active_panels.keys()
	for panel_name in panel_names:
		close_panel(panel_name)


## 检查面板是否打开
func is_panel_open(panel_name: String) -> bool:
	return panel_name in _active_panels


## 获取活动面板
func get_panel(panel_name: String) -> Control:
	return _active_panels.get(panel_name)


## 返回上一个面板（关闭当前面板）
func go_back() -> void:
	if _panel_stack.size() > 1:
		var current_panel: Control = _panel_stack.pop_back()
		close_panel(current_panel.name)


## 场景转场
## @param scene_path: 目标场景路径
## @param _transition_type: 转场类型（fade, slide_left等，当前仅支持fade）
func transition_to_scene(scene_path: String, _transition_type: String = "fade") -> void:
	transition_started.emit()

	# 简单淡入淡出转场
	var fade_rect := ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.modulate.a = 0.0
	_layers[UILayer.LOADING].add_child(fade_rect)

	# 淡入
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 0.3)
	await tween.finished

	# 切换场景
	get_tree().change_scene_to_file(scene_path)

	# 淡出
	tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 0.3)
	await tween.finished

	fade_rect.queue_free()
	transition_completed.emit()


## 显示Toast提示
## @param message: 提示内容
## @param duration: 显示时长（秒）
## @param message_type: 消息类型（info/success/warning/error）
func show_toast(message: String, duration: float = 2.0, message_type: String = "info") -> void:
	var toast_scene := preload("res://Util/UI/Components/toast.tscn")
	var toast := toast_scene.instantiate()
	_layers[UILayer.TOOLTIP].add_child(toast)

	# 居中显示（靠上）
	toast.position = Vector2(
		get_viewport().get_visible_rect().size.x / 2.0,
		100.0
	)

	if toast.has_method("show_message"):
		toast.show_message(message, duration, message_type)


## 显示确认对话框
## @param title: 标题
## @param message: 消息内容
## @param on_confirm: 确认回调
## @param on_cancel: 取消回调
func show_confirm_dialog(
	title: String,
	message: String,
	on_confirm: Callable,
	on_cancel: Callable = func(): pass
) -> void:
	var dialog_scene := preload("res://Util/UI/Components/confirm_dialog.tscn")
	var dialog := dialog_scene.instantiate()
	_layers[UILayer.POPUP].add_child(dialog)

	if dialog.has_method("setup"):
		dialog.setup(title, message, on_confirm, on_cancel)


## 使用LoadingScreen异步加载场景
## @param scene_path: 目标场景路径
func load_scene_async(scene_path: String) -> void:
	var loading_screen := preload("res://Util/UI/Modules/Loading/loading_screen.tscn").instantiate()
	_layers[UILayer.LOADING].add_child(loading_screen)

	if loading_screen.has_method("load_scene_async"):
		loading_screen.load_scene_async(scene_path)
