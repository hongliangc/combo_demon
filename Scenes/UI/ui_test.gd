extends Control

## UI系统测试场景 - 测试Toast和ConfirmDialog功能
##
## 测试项目：
## - Toast提示（4种类型）
## - ConfirmDialog确认对话框
## - UIManager层级管理

@onready var info_button: Button = $CenterContainer/VBox/InfoButton
@onready var success_button: Button = $CenterContainer/VBox/SuccessButton
@onready var warning_button: Button = $CenterContainer/VBox/WarningButton
@onready var error_button: Button = $CenterContainer/VBox/ErrorButton
@onready var dialog_button: Button = $CenterContainer/VBox/DialogButton
@onready var panel_button: Button = $CenterContainer/VBox/PanelButton
@onready var quit_button: Button = $CenterContainer/VBox/QuitButton


func _ready() -> void:
	# 连接信号
	info_button.pressed.connect(_on_info_pressed)
	success_button.pressed.connect(_on_success_pressed)
	warning_button.pressed.connect(_on_warning_pressed)
	error_button.pressed.connect(_on_error_pressed)
	dialog_button.pressed.connect(_on_dialog_pressed)
	panel_button.pressed.connect(_on_panel_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


## Info Toast
func _on_info_pressed() -> void:
	UIManager.show_toast("这是一条普通信息", 2.0, "info")


## Success Toast
func _on_success_pressed() -> void:
	UIManager.show_toast("操作成功！", 2.0, "success")


## Warning Toast
func _on_warning_pressed() -> void:
	UIManager.show_toast("警告：请注意！", 2.0, "warning")


## Error Toast
func _on_error_pressed() -> void:
	UIManager.show_toast("错误：操作失败！", 2.0, "error")


## 测试确认对话框
func _on_dialog_pressed() -> void:
	UIManager.show_confirm_dialog(
		"确认对话框测试",
		"这是一个确认对话框，点击确认或取消查看效果",
		func(): UIManager.show_toast("你点击了确认", 2.0, "success"),
		func(): UIManager.show_toast("你点击了取消", 2.0, "info")
	)


## 测试打开面板
func _on_panel_pressed() -> void:
	var game_over := preload("res://Scenes/UI/GameOverUI.tscn").instantiate()
	UIManager.open_panel(game_over, UIManager.UILayer.POPUP)


## 退出测试
func _on_quit_pressed() -> void:
	UIManager.show_confirm_dialog(
		"退出测试",
		"确定要退出UI测试吗？",
		func(): get_tree().change_scene_to_file("res://Scenes/main.tscn"),
		func(): UIManager.show_toast("取消退出", 1.5, "info")
	)
