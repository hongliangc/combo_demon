extends "res://Core/StateMachine/CommonStates/WanderState.gd"

## ForestBee Wander 状态 - 飞行巡游
## WanderState 自动从 owner 获取参数（wander_speed, min_wander_time 等）

func _init():
	super._init()
	random_direction = true
	enable_player_detection = true
	next_state_on_timeout = "idle"
	enable_sprite_flip = false  # 由主脚本 _physics_process 处理
