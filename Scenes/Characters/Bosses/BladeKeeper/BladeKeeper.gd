extends BossBase
class_name BladeKeeper

## BladeKeeper Boss — 快速技巧型剑士
## 3 段连击、防御反击、闪避翻滚、剑气投射、地面陷阱

const PHASE_SPEED := {
	Phase.PHASE_1: 1.0,
	Phase.PHASE_2: 1.3,
	Phase.PHASE_3: 1.5,
}

@export var base_move_speed := 180.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var move_speed: float:
	get: return base_move_speed * PHASE_SPEED.get(current_phase, 1.0)

func _init() -> void:
	# 覆盖 BossBase 默认值（inspector 可进一步调整）
	detection_radius = 800.0
	attack_range = 200.0
	is_melee = true
	# 闪避反应
	evasion_enabled = true
	evasion_chance_per_phase = {Phase.PHASE_1: 0.15, Phase.PHASE_2: 0.25, Phase.PHASE_3: 0.35}
	# Poise 反击系统
	poise_enabled = true
	max_poise = 5
	poise_per_phase = {Phase.PHASE_2: 4, Phase.PHASE_3: 3}

func _update_facing() -> void:
	if velocity.x != 0 and sprite: 
		sprite.flip_h = velocity.x < 0
