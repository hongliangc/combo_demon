extends Area2D
class_name Hurtbox

############################################################
# Hurtbox component - this gets hit by the bullet's hitbox.
# Only used by enemies by default, but can be referenced by
# health components to receive damage
############################################################

# 如果关联了health, 可以进行通知收到攻击。
# 实际使用例子是enemy的子节点helath会导入Hurtbox 继承类。并关联该信号到health.on_damaged
signal damaged(damage: Damage)

# hurtbox 会通过碰撞的area，判断如果是Hitbox就会调用damage告知受到的伤害
func take_damage(damage: Damage):
	damaged.emit(damage)
