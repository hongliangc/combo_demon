class_name CyclopeAttackState extends "res://Core/AI/Stock/GenericAttackState.gd"

## Cyclope 攻击 state — 正常攻击; randf()<charge_probability 时先蓄力再释放强化攻击
## faithful port: 旧 CyclopeAttackState (20% 蓄力猛击 → 普通攻击 + charge_damage 直伤)
## 旧的 _charge_ready 跨次状态收进单次 enter() 的 await 计时器 —— 蓄力→释放是一次攻击决策。

@export var charge_probability := 0.2
@export var charge_duration := 1.0
@export var charge_damage := 20.0

var _charging := false
var _flash_tween: Tween = null

func enter() -> void:
	if randf() < charge_probability:
		_charge_then_strike()
	else:
		super.enter()   # 普通攻击: 播 attack 动画 + HitBox

## 蓄力分支: 黄色闪烁 charge_duration 秒 → 正常攻击 + charge_damage 直伤 + 火花粒子
func _charge_then_strike() -> void:
	_charging = true
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	# 黄色闪烁蓄力提示
	if is_instance_valid(owner_node) and "sprite" in owner_node and owner_node.sprite:
		_flash_tween = owner_node.create_tween().set_loops(5)
		_flash_tween.tween_property(owner_node.sprite, "modulate", Color(2.0, 1.8, 0.2, 1.0), 0.1)
		_flash_tween.tween_property(owner_node.sprite, "modulate", Color(1, 1, 1, 1), 0.1)
	await owner_node.get_tree().create_timer(charge_duration).timeout
	# 蓄力期间被打断 (exit 已运行) → 放弃释放
	if not _charging or not is_instance_valid(owner_node):
		return
	_clear_flash()
	super.enter()             # 正常攻击: 播 attack 动画 + HitBox
	_release_charge_damage()

## 蓄力释放的额外直伤 + 火花粒子 (经 v2 DamagePipeline)
func _release_charge_damage() -> void:
	var target: Node = ai.target_node if ai else null
	if not is_instance_valid(target) or not (owner_node is Node2D) or not (target is Node2D):
		return
	var origin: Vector2 = (owner_node as Node2D).global_position
	var dist: float = origin.distance_to((target as Node2D).global_position)
	var max_range: float = ai.current_skill.max_range if ai and ai.current_skill else 25.0
	if dist > max_range * 1.5:
		return

	var pipe: DamagePipeline = target.get_node_or_null(^"DamagePipeline")
	if pipe:
		var ctx := DamageContext.new()
		ctx.source = owner_node
		ctx.target = target
		ctx.raw_amount = charge_damage
		ctx.amount = charge_damage
		ctx.tags = DamageTags.PHYSICAL
		ctx.source_pos = origin
		pipe.process(ctx)

	# 黄色电击粒子爆发
	VfxHelper.spawn_burst(owner_node.get_parent(), origin,
		"res://Assets/Art/FX/Particle/Spark.png", 12, Color(2.0, 1.5, 0.1), 95.0)

func exit() -> void:
	super.exit()
	_charging = false
	_clear_flash()

## 杀掉闪烁 tween 并恢复精灵 modulate
func _clear_flash() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = null
	if is_instance_valid(owner_node) and "sprite" in owner_node and owner_node.sprite:
		owner_node.sprite.modulate = Color(1, 1, 1, 1)
