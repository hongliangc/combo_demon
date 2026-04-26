# Core/Components/HealthComponent.gd
extends Node
class_name HealthComponent

## Thin HP container. Subscribes DamagePipeline.apply only — no buff awareness.
## Death is signaled to AAB; reset_health is exposed for spawning/respawn.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source_pos: Vector2)
signal died

@export_group("Health")
@export var max_health: float = 100.0
@export var health: float = 100.0

@export_group("Damage Display")
@export var critical_threshold: float = 0.8

var is_alive: bool = true

@onready var owner_body: Node = get_parent()
@onready var pipeline: DamagePipeline = owner_body.get_node_or_null(^"DamagePipeline") if owner_body else null

func _ready() -> void:
	if health <= 0.0:
		health = max_health
	if pipeline:
		pipeline.apply.connect(_commit)
	call_deferred(&"_emit_initial_health")

func _emit_initial_health() -> void:
	health_changed.emit(health, max_health)

# ============ Pipeline subscriber ============
func _commit(ctx: DamageContext) -> void:
	if ctx.target != owner_body or not is_alive:
		return
	var prev := health
	if ctx.is_heal:
		health = minf(health + ctx.amount, max_health)
		ctx.dealt = health - prev
	else:
		health = clampf(health - ctx.amount, 0.0, max_health)
		ctx.dealt = prev - health
		if ctx.dealt > 0.0:
			damaged.emit(ctx.dealt, ctx.source_pos)
			_display_damage_number(ctx.dealt, ctx.tags)
	health_changed.emit(health, max_health)
	if health <= 0.0 and is_alive:
		is_alive = false
		died.emit()

# ============ External entry points ============
func heal(amount: float) -> void:
	if not is_alive or pipeline == null:
		return
	var ctx := DamageContext.new()
	ctx.target = owner_body
	ctx.is_heal = true
	ctx.raw_amount = amount
	ctx.amount = amount
	pipeline.process(ctx)

func reset_health() -> void:
	health = max_health
	is_alive = true
	health_changed.emit(health, max_health)

func get_health_percent() -> float:
	return health / max_health if max_health > 0.0 else 0.0

func is_character_alive() -> bool:
	return is_alive

# ============ Internals ============
func _display_damage_number(amount: float, _tags: int) -> void:
	if owner_body == null:
		return
	var anchor := owner_body.get_node_or_null(^"DamageNumbersAnchor")
	if anchor:
		var is_critical := false
		if max_health > 0.0:
			is_critical = amount > max_health * critical_threshold
		DamageNumbers.display_number(int(amount), anchor.global_position, is_critical)
