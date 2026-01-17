extends Control
class_name CharacterSelectionScreen

## 角色选择界面 - 使用轮播组件展示可选角色，选择后进入游戏
##
## 特性：
## - 自动加载 res://Util/Data/Characters/ 目录下的角色数据
## - 使用轮播容器展示角色卡片
## - 支持键盘/按钮控制选择
## - 可通过 GameManager 启动游戏

# 信号
signal character_selected(character_data: Resource)  ## 角色被选中（切换时触发）
signal start_game(character_data: Resource)  ## 确认开始游戏

# 常量
const CharacterCardScene: PackedScene = preload("res://Scenes/UI/CharacterCard.tscn")

## 可选角色数据列表
@export var character_list: Array[Resource] = []

## 主场景路径（选择角色后加载）
@export_file("*.tscn") var main_scene_path: String = "res://Scenes/main.tscn"

## UI 节点引用
@onready var carousel: CarouselContainer = $MainContainer/VBoxContainer/CarouselSection/CarouselContainer
@onready var carousel_section: Control = $MainContainer/VBoxContainer/CarouselSection
@onready var title_label: Label = $MainContainer/VBoxContainer/TitleLabel
@onready var description_label: Label = $MainContainer/VBoxContainer/DescriptionPanel/DescriptionLabel
@onready var confirm_button: Button = $MainContainer/VBoxContainer/ButtonContainer/ConfirmButton
@onready var left_button: Button = $MainContainer/VBoxContainer/CarouselSection/LeftButton
@onready var right_button: Button = $MainContainer/VBoxContainer/CarouselSection/RightButton

## 当前选中的角色数据
var selected_character: Resource = null

## 生成的角色卡片列表
var _character_cards: Array = []


func _ready() -> void:
	_setup_ui()
	_load_characters()
	_connect_signals()


## 初始化UI
func _setup_ui() -> void:
	if title_label:
		title_label.text = "选择角色"


## 加载角色到轮播
func _load_characters() -> void:
	print("[CharacterSelectionScreen] _load_characters called")
	print("[CharacterSelectionScreen] carousel: ", carousel)
	if carousel:
		print("[CharacterSelectionScreen] carousel.position_offset_node: ", carousel.position_offset_node)
	else:
		print("[CharacterSelectionScreen] carousel is null")

	if not carousel or not carousel.position_offset_node:
		push_error("CharacterSelectionScreen: Carousel or position_offset_node not found")
		return

	var cards_container = carousel.position_offset_node
	print("[CharacterSelectionScreen] cards_container: ", cards_container)

	# 清空现有卡片
	for child in cards_container.get_children():
		child.queue_free()
	_character_cards.clear()

	# 如果没有配置角色，尝试从 Data/Characters 加载
	if character_list.is_empty():
		_auto_load_characters()

	print("[CharacterSelectionScreen] character_list size: ", character_list.size())

	# 为每个角色创建卡片
	for char_data in character_list:
		print("[CharacterSelectionScreen] Creating card for: ", char_data.display_name if char_data else "null")
		var card = CharacterCardScene.instantiate()
		cards_container.add_child(card)
		card.set_character(char_data)
		card.card_selected.connect(_on_card_selected)
		_character_cards.append(card)

	print("[CharacterSelectionScreen] Total cards created: ", _character_cards.size())
	print("[CharacterSelectionScreen] cards_container child_count: ", cards_container.get_child_count())

	# 默认选中第一个角色
	if not character_list.is_empty():
		carousel.selected_index = 0
		_update_selected_character(0)


## 自动从目录加载角色数据
func _auto_load_characters() -> void:
	var dir_path = "res://Util/Data/Characters/"
	var dir = DirAccess.open(dir_path)
	if dir == null:
		print("CharacterSelectionScreen: Characters directory not found, using default")
		_create_default_character()
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var resource = load(dir_path + file_name)
			# 检查是否为 CharacterData 类型
			if resource is CharacterData:
				character_list.append(resource)
		file_name = dir.get_next()
	dir.list_dir_end()

	# 如果仍然没有角色，创建默认角色
	if character_list.is_empty():
		_create_default_character()


## 创建默认角色数据（hahashin）
func _create_default_character() -> void:
	var default_char := CharacterData.new()
	default_char.id = "hahashin"
	default_char.display_name = "哈哈辛"
	default_char.description = "一位敏捷的战士，擅长近战连击攻击。"
	default_char.scene_path = "res://Scenes/charaters/hahashin.tscn"
	default_char.base_health = 100.0
	default_char.base_speed = 100.0
	default_char.base_damage = 10.0
	default_char.is_unlocked = true
	default_char.tags = ["melee", "warrior"]
	character_list.append(default_char)


## 连接信号（注意：按钮信号已在场景中连接）
func _connect_signals() -> void:
	# 按钮信号已在 .tscn 场景文件中通过编辑器连接
	# 这里只需要连接动态生成的信号
	pass


func _process(_delta: float) -> void:
	# 让 CarouselContainer (Node2D) 在 CarouselSection (Control) 中居中
	if carousel and carousel_section:
		var center := carousel_section.size / 2.0
		# 向上偏移，让选中卡片不会挡住下方描述
		carousel.position = Vector2(center.x, center.y - 60.0)

	# 检测轮播选中变化
	if carousel:
		var current_index = carousel.selected_index
		if selected_character == null or _get_character_index(selected_character) != current_index:
			_update_selected_character(current_index)


## 根据角色数据获取索引
func _get_character_index(char_data: Resource) -> int:
	for i in range(character_list.size()):
		if character_list[i] == char_data:
			return i
	return -1


## 更新当前选中的角色
func _update_selected_character(index: int) -> void:
	if index < 0 or index >= character_list.size():
		return

	selected_character = character_list[index]
	character_selected.emit(selected_character)

	# 更新描述
	if description_label and selected_character:
		description_label.text = selected_character.description

	# 更新确认按钮状态
	if confirm_button and selected_character:
		confirm_button.disabled = not selected_character.is_unlocked
		confirm_button.text = "开始游戏" if selected_character.is_unlocked else "未解锁"


## 卡片被点击
func _on_card_selected(char_data: Resource) -> void:
	if char_data.is_unlocked:
		_confirm_selection()


## 左按钮点击
func _on_left_pressed() -> void:
	if carousel:
		carousel.select_previous()


## 右按钮点击
func _on_right_pressed() -> void:
	if carousel:
		carousel.select_next()


## 确认选择按钮点击
func _on_confirm_pressed() -> void:
	_confirm_selection()


## 确认选择并开始游戏
func _confirm_selection() -> void:
	if selected_character == null or not selected_character.is_unlocked:
		return

	start_game.emit(selected_character)

	# 通知 GameManager
	if GameManager:
		GameManager.set_selected_character(selected_character)
		GameManager.start_game()
	else:
		# 直接切换场景
		get_tree().change_scene_to_file(main_scene_path)


## 处理输入
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_on_left_pressed()
	elif event.is_action_pressed("ui_right"):
		_on_right_pressed()
	elif event.is_action_pressed("ui_accept"):
		_on_confirm_pressed()


## 获取当前选中的角色
func get_selected_character() -> Resource:
	return selected_character
