extends Control
class_name GameOverUI

## 游戏结束UI - 显示游戏结束信息和重新开始选项
##
## 可通过UIManager打开：
## ```gdscript
## var game_over = preload("res://Scenes/UI/GameOverUI.tscn").instantiate()
## UIManager.open_panel(game_over, UIManager.UILayer.POPUP)
## ```

# 节点引用
@onready var background: ColorRect = $Background
@onready var panel: VBoxContainer = $VBoxContainer
@onready var title: Label = $VBoxContainer/Title


func _ready() -> void:
	# 设置全屏
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# 设置标题字体大小
	if title:
		title.add_theme_font_size_override("font_size", 48)

	# 初始状态：透明
	background.modulate.a = 0.0
	panel.modulate.a = 0.0

	# 播放打开动画
	play_open_animation()

## 重新开始按钮点击
func _on_restart_button_pressed() -> void:
	restart_game()

## 退出游戏按钮点击
func _on_quit_button_pressed() -> void:
	quit_game()

## 重新开始游戏
func restart_game() -> void:
	# 先移除UI
	queue_free()
	# 然后重新加载场景
	get_tree().reload_current_scene()

## 退出游戏
func quit_game() -> void:
	get_tree().quit()

## 处理键盘输入
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				restart_game()
			KEY_Q:
				quit_game()


## 打开动画（淡入）
func play_open_animation() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(background, "modulate:a", 0.7, 0.3)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)


## 关闭动画（淡出）
func play_close_animation() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(background, "modulate:a", 0.0, 0.2)
	tween.tween_property(panel, "modulate:a", 0.0, 0.2)
	await tween.finished
