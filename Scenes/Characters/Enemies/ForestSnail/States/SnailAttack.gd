extends "res://Core/StateMachine/CommonStates/AttackState.gd"

## ForestSnail Attack 状态 - 接触伤害

func _init():
	super._init()
	attack_interval = 3.0
	use_attack_component = false
	stop_on_attack = true
	default_state_name = "wander"
