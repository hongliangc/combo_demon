extends "res://Core/StateMachine/CommonStates/AttackState.gd"
class_name MouseAttackState

## Mouse 特殊技能：连击冲刺
## 20% 概率：快速冲刺3次，每次造成小额伤害

@export var skill_probability := 0.2
@export var dash_speed := 220.0
@export var dash_damage := 6.0
@export var combo_hits := 3
@export var hit_interval := 0.2

var _comboing := false
var _hit_count := 0


func _init() -> void:
	use_attack_component = false


func exit() -> void:
	super.exit()
	_comboing = false
	_hit_count = 0


func on_custom_attack() -> void:
	if _comboing:
		return
	if randf() < skill_probability:
		_start_combo()
	else:
		fire_attack()


func _start_combo() -> void:
	_comboing = true
	_hit_count = 0
	_do_next_hit()


func _do_next_hit() -> void:
	if not is_instance_valid(owner_node) or not is_instance_valid(target_node):
		_end_combo()
		return
	if not _comboing:
		return

	# 冲向玩家
	var dir: Vector2 = (target_node.global_position - owner_node.global_position).normalized()
	owner_node.velocity = dir * dash_speed
	owner_node.move_and_slide()

	fire_attack()

	# 施加小额伤害
	var dist: float = owner_node.global_position.distance_to(target_node.global_position)
	if dist < 60.0:
		var dmg := Damage.new()
		dmg.amount = dash_damage
		dmg.min_amount = dash_damage
		dmg.max_amount = dash_damage
		var hurtbox: HurtBoxComponent = target_node.get_node_or_null("HurtBoxComponent")
		if hurtbox:
			hurtbox.take_damage(dmg, owner_node.global_position)
		# 冲刺命中火花
		VfxHelper.spawn_burst(owner_node.get_parent(), owner_node.global_position,
			"res://Assets/Art/FX/Particle/Spark.png", 5, Color(1.0, 1.0, 1.0), 65.0)

	_hit_count += 1
	if _hit_count < combo_hits:
		start_timer(hit_interval, _do_next_hit)
	else:
		start_timer(hit_interval, _end_combo)


func _end_combo() -> void:
	_comboing = false
	_hit_count = 0
	if is_instance_valid(owner_node):
		owner_node.velocity = Vector2.ZERO
