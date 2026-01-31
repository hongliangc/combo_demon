extends "res://Core/StateMachine/CommonStates/IdleState.gd"

## Boss Idle 状态 - 继承通用 IdleState
## 通过 owner 的属性配置行为（detection_radius）
## 无需重写方法，基类自动从 owner 获取参数

## Boss 特有配置（覆盖基类默认值）
@export var boss_idle_time := 2.0
@export var boss_next_state := "patrol"

func _ready():
	# 配置基类参数
	min_idle_time = boss_idle_time
	use_fixed_time = true
	next_state_on_timeout = boss_next_state
	chase_state_name = "chase"
	stop_movement = true

func enter():
	DebugConfig.debug("Boss: 进入闲置状态", "", "ai")
	super.enter()
