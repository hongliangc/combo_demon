extends BaseState

## 通用 Chase（追击）状态
## 适用于所有需要追击玩家的敌人
## 支持从 owner 节点动态获取参数（chase_speed, follow_radius, chase_radius）

## 动画设置
@export var chase_animation := "run"

## 默认值（优先使用 owner 节点的属性）
@export var default_chase_speed := 100.0
@export var default_attack_range := 50.0  # owner.follow_radius
@export var default_give_up_range := 300.0  # owner.chase_radius

## 状态转换设置
@export var attack_state_name := "attack"
@export var give_up_state_name := "wander"
@export var target_lost_state_name := "idle"

## 移动设置
@export var enable_sprite_flip := true

func enter() -> void:
	if owner_node and owner_node.has_method("play_animation"):
		owner_node.play_animation(chase_animation)

func physics_process_state(_delta: float) -> void:
	if not is_target_alive():
		transitioned.emit(self, target_lost_state_name)
		return

	# 从 owner 获取参数（优先）或使用默认值
	var give_up_range: float = get_owner_property("chase_radius", default_give_up_range)
	var attack_range: float = get_owner_property("follow_radius", default_attack_range)
	var speed: float = get_owner_property("chase_speed", default_chase_speed)

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

	# 移动向目标
	if owner_node is CharacterBody2D:
		var body = owner_node as CharacterBody2D
		var direction = get_direction_to_target()

		body.velocity = direction * speed
		body.move_and_slide()

		# 翻转精灵
		if enable_sprite_flip and "sprite" in owner_node and owner_node.sprite is Sprite2D:
			owner_node.sprite.flip_h = direction.x < 0
