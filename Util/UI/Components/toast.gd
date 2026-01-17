extends Control
class_name Toast

## Toast提示框组件 - 显示临时消息提示
##
## 特性：
## - 支持4种消息类型（info/success/warning/error）
## - 滑入/滑出动画
## - 自动消失
## - 自适应内容宽度
##
## 使用示例：
## ```gdscript
## var toast = Toast_SCENE.instantiate()
## add_child(toast)
## toast.show_message("操作成功！", 2.0, "success")
## ```

# 节点引用
@onready var panel: Panel = $Panel
@onready var label: Label = $Panel/MarginContainer/Label

# 配置参数
@export var default_duration: float = 2.0
@export var fade_duration: float = 0.3
@export var slide_distance: float = 50.0

# 消息类型颜色配置
const TYPE_COLORS: Dictionary = {
	"info": Color(0.2, 0.6, 1.0),
	"success": Color(0.2, 0.8, 0.2),
	"warning": Color(1.0, 0.8, 0.2),
	"error": Color(1.0, 0.3, 0.2)
}


func _ready() -> void:
	# 初始状态：透明且上移
	modulate.a = 0.0
	position.y -= slide_distance


## 显示消息
## @param message: 提示内容
## @param duration: 显示时长（秒，0=使用默认值）
## @param message_type: 消息类型（info/success/warning/error）
func show_message(message: String, duration: float = 0.0, message_type: String = "info") -> void:
	label.text = message

	# 设置颜色
	if message_type in TYPE_COLORS:
		panel.modulate = TYPE_COLORS[message_type]

	# 等待一帧让 label 计算实际大小
	await get_tree().process_frame

	# 自适应宽度（留40像素边距）
	custom_minimum_size.x = label.size.x + 40

	# 播放进入动画
	await _play_enter_animation()

	# 等待显示时长
	var show_duration := duration if duration > 0.0 else default_duration
	await get_tree().create_timer(show_duration).timeout

	# 播放退出动画
	await _play_exit_animation()

	queue_free()


## 进入动画（滑入+淡入）
func _play_enter_animation() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, fade_duration)
	tween.tween_property(self, "position:y", position.y + slide_distance, fade_duration) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	await tween.finished


## 退出动画（滑出+淡出）
func _play_exit_animation() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	tween.tween_property(self, "position:y", position.y - slide_distance, fade_duration) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN)
	await tween.finished
