extends "res://Core/StateMachine/CommonStates/IdleState.gd"

## Boss 通用 Idle 状态 — 继承通用 IdleState
## 重写转换逻辑使用 Boss 距离决策（attack_range + detection_radius）
## 各 Boss 可直接使用或继承后覆盖参数

@export var boss_idle_time := 2.0
@export var boss_next_state := "chase"

func _init():
	super._init()
	use_fixed_time = true
	stop_immediately = true

func _ready():
	min_idle_time = boss_idle_time
	next_state_on_timeout = boss_next_state

## 重写：使用 Boss 距离决策代替通用 try_attack/try_chase
func _evaluate_idle_transition() -> void:
	var boss := owner_node as BossBase
	if not boss:
		super._evaluate_idle_transition()
		return

	if not is_target_alive():
		return

	var distance := get_distance_to_target()
	if distance <= boss.attack_range and boss.attack_cooldown <= 0:
		transition_to("attack")
	elif distance <= boss.detection_radius:
		transition_to("chase")
