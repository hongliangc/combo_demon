extends PlayerBaseState
class_name PlayerFallDeathState

## 坠落死亡状态：玩家掉出关卡边界后触发
## priority = CONTROL(2), can_be_interrupted = false
## 流程：禁用移动 → 屏幕渐黑 → 显示GameOverUI → 重新开始关卡

@export var fade_duration: float = 0.5

var _fade_rect: ColorRect
var _canvas_layer: CanvasLayer

func enter() -> void:
	# 禁用移动
	var movement = get_movement()
	if movement:
		movement.can_move = false

	# 停止速度
	stop_movement()

	# 开始屏幕渐黑效果
	_start_fade_to_black()


func exit() -> void:
	# 重新启用移动
	var movement = get_movement()
	if movement:
		movement.can_move = true

	# 清理遮罩
	_cleanup_fade_rect()


func _start_fade_to_black() -> void:
	# 创建全屏黑色遮罩
	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 添加到 CanvasLayer 确保覆盖整个屏幕
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 100
	_canvas_layer.add_child(_fade_rect)
	owner_node.get_tree().root.add_child(_canvas_layer)

	# 渐黑动画
	var tween = owner_node.create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, fade_duration)
	tween.tween_callback(_on_fade_complete)


func _on_fade_complete() -> void:
	# 隐藏玩家
	owner_node.visible = false

	# 显示GameOverUI（无回调，点击重新开始会重载场景）
	var game_over_scene = load("res://Scenes/UI/Screens/GameOver/GameOverUI.tscn")
	if game_over_scene:
		var game_over_ui = game_over_scene.instantiate()
		game_over_ui.set_title("坠落！")
		_canvas_layer.add_child(game_over_ui)


func _cleanup_fade_rect() -> void:
	if _canvas_layer:
		_canvas_layer.queue_free()
		_canvas_layer = null
	_fade_rect = null
