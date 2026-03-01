extends Control
class_name HealthBar

## 通用血条UI组件

@export var bar_color: Color = Color.RED
@export var background_color: Color = Color(0.2, 0.2, 0.2, 0.8)
@export var border_color: Color = Color.WHITE
@export var show_text: bool = true

var max_value: float = 100.0
var current_value: float = 100.0
var _fill_style: StyleBoxFlat = null

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var label: Label = $Label

func _ready() -> void:
	update_display()

## 设置最大值
func set_max_value(value: float) -> void:
	max_value = value
	update_display()

## 设置当前值
func set_value(value: float) -> void:
	current_value = clamp(value, 0, max_value)
	update_display()

## 更新血条显示
func update_display() -> void:
	if not progress_bar:
		return

	progress_bar.max_value = max_value
	progress_bar.value = current_value

	# 更新文本
	if label and show_text:
		label.text = "%d / %d" % [int(current_value), int(max_value)]
		label.visible = true
	elif label:
		label.visible = false

	# 更新颜色（复用缓存的 StyleBoxFlat，避免重复创建导致资源泄漏）
	if not _fill_style:
		_fill_style = StyleBoxFlat.new()
		progress_bar.add_theme_stylebox_override("fill", _fill_style)
	_fill_style.bg_color = bar_color
	_fill_style.border_color = border_color

## 平滑更新到目标值
func tween_to_value(target_value: float, duration: float = 0.3) -> void:
	var tween = create_tween()
	tween.tween_method(set_value, current_value, target_value, duration)
