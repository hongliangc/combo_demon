extends "res://Scenes/Characters/Bosses/Shared/BossStunState.gd"

## DemonSlime Stun — 继承 BossStunState，添加 Phase 3 免疫

func _init():
	super._init()
	stun_duration = 1.5

## Phase 3 免疫眩晕
func on_damaged(damage: Damage, _attacker_position: Vector2) -> void:
	var boss := owner_node as BossBase
	if boss and boss.current_phase == BossBase.Phase.PHASE_3:
		return
	super.on_damaged(damage, _attacker_position)
