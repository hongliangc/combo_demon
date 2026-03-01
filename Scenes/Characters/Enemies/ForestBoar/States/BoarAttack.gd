extends "res://Core/StateMachine/CommonStates/AttackState.gd"

## ForestBoar Attack 状态 - 接触伤害（冲刺攻击）

func _init():
	super._init()
	attack_interval = 2.0
	use_attack_component = false
	stop_on_attack = false
	deceleration_rate = 5.0
	default_state_name = "wander"
