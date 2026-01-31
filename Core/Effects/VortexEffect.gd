extends Node2D
class_name VortexEffect

## 漩涡特效 - 在指定位置显示旋转的漩涡效果
## 用于标记敌人聚集的目标点

# ============ 信号 ============
signal vortex_ready()
signal vortex_finished()

# ============ 配置参数 ============
## 漩涡半径
@export var radius: float = 60.0
## 漩涡颜色（更明亮的蓝紫色）
@export var vortex_color: Color = Color(0.4, 0.5, 1.0, 1.0)
## 旋转速度（弧度/秒）
@export var rotation_speed: float = 6.0
## 漩涡线条数量
@export var spiral_count: int = 4
## 线条宽度
@export var line_width: float = 4.0
## 出现动画时间
@export var appear_duration: float = 0.2
## 消失动画时间
@export var disappear_duration: float = 0.3

# ============ 运行时变量 ============
var _current_radius: float = 0.0
var _is_active: bool = false
var _alpha: float = 0.0

# ============ 生命周期 ============
func _ready() -> void:
	z_index = 1  # 在角色上方显示，更容易看到
	

func _process(delta: float) -> void:
	if _is_active:
		rotation += rotation_speed * delta
		queue_redraw()

func _draw() -> void:
	if not _is_active or _current_radius <= 0:
		return

	var color = Color(vortex_color.r, vortex_color.g, vortex_color.b, vortex_color.a * _alpha)

	# 绘制多条螺旋线
	for i in range(spiral_count):
		var start_angle = (TAU / spiral_count) * i
		_draw_spiral(start_angle, color)

	# 绘制中心圆
	var center_color = Color(color.r, color.g, color.b, color.a * 0.5)
	draw_circle(Vector2.ZERO, _current_radius * 0.2, center_color)

	# 绘制外圈
	var outer_color = Color(color.r, color.g, color.b, color.a * 0.3)
	draw_arc(Vector2.ZERO, _current_radius, 0, TAU, 32, outer_color, line_width * 0.5)

## 绘制单条螺旋线
func _draw_spiral(start_angle: float, color: Color) -> void:
	var points: PackedVector2Array = []
	var segments = 20

	for j in range(segments + 1):
		var t = float(j) / float(segments)
		var angle = start_angle + t * TAU * 0.8  # 螺旋角度
		var r = _current_radius * (1.0 - t * 0.7)  # 从外向内收缩
		var point = Vector2(cos(angle), sin(angle)) * r
		points.append(point)

	if points.size() >= 2:
		# 绘制渐变线条
		for k in range(points.size() - 1):
			var t = float(k) / float(points.size() - 1)
			var line_color = Color(color.r, color.g, color.b, color.a * (1.0 - t * 0.5))
			var width = line_width * (1.0 - t * 0.5)
			draw_line(points[k], points[k + 1], line_color, width)

# ============ 公共 API ============
## 显示漩涡效果
func show_vortex() -> void:
	_is_active = true
	_current_radius = 0.0
	_alpha = 0.0

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

	# 半径从0扩展到目标值
	tween.tween_property(self, "_current_radius", radius, appear_duration)
	tween.parallel().tween_property(self, "_alpha", 1.0, appear_duration * 0.5)

	tween.tween_callback(func():
		vortex_ready.emit()
	)

	DebugConfig.debug("漩涡特效显示: %v" % global_position, "", "effect")

## 隐藏漩涡效果
func hide_vortex() -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)

	# 半径收缩到0
	tween.tween_property(self, "_current_radius", 0.0, disappear_duration)
	tween.parallel().tween_property(self, "_alpha", 0.0, disappear_duration)

	tween.tween_callback(func():
		_is_active = false
		vortex_finished.emit()
		queue_free()
	)

	DebugConfig.debug("漩涡特效隐藏", "", "effect")

## 获取漩涡中心位置
func get_vortex_position() -> Vector2:
	return global_position

## 检查漩涡是否激活
func is_active() -> bool:
	return _is_active

# ============ 静态工厂方法 ============
## 在指定位置创建漩涡效果
## @param position: 位置
## @param parent: 父节点
## @return: VortexEffect 实例
static func create_at(spawn_position: Vector2, parent: Node) -> VortexEffect:
	var effect = VortexEffect.new()
	parent.add_child(effect)
	effect.global_position = spawn_position
	effect.show_vortex()
	return effect
