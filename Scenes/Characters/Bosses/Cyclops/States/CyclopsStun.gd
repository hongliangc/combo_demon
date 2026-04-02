extends "res://Scenes/Characters/Bosses/Shared/BossStunState.gd"

## Cyclops Stun — 继承 BossStunState，覆盖参数

func _init():
	super._init()
	stun_duration = 1.0
	stun_anim_speed = 1.0
	reset_on_damage = true
	knockback_friction = 8.0
