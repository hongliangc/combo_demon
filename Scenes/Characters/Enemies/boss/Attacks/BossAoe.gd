extends Node2D
class_name BossAOE

## Boss AOE 范围攻击 - 扩散型冲击波

@export var expand_time := 0.8        # 扩散时间
@export var hold_time := 0.5          # 保持时间
@export var max_radius := 200.0       # 最大半径
@export var damage_config: Damage     # 伤害配置

var current_radius := 0.0
var damaged_targets: Array = []

@onready var area: Area2D = $Area2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var visual_circle: Polygon2D = $VisualCircle  # 可选的视觉圆形

func _ready() -> void:
	# 初始化碰撞形状
	var shape = CircleShape2D.new()
	shape.radius = 0
	collision_shape.shape = shape

	# 初始化视觉（如果有）
	if visual_circle:
		visual_circle.modulate = Color(1, 0, 0, 0.3)
		visual_circle.scale = Vector2.ZERO

	# 连接信号
	area.area_entered.connect(_on_area_entered)

	# 开始扩散动画
	start_expansion()

func start_expansion() -> void:
	# 使用 Tween 进行扩散动画
	var tween = create_tween()
	tween.set_parallel(true)

	# 扩散半径
	tween.tween_property(self, "current_radius", max_radius, expand_time)

	# 视觉扩散（如果有）
	if visual_circle:
		var target_scale = Vector2.ONE * (max_radius / 50.0)  # 假设原始大小为100x100
		tween.tween_property(visual_circle, "scale", target_scale, expand_time)
		tween.tween_property(visual_circle, "modulate:a", 0.6, expand_time)

	await tween.finished

	# 保持一段时间
	await get_tree().create_timer(hold_time).timeout

	# 消失动画
	var fade_tween = create_tween()
	if visual_circle:
		fade_tween.tween_property(visual_circle, "modulate:a", 0.0, 0.2)
	await fade_tween.finished

	queue_free()

func _exit_tree() -> void:
	# 显式释放动态创建的 CircleShape2D，防止物理形状 RID 泄漏
	if collision_shape:
		collision_shape.shape = null

func _process(_delta: float) -> void:
	# 更新碰撞半径
	var shape = collision_shape.shape as CircleShape2D
	if shape:
		shape.radius = current_radius

func _on_area_entered(area: Area2D) -> void:
	# 检测 HurtBoxComponent
	if area is HurtBoxComponent and area not in damaged_targets:
		damaged_targets.append(area)

		# 造成伤害
		if damage_config:
			var damage_copy = damage_config.duplicate(true)
			damage_copy.randomize_damage()
			area.take_damage(damage_copy)
		else:
			# 默认伤害
			var default_damage = Damage.new()
			default_damage.min_amount = 30
			default_damage.max_amount = 50
			default_damage.randomize_damage()
			area.take_damage(default_damage)
