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

@onready var sprite: Sprite2D = $Sprite2D

var move_speed: float:
	get: return base_move_speed * PHASE_SPEED.get(current_phase, 1.0)

func _on_boss_ready() -> void:
	detection_radius = 800.0
	attack_range = 200.0
	min_distance = 100.0

func _update_facing() -> void:
	if velocity.x != 0 and sprite:
		sprite.flip_h = velocity.x < 0
