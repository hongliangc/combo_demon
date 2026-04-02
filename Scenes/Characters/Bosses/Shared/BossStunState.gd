extends "res://Core/StateMachine/CommonStates/StunState.gd"

## Boss 通用 Stun 状态 — 继承通用 StunState
## 添加眩晕免疫 + Boss 距离决策恢复
## 各 Boss 可直接使用或继承后覆盖（如 Phase 3 免疫）

@export var stun_immunity_duration := 1.5

func _init():
	super._init()
	reset_on_damage = true

## 设置眩晕免疫
func _on_stun_exit() -> void:
	var boss := owner_node as BossBase
	if boss:
		boss.stun_immunity = stun_immunity_duration

## 使用 Boss 距离决策选择恢复状态
func decide_next_state() -> void:
	var boss := owner_node as BossBase
	if not boss:
		super.decide_next_state()
		return

	if not is_target_alive():
		transition_to("idle")
		return

	var distance := get_distance_to_target()
	if distance > boss.detection_radius:
		transition_to("idle")
	elif distance <= boss.attack_range and boss.attack_cooldown <= 0:
		transition_to("attack")
	else:
		transition_to("chase")
