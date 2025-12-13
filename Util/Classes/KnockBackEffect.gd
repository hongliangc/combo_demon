extends AttackEffect
class_name KnockBackEffect

## 击退特效 - 将敌人水平击退并控制一段时间

@export_group("击退参数")
## 击退力度（水平速度）
@export var knockback_force: float = 200.0

## 摩擦力（影响减速速度，越大减速越快）
@export var friction: float = 0.8

## 是否在击退期间禁用敌人AI
@export var disable_ai_during_knockback: bool = true

func _init():
	effect_name = "击退"
	duration = 0.5

func apply_effect(enemy: Enemy, damage_source_position: Vector2) -> void:
	super.apply_effect(enemy, damage_source_position)

	print("[KnockBackEffect] 开始应用击退效果")
	print("[KnockBackEffect] 敌人当前速度: ", enemy.velocity)

	# 计算击退方向（远离伤害源）
	var direction = (enemy.global_position - damage_source_position).normalized()

	# 设置击退速度（仅水平方向）
	enemy.velocity.x = direction.x * knockback_force
	enemy.velocity.y = 0  # 不影响Y轴

	print("[KnockBackEffect] 设置后的速度: ", enemy.velocity)
	print("[KnockBackEffect] 击退方向: ", direction, " 力度: ", knockback_force)

	# 注意：不在这里设置 enemy.stunned，由 stun 状态的 enter() 方法管理
	# 注意：击退状态的持续时间和摩擦力由 stun 状态管理

func get_description() -> String:
	return "击退 - 力度: %.0f, 持续: %.1f秒" % [knockback_force, duration]
