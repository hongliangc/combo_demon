extends Node2D

## 关卡1: 森林冒险 - 平台跳跃风格
##
## 目标：收集5个宝箱后进入传送门
## 玩法：左右移动 + 上下跳跃

@onready var player_spawn: Node2D = $PlayerSpawn
@onready var portal: Portal = $Portal
@onready var level_hud: LevelHUD = $LevelHUD
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	# 设置当前关卡
	LevelManager.current_level = 0
	LevelManager.is_level_active = true
	LevelManager._reset_level_stats()

	# 发出关卡开始信号
	LevelManager.level_started.emit(0)

	# 设置摄像机跟随玩家
	_setup_camera_follow()

	print("Level1: Forest Adventure started!")


func _setup_camera_follow() -> void:
	# 等待玩家生成
	await get_tree().process_frame

	var player = get_tree().get_first_node_in_group("player")
	if player and camera:
		# 摄像机跟随玩家
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 5.0


func _physics_process(_delta: float) -> void:
	# 摄像机跟随玩家
	var player = get_tree().get_first_node_in_group("player")
	if player and camera:
		camera.global_position = camera.global_position.lerp(player.global_position, 0.1)
