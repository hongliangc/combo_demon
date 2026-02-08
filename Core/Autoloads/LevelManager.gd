extends Node

## 关卡管理器 - 管理多关卡进度、切换和收集物统计
##
## 核心功能：
## - 关卡进度管理
## - 收集物统计（宝箱、钥匙、金币）
## - 关卡切换（线性推进）
## - 胜利/失败条件检查

# 信号
signal level_started(level_index: int)
signal level_completed(level_index: int)
signal item_collected(item_type: String, count: int)
signal objective_updated(objective_type: String, current: int, required: int)
signal boss_defeated()
signal game_completed()

# 关卡场景路径
const LEVEL_SCENES: Array[String] = [
	"res://Scenes/Levels/Level1_Adventure/Level1.tscn",
	"res://Scenes/Levels/Level2_Maze/Level2.tscn",
	"res://Scenes/Levels/Level3_Boss/Level3.tscn"
]

# 关卡目标配置
const LEVEL_OBJECTIVES: Dictionary = {
	0: {"treasures": 5},  # 关卡1: 收集5个宝箱
	1: {"keys": 5},       # 关卡2: 收集5把钥匙
	2: {"boss": true}     # 关卡3: 击败Boss
}

# 当前关卡索引
var current_level: int = 0

# 收集物统计
var collected_treasures: int = 0
var collected_keys: int = 0
var collected_coins: int = 0

# Boss状态
var is_boss_defeated: bool = false

# 关卡状态
var is_level_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## 开始指定关卡
func start_level(level_index: int) -> void:
	if level_index < 0 or level_index >= LEVEL_SCENES.size():
		push_error("LevelManager: Invalid level index - ", level_index)
		return

	current_level = level_index
	_reset_level_stats()
	is_level_active = true

	level_started.emit(level_index)
	UIManager.transition_to_scene(LEVEL_SCENES[level_index], "fade")
	print("LevelManager: Starting level ", level_index + 1)


## 从头开始游戏
func start_game() -> void:
	start_level(0)


## 重置当前关卡统计
func _reset_level_stats() -> void:
	collected_treasures = 0
	collected_keys = 0
	collected_coins = 0
	is_boss_defeated = false


## 收集物品
func collect_item(item_type: String, amount: int = 1) -> void:
	match item_type:
		"treasure":
			collected_treasures += amount
			item_collected.emit("treasure", collected_treasures)
			_check_treasure_objective()
		"key":
			collected_keys += amount
			item_collected.emit("key", collected_keys)
			_check_key_objective()
		"coin":
			collected_coins += amount
			item_collected.emit("coin", collected_coins)
		_:
			push_warning("LevelManager: Unknown item type - ", item_type)


## 检查宝箱收集目标
func _check_treasure_objective() -> void:
	if current_level == 0:
		var required = LEVEL_OBJECTIVES[0]["treasures"]
		objective_updated.emit("treasures", collected_treasures, required)
		if collected_treasures >= required:
			print("LevelManager: Treasure objective completed!")


## 检查钥匙收集目标
func _check_key_objective() -> void:
	if current_level == 1:
		var required = LEVEL_OBJECTIVES[1]["keys"]
		objective_updated.emit("keys", collected_keys, required)
		if collected_keys >= required:
			print("LevelManager: Key objective completed!")


## Boss被击败
func on_boss_defeated() -> void:
	is_boss_defeated = true
	boss_defeated.emit()
	print("LevelManager: Boss defeated!")

	# 延迟显示胜利
	await get_tree().create_timer(2.0).timeout
	complete_level()


## 检查是否可以通过当前关卡
func can_complete_level() -> bool:
	match current_level:
		0:
			return collected_treasures >= LEVEL_OBJECTIVES[0]["treasures"]
		1:
			return collected_keys >= LEVEL_OBJECTIVES[1]["keys"]
		2:
			return is_boss_defeated
		_:
			return false


## 完成当前关卡
func complete_level() -> void:
	if not is_level_active:
		return

	is_level_active = false
	level_completed.emit(current_level)
	print("LevelManager: Level ", current_level + 1, " completed!")

	# 检查是否还有下一关
	if current_level < LEVEL_SCENES.size() - 1:
		# 延迟后进入下一关
		await get_tree().create_timer(1.0).timeout
		next_level()
	else:
		# 游戏通关
		game_completed.emit()
		_show_victory_screen()


## 进入下一关
func next_level() -> void:
	start_level(current_level + 1)


## 重新开始当前关卡
func restart_level() -> void:
	start_level(current_level)


## 显示胜利界面
func _show_victory_screen() -> void:
	print("LevelManager: Game completed! Showing victory screen...")
	# 可以显示一个胜利UI
	UIManager.show_toast("Congratulations! You Win!", 5.0, "success")


## 获取当前关卡名称
func get_current_level_name() -> String:
	match current_level:
		0:
			return "Forest Adventure"
		1:
			return "Dungeon Maze"
		2:
			return "Boss Battle"
		_:
			return "Unknown"


## 获取当前关卡目标描述
func get_objective_text() -> String:
	match current_level:
		0:
			return "Collect %d/%d Treasures" % [collected_treasures, LEVEL_OBJECTIVES[0]["treasures"]]
		1:
			return "Find %d/%d Keys" % [collected_keys, LEVEL_OBJECTIVES[1]["keys"]]
		2:
			return "Defeat the Boss!"
		_:
			return ""


## 检查是否有钥匙可用
func has_key() -> bool:
	return collected_keys > 0


## 使用一把钥匙
func use_key() -> bool:
	if collected_keys > 0:
		collected_keys -= 1
		item_collected.emit("key", collected_keys)
		return true
	return false
