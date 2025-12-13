extends AttackEffect
class_name KnockUpEffect

## 击飞特效 - 将敌人向上击飞并控制一段时间

@export_group("击飞参数")
## 击飞力度（向上的速度）
@export var knockup_force: float = 300.0

## 横向击飞力度（可选，默认为0表示垂直击飞）
@export var horizontal_force: float = 0.0

func _init():
	effect_name = "击飞"
	duration = 1.0

func apply_effect(enemy: Enemy, damage_source_position: Vector2) -> void:
	super.apply_effect(enemy, damage_source_position)

	print("[KnockUpEffect] 开始应用击飞效果")
	print("[KnockUpEffect] 敌人当前速度: ", enemy.velocity)

	# 设置击飞速度（主要是向上）
	enemy.velocity.y = -knockup_force  # 向上（负数表示向上）

	# 如果有横向力，则计算方向
	if horizontal_force > 0:
		var direction = (enemy.global_position - damage_source_position).normalized()
		enemy.velocity.x = direction.x * horizontal_force
	else:
		enemy.velocity.x = 0  # 纯垂直击飞

	print("[KnockUpEffect] 设置后的速度: ", enemy.velocity)
	print("[KnockUpEffect] 击飞力度: ", knockup_force, " 持续时间: ", duration)

	# 注意：不在这里设置 enemy.stunned，由 stun 状态的 enter() 方法管理

	if show_debug_info:
		print("[KnockUpEffect] 击飞 %s - 力度: %.0f, 持续: %.1fs" % [enemy.name, knockup_force, duration])

	# 注意：击飞状态的持续时间由 stun 状态的定时器管理
	# 不需要在这里单独创建定时器

func get_description() -> String:
	return "击飞 - 力度: %.0f, 持续: %.1f秒" % [knockup_force, duration]
