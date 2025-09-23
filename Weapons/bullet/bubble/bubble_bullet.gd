extends BaseBullet

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var splash_particles_scenc : PackedScene = preload("res://Weapons/bullet/bubble/bubble_bullet_splash.tscn")

@export var rotation_speed := 10.0        # 每秒绕圈旋转速度（弧度）
@export var radius := 20.0               # 旋转半径
var move_direction := Vector2.RIGHT  # 子弹飞行方向

func _physics_process(delta: float) -> void:
	# 更新旋转角度
	direction = direction.rotated(rotation_speed * delta)
	
	# 整体沿方向平移
	var offset = 100*move_direction.normalized()  * delta
	global_position += offset
	super._physics_process(delta)


func _before_lifespan_expired():
	anim_player.play_backwards("spawn")
	await anim_player.animation_finished


func _on_tree_exiting() -> void:
	print("bubble bullet _on_tree_exiting")
	var splash_particles:GPUParticles2D = splash_particles_scenc.instantiate()
	splash_particles.global_position = global_position
	splash_particles.rotation = rotation
	splash_particles.emitting = true
	get_tree().root.call_deferred("add_child", splash_particles)
