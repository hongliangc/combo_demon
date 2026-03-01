extends Area2D
class_name HurtBoxComponent

############################################################
# HurtBoxComponent component - this gets hit by the bullet's hitbox.
# Only used by enemies by default, but can be referenced by
# health components to receive damage
############################################################

# 受到伤害时发出的信号
# @param damage: 伤害数据
# @param attacker_position: 攻击者位置（用于计算击飞/击退方向）
signal damaged(damage: Damage, attacker_position: Vector2)

# 接收伤害并发出信号
# @param damage: 伤害数据
# @param attacker_position: 攻击者位置（可选，默认为Vector2.ZERO）
func take_damage(damage: Damage, attacker_position: Vector2 = Vector2.ZERO):
	damaged.emit(damage, attacker_position)
