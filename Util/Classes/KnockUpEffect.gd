extends AttackEffect
class_name KnockUpEffect

## 击飞特效 - 可应用到任何 CharacterBody2D（Player, Boss, Enemy）

@export_group("击飞参数")
## 击飞力度（向上的速度）
@export var launch_force: float = 300.0

## 横向击飞力度（可选，默认为0表示垂直击飞）
@export var horizontal_force: float = 0.0

func _init():
	effect_name = "击飞"
	duration = 1.0

func apply_effect(target: CharacterBody2D, damage_source_position: Vector2) -> void:
	super.apply_effect(target, damage_source_position)

	if show_debug_info:
		print("[KnockUpEffect] 开始应用击飞效果")
		print("[KnockUpEffect] 目标当前速度: ", target.velocity)

	# 设置击飞速度（主要是向上）
	target.velocity.y = -launch_force  # 向上（负数表示向上）

	# 如果有横向力，则计算方向
	if horizontal_force > 0:
		var direction = (target.global_position - damage_source_position).normalized()
		target.velocity.x = direction.x * horizontal_force
	else:
		target.velocity.x = 0  # 纯垂直击飞

	# 禁用移动控制（如果目标有 can_move 属性）
	if "can_move" in target:
		target.can_move = false
		# 使用定时器在持续时间后恢复控制
		if target.get_tree():
			await target.get_tree().create_timer(duration).timeout
			if is_instance_valid(target) and "can_move" in target:
				target.can_move = true
				if show_debug_info:
					print("[KnockUpEffect] 恢复移动控制")

	if show_debug_info:
		print("[KnockUpEffect] 设置后的速度: ", target.velocity)
		print("[KnockUpEffect] 击飞力度: ", launch_force, " 持续时间: ", duration)

func get_description() -> String:
	return "击飞 - 力度: %.0f, 持续: %.1f秒" % [launch_force, duration]
