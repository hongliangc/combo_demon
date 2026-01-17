extends "res://Util/StateMachine/CommonStates/chase_state.gd"

## Enemy Chase 状态 - 使用通用 ChaseState 模板
## 配置参数以匹配原有行为

func _ready():
	# 使用 owner 的速度属性
	use_owner_speed = true  # 使用 owner.chase_speed

	# 距离设置（使用 owner 的属性）
	# attack_range 和 give_up_range 将在 physics_process_state 中动态获取

	# 状态转换
	attack_state_name = "attack"
	give_up_state_name = "wander"  # 放弃追击后转到 wander
	target_lost_state_name = "wander"  # 目标丢失后转到 wander

	# 移动设置
	enable_sprite_flip = true
	random_movement = false


func physics_process_state(delta: float) -> void:
	if not is_target_alive():
		transitioned.emit(self, target_lost_state_name)
		return

	if owner_node is not Enemy:
		return

	var enemy = owner_node as Enemy
	if not enemy.alive:
		return

	var distance = get_distance_to_target()

	# 离开追击范围，返回巡逻
	if distance > enemy.chase_radius:
		transitioned.emit(self, give_up_state_name)
		return

	# 进入攻击范围（使用 enemy.follow_radius）
	if distance < enemy.follow_radius:
		transitioned.emit(self, attack_state_name)
		return

	# 追击玩家
	var direction = get_direction_to_target()
	enemy.velocity = direction * enemy.chase_speed

	# CharacterBody2D 调用 move_and_slide()
	enemy.move_and_slide()
