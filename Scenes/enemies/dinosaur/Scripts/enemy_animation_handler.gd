extends Node

###################################################
# This controls all animations for the enemy.
# You totally could use an AnimationTree for this,
# but this is an example of how you could control
# it through code.
###################################################

@export var anim_player :AnimationPlayer
@export var sprite : Sprite2D

@onready var enemy: Enemy = get_owner()

var player: Hahashin

func _ready() -> void:
	player = get_tree().get_first_node_in_group("Player")

func _physics_process(delta: float) -> void:
	if !enemy.alive:
		return
	if !enemy.velocity and !enemy.stunned:
		anim_player.play("idle")
		return
	if enemy.stunned:
		anim_player.play("stunned")
		return

	sprite.flip_h = enemy.velocity.x < 0
	
	var animation_name = "right_"
	if sprite.flip_h:
		animation_name = "left_"
	
	if enemy.velocity.length() > 50:
		animation_name += "run"
	else:
		animation_name += "walk"
	
	anim_player.play(animation_name)
