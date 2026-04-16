extends AIState

## Stock Idle — 停止移动，播放 idle 动画

func enter() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	if "anim_player" in owner_node and owner_node.anim_player:
		if owner_node.anim_player.has_animation(&"idle"):
			owner_node.anim_player.play(&"idle")
