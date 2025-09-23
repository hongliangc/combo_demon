extends Hitbox

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	attack.min_damage = 1
	attack.max_damage = 5
	rng.randomize()
	super._ready()

func update_attack():
	attack.damage = rng.randi_range(attack.min_damage, attack.max_damage)

# 建议子类覆盖该方法，然后get_owner().queue_free()
func _on_hitbox_area_entered_(area: Area2D):
	# 更新子类的攻击、伤害等属性
	update_attack()
	if area is Hurtbox:
		area.damage(attack)
