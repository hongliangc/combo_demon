## 角色卡片组件
## 用于在轮播中显示角色信息
extends Panel
class_name CharacterCard

## 角色数据发生变化时发出
signal character_changed(character_data: Resource)

## 卡片被选中时发出
signal card_selected(character_data: Resource)

## 关联的角色数据
var character_data: Resource = null:
	set(value):
		character_data = value
		_update_display()

## UI 节点引用
@onready var portrait_rect: TextureRect = $VBoxContainer/PortraitContainer/Portrait
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var stats_container: VBoxContainer = $VBoxContainer/StatsContainer
@onready var health_label: Label = $VBoxContainer/StatsContainer/HealthLabel
@onready var speed_label: Label = $VBoxContainer/StatsContainer/SpeedLabel
@onready var lock_overlay: ColorRect = $LockOverlay


func _ready() -> void:
	# 连接点击事件
	gui_input.connect(_on_gui_input)
	_update_display()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if character_data and character_data.is_unlocked:
				card_selected.emit(character_data)


## 设置角色数据
func set_character(data: Resource) -> void:
	character_data = data


## 更新显示内容
func _update_display() -> void:
	if not is_inside_tree():
		return

	if character_data == null:
		_clear_display()
		return

	# 更新头像
	if portrait_rect and character_data.portrait:
		portrait_rect.texture = character_data.portrait

	# 更新名称
	if name_label:
		name_label.text = character_data.display_name

	# 更新属性显示
	if health_label:
		health_label.text = "HP: %d" % character_data.base_health
	if speed_label:
		speed_label.text = "SPD: %d" % character_data.base_speed

	# 更新锁定状态
	if lock_overlay:
		lock_overlay.visible = not character_data.is_unlocked

	character_changed.emit(character_data)


## 清空显示
func _clear_display() -> void:
	if portrait_rect:
		portrait_rect.texture = null
	if name_label:
		name_label.text = "???"
	if health_label:
		health_label.text = "HP: ---"
	if speed_label:
		speed_label.text = "SPD: ---"
	if lock_overlay:
		lock_overlay.visible = true
