extends Hitbox

## 火焰子弹的碰撞处理
## 在编辑器中配置 min_damage=10, max_damage=50

func _on_hitbox_area_entered_(area: Area2D):
	# player自动碰撞直接返回
	if area.is_in_group("player_bullet"):
		return
	# 更新子类的攻击、伤害等属性
	update_attack()
	if area is Hurtbox:
		area.take_damage(damage)
	# print("_on_hitbox_area_entered_ name:{0}".format([area.name]))
	get_owner().queue_free()
