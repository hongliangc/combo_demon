extends "res://Core/StateMachine/CommonStates/ChaseState.gd"

## Enemy Chase 状态 - 继承通用 ChaseState
## 通过 owner 的属性配置行为（chase_speed, follow_radius, chase_radius）
## 无需重写方法，基类自动从 owner 获取参数
