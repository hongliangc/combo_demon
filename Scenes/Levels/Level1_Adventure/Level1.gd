extends Node2D

## 关卡1: 森林冒险 - 平台跳跃风格
##
## 目标：收集5个宝箱后进入传送门
## 玩法：左右移动 + 上下跳跃

@onready var player_spawn: Node2D = $PlayerSpawn
@onready var portal: Portal = $Portal
@onready var level_hud: LevelHUD = $LevelHUD


func _ready() -> void:
	# 设置当前关卡
	LevelManager.current_level = 0
	LevelManager.is_level_active = true
	LevelManager._reset_level_stats()

	# 发出关卡开始信号
	LevelManager.level_started.emit(0)

	print("Level1: Forest Adventure started!")
