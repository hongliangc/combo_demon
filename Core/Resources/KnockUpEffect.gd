extends AttackEffect
class_name KnockUpEffect

## 击飞特效 - 可应用到任何 CharacterBody2D（Player, Boss, Enemy）
## 使用 Tween 实现平滑的击飞效果（适用于无重力的 2D 地图）

@export_group("击飞参数")
## 击飞高度（向上移动的像素距离）
@export var launch_height: float = 80.0

## 横向击飞距离（可选，默认为0表示垂直击飞）
@export var horizontal_distance: float = 0.0

## 上升时间（秒）
@export var rise_duration: float = 0.25

## 下落时间（秒）
@export var fall_duration: float = 0.2

## 是否根据攻击方向决定横向击飞方向
@export var use_attack_direction: bool = true

func _init():
	effect_name = "击飞"
	duration = 0.45  # rise_duration + fall_duration

func apply_effect(target: CharacterBody2D, damage_source_position: Vector2) -> void:
	super.apply_effect(target, damage_source_position)

	if show_debug_info:
		print("[KnockUpEffect] 开始应用击飞效果")
		print("[KnockUpEffect] 目标位置: ", target.global_position)

	# 保存原始位置
	var original_position = target.global_position

	# 计算横向方向（远离攻击源）
	var horizontal_dir = 0.0
	if horizontal_distance > 0 and use_attack_direction:
		horizontal_dir = sign(target.global_position.x - damage_source_position.x)
		if horizontal_dir == 0:
			horizontal_dir = 1.0  # 默认向右

	# 计算目标位置
	var peak_position = Vector2(
		original_position.x + horizontal_distance * horizontal_dir * 0.5,
		original_position.y - launch_height  # 向上为负
	)
	var land_position = Vector2(
		original_position.x + horizontal_distance * horizontal_dir,
		original_position.y
	)

	# 禁用移动控制
	if "can_move" in target:
		target.can_move = false

	# 使用 Tween 实现击飞动画
	var tween = target.create_tween()

	# 上升阶段 - 使用 EASE_OUT 实现减速效果
	tween.tween_property(target, "global_position", peak_position, rise_duration) \
		.set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_QUAD)

	# 下落阶段 - 使用 EASE_IN 实现加速效果
	tween.tween_property(target, "global_position", land_position, fall_duration) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_QUAD)

	# 动画完成后恢复控制
	tween.finished.connect(func():
		if is_instance_valid(target):
			# 确保最终位置精确
			target.global_position = land_position

			# 恢复移动控制（除非被眩晕）
			if "can_move" in target:
				var is_stunned = false
				if "stunned" in target:
					is_stunned = target.stunned

				if not is_stunned:
					target.can_move = true
					if show_debug_info:
						print("[KnockUpEffect] 恢复移动控制")
				elif show_debug_info:
					print("[KnockUpEffect] 目标被眩晕，不恢复移动")

			if show_debug_info:
				print("[KnockUpEffect] 击飞完成，最终位置: ", target.global_position)
	, CONNECT_ONE_SHOT)

	if show_debug_info:
		print("[KnockUpEffect] 击飞高度: ", launch_height, " 上升: ", rise_duration, "s 下落: ", fall_duration, "s")

func get_description() -> String:
	return "击飞 - 高度: %.0f, 持续: %.2f秒" % [launch_height, rise_duration + fall_duration]
