extends AIState

## DS2 Counter — Poise 破防后的反击动作

func enter() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	if "anim_player" in owner_node and owner_node.anim_player:
		owner_node.anim_player.animation_finished.connect(_on_anim_finished, CONNECT_ONE_SHOT)
		owner_node.anim_player.play(&"hit")

func _on_anim_finished(_name: StringName) -> void:
	dispatch(AIEvents.EV_REACTION_DONE)

func exit() -> void:
	if "anim_player" in owner_node and owner_node.anim_player:
		if owner_node.anim_player.animation_finished.is_connected(_on_anim_finished):
			owner_node.anim_player.animation_finished.disconnect(_on_anim_finished)
