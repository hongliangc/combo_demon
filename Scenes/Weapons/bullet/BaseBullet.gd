extends CharacterBody2D
class_name BaseBullet

@export var initial_speed: float = 100.0
@export var target_speed: float = 240.0
@export var acceleration: float = 4.0
@export var lifespan: float = 1.0

var speed = initial_speed
var direction = Vector2.RIGHT


func _ready() -> void:
	reset()

func _physics_process(delta: float) -> void:
	# 均匀插值加速
	speed = lerp(speed, target_speed, acceleration * delta)
	velocity = speed * direction * delta
	#print("velocity:{0}, speed: {1} , direction: {2}, delta: {3}".format([velocity, speed, direction, delta]))
	var collision = move_and_collide(velocity)
	if collision:
		queue_free()

	

func _before_lifespan_expired():
	pass

func reset() ->void:
	speed = initial_speed
	direction = Vector2.RIGHT.rotated(rotation)
	#var t1 = Time.get_ticks_msec()
	await get_tree().create_timer(lifespan).timeout
	#var t2 = Time.get_ticks_msec()
	#print("create_timer wait time:%d" % [t2 -t1])
	await _before_lifespan_expired()
	#var t3 = Time.get_ticks_msec()
	#print("_before_lifespan_expired wait time:%d" % [t3 -t2])
	queue_free()
	#print("basebullet ready!")
