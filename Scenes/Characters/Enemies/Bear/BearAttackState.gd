extends "res://Core/StateMachine/CommonStates/AttackState.gd"
class_name BearAttackState

## Bear 特殊技能：震地重击
## 20% 概率：范围击退波 + 1.5x 伤害 + 精灵震动
## 默认：播放攻击动画（HitBoxComponent 近战伤害）

@export var skill_probability := 0.2
@export var slam_radius := 80.0
@export var slam_damage := 18.0
@export var slam_knockback := 280.0


func _init() -> void:
	use_attack_component = false


func on_custom_attack() -> void:
	fire_attack()
	if randf() < skill_probability:
		_perform_ground_slam()


func _perform_ground_slam() -> void:
	if not is_instance_valid(target_node):
		return
	var dist: float = owner_node.global_position.distance_to(target_node.global_position)
	if dist > slam_radius:
		return

	# 击退波：施加伤害 + 击退
	var dmg := Damage.new()
	dmg.amount = slam_damage
	dmg.min_amount = slam_damage
	dmg.max_amount = slam_damage
	var kb := KnockBackEffect.new()
	kb.knockback_force = slam_knockback
	dmg.effects.append(kb)

	var hurtbox: HurtBoxComponent = target_node.get_node_or_null("HurtBoxComponent")
	if hurtbox:
		hurtbox.take_damage(dmg, owner_node.global_position)

	# 岩石碎裂粒子 + 精灵震动
	VfxHelper.spawn_burst(owner_node.get_parent(), owner_node.global_position,
		"res://Assets/Art/FX/Particle/Rock.png", 10, Color(0.9, 0.7, 0.4), 110.0)
	_shake_sprite()


func _shake_sprite() -> void:
	if not is_instance_valid(owner_node) or not ("sprite" in owner_node):
		return
	var sprite: Node2D = owner_node.sprite
	if not sprite:
		return
	var original_pos := sprite.position
	var tween := owner_node.create_tween()
	tween.tween_property(sprite, "position", original_pos + Vector2(4, 0), 0.05)
	tween.tween_property(sprite, "position", original_pos + Vector2(-4, 0), 0.05)
	tween.tween_property(sprite, "position", original_pos + Vector2(3, 0), 0.04)
	tween.tween_property(sprite, "position", original_pos, 0.04)
