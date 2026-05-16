extends AIState

## Cyclops phase-transition reaction — short i-frame window + radial knockback.
## Mirrors the old BossBase.activate_phase_transition_effect():
##   1. 1s invincibility (StatusController HURTABLE lock — the project's i-frame API)
##   2. knockback nearby units via PhysicsShapeQueryParameters2D
##   3. play phase_transition anim if available, else dispatch attack_finished

const KNOCKBACK_RADIUS := 200.0
const KNOCKBACK_FORCE := 500.0
const IFRAME_DURATION := 1.0

func enter() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO

	if agent and agent.status:
		agent.status.apply_lock(LegalAction.HURTABLE, IFRAME_DURATION)

	_knockback_nearby_units()

	if agent and agent.anim and agent.anim.has_action(&"phase_transition"):
		agent.anim.play_action(&"phase_transition")
		agent.anim.action_finished.connect(_on_anim_finished, CONNECT_ONE_SHOT)
	else:
		dispatch.call_deferred(AIEvents.EV_ATTACK_FINISHED)

func _on_anim_finished(_action_id: StringName) -> void:
	dispatch(AIEvents.EV_ATTACK_FINISHED)

func _knockback_nearby_units() -> void:
	if owner_node is not Node2D:
		return
	var body := owner_node as Node2D
	var space_state := body.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = KNOCKBACK_RADIUS
	query.shape = shape
	query.transform = Transform2D(0, body.global_position)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var results := space_state.intersect_shape(query, 32)
	for r in results:
		var collider = r.collider
		if collider == body:
			continue
		var direction: Vector2 = (collider.global_position - body.global_position).normalized()
		var distance: float = body.global_position.distance_to(collider.global_position)
		var strength: float = KNOCKBACK_FORCE * (1.0 - distance / KNOCKBACK_RADIUS)
		if collider.is_in_group(&"player") and collider.has_method(&"apply_knockback"):
			collider.apply_knockback(direction * strength)
		elif collider is CharacterBody2D and "velocity" in collider:
			collider.velocity += direction * strength
