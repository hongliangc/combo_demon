extends Node2D

## 关卡3: Boss战 - 森林深处
##
## 目标：击败Boss
## 玩法：平台跳跃 + Boss战

@onready var player_spawn: Node2D = $PlayerSpawn
@onready var level_hud: LevelHUD = $LevelHUD
@onready var camera: Camera2D = $Camera2D
@onready var boss: Node2D = $Boss

var boss_spawned: bool = false


func _ready() -> void:
	# 设置当前关卡
	LevelManager.current_level = 2
	LevelManager.is_level_active = true
	LevelManager._reset_level_stats()

	# 发出关卡开始信号
	LevelManager.level_started.emit(2)

	# 连接Boss死亡信号
	_setup_boss()

	print("Level3: Boss Battle started!")


func _setup_boss() -> void:
	if boss and boss.has_signal("died"):
		boss.died.connect(_on_boss_died)


func _on_boss_died() -> void:
	print("Level3: Boss defeated!")
	LevelManager.on_boss_defeated()


func _physics_process(_delta: float) -> void:
	# 摄像机跟随玩家
	var player = get_tree().get_first_node_in_group("player")
	if player and camera:
		camera.global_position = camera.global_position.lerp(player.global_position, 0.1)
