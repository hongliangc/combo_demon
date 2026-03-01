extends "res://Core/StateMachine/CommonStates/IdleState.gd"

## ForestBee Idle 状态 - 继承通用 IdleState
## 基类自动从 owner 获取 detection_radius

func _init():
	super._init()
	use_fixed_time = true
