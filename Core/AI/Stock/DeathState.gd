extends AIState

## Stock Death — 播放死亡动画，禁用 owner

func enter() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	if "anim_player" in owner_node and owner_node.anim_player:
		if owner_node.anim_player.has_animation(&"death"):
			owner_node.anim_player.play(&"death")
	if owner_node:
		owner_node.set_physics_process(false)
		var col: CollisionShape2D = owner_node.get_node_or_null(^"CollisionShape2D")
		if col:
			col.set_deferred(&"disabled", true)
