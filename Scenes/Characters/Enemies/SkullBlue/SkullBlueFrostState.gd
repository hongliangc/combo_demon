extends "res://Core/StateMachine/CommonStates/SpecialSkillState.gd"
class_name SkullBlueFrostState

## SkullBlue 特殊技能：寒霜新星
## 蓝白光晕蓄力 → AOE 伤害（70px 内 8 dmg）+ 眩晕 1.5s
## 触发条件：距离 < 80，冷却 7s，20% 概率

@export var max_trigger_distance := 80.0
@export var nova_radius := 70.0
@export var nova_damage := 8.0
@export var stun_dur := 1.5
@export var charge_duration := 0.4


func _init() -> void:
	skill_cooldown = 7.0
	skill_probability = 0.2


func _check_condition(distance: float) -> bool:
	return distance < max_trigger_distance


func execute_skill() -> void:
	if not is_instance_valid(owner_node) or not is_instance_valid(target_node):
		finish_skill()
		return

	owner_node.velocity = Vector2.ZERO

	# 蓝白光晕蓄力
	var sprite: Node2D = owner_node.sprite if "sprite" in owner_node else null
	if sprite:
		var charge := owner_node.create_tween()
		charge.tween_property(sprite, "modulate", Color(0.4, 0.8, 2.0, 1.0), charge_duration * 0.5)
		charge.tween_property(sprite, "modulate", Color(1.8, 1.8, 2.5, 1.0), charge_duration * 0.5)
		await charge.finished

	if not is_instance_valid(owner_node) or not is_instance_valid(target_node):
		finish_skill()
		return

	# 冰晶粒子爆发
	VfxHelper.spawn_burst(owner_node.get_parent(), owner_node.global_position,
		"res://Assets/Art/FX/Particle/Snow.png", 14, Color(0.5, 0.8, 2.5), 90.0)

	# 释放寒霜新星：范围伤害 + 眩晕
	var dist: float = (owner_node as Node2D).global_position.distance_to((target_node as Node2D).global_position)
	if dist < nova_radius:
		var dmg := Damage.new()
		dmg.amount = nova_damage
		dmg.min_amount = nova_damage
		dmg.max_amount = nova_damage
		var stun := StunEffect.new()
		stun.stun_duration = stun_dur
		dmg.effects.append(stun)
		_apply_damage_to_player(dmg)

	# 白蓝闪光消散
	if is_instance_valid(owner_node) and sprite:
		var flash := owner_node.create_tween()
		flash.tween_property(sprite, "modulate", Color(2.0, 2.0, 3.0, 1.0), 0.05)
		flash.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25)
		await flash.finished

	if is_instance_valid(owner_node):
		finish_skill()
