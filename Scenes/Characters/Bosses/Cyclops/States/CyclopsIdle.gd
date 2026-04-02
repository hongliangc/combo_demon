extends "res://Scenes/Characters/Bosses/Shared/BossIdleState.gd"

## Cyclops Idle — 继承 BossIdleState，覆盖参数

func _init():
	super._init()

func _ready():
	min_idle_time = boss_idle_time
	next_state_on_timeout = boss_next_state

func enter():
	DebugConfig.debug("Boss: 进入闲置状态", "", "ai")
	super.enter()
