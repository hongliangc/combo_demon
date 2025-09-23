extends Hitbox

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	attack.max_damage = 50
	attack.min_damage = 10
	attack.knockback = 10
	rng.randomize()
	#print("fire bullet self:{0} groups:{1}".format([self, str(get_groups())]))
	super._ready()

func update_attack():
	attack.damage = rng.randi_range(attack.min_damage, attack.max_damage)

func _on_hitbox_area_entered_(area: Area2D):
	# player自动碰撞直接返回
	if area.is_in_group("player_bullet"):
		return
	# 更新子类的攻击、伤害等属性
	update_attack()
	if area is Hurtbox:
		area.damage(attack)
	# print("_on_hitbox_area_entered_ name:{0}".format([area.name]))
	get_owner().queue_free()
