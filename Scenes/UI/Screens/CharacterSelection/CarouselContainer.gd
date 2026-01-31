## 轮播容器组件
## 用于创建水平滚动的轮播效果，支持线性排列和环绕（圆弧）两种布局模式
## 选中项会放大并完全不透明，非选中项会缩小并变透明
##
## 架构说明：
## - CarouselContainer (Node2D): 主容器，使用 position 定位
## - position_offset_node (Control): 卡片容器，子节点使用 position 定位
##   - 环绕模式：position.x 固定为 0
##   - 线性模式：position.x 用于平移使选中项居中
@tool
extends Node2D
class_name CarouselContainer

# ==================== 布局设置 ====================

## 线性模式下子项之间的水平间距（像素）
@export var spacing: float = 20.0

## 是否启用环绕模式（子项沿圆弧排列）
@export var wraparound_enabled: bool = false

## 环绕模式的圆弧半径
@export var wraparound_radius: float = 300.0

## 环绕模式的垂直偏移高度
@export var wraparound_height: float = 50.0

## 角度分布模式：true=均匀分布（间隔一致），false=动态分布（根据卡片数量自适应）
@export var uniform_angle_distribution: bool = false

## 均匀分布时的角度间隔（度数）
@export_range(30.0, 120.0, 5.0) var uniform_angle_spacing: float = 60.0

# ==================== 视觉效果设置 ====================

## 透明度衰减强度：距离选中项每增加1个索引，透明度降低的比例
@export_range(0.0, 1.0) var opacity_strength: float = 0.35

## 缩放衰减强度：距离选中项每增加1个索引，缩放降低的比例
@export_range(0.0, 1.0) var scale_strength: float = 0.25

## 最小缩放比例，防止子项缩放过小
@export_range(0.01, 0.99, 0.01) var scale_min: float = 0.1

# ==================== 动画与交互设置 ====================

## 动画平滑速度（lerp插值系数）
@export var smoothing_speed: float = 6.5

## 当前选中的子项索引
@export var selected_index: int = 0

## 是否跟随按钮焦点自动切换选中项
@export var follow_button_focus: bool = false

## 包含所有轮播子项的容器节点
@export var position_offset_node: Control = null

# ==================== 调试设置 ====================

## 是否显示调试线条
@export var show_debug_lines: bool = false

## 是否显示 Godot 标准坐标系标注
@export var show_godot_coordinate: bool = false

# ==================== 缓存变量 ====================

var _child_count: int = 0
var _max_index_range: float = 1.0
var _lerp_factor: float = 0.0
var _debug_printed: bool = false


func _process(delta: float) -> void:
	# 调试输出（只打印一次）
	if not _debug_printed:
		_debug_printed = true
		print("[CarouselContainer] position_offset_node: ", position_offset_node)
		if position_offset_node:
			print("[CarouselContainer] child_count: ", position_offset_node.get_child_count())

	# 检查容器节点有效性
	if not position_offset_node:
		return

	_child_count = position_offset_node.get_child_count()
	if _child_count == 0:
		return

	# 缓存常用计算值，避免每帧重复计算
	_lerp_factor = smoothing_speed * delta
	selected_index = clampi(selected_index, 0, _child_count - 1)

	# 环绕模式下预计算最大索引范围
	if wraparound_enabled:
		_max_index_range = maxf(1.0, (_child_count - 1) / 2.0)

	# 遍历所有子项并更新其状态
	var children := position_offset_node.get_children()
	var prev_child: Control = null

	for child in children:
		if not child is Control:
			continue

		var ctrl := child as Control
		var child_index := ctrl.get_index()
		var distance_from_selected := child_index - selected_index
		var abs_distance := absf(distance_from_selected)

		# 更新位置
		_update_child_position(ctrl, child_index, distance_from_selected, prev_child)

		# 更新缩放和透明度
		_update_child_visual(ctrl, abs_distance)

		# 更新交互状态（z_index、鼠标过滤、焦点模式）
		_update_child_interaction(ctrl, child_index, abs_distance)

		# 检查焦点跟随
		if follow_button_focus and ctrl.has_focus():
			selected_index = child_index

		prev_child = ctrl

	# 更新容器整体位置，使选中项居中
	_update_container_position()

	# 触发重绘以显示调试线条
	if show_debug_lines:
		queue_redraw()


