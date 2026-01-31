extends Node2D
class_name BossLaser

## Boss 激光攻击 - 扫射型激光

@export var charge_time := 2.5       # 蓄力时间
@export var fire_duration := 1.5     # 发射持续时间
@export var rotation_speed := 1.0    # 旋转速度（弧度/秒）
@export var laser_length := 500.0    # 激光长度
@export var damage_config: Damage    # 伤害配置

var state := "charging"  # charging, firing, done
var timer := 0.0

@onready var laser_line: Line2D = $LaserLine
@onready var hitbox_area: Area2D = $HitboxArea
@onready var collision_shape: CollisionShape2D = $HitboxArea/CollisionShape2D

# 已经伤害过的目标（避免重复伤害）
var damaged_targets: Array = []

func _ready() -> void:
	# 初始化激光视觉
	if laser_line:
		laser_line.width = 100
		laser_line.default_color = Color(1, 0, 0, 0.5)
		laser_line.clear_points()
		laser_line.add_point(Vector2.ZERO)
		laser_line.add_point(Vector2.RIGHT * laser_length)

	# 初始化碰撞形状（矩形）
	if collision_shape:
		var rect = RectangleShape2D.new()
		rect.size = Vector2(laser_length, 20)
		collision_shape.shape = rect
		collision_shape.position = Vector2(laser_length / 2, 0)

	# 连接区域信号
	if hitbox_area:
		hitbox_area.area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	match state:
		"charging":
			_process_charging(delta)
		"firing":
			_process_firing(delta)
		"done":
			queue_free()

func _process_charging(delta: float) -> void:
	timer += delta

	# 蓄力阶段：激光闪烁
	if laser_line:
		var alpha = abs(sin(timer * 10.0)) * 0.5 + 0.3
		laser_line.default_color = Color(1, 0, 0, alpha)

	if timer >= charge_time:
		state = "firing"
		timer = 0.0
		damaged_targets.clear()

		# 发射阶段：激光变为实体
		if laser_line:
			laser_line.default_color = Color(1, 0, 0, 0.8)

func _process_firing(delta: float) -> void:
	timer += delta

	# 旋转激光
	rotate(rotation_speed * delta)

	# 更新激光线
	if laser_line:
		laser_line.set_point_position(1, Vector2.RIGHT * laser_length)

	if timer >= fire_duration:
		state = "done"

func _on_area_entered(area: Area2D) -> void:
	# 只在发射阶段造成伤害
	if state != "firing":
		return

	# 检测 Hurtbox
	if area is Hurtbox and area not in damaged_targets:
		damaged_targets.append(area)

		# 造成伤害
		if damage_config:
			var damage_copy = damage_config.duplicate(true)
			damage_copy.randomize_damage()
			area.take_damage(damage_copy)
		else:
			# 默认伤害
			var default_damage = Damage.new()
			default_damage.min_amount = 20
			default_damage.max_amount = 30
			default_damage.randomize_damage()
			area.take_damage(default_damage)
