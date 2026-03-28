extends "res://Core/StateMachine/CommonStates/AttackState.gd"
class_name FlamAttackState

## Flam 特殊技能：自爆
## HP < 30% 时，20% 概率触发：膨胀动画 → 范围 AOE 伤害 → 自身死亡

@export var skill_probability := 0.2
@export var hp_threshold := 0.3
@export var explosion_radius := 100.0
@export var explosion_damage := 30.0
@export var explosion_knockback := 320.0

var _exploding := false


func _init() -> void:
	use_attack_component = false


func on_custom_attack() -> void:
	if _exploding:
		return
	var hp_ratio: float = _get_hp_ratio()
	if hp_ratio < hp_threshold and randf() < skill_probability:
		_start_explosion()
	else:
		fire_attack()


func _get_hp_ratio() -> float:
	if "health" in owner_node and "max_health" in owner_node and owner_node.max_health > 0:
		return float(owner_node.health) / float(owner_node.max_health)
	return 1.0


func _start_explosion() -> void:
	_exploding = true
	# 停止移动
	if is_instance_valid(owner_node):
		owner_node.velocity = Vector2.ZERO

	# 膨胀 + 红色着色
	var sprite: Node2D = owner_node.sprite if "sprite" in owner_node else null
	if sprite:
		var tween := owner_node.create_tween()
		tween.tween_property(sprite, "scale", Vector2(2.0, 2.0), 0.6)
		tween.parallel().tween_property(sprite, "modulate", Color(3.0, 0.3, 0.1, 1.0), 0.4)
		await tween.finished

	if not is_instance_valid(owner_node):
		return

	# AOE 伤害
	if is_instance_valid(target_node):
		var dist: float = owner_node.global_position.distance_to(target_node.global_position)
		if dist <= explosion_radius:
			var dmg := Damage.new()
			dmg.amount = explosion_damage
			dmg.min_amount = explosion_damage
			dmg.max_amount = explosion_damage
			var kb := KnockBackEffect.new()
			kb.knockback_force = explosion_knockback
			dmg.effects.append(kb)
			var hurtbox: HurtBoxComponent = target_node.get_node_or_null("HurtBoxComponent")
			if hurtbox:
				hurtbox.take_damage(dmg, owner_node.global_position)

	# 火焰爆炸粒子
	if is_instance_valid(owner_node):
		VfxHelper.spawn_burst(owner_node.get_parent(), owner_node.global_position,
			"res://Assets/Art/FX/Particle/Fire.png", 16, Color(2.0, 0.5, 0.05), 140.0)

	# 自我销毁
	var health_comp: Node = owner_node.get_node_or_null("HealthComponent")
	if health_comp and health_comp.has_method("die"):
		health_comp.die()
	else:
		owner_node.queue_free()
