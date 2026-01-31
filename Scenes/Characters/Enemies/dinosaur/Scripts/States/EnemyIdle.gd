extends "res://Core/StateMachine/CommonStates/IdleState.gd"

## Enemy Idle 状态 - 继承通用 IdleState
## 通过 owner 的属性配置行为（detection_radius）
## 基类默认参数已满足需求，只需设置 use_fixed_time

func _ready():
	use_fixed_time = true  # Enemy 使用固定时间
