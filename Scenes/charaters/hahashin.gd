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
	# 初始化为默认物理伤害
	if damage_types.size() > 0:
		current_damage = damage_types[0]
	
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

## 调试打印玩家状态信息
func debug_print() -> void:
	print("========== Player 状态信息 ==========")
	print("存活状态: ", alive)
	print("生命值: ", health, "/", max_health)
	print("可移动: ", can_move)
	print("速度: ", velocity, " (最大速度: ", max_speed, ")")
	print("面对方向: ", last_face_direction)
	print("输入方向: ", input_direction)
	if current_damage:
		current_damage.debug_print()
	else:
		print("当前伤害: null")
	print("====================================")
