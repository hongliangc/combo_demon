extends Node2D
class_name player_spawn

## 角色场景预加载（用于编辑器测试和备用）
var player_selection: Dictionary = {
	"hahashin": preload("res://Scenes/Characters/Player/Hahashin/Hahashin.tscn"),
}

@export_group("Character Selection")
@export_enum("hahashin")
var player_name: String = "hahashin"

## 是否使用 GameManager 的角色选择
@export var use_game_manager: bool = true

var player = null


func _ready() -> void:
	_spawn_player()


## 生成玩家角色
func _spawn_player() -> void:
	# 优先使用 GameManager 的角色选择
	if use_game_manager and GameManager and GameManager.has_selected_character():
		player = GameManager.create_player()
		if player:
			add_child(player)
			player.global_position = self.global_position
			print("PlayerSpawn: Spawned character from GameManager - ", GameManager.selected_character.display_name)
			return

	# 备用方案：使用预设的角色
	if player_selection.has(player_name):
		var scene: PackedScene = player_selection[player_name]
		player = scene.instantiate()
		add_child(player)
		player.global_position = self.global_position
		print("PlayerSpawn: Spawned default character - ", player_name)
	else:
		push_error("PlayerSpawn: Character not found - ", player_name)
