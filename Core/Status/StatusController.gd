# Core/Status/StatusController.gd
class_name StatusController extends Node

## Aggregates LegalAction bitmask from active buffs and per-action timers.
## Subscribes pipeline.pre_apply to enforce HURTABLE.

signal legal_actions_changed(prev: int, new: int)

const _ACTION_BITS := [
	LegalAction.ATTACK,
	LegalAction.MOVE,
	LegalAction.DEFEND,
	LegalAction.CAST,
	LegalAction.HURTABLE,
]

var legal_actions: int = LegalAction.ALL
var _action_timers: Dictionary = {}     # bit → remaining float

@onready var owner_node: Node = get_parent()
@onready var pipeline: DamagePipeline = owner_node.get_node_or_null(^"DamagePipeline") if owner_node else null
@onready var bc: BuffController = owner_node.get_node_or_null(^"BuffController") if owner_node else null

func _ready() -> void:
	if pipeline:
		pipeline.pre_apply.connect(_on_pre_apply)
	if bc:
		bc.buffs_changed.connect(_recompute_buff_locks)

func _process(delta: float) -> void:
	if _action_timers.is_empty():
		return
	var prev := legal_actions
	var to_clear: Array = []
	for bit in _action_timers.keys():
		_action_timers[bit] -= delta
		if _action_timers[bit] <= 0.0:
			to_clear.append(bit)
	for k in to_clear:
		_action_timers.erase(k)
	_recompute_legal_actions()
	if legal_actions != prev:
		legal_actions_changed.emit(prev, legal_actions)

# ============ Public API ============
func apply_lock(action_mask: int, duration: float) -> void:
	var prev := legal_actions
	for bit in _ACTION_BITS:
		if action_mask & bit:
			var cur: float = _action_timers.get(bit, 0.0)
			if duration > cur:
				_action_timers[bit] = duration
	_recompute_legal_actions()
	if legal_actions != prev:
		legal_actions_changed.emit(prev, legal_actions)

func release_lock(action_mask: int) -> void:
	var prev := legal_actions
	for bit in _ACTION_BITS:
		if action_mask & bit:
			_action_timers.erase(bit)
	_recompute_legal_actions()
	if legal_actions != prev:
		legal_actions_changed.emit(prev, legal_actions)

func has_legal_action(action: int) -> bool:
	return (legal_actions & action) == action

func can_attack() -> bool: return has_legal_action(LegalAction.ATTACK)
func can_move() -> bool:   return has_legal_action(LegalAction.MOVE)
func can_be_hit() -> bool: return has_legal_action(LegalAction.HURTABLE)

# ============ Pipeline subscription ============
func _on_pre_apply(ctx: DamageContext) -> void:
	if ctx.target != owner_node:
		return
	if ctx.is_heal:
		return
	if not has_legal_action(LegalAction.HURTABLE):
		ctx.blocked = true

# ============ Recompute ============
func _recompute_legal_actions() -> void:
	var locked := 0
	for bit in _action_timers.keys():
		locked |= bit
	if bc:
		locked |= bc.get_legal_action_locks()
	legal_actions = LegalAction.ALL & ~locked

func _recompute_buff_locks() -> void:
	var prev := legal_actions
	_recompute_legal_actions()
	if legal_actions != prev:
		legal_actions_changed.emit(prev, legal_actions)
