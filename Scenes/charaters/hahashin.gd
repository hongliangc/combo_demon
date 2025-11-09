extends CharacterBody2D
class_name Hahashin

var alive: bool = true
var last_face_direction:Vector2 = Vector2.RIGHT
var input_direction: Vector2 = Vector2.RIGHT

@export_group("Speed")
@export var max_speed: float = 100

@export_group("Health")
@export var max_health:float
@export var health:float

@export_group("Damage")
@export var damage_types : Array[Damage]
@export var current_damage: Damage


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

func switch_to_physical() -> void:
	current_damage = damage_types[0]
	
func switch_to_knockup() -> void:
	current_damage = damage_types[1]
	
