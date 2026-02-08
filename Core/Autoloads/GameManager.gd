extends Node

## 游戏管理器单例 - 管理游戏状态、角色选择和场景切换
##
## 核心功能：
## - 游戏状态管理（Menu/CharacterSelect/Playing/Paused/GameOver）
## - 角色选择和数据管理
## - 场景切换（使用UIManager）
## - 游戏流程控制

## 游戏状态枚举
enum GameState {
	MENU,           # 主菜单
	CHARACTER_SELECT,  # 角色选择
	PLAYING,        # 游戏中
	PAUSED,         # 暂停
	GAME_OVER       # 游戏结束
}

## 游戏状态变化信号
signal game_state_changed(old_state: GameState, new_state: GameState)

## 角色选择完成信号
signal character_selection_completed(character_data: Resource)

## 当前游戏状态
var current_state: GameState = GameState.MENU:
	set(value):
		var old_state = current_state
		current_state = value
		game_state_changed.emit(old_state, current_state)

## 当前选中的角色数据
var selected_character: Resource = null

## 场景路径配置
var character_select_scene: String = "res://Scenes/UI/Screens/CharacterSelection/CharacterSelectionScreen.tscn"
var main_scene: String = "res://Scenes/main.tscn"

## 玩家实例引用
var player_instance: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## 设置选中的角色
func set_selected_character(character_data: Resource) -> void:
	selected_character = character_data
	character_selection_completed.emit(character_data)
	print("GameManager: Character selected - ", character_data.display_name if character_data else "None")


## 获取选中的角色
func get_selected_character() -> Resource:
	return selected_character


## 显示角色选择界面
func show_character_selection() -> void:
	current_state = GameState.CHARACTER_SELECT
	UIManager.transition_to_scene(character_select_scene, "fade")


## 开始游戏（从角色选择界面）
func start_game() -> void:
	if selected_character == null:
		push_error("GameManager: Cannot start game without selected character")
		return

	current_state = GameState.PLAYING
	# 使用LevelManager启动关卡系统
	LevelManager.start_game()


## 开始冒险模式（多关卡）
func start_adventure() -> void:
	current_state = GameState.PLAYING
	LevelManager.start_game()


## 返回主菜单
func return_to_menu() -> void:
	current_state = GameState.MENU
	selected_character = null
	# TODO: 实现主菜单场景


## 暂停游戏
func pause_game() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true


## 继续游戏
func resume_game() -> void:
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false


## 游戏结束 - 显示GameOverUI
func game_over() -> void:
	current_state = GameState.GAME_OVER

	# 使用 UIManager 打开 GameOver 面板
	var game_over_ui := preload("res://Scenes/UI/Screens/GameOver/GameOverUI.tscn").instantiate()
	UIManager.open_panel(game_over_ui, UIManager.UILayer.POPUP)


## 重新开始游戏（保持当前角色）
func restart_game() -> void:
	if selected_character:
		current_state = GameState.PLAYING
		get_tree().reload_current_scene()


## 创建玩家实例
func create_player() -> Node:
	if selected_character == null:
		push_error("GameManager: No character selected")
		return null

	player_instance = selected_character.instantiate_character()
	return player_instance


## 检查是否有选中的角色
func has_selected_character() -> bool:
	return selected_character != null


## 获取选中角色的场景路径
func get_selected_character_scene_path() -> String:
	if selected_character:
		return selected_character.scene_path
	return ""


## 调试打印当前状态
func debug_print() -> void:
	print("========== GameManager ==========")
	print("Current State: ", GameState.keys()[current_state])
	print("Selected Character: ", selected_character.display_name if selected_character else "None")
	print("=================================")
