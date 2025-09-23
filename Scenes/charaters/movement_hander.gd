extends Node

@onready var player:Hahashin = get_owner()
var acceleration_time = 0.1

@onready var anim_sprite :AnimatedSprite2D = $"../AnimatedSprite2D"

@onready var animation_handler = $"../AnimationHandler"


func _ready():
	pass


func _process(delta: float) -> void:
	if not player.can_move:
		return
	# 技能按键处理，切换到技能是否状态，技能释放完毕后状态变为idle。不直接参与run,walk等状态切换
	for key in animation_handler.skill_config.keys():	
		if Input.is_action_just_pressed(key):
			animation_handler.play_animation(key)
			if key != "roll":
				player.can_move = false

func _physics_process(delta: float) -> void:
	if player and player.alive:
		if player.can_move:
			var velocity = player.velocity
			velocity = velocity.move_toward(
				player.input_direction*player.max_speed, 
				(1.0/acceleration_time) * player.max_speed * delta)
			player.velocity = velocity
		if player.last_face_direction.x < 0:
			anim_sprite.flip_h = true
			%Hitbox.scale.x = -1
		else:
			anim_sprite.flip_h = false
			%Hitbox.scale.x = 1

func on_animation_finished():
	player.can_move = true
	
func set_speed(speed: int):
	player.velocity = player.last_face_direction* speed
	
