extends Node2D

@onready var anime_sprite2d: AnimatedSprite2D = $AnimatedSprite2D


func start():
	var t1 = Time.get_ticks_msec()
	anime_sprite2d.play("attack1")
	await anime_sprite2d.animation_finished
	queue_free()
	var t2 = Time.get_ticks_msec()
	#print("slash attack global_postions:{0}, elapse time:{1}, rotation:{2}".format([global_position, t2-t1, rotation]))
