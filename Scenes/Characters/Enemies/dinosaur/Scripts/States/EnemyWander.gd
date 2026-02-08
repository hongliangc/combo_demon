extends "res://Core/StateMachine/CommonStates/WanderState.gd"

## Enemy Wander 状态 - 使用通用 WanderState 模板
## 简化版：WanderState 现在自动从 owner 获取参数（wander_speed, min_wander_time 等）

func _init():
	super._init()
	# 配置参数
	random_direction = true
	enable_player_detection = true
	next_state_on_timeout = "idle"
	enable_sprite_flip = true
