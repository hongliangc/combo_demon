extends BaseState

## 通用 Chase（追击）状态
## 适用于所有需要追击玩家的敌人

## 动画设置
@export var chase_animation := "run"

## 速度设置
@export var chase_speed := 100.0
@export var use_owner_speed := true  # 优先使用 owner.chase_speed

## 距离设置
@export var attack_range := 50.0  # 进入攻击范围
@export var give_up_range := 300.0  # 放弃追击的距离

## 状态转换设置
@export var attack_state_name := "attack"  # 攻击状态名称
@export var give_up_state_name := "wander"  # 放弃追击后的状态
@export var target_lost_state_name := "idle"  # 目标丢失后的状态

## 移动设置
@export var enable_sprite_flip := true  # 是否翻转精灵
@export var random_movement := false  # 添加随机偏移（更自然）
@export var random_offset := 0.2  # 随机偏移量 (0.0 - 1.0)

func enter() -> void:
	if owner_node and owner_node.has_method("play_animation"):
		owner_node.play_animation(chase_animation)


func physics_process_state(_delta: float) -> void:
	if not is_target_alive():
		transitioned.emit(self, target_lost_state_name)
		return

	var distance = get_distance_to_target()

	# 距离太远，放弃追击
	if distance > give_up_range:
		transitioned.emit(self, give_up_state_name)
		return

	# 进入攻击范围
	if distance <= attack_range:
		if state_machine.states.has(attack_state_name):
			transitioned.emit(self, attack_state_name)
		return

	# 移动向玩家
	if owner_node is CharacterBody2D:
		var body = owner_node as CharacterBody2D
		var direction = get_direction_to_target()

		# 添加随机偏移（使移动更自然）
		if random_movement:
			var random_angle = randf_range(-random_offset, random_offset)
			direction = direction.rotated(random_angle)
			direction = direction.normalized()

		# 使用 owner 的速度属性（如果有且启用）
		var speed = chase_speed
		if use_owner_speed and "chase_speed" in owner_node:
			speed = owner_node.chase_speed

		body.velocity = direction * speed
		body.move_and_slide()

		# 翻转精灵（如果有且启用）
		if enable_sprite_flip and "sprite" in owner_node and owner_node.sprite is Sprite2D:
			var sprite = owner_node.sprite as Sprite2D
			sprite.flip_h = direction.x < 0
