extends EnemyStates

var attack_component := AttackComponent.new()
@onready var anchor = $"../../AttackAnchor"
var attack_interval: float = 3
var attack_timer: float = 0


func enter():
	attack_timer = 0

func physics_process_state(delta) -> void:
	if !player or !player.alive:
		transitioned.emit(self, "wander")
	if !enemy.alive:
		return
	var	direction = player.global_position - enemy.global_position
	var distance = direction.length()
	if distance > enemy.follow_radius:
		transitioned.emit(self, "chase")
		return
	
	attack_timer -= delta
	if attack_timer <= 0:
		attack_timer = attack_interval
		attack_component.perform_attack("slash_attack", direction.normalized(), anchor)
	
