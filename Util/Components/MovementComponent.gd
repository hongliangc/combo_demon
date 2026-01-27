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

# ============ 配置参数 ============
@export_group("Movement")
@export var max_speed: float = 100.0
@export var acceleration_time: float = 0.1

@export_group("Input")
## 输入映射名称
@export var input_left: String = "move_left"
@export var input_right: String = "move_right"
@export var input_up: String = "move_up"
@export var input_down: String = "move_down"

@export_group("Sprite Flip")
## 是否自动翻转精灵（如果提供了 sprite_node）
@export var auto_flip_sprite: bool = true
## 精灵节点路径（相对于 owner）
@export var sprite_node_path: NodePath = ^"AnimatedSprite2D"
## Hitbox节点路径（相对于 owner，用于翻转攻击判定）
@export var hitbox_node_path: NodePath = ^"%Hitbox"

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

	# 获取 Hitbox 节点
	if hitbox_node_path:
		hitbox_node = owner_body.get_node_or_null(hitbox_node_path)

func _process(delta: float) -> void:
	# 自动处理输入更新
	update_input_direction()

func _physics_process(delta: float) -> void:
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

## 处理移动逻辑（子类可重载）
func process_movement(delta: float) -> void:
	if not owner_body:
		return

	# 计算目标速度
	var target_velocity = Vector2.ZERO
	if can_move:
		target_velocity = input_direction * max_speed

	# 应用加速度（带平滑过渡）
	var acceleration = (1.0 / acceleration_time) * max_speed * delta
	owner_body.velocity = owner_body.velocity.move_toward(target_velocity, acceleration)

	# 发射速度改变信号
	velocity_changed.emit(owner_body.velocity)

	# 更新面朝方向（只在移动时更新）
	if owner_body.velocity.length() > 0:
		var new_direction = owner_body.velocity.normalized()
		if last_face_direction != new_direction:
			last_face_direction = new_direction

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

	# 翻转 Hitbox
	if hitbox_node:
		var hitbox_scale = -1 if should_flip else 1
		if hitbox_node.scale.x != hitbox_scale:
			hitbox_node.scale.x = hitbox_scale

# ============ 公共 API ============
## 设置移动能力
func set_movement_enabled(enabled: bool) -> void:
	can_move = enabled

## 获取当前速度
func get_current_speed() -> float:
	return owner_body.velocity.length() if owner_body else 0.0

## 是否正在移动
func is_moving() -> bool:
	return get_current_speed() > 1.0

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
