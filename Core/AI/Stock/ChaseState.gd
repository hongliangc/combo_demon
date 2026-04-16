extends AIState

## Stock Chase — 水平追击目标,保留重力,边缘自动停步

@export var default_speed: float = 80.0
@export var stop_distance: float = 4.0

func enter() -> void:
	if "anim_player" in owner_node and owner_node.anim_player:
		if owner_node.anim_player.has_animation(&"walk"):
			owner_node.anim_player.play(&"walk")

func physics_update(_delta: float) -> void:
	if owner_node is not CharacterBody2D:
		return
	var body := owner_node as CharacterBody2D
	var target_pos: Vector2 = bb.get_var(&"target_position", body.global_position) as Vector2
	var speed := float(bb.get_var(&"chase_speed", default_speed))
	var dx: float = target_pos.x - body.global_position.x
	if absf(dx) < stop_distance:
		body.velocity.x = 0.0
		return
	var dir: int = signi(dx)
	if owner_node.has_method(&"can_move_dir") and not owner_node.can_move_dir(dir):
		body.velocity.x = 0.0
		return
	body.velocity.x = float(dir) * speed

func exit() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity.x = 0.0
