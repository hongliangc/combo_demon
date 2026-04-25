extends Node2D
class_name BOSSSpawn


var boss_selection: Dictionary = {
	"BladeKeeper": preload("res://Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn"),
	"DemonSlime2": preload("res://Scenes/Characters/Bosses/DemonSlime2/DemonSlime2.tscn")
}

@export_group("BOSS Selection")
@export_enum("BladeKeeper", "DemonSlime2") var boss_name: String = "DemonSlime2"


## 是否使用 GameManager 的角色选择
@export var use_game_manager: bool = false
var boss = null


func _ready() -> void:
	_spawn_boss()

func _spawn_boss() -> void:
	# 优先使用 GameManager 的角色选择
	if use_game_manager and GameManager and GameManager.has_selected_character():
		boss = GameManager.create_boss()
		if boss:
			add_child(boss)
			boss.global_position = self.global_position
			print("bossSpawn: Spawned character from GameManager - ", GameManager.selected_character.display_name)
			return

	# 备用方案：使用预设的角色
	if boss_selection.has(boss_name):
		var scene: PackedScene = boss_selection[boss_name]
		boss = scene.instantiate()
		add_child(boss)
		boss.global_position = self.global_position
		print("bossSpawn: Spawned default character - ", boss_name)
	else:
		push_error("bossSpawn: Character not found - ", boss_name)