## 更新子项位置
func _update_child_position(child: Control, _index: int, distance: int, prev_child: Control) -> void:
	child.pivot_offset = child.size / 2.0

	if wraparound_enabled:
		# 环绕模式：沿圆弧排列
		var angle: float

		if uniform_angle_distribution:
			# 均匀分布模式：每个卡片固定角度间隔
			angle = deg_to_rad(distance * uniform_angle_spacing)
		else:
			# 动态分布模式：根据卡片数量自适应
			var normalized_distance := clampf(distance / _max_index_range, -1.0, 1.0)
			angle = normalized_distance * PI

		var target_pos := Vector2(
			sin(angle) * wraparound_radius,
			cos(angle) * wraparound_radius - wraparound_height
		) - child.size / 2.0
		child.position = child.position.lerp(target_pos, _lerp_factor)
	else:
		# 线性模式：水平排列
		var position_x := 0.0
		if prev_child:
			position_x = prev_child.position.x + prev_child.size.x + spacing
		child.position = Vector2(position_x, -child.size.y / 2.0)


## 更新子项视觉效果（缩放和透明度）
func _update_child_visual(child: Control, abs_distance: float) -> void:
	# 计算目标缩放
	var target_scale := clampf(1.0 - scale_strength * abs_distance, scale_min, 1.0)
	child.scale = child.scale.lerp(Vector2.ONE * target_scale, _lerp_factor)

	# 计算目标透明度
	var target_opacity := clampf(1.0 - opacity_strength * abs_distance, 0.0, 1.0)
	child.modulate.a = lerpf(child.modulate.a, target_opacity, _lerp_factor)


## 更新子项交互状态
func _update_child_interaction(child: Control, index: int, abs_distance: float) -> void:
	var is_selected := index == selected_index

	if is_selected:
		# 选中项：置于顶层，可接收鼠标和焦点
		child.z_index = 100
		child.mouse_filter = Control.MOUSE_FILTER_STOP
		child.focus_mode = Control.FOCUS_ALL
	else:
		# 非选中项：根据距离设置层级（使用正数，确保在背景之上）
		child.z_index = 100 - int(abs_distance)
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		child.focus_mode = Control.FOCUS_NONE


## 更新容器位置使选中项居中
func _update_container_position() -> void:
	if wraparound_enabled:
		# 环绕模式：容器保持居中
		position_offset_node.position.x = lerpf(
			position_offset_node.position.x,
			0.0,
			_lerp_factor
		)
	else:
		# 线性模式：移动容器使选中项居中
		var selected_child := position_offset_node.get_child(selected_index) as Control
		if selected_child:
			var target_x := -(selected_child.position.x + selected_child.size.x / 2.0)
			position_offset_node.position.x = lerpf(
				position_offset_node.position.x,
				target_x,
				_lerp_factor
			)


## 切换到上一项
func select_previous() -> void:
	if selected_index > 0:
		selected_index -= 1


## 切换到下一项
func select_next() -> void:
	if position_offset_node and selected_index < position_offset_node.get_child_count() - 1:
		selected_index += 1


## 直接跳转到指定索引
func select_index(index: int) -> void:
	if position_offset_node:
		selected_index = clampi(index, 0, position_offset_node.get_child_count() - 1)


## 获取当前选中项
func get_selected_child() -> Control:
	if position_offset_node and _child_count > 0:
		return position_offset_node.get_child(selected_index) as Control
	return null


# 保留旧方法名以保持向后兼容
func _left() -> void:
	select_previous()


func _right() -> void:
	select_next()


