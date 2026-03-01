extends Node
class_name MovementComponent

## 自治移动组件 - 参考 BaseState 设计模式
## 自动处理输入、移动、加速度、精灵翻转
## 子类可重载 get_input(), process_movement() 等方法实现自定义逻辑

# ============ 信号 ============
## 移动方向改变时发出
signal direction_changed(new_direction: Vector2)
## 移动能力改变时发出（被眩晕、击飞等）
signal movement_ability_changed(can_move: bool)
## 速度改变时发出
signal velocity_changed(velocity: Vector2)
## 精灵翻转时发出
signal sprite_flipped(flip_h: bool)
## 跳跃开始
signal jump_started()
## 跳跃到达顶点（开始下落）
signal jump_apex_reached()
## 落地
signal landed()

# ============ 配置参数 ============
@export_group("Movement")
@export var max_speed: float = 100.0
@export var acceleration_time: float = 0.1

@export_group("Jump")
## 跳跃力度（向上的初速度）
@export var jump_force: float = -400.0
## 是否启用跳跃功能
@export var enable_jump: bool = true

@export_group("Input")
## 输入映射名称
@export var input_left: String = "move_left"
@export var input_right: String = "move_right"
@export var input_up: String = "move_up"
@export var input_down: String = "move_down"
@export var input_jump: String = "jump"

@export_group("Sprite Flip")
## 是否自动翻转精灵（如果提供了 sprite_node）
@export var auto_flip_sprite: bool = true
## 精灵节点路径（相对于 owner）
@export var sprite_node_path: NodePath = ^"AnimatedSprite2D"
## Hitbox节点路径（相对于 owner，用于翻转攻击判定）
@export var hitbox_node_path: NodePath = ^"%HitBoxComponent"

# ============ 运行时变量 ============
## 是否可以移动（受击飞、眩晕等影响）
var can_move: bool = true:
	set(value):
		if can_move != value:
			can_move = value
			movement_ability_changed.emit(can_move)

## 当前输入方向
var input_direction: Vector2 = Vector2.ZERO

## 上一次面朝方向（用于动画、攻击方向）
var last_face_direction: Vector2 = Vector2.RIGHT

## 跳跃状态
var is_jumping: bool = false
var is_falling: bool = false
var was_on_floor: bool = false

# ============ 节点引用（由组件自动获取）============
var owner_body: CharacterBody2D = null
var sprite_node: Node2D = null
var hitbox_node: Node2D = null

# ============ 生命周期 ============
func _ready() -> void:
	# 依赖注入：自动获取 owner 节点
	owner_body = get_parent() as CharacterBody2D
	if not owner_body:
		push_error("MovementComponent: owner 必须是 CharacterBody2D")
		return

	# 获取精灵节点
	if auto_flip_sprite and sprite_node_path:
		sprite_node = owner_body.get_node_or_null(sprite_node_path)

	# 获取 HitBoxComponent 节点
	if hitbox_node_path:
		hitbox_node = owner_body.get_node_or_null(hitbox_node_path)

func _process(delta: float) -> void:
	# 自动处理输入更新
	update_input_direction()

func _physics_process(delta: float) -> void:
	# 更新跳跃状态
	update_jump_state()

	# 自动处理移动（子类可重载）
	process_movement(delta)

# ============ 核心方法（子类可重载）============
## 获取用户输入（子类可重载以实现 AI 控制）
func get_input() -> Vector2:
	return Input.get_vector(input_left, input_right, input_up, input_down)

## 更新输入方向
func update_input_direction() -> void:
	var new_direction = get_input()
	if input_direction != new_direction:
		input_direction = new_direction
		if new_direction != Vector2.ZERO:
			direction_changed.emit(new_direction)

## 处理跳跃输入
func handle_jump_input() -> void:
	if not enable_jump or not owner_body or not can_move:
		return

	# 只有在地面上才能跳跃
	if Input.is_action_just_pressed(input_jump):
		if owner_body.is_on_floor():
			perform_jump()

## 执行跳跃
func perform_jump() -> void:
	if not owner_body:
		return

	owner_body.velocity.y = jump_force
	is_jumping = true
	is_falling = false
	jump_started.emit()

	DebugConfig.debug("跳跃开始", "", "movement")

