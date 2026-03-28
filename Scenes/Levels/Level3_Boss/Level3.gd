extends Node2D

## 关卡3: Boss战 - 森林洞穴竞技场
##
## 目标：击败Boss，获取宝箱奖励，通过传送门离开
## 布局：封闭竞技场 + 掩体柱子 + 多层平台

@onready var player_spawn: Node2D = $PlayerSpawn
@onready var level_hud: LevelHUD = $LevelHUD
@onready var boss: Node2D = $Boss
@onready var treasure_chest: TreasureChest = $TreasureChest
@onready var portal: Portal = $Portal


func _ready() -> void:
	LevelManager.current_level = 2
	LevelManager.is_level_active = true
	LevelManager._reset_level_stats()
	LevelManager.level_started.emit(2)

	_setup_boss()

	print("Level3: Boss Battle started!")


func _setup_boss() -> void:
	if boss and boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_boss_defeated)


func _on_boss_defeated() -> void:
	print("Level3: Boss defeated!")
	LevelManager.on_boss_defeated()

	# 显示胜利提示
	UIManager.show_toast("Boss Defeated!", 3.0, "success")

	# 显示并解锁宝箱
	if treasure_chest:
		treasure_chest.visible = true
		treasure_chest.unlock()

		# 金币爆散特效（在Boss位置）
		var coin_burst_scene := preload("res://Effects/CoinBurst.tscn")
		var coin_burst := coin_burst_scene.instantiate()
		coin_burst.coin_amount = 8
		coin_burst.global_position = boss.global_position + Vector2(0, -16)
		add_child(coin_burst)
