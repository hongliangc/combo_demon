extends "res://Core/StateMachine/CommonStates/ChaseState.gd"

## ForestBee Chase 状态 - 继承通用 ChaseState
## 通过 owner 的属性配置行为（chase_speed, follow_radius, chase_radius）

func _init():
	super._init()
	enable_sprite_flip = false  # 由主脚本 _physics_process 处理
