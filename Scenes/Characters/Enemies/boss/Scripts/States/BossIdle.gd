extends "res://Core/StateMachine/CommonStates/IdleState.gd"

## Boss Idle 状态 - 继承通用 IdleState
## 基类自动从 owner 获取参数

## Boss 特有配置
@export var boss_idle_time := 2.0
@export var boss_next_state := "patrol"

func _init():
	super._init()
	use_fixed_time = true
	stop_immediately = true

func _ready():
	min_idle_time = boss_idle_time
	next_state_on_timeout = boss_next_state

func enter():
	DebugConfig.debug("Boss: 进入闲置状态", "", "ai")
	super.enter()
