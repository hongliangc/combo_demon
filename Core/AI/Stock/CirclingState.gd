extends AIState

## Stock Circling — boss orbits target at circle_radius via tangential motion
## with radial correction. AnimationDriver auto-locomotion handles walk anim.
##
## Blackboard inputs: target_position, circle_radius, chase_speed
## Agent property (optional): circle_direction (int, 1 = CW or -1 = CCW)

@export var default_radius: float = 200.0
@export var default_speed: float = 100.0

func physics_update(_delta: float) -> void:
	if owner_node is not CharacterBody2D:
		return
	var body := owner_node as CharacterBody2D
	var target_pos: Vector2 = bb.get_var(&"target_position", body.global_position) as Vector2
	var circle_radius := float(bb.get_var(&"circle_radius", default_radius))
	var chase_speed := float(bb.get_var(&"chase_speed", default_speed))
	var circle_dir := 1
	if agent and "circle_direction" in agent:
		circle_dir = int(agent.circle_direction)

	var to_target: Vector2 = target_pos - body.global_position
	var current_dist := to_target.length()
	if current_dist < 0.01:
		body.velocity = Vector2.ZERO
		return

	var to_target_n: Vector2 = to_target / current_dist
	var tangent: Vector2 = to_target_n.orthogonal() * float(circle_dir)
	var radial_correction := 0.0
	if current_dist > circle_radius * 1.1:
		radial_correction = 1.0
	elif current_dist < circle_radius * 0.9:
		radial_correction = -1.0

	var move_dir: Vector2 = (tangent + to_target_n * radial_correction).normalized()
	body.velocity = move_dir * chase_speed

func exit() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
