extends Node2D

## BOSS 战房间 - Level1 传送门目标
##
## 流程：玩家在 Level1 收集宝箱后通过传送门进入此场景
## 击败 BOSS 后自动进入下一关（Level2）

@onready var boss: Node2D = $Boss


func _ready() -> void:
	# 保持 current_level = 0（属于 Level1 流程）
	LevelManager.is_level_active = true

	# 连接 Boss 死亡信号
	_setup_boss()

	print("BossArena: Boss fight started!")


func _setup_boss() -> void:
	if boss and boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_boss_defeated)


func _on_boss_defeated() -> void:
	print("BossArena: Boss defeated!")
	LevelManager.on_boss_defeated()
