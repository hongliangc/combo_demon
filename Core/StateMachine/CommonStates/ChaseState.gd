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
## 攻击范围（优先使用 owner.attack_activation_radius）
@export var default_attack_range := 50.0
## 放弃追击范围（优先使用 owner.chase_abandon_distance）
@export var default_give_up_range := 300.0

# ============ 移动设置 ============
@export_group("移动设置")
## 水平移动模式（仅 X 轴，用于地面敌人如 Snail/Boar）
@export var ground_only := false

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

	# 从 config 或 owner 获取参数
	var config := _get_config()
	var give_up_range: float = config.chase_abandon_distance if config else get_owner_property("chase_abandon_distance", default_give_up_range)
	var attack_range: float = config.attack_activation_radius if config else get_owner_property("attack_activation_radius", default_attack_range)
	var speed: float = config.chase_speed if config else get_owner_property("chase_speed", default_chase_speed)
	var is_ground: bool = config.ground_only if config else ground_only

	var distance = get_distance_to_target()

	# 距离太远，放弃追击
	if distance > give_up_range:
		transition_to(give_up_state_name)
		return

	# 检查特殊技能（冷却完成 + 概率）
	var ss := state_machine.states.get(StateNames.SPECIALSKILL) as SpecialSkillState
	if ss and ss.can_trigger(distance):
		transition_to(StateNames.SPECIALSKILL)
		return

	# 进入攻击范围
	if distance <= attack_range:
		var target_state := _on_reached_attack_range()
		if target_state != "":
			transition_to(target_state)
			return
		# 冷却中：继续移动跟随，不卡死

	# 移动向目标
	if is_ground:
		_move_ground_only(speed)
	else:
		move_toward_target(speed)

	# 更新动画
	_update_animation_locomotion()

	# 翻转精灵朝向
	if enable_sprite_flip:
		update_sprite_facing(false)


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


## 地面模式移动：仅 X 轴
func _move_ground_only(speed: float) -> void:
	if owner_node is not CharacterBody2D:
		return
	var body := owner_node as CharacterBody2D
	var dir := get_direction_to_target()
	body.velocity.x = sign(dir.x) * speed
	# 保留 Y 轴速度（重力由 EnemyBase._physics_process 处理）
	body.move_and_slide()


## 到达攻击范围时的状态选择（子类可重写）
## Boss: 检查攻击冷却
## Enemy: 直接进入攻击
func _on_reached_attack_range() -> String:
	if owner_node is BossBase:
		var boss := owner_node as BossBase
		if boss.attack_cooldown > 0:
			return ""  # 空字符串 = 继续当前行为
		return attack_state_name
	return attack_state_name
