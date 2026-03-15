extends Node2D

## 关卡2: 迷宫探索 - 地下森林
##
## 目标：收集5把钥匙，解锁迷宫门，找到出口
## 玩法：平台跳跃 + 钥匙解谜

@onready var player_spawn: Node2D = $PlayerSpawn
@onready var portal: Portal = $Portal
@onready var level_hud: LevelHUD = $LevelHUD


func _ready() -> void:
	# 设置当前关卡
	LevelManager.current_level = 1
	LevelManager.is_level_active = true
	LevelManager._reset_level_stats()

	# 发出关卡开始信号
	LevelManager.level_started.emit(1)

	print("Level2: Maze Exploration started!")
