extends Node2D

@onready var anime_sprite2d: AnimatedSprite2D = $AnimatedSprite2D


func start():
	anime_sprite2d.play("attack1")
	await anime_sprite2d.animation_finished
	queue_free()
