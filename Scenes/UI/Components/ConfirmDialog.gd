extends Control
class_name ConfirmDialog

## 确认对话框组件 - 显示确认/取消对话框
##
## 特性：
## - 带背景遮罩
## - 弹出动画
## - 支持确认/取消回调
## - 点击背景关闭
##
## 使用示例：
## ```gdscript
## var dialog = CONFIRM_DIALOG_SCENE.instantiate()
## add_child(dialog)
## dialog.setup("删除角色", "确定要删除吗？",
##     func(): print("已删除"),
##     func(): print("已取消")
## )
## ```

# 节点引用
@onready var background_overlay: ColorRect = $BackgroundOverlay
@onready var panel: Panel = $CenterContainer/Panel
@onready var title_label: Label = $CenterContainer/Panel/VBox/Title
@onready var message_label: Label = $CenterContainer/Panel/VBox/Message
@onready var confirm_button: Button = $CenterContainer/Panel/VBox/HBox/ConfirmButton
@onready var cancel_button: Button = $CenterContainer/Panel/VBox/HBox/CancelButton

# 回调函数
var on_confirm: Callable
var on_cancel: Callable


func _ready() -> void:
	# 初始状态：透明且缩小
	background_overlay.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.8, 0.8)

	# 连接信号
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	background_overlay.gui_input.connect(_on_background_clicked)

	# 播放打开动画
	play_open_animation()


## 设置对话框内容和回调
## @param title: 标题
## @param message: 消息内容
## @param confirm_callback: 确认回调
## @param cancel_callback: 取消回调（可选）
func setup(
	title: String,
	message: String,
	confirm_callback: Callable,
	cancel_callback: Callable = func(): pass
) -> void:
	title_label.text = title
	message_label.text = message
	on_confirm = confirm_callback
	on_cancel = cancel_callback


## 确认按钮按下
func _on_confirm_pressed() -> void:
	if on_confirm:
		on_confirm.call()
	await play_close_animation()
	queue_free()


## 取消按钮按下
func _on_cancel_pressed() -> void:
	if on_cancel:
		on_cancel.call()
	await play_close_animation()
	queue_free()


## 点击背景关闭
func _on_background_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_cancel_pressed()


## 打开动画（淡入+缩放）
func play_open_animation() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(background_overlay, "modulate:a", 0.7, 0.3)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)


## 关闭动画（淡出+缩放）
func play_close_animation() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(background_overlay, "modulate:a", 0.0, 0.2)
	tween.tween_property(panel, "modulate:a", 0.0, 0.2)
	tween.tween_property(panel, "scale", Vector2(0.8, 0.8), 0.2)
	await tween.finished
