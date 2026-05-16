extends Node2D
class_name BossAOE

## Boss AOE 范围攻击 - 扩散型冲击波

@export var expand_time := 0.8        # 扩散时间
@export var hold_time := 0.5          # 保持时间
@export var max_radius := 200.0       # 最大半径
@export var damage_min: float = 30.0  # 内联最小伤害
@export var damage_max: float = 50.0  # 内联最大伤害

const SPRITE_BASE_SIZE := 50.0

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

	# 初始化视觉（如果有）— 生成32点圆形多边形替换粗糙六边形
	if visual_circle:
		var points: PackedVector2Array = []
		var segments := 32
		for i in range(segments):
			var angle := i * TAU / segments
			points.append(Vector2(cos(angle), sin(angle)) * SPRITE_BASE_SIZE)
		visual_circle.polygon = points
		visual_circle.color = Color(1, 0.2, 0.1, 0.35)
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
		var target_scale = Vector2.ONE * (max_radius / SPRITE_BASE_SIZE)
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

func _on_area_entered(entered_area: Area2D) -> void:
	# 检测 HurtBoxComponent
	if entered_area is HurtBoxComponent and entered_area not in damaged_targets:
		damaged_targets.append(entered_area)

		# 内联伤害（不再使用 Damage Resource @export）
		var damage := Damage.new()
		damage.min_amount = damage_min
		damage.max_amount = damage_max
		damage.randomize_damage()
		entered_area.take_damage(damage)
