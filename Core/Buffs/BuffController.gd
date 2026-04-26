# Core/Buffs/BuffController.gd
class_name BuffController extends Node

## Per-actor buff container. Subscribes parent's DamagePipeline for incoming-damage hooks.

signal buffs_changed

var active: Array[BuffInstance] = []
var _stat_modifiers: Dictionary = {}     # StringName → Array[float]
var _gen_id_counter: int = 0

@onready var owner_node: Node = get_parent()
@onready var pipeline: DamagePipeline = owner_node.get_node_or_null(^"DamagePipeline") if owner_node else null

func _ready() -> void:
	if pipeline:
		pipeline.pre_calc.connect(_on_pre_calc)
		pipeline.pre_apply.connect(_on_pre_apply)
		pipeline.post_apply.connect(_on_post_apply)

# ============ Apply ============
func apply(buff: BuffEntity, source_actor: Node, source_pos: Vector2) -> void:
	if buff == null:
		return
	match buff.stacking:
		BuffEntity.Stacking.REFRESH:
			var existing := _find_by_id(buff.id)
			if existing:
				existing.remaining = buff.duration
				buffs_changed.emit()
				return
		BuffEntity.Stacking.REPLACE:
			var existing := _find_by_id(buff.id)
			if existing:
				_expire(existing)
				active.erase(existing)
		BuffEntity.Stacking.STACK:
			pass

	var inst := BuffInstance.new()
	inst.entity = buff
	inst.remaining = buff.duration
	inst.source_actor = source_actor
	inst.source_pos = source_pos
	inst.gen_id = _gen_id_counter
	_gen_id_counter += 1
	active.append(inst)

	var ctx := _make_ctx(inst, BuffEffect.EffectOn.APPLY)
	buff.execute_on(BuffEffect.EffectOn.APPLY, ctx)
	buffs_changed.emit()

# ============ Tick (per physics frame) ============
func _physics_process(delta: float) -> void:
	var changed := false
	var i := active.size() - 1
	while i >= 0:
		var inst := active[i]
		_tick_instance(inst, delta)
		if inst.entity.duration > 0:
			inst.remaining -= delta
			if inst.remaining <= 0.0:
				_expire(inst)
				active.remove_at(i)
				changed = true
		i -= 1
	if changed:
		buffs_changed.emit()

func _tick_instance(inst: BuffInstance, delta: float) -> void:
	for idx in inst.entity.effects.size():
		var eff: BuffEffect = inst.entity.effects[idx]
		if eff == null or (eff.effect_on & BuffEffect.EffectOn.TICK) == 0:
			continue
		var interval: float = 0.0
		if &"tick_interval" in eff:
			interval = float(eff.get(&"tick_interval"))
		if interval <= 0.0:
			_exec_effect(eff, inst, delta, BuffEffect.EffectOn.TICK)
			continue
		var accum: float = float(inst.tick_accums.get(idx, 0.0)) + delta
		if accum >= interval:
			inst.tick_accums[idx] = accum - interval
			_exec_effect(eff, inst, delta, BuffEffect.EffectOn.TICK)
		else:
			inst.tick_accums[idx] = accum

func _expire(inst: BuffInstance) -> void:
	var ctx := _make_ctx(inst, BuffEffect.EffectOn.EXPIRE)
	inst.entity.execute_on(BuffEffect.EffectOn.EXPIRE, ctx)

func clear_all() -> void:
	for inst in active:
		_expire(inst)
	active.clear()
	_stat_modifiers.clear()
	buffs_changed.emit()

# ============ Pipeline subscriptions ============
func _on_pre_calc(dc: DamageContext) -> void:
	if dc.target != owner_node:
		return
	if dc.tags & DamageTags.TRUE:
		return
	if dc.is_heal:
		dc.amount *= get_modifier(StatIds.HEAL_RECEIVED)
	else:
		dc.amount *= get_modifier(StatIds.INCOMING_DAMAGE)

func _on_pre_apply(_dc: DamageContext) -> void:
	pass  # invincibility 由 StatusController 处理

func _on_post_apply(dc: DamageContext) -> void:
	if dc.target != owner_node:
		return
	for buff in dc.attached_buffs:
		if buff:
			apply(buff, dc.source, dc.source_pos)
	if dc.is_heal:
		return
	for inst in active:
		for eff in inst.entity.effects:
			if eff and (eff.effect_on & BuffEffect.EffectOn.ON_DAMAGED) != 0:
				_exec_effect(eff, inst, 0.0, BuffEffect.EffectOn.ON_DAMAGED, dc)

# ============ Aggregation ============
func get_modifier(stat_id: StringName) -> float:
	var arr: Array = _stat_modifiers.get(stat_id, [])
	var result := 1.0
	for m in arr:
		result *= m
	return result

func add_stat_modifier(stat_id: StringName, mult: float) -> void:
	if not _stat_modifiers.has(stat_id):
		_stat_modifiers[stat_id] = []
	_stat_modifiers[stat_id].append(mult)

func remove_stat_modifier(stat_id: StringName, mult: float) -> void:
	var arr: Array = _stat_modifiers.get(stat_id, [])
	arr.erase(mult)

func get_legal_action_locks() -> int:
	var mask := 0
	for inst in active:
		mask |= inst.entity.legal_action_locks
	return mask

func get_top_hit_buff() -> BuffEntity:
	var top: BuffInstance = null
	for inst in active:
		if inst.entity.hit_reaction == &"":
			continue
		if top == null or inst.entity.hit_priority > top.entity.hit_priority:
			top = inst
	return top.entity if top else null

# ============ Internals ============
func _exec_effect(eff: BuffEffect, inst: BuffInstance, delta: float,
				  trigger: int, dc: DamageContext = null) -> void:
	var ctx := _make_ctx(inst, trigger)
	ctx.delta = delta
	ctx.damage_ctx = dc
	eff.execute(ctx)

func _make_ctx(inst: BuffInstance, trigger: int) -> BuffEffectContext:
	var ctx := BuffEffectContext.new()
	ctx.owner = owner_node
	ctx.instance = inst
	ctx.trigger = trigger
	return ctx

func _find_by_id(id: StringName) -> BuffInstance:
	if id == &"":
		return null
	for inst in active:
		if inst.entity.id == id:
			return inst
	return null
