extends BossBase
class_name Boss

## Boss 具体实现 - 继承 BossBase
## 实现8方位移动、纹理选择、巡逻点设置、旋转逻辑
##
## 架构:
##   BaseCharacter → BossBase → Boss
##   - BaseCharacter: 生命系统、伤害信号
##   - BossBase: 阶段系统、检测参数、冷却管理、死亡逻辑
##   - Boss: 8方位移动、巡逻路径、纹理选择、旋转逻辑

# ============ 配置参数 ============
@export_group("Textures")
@export var textures: Array[Texture2D] = []

@export_group("Movement")
@export var base_move_speed := 150.0  # 基础移动速度
@export var rotation_speed := 5.0

# 阶段速度倍率
const PHASE_1_SPEED_MULT = 1.0    # 正常速度
const PHASE_2_SPEED_MULT = 1.3    # 1.3倍速度
const PHASE_3_SPEED_MULT = 1.5    # 1.5倍速度

# 当前有效移动速度（根据阶段动态计算）
var move_speed: float:
	get:
		match current_phase:
			Phase.PHASE_1:
				return base_move_speed * PHASE_1_SPEED_MULT
			Phase.PHASE_2:
				return base_move_speed * PHASE_2_SPEED_MULT
			Phase.PHASE_3:
				return base_move_speed * PHASE_3_SPEED_MULT
			_:
				return base_move_speed

# ============ 8方位方向常量 ============
# 预计算的归一化向量（避免运行时计算）
const SQRT2_INV = 0.7071067811865476  # 1 / sqrt(2)
const DIRECTIONS_8 = [
	Vector2(1, 0),                    # 0: 右
	Vector2(SQRT2_INV, -SQRT2_INV),   # 1: 右上
	Vector2(0, -1),                   # 2: 上
	Vector2(-SQRT2_INV, -SQRT2_INV),  # 3: 左上
	Vector2(-1, 0),                   # 4: 左
	Vector2(-SQRT2_INV, SQRT2_INV),   # 5: 左下
	Vector2(0, 1),                    # 6: 下
	Vector2(SQRT2_INV, SQRT2_INV)     # 7: 右下
]

# ============ 运行时变量 ============
var circle_direction := 1  # 1=顺时针, -1=逆时针

# ============ 节点引用 ============
@onready var sprite: Sprite2D = $Sprite2D

# ============ Boss 特定初始化 ============
func _on_boss_ready() -> void:
	# 随机选择纹理
	if not textures.is_empty():
		sprite.texture = textures.pick_random()

	# 设置巡逻点
	setup_patrol_points()

# ============ 巡逻点设置 ============
func setup_patrol_points() -> void:
	# 从场景中查找巡逻标记点
	var patrol_markers = get_tree().get_nodes_in_group("boss_patrol_points")
	for marker in patrol_markers:
		if marker is Marker2D:
			patrol_points.append(marker.global_position)

	# 如果没有设置，创建默认的矩形巡逻路径
	if patrol_points.is_empty():
		var center = global_position
		for i in range(4):
			var angle = i * PI / 2
			patrol_points.append(center + Vector2(cos(angle), sin(angle)) * 200)

# ============ 8方位朝向更新 ============
func _update_facing() -> void:
	if velocity.length() < 10:
		return

	var direction = velocity.normalized()
	var angle = direction.angle()

	# 转换为8方位索引
	var direction_index = int(round(angle / (PI / 4))) % 8
	if direction_index < 0:
		direction_index += 8

	# 平滑旋转到目标方向
	if sprite:
		var target_rotation = DIRECTIONS_8[direction_index].angle()
		sprite.rotation = lerp_angle(sprite.rotation, target_rotation, rotation_speed * get_physics_process_delta_time())

# ============ 调试绘制 ============
func _draw() -> void:
	if Engine.is_editor_hint() or OS.is_debug_build():
		# 绘制检测范围
		draw_circle(Vector2.ZERO, detection_radius, Color(1, 1, 0, 0.1))
		draw_circle(Vector2.ZERO, attack_range, Color(1, 0, 0, 0.1))
		draw_circle(Vector2.ZERO, min_distance, Color(0, 1, 0, 0.1))
