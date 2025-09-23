extends CharacterBody2D
class_name Hahashin

var alive: bool = true
var last_face_direction:Vector2 = Vector2.RIGHT
var input_direction: Vector2 = Vector2.RIGHT

@export_group("Speed")
var max_speed: float = 100

@export_group("Health")
var max_health:float
var health:float


var can_move: bool = true

func _ready() -> void:
	velocity = input_direction* max_speed
	
# 获取用户输入，控制方向
func _process(delta: float) -> void:
	if alive:
		input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

# 控制移动
func _physics_process(delta: float) -> void:
	if alive:
		# 移动状态才有方向
		if velocity:
			last_face_direction = velocity.normalized()
		if can_move:
			move_and_slide()
