extends Hitbox

@onready var player : Hahashin = get_owner()

func _ready() -> void:
	# 跳过基类的 _ready，避免创建默认 damage
	# 玩家的 hitbox 直接使用 player.current_damage
	area_entered.connect(_on_hitbox_area_entered_)

## 玩家的伤害使用 combat_component.current_damage，不需要随机化
## 重写基类方法，使用玩家配置的伤害数据
func update_attack():
	# 玩家的伤害从 CombatComponent 获取，支持动态切换技能
	if player and player.combat_component:
		damage = player.combat_component.current_damage

# 建议子类覆盖该方法，然后get_owner().queue_free()
func _on_hitbox_area_entered_(area: Area2D):
	# 更新攻击伤害（获取玩家当前技能的伤害）
	update_attack()
	if area is Hurtbox:
		# 传递伤害数据和攻击者位置（用于计算击飞/击退方向）
		player.debug_print()
		area.take_damage(damage, player.global_position)
