extends Hitbox

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	damage.max_amount = 50
	damage.min_amount = 10
	# Note: Damage class doesn't have knockback property
	rng.randomize()
	#print("fire bullet self:{0} groups:{1}".format([self, str(get_groups())]))
	super._ready()

func update_attack():
	damage.amount = rng.randi_range(damage.min_amount, damage.max_amount)

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
