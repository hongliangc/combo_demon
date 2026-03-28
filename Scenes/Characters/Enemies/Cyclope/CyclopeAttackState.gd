extends "res://Core/StateMachine/CommonStates/AttackState.gd"
class_name CyclopeAttackState

## Cyclope 特殊技能：蓄力猛击
## 20% 概率：蓄力 1 秒（黄色闪烁）→ 释放 2x 伤害攻击

@export var skill_probability := 0.2
@export var charge_duration := 1.0
@export var charge_damage := 20.0

var _is_charging := false
var _charge_ready := false
var _flash_tween: Tween = null


func _init() -> void:
	use_attack_component = false


func exit() -> void:
	super.exit()
	_cancel_charge()


func on_custom_attack() -> void:
	if _charge_ready:
		_release_charge()
		return
	if not _is_charging and randf() < skill_probability:
		_start_charge()
	else:
		fire_attack()


func _start_charge() -> void:
	_is_charging = true
	_charge_ready = false
	# 黄色闪烁提示
	if is_instance_valid(owner_node) and "sprite" in owner_node and owner_node.sprite:
		_flash_tween = owner_node.create_tween().set_loops(5)
		_flash_tween.tween_property(owner_node.sprite, "modulate", Color(2.0, 1.8, 0.2, 1.0), 0.1)
		_flash_tween.tween_property(owner_node.sprite, "modulate", Color(1, 1, 1, 1), 0.1)
	start_timer(charge_duration, _on_charge_complete)


func _on_charge_complete() -> void:
	_is_charging = false
	_charge_ready = true
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	if is_instance_valid(owner_node) and "sprite" in owner_node and owner_node.sprite:
		owner_node.sprite.modulate = Color(1, 1, 1, 1)


func _release_charge() -> void:
	_charge_ready = false
	fire_attack()
	if not is_instance_valid(target_node):
		return
	var dist: float = owner_node.global_position.distance_to(target_node.global_position)
	var effective_range: float = get_owner_property("follow_radius", default_attack_range)
	if dist > effective_range * 1.5:
		return
	var dmg := Damage.new()
	dmg.amount = charge_damage
	dmg.min_amount = charge_damage
	dmg.max_amount = charge_damage
	var hurtbox: HurtBoxComponent = target_node.get_node_or_null("HurtBoxComponent")
	if hurtbox:
		hurtbox.take_damage(dmg, owner_node.global_position)

	# 黄色电击粒子爆发
	VfxHelper.spawn_burst(owner_node.get_parent(), owner_node.global_position,
		"res://Assets/Art/FX/Particle/Spark.png", 12, Color(2.0, 1.5, 0.1), 95.0)


func _cancel_charge() -> void:
	_is_charging = false
	_charge_ready = false
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = null
	if is_instance_valid(owner_node) and "sprite" in owner_node and owner_node.sprite:
		owner_node.sprite.modulate = Color(1, 1, 1, 1)
