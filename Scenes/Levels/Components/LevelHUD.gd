extends CanvasLayer
class_name LevelHUD

## 关卡HUD - 显示关卡信息和目标进度

@onready var level_name_label: Label = $MarginContainer/VBoxContainer/LevelName
@onready var objective_label: Label = $MarginContainer/VBoxContainer/Objective
@onready var coin_label: Label = $MarginContainer/VBoxContainer/Coins


func _ready() -> void:
	# 连接LevelManager信号
	LevelManager.item_collected.connect(_on_item_collected)
	LevelManager.objective_updated.connect(_on_objective_updated)
	LevelManager.level_started.connect(_on_level_started)

	# 初始化显示
	_update_display()


func _on_level_started(_level_index: int) -> void:
	_update_display()


func _on_item_collected(_item_type: String, _count: int) -> void:
	_update_display()


func _on_objective_updated(_type: String, _current: int, _required: int) -> void:
	_update_display()


func _update_display() -> void:
	if level_name_label:
		level_name_label.text = LevelManager.get_current_level_name()

	if objective_label:
		objective_label.text = LevelManager.get_objective_text()

	if coin_label:
		coin_label.text = "Coins: %d" % LevelManager.collected_coins
