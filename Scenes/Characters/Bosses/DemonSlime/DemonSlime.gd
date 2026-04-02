extends BossBase
class_name DemonSlime

## DemonSlime Boss — 慢速重击型，冲击波施压

const PHASE_SPEED := {
	Phase.PHASE_1: 1.0,
	Phase.PHASE_2: 1.3,
	Phase.PHASE_3: 1.5,
}

@export var base_move_speed := 80.0
@export var health_multiplier := 1.5  ## 相对默认血量的倍率

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var move_speed: float:
	get: return base_move_speed * PHASE_SPEED.get(current_phase, 1.0)

func _on_boss_ready() -> void:
	detection_radius = 600.0
	attack_range = 250.0
	min_distance = 80.0
	if health_component:
		health_component.max_health *= health_multiplier
		health_component.health = health_component.max_health
		max_health = int(health_component.max_health)
		health = max_health

func _update_facing() -> void:
	if velocity.x != 0 and sprite:
		sprite.flip_h = velocity.x < 0
