## 角色数据资源类
## 存储角色的基本信息、显示信息和场景引用
@tool
extends Resource
class_name CharacterData

## 角色唯一标识符
@export var id: String = ""

## 角色显示名称
@export var display_name: String = ""

## 角色描述
@export_multiline var description: String = ""

## 角色头像/卡片图片
@export var portrait: Texture2D = null

## 角色场景路径
@export_file("*.tscn") var scene_path: String = ""

## 角色基础属性
@export_group("Base Stats")
@export var base_health: float = 100.0
@export var base_speed: float = 100.0
@export var base_damage: float = 10.0

## 角色标签（用于分类：近战、远程、坦克等）
@export var tags: Array[String] = []

## 是否解锁
@export var is_unlocked: bool = true


## 获取角色场景实例
func instantiate_character() -> Node:
	if scene_path.is_empty():
		push_error("CharacterData: scene_path is empty for character: " + id)
		return null

	var scene = load(scene_path)
	if scene == null:
		push_error("CharacterData: Failed to load scene: " + scene_path)
		return null

	return scene.instantiate()


## 调试打印
func debug_print() -> void:
	print("========== CharacterData ==========")
	print("ID: ", id)
	print("Name: ", display_name)
	print("Description: ", description)
	print("Scene: ", scene_path)
	print("Health: ", base_health)
	print("Speed: ", base_speed)
	print("Damage: ", base_damage)
	print("Tags: ", tags)
	print("Unlocked: ", is_unlocked)
	print("===================================")