## 绘制调试线条
func _draw() -> void:
	if not show_debug_lines or not position_offset_node:
		return

	var children := position_offset_node.get_children()
	if children.is_empty():
		return

	# 旋转中心（CarouselContainer 的原点）
	var rotation_center := Vector2.ZERO

	# 字体设置（供所有绘制使用）
	var font := ThemeDB.fallback_font
	var font_size := 14

	# 收集所有卡片的中心位置（转换到 CarouselContainer 坐标系）
	var card_centers: Array[Vector2] = []

	for child in children:
		if not child is Control:
			continue

		var ctrl := child as Control
		# 计算卡片中心在 position_offset_node 中的位置
		var center_in_container := ctrl.position + ctrl.size / 2.0
		# 转换到 CarouselContainer 坐标系
		var center_in_carousel := position_offset_node.position + center_in_container
		card_centers.append(center_in_carousel)

	# 1. 绘制旋转半径圆圈（红色）
	if wraparound_enabled:
		draw_arc(rotation_center, wraparound_radius, 0, TAU, 64, Color.RED, 2.0)
		# 绘制中心点标记
		draw_circle(rotation_center, 5.0, Color.RED)

	# 2. 绘制从旋转中心到每个卡片中心的连线（红色）
	for center in card_centers:
		draw_line(rotation_center, center, Color.RED, 2.0)

	# 3. 绘制每个卡片中心之间的连线（红色）
	for i in range(card_centers.size() - 1):
		draw_line(card_centers[i], card_centers[i + 1], Color.RED, 2.0)

	# 4. 标注每个卡片的角度
	if wraparound_enabled:
		# 显示当前角度分布模式
		var mode_text := "均匀分布 (%.0f°)" % uniform_angle_spacing if uniform_angle_distribution else "动态分布"
		draw_string(font, rotation_center + Vector2(-80, -180),
					"角度模式: " + mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.CYAN)

		for i in range(children.size()):
			var child := children[i]
			if not child is Control:
				continue

			# 计算与选中项的距离和角度（与 _update_child_position 中的逻辑一致）
			var child_index := child.get_index()
			var distance_from_selected := child_index - selected_index
			var angle: float

			if uniform_angle_distribution:
				# 均匀分布模式
				angle = deg_to_rad(distance_from_selected * uniform_angle_spacing)
			else:
				# 动态分布模式
				var normalized_distance := clampf(distance_from_selected / _max_index_range, -1.0, 1.0)
				angle = normalized_distance * PI

			# 转换角度为度数
			var angle_degrees := rad_to_deg(angle)

			# 在卡片中心附近绘制角度文本
			var text := "%.1f°" % angle_degrees
			var text_pos := card_centers[i] + Vector2(10, -10)
			draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.RED)

	# 5. 绘制标准 Godot 坐标系（最上层，可选）
	if show_godot_coordinate:
		var axis_length := wraparound_radius + 50.0

		# X 轴（绿色，指向右侧）
		draw_line(rotation_center, rotation_center + Vector2(axis_length, 0), Color.GREEN, 3.0)
		draw_circle(rotation_center + Vector2(axis_length, 0), 6.0, Color.GREEN)
		draw_string(font, rotation_center + Vector2(axis_length + 10, 5),
					"X+ (右)", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.GREEN)

		# Y 轴（蓝色，指向下侧）
		draw_line(rotation_center, rotation_center + Vector2(0, axis_length), Color.BLUE, 3.0)
		draw_circle(rotation_center + Vector2(0, axis_length), 6.0, Color.BLUE)
		draw_string(font, rotation_center + Vector2(10, axis_length + 15),
					"Y+ (下)", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLUE)

		# 标注标准 Godot 角度系统的四个主要方向
		if wraparound_enabled:
			var marker_radius := wraparound_radius + 30.0

			# 0° = 正右方 (标准 Godot 角度)
			var pos_0 := Vector2(marker_radius, 0)
			draw_circle(pos_0, 10.0, Color.YELLOW)
			draw_string(font, pos_0 + Vector2(15, 5),
						"Godot 0°", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.YELLOW)

			# 90° = 正下方 (标准 Godot 角度)
			var pos_90 := Vector2(0, marker_radius)
			draw_circle(pos_90, 10.0, Color.ORANGE)
			draw_string(font, pos_90 + Vector2(15, 5),
						"Godot 90°", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.ORANGE)

			# 180° = 正左方 (标准 Godot 角度)
			var pos_180 := Vector2(-marker_radius, 0)
			draw_circle(pos_180, 10.0, Color.CYAN)
			draw_string(font, pos_180 + Vector2(-110, 5),
						"Godot 180°", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.CYAN)

			# -90° (270°) = 正上方 (标准 Godot 角度)
			var pos_neg90 := Vector2(0, -marker_radius)
			draw_circle(pos_neg90, 10.0, Color.MAGENTA)
			draw_string(font, pos_neg90 + Vector2(15, -10),
						"Godot -90°", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.MAGENTA)

		# 原点标记（白色，最上层）
		draw_circle(rotation_center, 8.0, Color.WHITE)
		draw_string(font, rotation_center + Vector2(15, -15),
					"原点 (0, 0)", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
