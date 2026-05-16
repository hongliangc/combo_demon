extends Area2D
class_name HitBoxComponent

## Attack collision area. Inline damage fields (no Damage Resource).
## Pushed into the HitBox by GenericAttackState.configure_from_skill or its caller.

@export_group("伤害配置")
@export var damage_amount: float = 1.0
@export_flags("Physical:1","Magical:2","DOT:4","Crit:8","True:16") var damage_tags: int = 0
@export var attached_buffs: Array[BuffEntity] = []

func _ready() -> void:
	if not area_entered.is_connected(_on_hitbox_area_entered_):
		area_entered.connect(_on_hitbox_area_entered_)

func configure_from_skill(skill: Skill) -> void:
	damage_amount = skill.damage_amount
	damage_tags = skill.damage_tags
	attached_buffs = skill.attached_buffs

## 通过技能 id 查找并应用技能伤害配置。用于动画 method track 调用。
func configure_from_skill_id(id: StringName) -> void:
	var skill := _resolve_skill(id)
	if skill:
		configure_from_skill(skill)

## 从 owner 的 skill_set 中查找技能。owner 不含 skill_set 时静默返回 null。
func _resolve_skill(id: StringName) -> Skill:
	var owner_node := get_owner()
	if owner_node and "skill_set" in owner_node and owner_node.skill_set:
		return (owner_node.skill_set as SkillSet).get_skill(id)
	return null

func get_attacker_position() -> Vector2:
	return global_position

func _on_hitbox_area_entered_(target: Area2D) -> void:
	if not (target is HurtBoxComponent):
		return
	var attacker: Node = get_owner()
	var victim: Node = target.get_owner()
	if attacker == null or victim == null:
		return
	var pipe: DamagePipeline = victim.get_node_or_null(^"DamagePipeline")
	if pipe == null:
		return

	var ctx := DamageContext.new()
	ctx.source = attacker
	ctx.target = victim
	ctx.raw_amount = damage_amount
	ctx.amount = damage_amount
	ctx.tags = damage_tags
	ctx.attached_buffs = attached_buffs.duplicate()
	ctx.source_pos = get_attacker_position()

	var atk_bc: BuffController = attacker.get_node_or_null(^"BuffController")
	if atk_bc and (ctx.tags & DamageTags.TRUE) == 0:
		ctx.amount *= atk_bc.get_modifier(StatIds.OUTGOING_DAMAGE)

	pipe.process(ctx)
