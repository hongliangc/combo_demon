extends BaseState

## 通用 Chase（追击）状态
## 适用于所有需要追击玩家的敌人
## 支持从 owner 节点动态获取参数

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true
	animation_state = "chase"

# ============ 速度设置 ============
@export_group("速度设置")
## 默认追击速度（优先使用 owner.chase_speed）
@export var default_chase_speed := 100.0

# ============ 距离设置 ============
@export_group("距离设置")
## 攻击范围（优先使用 owner.follow_radius）
@export var default_attack_range := 50.0
## 放弃追击范围（优先使用 owner.chase_radius）
@export var default_give_up_range := 300.0

# ============ 状态转换 ============
@export_group("状态转换")
## 进入攻击范围时的状态
@export var attack_state_name := "attack"
## 放弃追击时的状态
@export var give_up_state_name := "wander"

# ============ 精灵设置 ============
@export_group("精灵设置")
## 是否根据移动方向翻转精灵
@export var enable_sprite_flip := true


func enter() -> void:
	# 设置动画：开始追击
	set_locomotion(Vector2.ONE)  # 最大速度运动

func physics_process_state(_delta: float) -> void:
	if not is_target_alive():
		transition_to(default_state_name)
		return

	# 从 owner 获取参数
	var give_up_range: float = get_owner_property("chase_radius", default_give_up_range)
	var attack_range: float = get_owner_property("follow_radius", default_attack_range)
	var speed: float = get_owner_property("chase_speed", default_chase_speed)
	var distance = get_distance_to_target()

	# 距离太远，放弃追击
	if distance > give_up_range:
		transition_to(give_up_state_name)
		return

	# 进入攻击范围
	if distance <= attack_range:
		transition_to(attack_state_name)
		return

	# 移动向目标
	move_toward_target(speed)

	# 翻转精灵
	if enable_sprite_flip:
		update_sprite_facing()

	# 更新 AnimationTree 的 locomotion 混合
	_update_animation_locomotion()


func _update_animation_locomotion() -> void:
	if owner_node is not CharacterBody2D:
		return

	var body = owner_node as CharacterBody2D
	var speed = body.velocity.length()

	if speed < 0.1:
		# 速度很低，设置为 idle
		set_locomotion(Vector2.ZERO)
		return

	var max_speed: float = get_owner_property("chase_speed", default_chase_speed)
	var direction = body.velocity.normalized()

	# 构建 blend_position: (direction.x, speed_ratio)
	var blend_x = sign(direction.x) if abs(direction.x) > 0.1 else 0.0
	var blend_y = minf(speed / max_speed, 1.0)

	var blend_pos = Vector2(blend_x, blend_y)
	set_locomotion(blend_pos)
	#print("[ANIMATION] Chase speed=%.1f blend_x=%.1f blend_y=%.2f" % [speed, blend_x, blend_y])
