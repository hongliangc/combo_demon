class_name BearAttackState extends "res://Core/AI/Stock/GenericAttackState.gd"

## Bear 攻击 state — 正常攻击; randf()<slam_probability 时附加震地重击 AOE
## faithful port: 旧 BearAttackState.on_custom_attack(总攻击 + 20% slam)

## 震地重击附带的击退 buff (effect_on=APPLY → 推开 buff 持有者, 即被命中的目标)
const SLAM_KNOCKBACK_BUFF: BuffEntity = preload("res://Scenes/Characters/Enemies/Bear/Skills/bear_slam_knockback.tres")

@export var slam_probability := 0.2
@export var slam_radius := 80.0
@export var slam_damage := 18.0
@export var slam_knockback := 280.0

func enter() -> void:
	super.enter()   # 正常攻击: 播 attack 动画 + HitBox
	if randf() < slam_probability:
		_perform_ground_slam()

## 震地重击: 范围内目标受 slam_damage + 击退, 岩石碎裂粒子, 精灵震动
func _perform_ground_slam() -> void:
	var target: Node = ai.target_node if ai else null
	if not is_instance_valid(target) or not (owner_node is Node2D):
		return
	var origin: Vector2 = (owner_node as Node2D).global_position
	if not (target is Node2D):
		return
	var dist: float = origin.distance_to((target as Node2D).global_position)
	if dist > slam_radius:
		return

	# 击退波: 经 v2 DamagePipeline 施加伤害, 击退作为 attached_buff 在 post_apply 入栈
	var pipe: DamagePipeline = target.get_node_or_null(^"DamagePipeline")
	if pipe:
		var ctx := DamageContext.new()
		ctx.source = owner_node
		ctx.target = target
		ctx.raw_amount = slam_damage
		ctx.amount = slam_damage
		ctx.tags = DamageTags.PHYSICAL
		ctx.source_pos = origin
		ctx.attached_buffs = [_build_knockback_buff()]
		pipe.process(ctx)

	# 岩石碎裂粒子 + 精灵震动
	VfxHelper.spawn_burst(owner_node.get_parent(), origin,
		"res://Assets/Art/FX/Particle/Rock.png", 10, Color(0.9, 0.7, 0.4), 110.0)
	_shake_sprite()

## 构造一次性击退 buff: 复制基础 buff 并以 slam_knockback 覆写 force
## (BuffEntity/Effect 为共享 Resource, duplicate 避免改动模板)
func _build_knockback_buff() -> BuffEntity:
	var buff: BuffEntity = SLAM_KNOCKBACK_BUFF.duplicate(true)
	for eff in buff.effects:
		if eff is KnockBackBuffEffect:
			(eff as KnockBackBuffEffect).force = slam_knockback
	return buff

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
