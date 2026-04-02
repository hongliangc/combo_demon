extends "res://Core/StateMachine/CommonStates/ChaseState.gd"

## BladeKeeper Chase 状态 — 继承通用 ChaseState
## 每次 enter 读取 Boss 参数（支持阶段变速），重写攻击冷却检查

func _init():
	super._init()
	enable_sprite_flip = true
	give_up_state_name = "idle"

func enter() -> void:
	# 每次进入 chase 时读取当前 Boss 参数（支持阶段变速）
	var boss := owner_node as BossBase
	if boss:
		default_chase_speed = (boss as BladeKeeper).move_speed if boss is BladeKeeper else 180.0
		default_attack_range = boss.attack_range
		default_give_up_range = boss.detection_radius
	super.enter()

## 重写：检查攻击冷却
func _on_reached_attack_range() -> String:
	var boss := owner_node as BossBase
	if boss and boss.attack_cooldown > 0:
		return ""  # 冷却中，不转换（留在 chase）
	return "attack"
