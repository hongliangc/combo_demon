extends Node2D

## 关卡2: 迷宫探索 - 地下森林
##
## 目标：收集5把钥匙，解锁迷宫门，找到出口
## 玩法：平台跳跃 + 钥匙解谜

@onready var player_spawn: Node2D = $PlayerSpawn
@onready var portal: Portal = $Portal
@onready var level_hud: LevelHUD = $LevelHUD
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	# 设置当前关卡
	LevelManager.current_level = 1
	LevelManager.is_level_active = true
	LevelManager._reset_level_stats()

	# 发出关卡开始信号
	LevelManager.level_started.emit(1)

	print("Level2: Maze Exploration started!")


func _physics_process(_delta: float) -> void:
	# 摄像机跟随玩家
	var player = get_tree().get_first_node_in_group("player")
	if player and camera:
		camera.global_position = camera.global_position.lerp(player.global_position, 0.1)
