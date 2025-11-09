extends Area2D
class_name Hitbox

############################################################
# hurtbox component - used to detect whether the collision area of the attacking object(such as bullet)
# overlaps with the enemy's hitbox area. If so, the damage method of the hit area is called to notify 
# the other party.
############################################################

var damage: Damage = Damage.new()

func _ready() -> void:
	# 使用Area节点自带的区域area_entered signal连接回调接口，检测碰撞
	area_entered.connect(_on_hitbox_area_entered_)

func update_attack():
	pass

# 建议子类覆盖该方法，然后get_owner().queue_free()
func _on_hitbox_area_entered_(area: Area2D):
	# 更新子类的攻击、伤害等属性
	update_attack()
	if area is Hurtbox:
		area.take_damage(damage)
