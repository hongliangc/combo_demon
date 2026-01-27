extends Node2D
class_name GatherTrailEffect

## 聚集轨迹线效果 - 敌人被聚集时显示能量线轨迹
## 使用 Line2D 绘制从敌人到玩家的动态轨迹

# ============ 配置参数 ============
## 轨迹线宽度
@export var line_width: float = 4.0
## 起点颜色（敌人端）
@export var start_color: Color = Color(1.0, 0.3, 0.3, 0.8)  # 红色
## 终点颜色（玩家端）
@export var end_color: Color = Color(0.3, 0.8, 1.0, 0.8)  # 蓝色
## 轨迹点数量（越多越平滑）
@export var point_count: int = 20
## 渐隐持续时间
@export var fade_duration: float = 0.3
## 曲线弧度（0 = 直线，正值 = 向上弯曲）
@export var curve_strength: float = 30.0

# ============ 节点引用 ============
var _line: Line2D = null
var _start_pos: Vector2 = Vector2.ZERO
var _end_pos: Vector2 = Vector2.ZERO
var _target: Node2D = null
var _is_following: bool = false

# ============ 生命周期 ============
func _ready() -> void:
	_setup_line()

func _process(_delta: float) -> void:
	if _is_following and is_instance_valid(_target):
		_start_pos = _target.global_position
		_update_line_points()

# ============ 初始化 ============
func _setup_line() -> void:
	_line = Line2D.new()
	_line.width = line_width
	_line.default_color = start_color
	_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_line.antialiased = true

	# 设置渐变
	var gradient = Gradient.new()
	gradient.set_color(0, start_color)
	gradient.set_color(1, end_color)
	_line.gradient = gradient

	add_child(_line)

# ============ 公共 API ============
## 创建从目标到终点的轨迹线
## @param target: 起点目标（敌人）
## @param destination: 终点位置（玩家位置）
## @param follow_target: 是否跟随目标移动
func create_trail(target: Node2D, destination: Vector2, follow_target: bool = true) -> void:
	_target = target
	_start_pos = target.global_position
	_end_pos = destination
	_is_following = follow_target

	_update_line_points()

	DebugConfig.debug("创建聚集轨迹线: %v -> %v" % [_start_pos, _end_pos], "", "effect")

## 更新终点位置
func update_destination(destination: Vector2) -> void:
	_end_pos = destination
	_update_line_points()

## 开始渐隐并自动删除
func fade_out() -> void:
	_is_following = false

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)

	# 渐隐线条
	tween.tween_property(_line, "modulate:a", 0.0, fade_duration)

	# 完成后删除
	tween.tween_callback(queue_free)

## 立即删除
func remove() -> void:
	queue_free()

# ============ 内部方法 ============
## 更新线条点位置（生成曲线）
func _update_line_points() -> void:
	_line.clear_points()

	# 使用全局坐标，但转换为相对于父节点的本地坐标
	var parent = get_parent()
	var local_start = _start_pos
	var local_end = _end_pos

	if parent and parent is Node2D:
		local_start = (parent as Node2D).to_local(_start_pos)
		local_end = (parent as Node2D).to_local(_end_pos)

	# 计算曲线控制点（贝塞尔曲线）
	var mid_point = (local_start + local_end) / 2
	var direction = (local_end - local_start).normalized()
	var perpendicular = Vector2(-direction.y, direction.x)  # 垂直方向

	# 控制点向上偏移
	var control_point = mid_point + perpendicular * curve_strength

	# 生成贝塞尔曲线点
	for i in range(point_count + 1):
		var t = float(i) / float(point_count)
		var point = _quadratic_bezier(local_start, control_point, local_end, t)
		_line.add_point(point)

## 二次贝塞尔曲线计算
func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var q0 = p0.lerp(p1, t)
	var q1 = p1.lerp(p2, t)
	return q0.lerp(q1, t)

# ============ 静态工厂方法 ============
## 创建轨迹线效果
## @param target: 起点目标（敌人）
## @param destination: 终点位置
## @param parent: 父节点（通常是场景根节点）
## @return: GatherTrailEffect 实例
static func create(target: Node2D, destination: Vector2, parent: Node = null) -> GatherTrailEffect:
	var effect = GatherTrailEffect.new()

	if parent:
		parent.add_child(effect)
	elif target.get_parent():
		target.get_parent().add_child(effect)

	effect.create_trail(target, destination, true)
	return effect
