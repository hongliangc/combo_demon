extends AttackEffect
class_name KnockBackEffect

## 击退特效 - 可应用到任何 CharacterBody2D（Player, Boss, Enemy）

@export_group("击退参数")
## 击退力度
@export var knockback_force: float = 200.0

func _init():
	effect_name = "击退"
	duration = 0.5

func apply_effect(target: CharacterBody2D, damage_source_position: Vector2) -> void:
	super.apply_effect(target, damage_source_position)

	if show_debug_info:
		print("[KnockBackEffect] 开始应用击退效果")
		print("[KnockBackEffect] 目标当前速度: ", target.velocity)

	# 计算击退方向（从攻击源指向目标）
	var direction = (target.global_position - damage_source_position).normalized()

	# 设置击退速度
	target.velocity = direction * knockback_force

	# 禁用移动控制（如果目标有 can_move 属性）
	if "can_move" in target:
		target.can_move = false
		# 使用信号连接在持续时间后恢复控制（避免await内存泄漏）
		if target.get_tree():
			var timer = target.get_tree().create_timer(duration)
			timer.timeout.connect(func():
				if is_instance_valid(target) and "can_move" in target:
					# 检查是否被眩晕，如果被眩晕则不恢复移动
					var is_stunned = false
					if "stunned" in target:
						is_stunned = target.stunned

					if not is_stunned:
						target.can_move = true
						if show_debug_info:
							print("[KnockBackEffect] 恢复移动控制")
					elif show_debug_info:
						print("[KnockBackEffect] 目标被眩晕，不恢复移动")
			, CONNECT_ONE_SHOT)

	if show_debug_info:
		print("[KnockBackEffect] 设置后的速度: ", target.velocity)
		print("[KnockBackEffect] 击退力度: ", knockback_force, " 方向: ", direction)

func get_description() -> String:
	return "击退 - 力度: %.0f, 持续: %.1f秒" % [knockback_force, duration]
