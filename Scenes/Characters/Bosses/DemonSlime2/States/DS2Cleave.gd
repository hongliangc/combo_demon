extends AIState

## DS2 Cleave — 扇形冲击波攻击

@export var cleave_cooldown: float = 2.5

func enter() -> void:
	bb.set_var(&"attack_cooldown", cleave_cooldown)
	bb.set_var(&"global_cooldown", 0.3)
	bb.set_var(&"last_action", &"cleave")
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	if "anim_player" in owner_node and owner_node.anim_player:
		owner_node.anim_player.animation_finished.connect(_on_anim_finished, CONNECT_ONE_SHOT)
		owner_node.anim_player.play(&"cleave")

func _on_anim_finished(_name: StringName) -> void:
	dispatch(AIEvents.EV_ATTACK_FINISHED)

func exit() -> void:
	if "anim_player" in owner_node and owner_node.anim_player:
		if owner_node.anim_player.animation_finished.is_connected(_on_anim_finished):
			owner_node.anim_player.animation_finished.disconnect(_on_anim_finished)
