extends "res://Core/StateMachine/CommonStates/AttackState.gd"
class_name LizardAttackState

## Lizard 特殊技能：毒液攻击
## 20% 概率：普通攻击附带持续毒素（3 次 tick，每秒 5 伤害，绿色着色）

const POISON_MARKER := "_LizardPoison"

@export var skill_probability := 0.2
@export var poison_damage_per_tick := 5.0
@export var poison_ticks := 3
@export var poison_interval := 1.0


func _init() -> void:
	use_attack_component = false


func on_custom_attack() -> void:
	fire_attack()
	if randf() < skill_probability:
		_apply_poison()


func _apply_poison() -> void:
	if not is_instance_valid(target_node):
		return
	# 防止叠加
	if target_node.get_node_or_null(POISON_MARKER):
		return

	# 标记
	var marker := Node.new()
	marker.name = POISON_MARKER
	target_node.add_child(marker)

	# 绿色着色
	target_node.modulate = Color(0.6, 1.2, 0.6, 1.0)

	# 毒素粒子喷溅
	VfxHelper.spawn_burst(owner_node.get_parent(), target_node.global_position,
		"res://Assets/Art/FX/Particle/Grass.png", 9, Color(0.3, 1.6, 0.3), 55.0)

	# 异步 3 tick 伤害
	_run_poison_ticks(marker)


func _run_poison_ticks(marker: Node) -> void:
	for i in poison_ticks:
		await owner_node.get_tree().create_timer(poison_interval).timeout
		if not is_instance_valid(target_node) or not is_instance_valid(marker):
			break
		var hurtbox: HurtBoxComponent = target_node.get_node_or_null("HurtBoxComponent")
		if hurtbox:
			var dmg := Damage.new()
			dmg.amount = poison_damage_per_tick
			dmg.min_amount = poison_damage_per_tick
			dmg.max_amount = poison_damage_per_tick
			var src_pos: Vector2 = owner_node.global_position if is_instance_valid(owner_node) else Vector2.ZERO
			hurtbox.take_damage(dmg, src_pos)

	# 清理
	if is_instance_valid(target_node):
		target_node.modulate = Color(1, 1, 1, 1)
	if is_instance_valid(marker):
		marker.queue_free()
