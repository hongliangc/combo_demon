class_name SkullFrostState extends BaseAttackState

## Skull 可选特殊技: 寒霜新星 — 蓝白蓄力 → AOE 伤害 + 眩晕 + 冰晶粒子
## faithful port: 旧 SkullBlueFrostState.execute_skill (SpecialSkillState 子类)。
## 20% 概率 / 距离门 / 7s 冷却已上移到 skull_frost.tres
## (precondition_method / max_range / cooldown) —— 见 Skull._can_skull_frost。

## 1.5s 眩晕 buff (duration=1.5, legal_action_locks=15) —— 旧 StunEffect(1.5s) 的 v2 等价
const STUN_BUFF: BuffEntity = preload("res://Core/Buffs/library/stun_short.tres")

@export var nova_radius := 70.0
@export var nova_damage := 8.0
@export var charge_duration := 0.4

var _active := false
var _tween: Tween = null

func enter() -> void:
	_active = true
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	# 蓝白光晕蓄力
	_play_charge_tween()
	await owner_node.get_tree().create_timer(charge_duration).timeout
	if not _active or not is_instance_valid(owner_node):
		return
	# 冰晶粒子爆发
	if owner_node is Node2D:
		VfxHelper.spawn_burst(owner_node.get_parent(), (owner_node as Node2D).global_position,
			"res://Assets/Art/FX/Particle/Snow.png", 14, Color(0.5, 0.8, 2.5), 90.0)
	# 寒霜新星: nova_radius 内施 nova_damage + 1.5s 眩晕
	_release_nova()
	# 白蓝闪光消散
	_play_flash_tween()
	await owner_node.get_tree().create_timer(0.3).timeout
	if not _active or not is_instance_valid(owner_node):
		return
	_finish()

func exit() -> void:
	_active = false
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
	if is_instance_valid(owner_node) and "sprite" in owner_node and owner_node.sprite:
		owner_node.sprite.modulate = Color(1, 1, 1, 1)

## 蓝白光晕蓄力 (charge_duration 内两段)
func _play_charge_tween() -> void:
	if not (is_instance_valid(owner_node) and "sprite" in owner_node and owner_node.sprite):
		return
	_tween = owner_node.create_tween()
	_tween.tween_property(owner_node.sprite, "modulate", Color(0.4, 0.8, 2.0, 1.0), charge_duration * 0.5)
	_tween.tween_property(owner_node.sprite, "modulate", Color(1.8, 1.8, 2.5, 1.0), charge_duration * 0.5)

## 白蓝闪光消散
func _play_flash_tween() -> void:
	if not (is_instance_valid(owner_node) and "sprite" in owner_node and owner_node.sprite):
		return
	_tween = owner_node.create_tween()
	_tween.tween_property(owner_node.sprite, "modulate", Color(2.0, 2.0, 3.0, 1.0), 0.05)
	_tween.tween_property(owner_node.sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25)

## nova_radius 内对目标施 nova_damage + 1.5s 眩晕 buff (经 v2 DamagePipeline)
func _release_nova() -> void:
	var target: Node = ai.target_node if ai else null
	if not is_instance_valid(target) or not (owner_node is Node2D) or not (target is Node2D):
		return
	var origin: Vector2 = (owner_node as Node2D).global_position
	var dist: float = origin.distance_to((target as Node2D).global_position)
	if dist >= nova_radius:
		return
	var pipe: DamagePipeline = target.get_node_or_null(^"DamagePipeline")
	if pipe == null:
		return
	var ctx := DamageContext.new()
	ctx.source = owner_node
	ctx.target = target
	ctx.raw_amount = nova_damage
	ctx.amount = nova_damage
	ctx.tags = DamageTags.MAGICAL
	ctx.source_pos = origin
	ctx.attached_buffs = [STUN_BUFF]
	pipe.process(ctx)