## 更新跳跃状态（检测顶点和落地）
func update_jump_state() -> void:
	if not owner_body:
		return

	var on_floor = owner_body.is_on_floor()

	# 检测到达顶点（速度从上升转为下落）
	if is_jumping and not is_falling and owner_body.velocity.y > 0:
		is_falling = true
		is_jumping = false
		jump_apex_reached.emit()
		DebugConfig.debug("到达跳跃顶点", "", "movement")

	# 检测落地
	if not was_on_floor and on_floor:
		is_jumping = false
		is_falling = false
		landed.emit()
		DebugConfig.debug("落地", "", "movement")

	was_on_floor = on_floor

## 处理移动逻辑（子类可重载）
func process_movement(delta: float) -> void:
	if not owner_body:
		return

	# 处理跳跃输入
	handle_jump_input()

	# 计算目标水平速度（只处理 x 轴，保留 y 轴用于重力）
	var target_velocity_x = 0.0
	if can_move:
		target_velocity_x = input_direction.x * max_speed

	# 应用加速度（只处理水平移动，保留垂直速度用于重力）
	var acceleration = (1.0 / acceleration_time) * max_speed * delta
	owner_body.velocity.x = move_toward(owner_body.velocity.x, target_velocity_x, acceleration)

	# 发射速度改变信号
	velocity_changed.emit(owner_body.velocity)

	# 更新面朝方向（只在水平移动时更新）
	if abs(owner_body.velocity.x) > 1.0:
		last_face_direction.x = sign(owner_body.velocity.x)

	# 自动翻转精灵
	if auto_flip_sprite:
		update_sprite_flip()

	# 执行移动
	owner_body.move_and_slide()

## 更新精灵翻转（子类可重载）
func update_sprite_flip() -> void:
	if not sprite_node:
		return

	var should_flip = last_face_direction.x < 0

	# 翻转精灵
	if sprite_node is AnimatedSprite2D:
		if sprite_node.flip_h != should_flip:
			sprite_node.flip_h = should_flip
			sprite_flipped.emit(should_flip)
	elif sprite_node is Sprite2D:
		if sprite_node.flip_h != should_flip:
			sprite_node.flip_h = should_flip
			sprite_flipped.emit(should_flip)

	# 翻转 HitBoxComponent
	if hitbox_node:
		var hitbox_scale = -1 if should_flip else 1
		if hitbox_node.scale.x != hitbox_scale:
			hitbox_node.scale.x = hitbox_scale

# ============ 公共 API ============
## 设置移动能力
func set_movement_enabled(enabled: bool) -> void:
	can_move = enabled

## 获取当前速度（包括垂直速度）
func get_current_speed() -> float:
	return owner_body.velocity.length() if owner_body else 0.0

## 获取水平速度（仅x方向，用于判断是否在移动）
func get_horizontal_speed() -> float:
	return abs(owner_body.velocity.x) if owner_body else 0.0

## 是否正在移动（仅判断水平方向）
func is_moving() -> bool:
	return get_horizontal_speed() > 1.0

## 强制设置面朝方向
func set_facing_direction(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		last_face_direction = direction.normalized()

## 获取面朝方向
func get_facing_direction() -> Vector2:
	return last_face_direction

## 强制设置速度（用于翻滚、击飞等）
func set_velocity(velocity: Vector2) -> void:
	if owner_body:
		owner_body.velocity = velocity
		velocity_changed.emit(velocity)

## 应用冲刺/翻滚速度
func apply_dash_speed(speed: float) -> void:
	if owner_body:
		owner_body.velocity = last_face_direction * speed
		velocity_changed.emit(owner_body.velocity)

## 检查是否在地面
func is_grounded() -> bool:
	return owner_body.is_on_floor() if owner_body else false

## 检查是否正在跳跃（上升阶段）
func is_jumping_up() -> bool:
	return is_jumping and owner_body.velocity.y < 0 if owner_body else false

## 检查是否正在下落
func is_falling_down() -> bool:
	return is_falling or (not owner_body.is_on_floor() and owner_body.velocity.y > 0) if owner_body else false
