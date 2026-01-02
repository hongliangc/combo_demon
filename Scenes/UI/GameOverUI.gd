extends CanvasLayer

## 游戏结束UI - 显示游戏结束信息和重新开始选项

func _ready() -> void:
	# 设置标题字体大小
	var title = $Control/VBoxContainer/Title
	if title:
		title.add_theme_font_size_override("font_size", 48)

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
