extends AIState

## Stock Idle — stops movement. AnimationDriver auto-locomotion handles idle animation.

func enter() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
