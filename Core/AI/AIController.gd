class_name AIController extends Node

## AI 总控制器 — 转换表（代码注册）+ 事件分派 + 条件式 safety tick
## 学 LimboAI hsm: add_transition(from, to, event, guard) + dispatch(event)

@export var initial_state_name: StringName = &"idle"
@export var safety_tick_interval: float = 0.2
@export var target_group: StringName = &"player"

var blackboard: AIBlackboard
var owner_node: Node
var target_node: Node
var states: Dictionary = {}       # StringName → State
var current_state: AIState
var ANYSTATE: AIState = null        # 哨兵值，null = 通配

var _transitions: Array = []
var _tick_accum: float = 0.0

# ---- 内部转换结构 ----
class _Transition:
	var from_state: AIState
	var to_state: AIState
	var event: StringName
	var guard: Callable
	var priority: int

## 注册转换规则
func add_transition(from: AIState, to: AIState, event: StringName = &"",
		guard: Callable = Callable(), priority: int = 0) -> void:
	var t := _Transition.new()
	t.from_state = from
	t.to_state = to
	t.event = event
	t.guard = guard
	t.priority = priority
	_transitions.append(t)
	_transitions.sort_custom(func(a, b): return a.priority > b.priority)

func _ready() -> void:
	owner_node = get_owner()
	blackboard = AIBlackboard.new()
	_collect_states()
	call_deferred("_deferred_init")

func _deferred_init() -> void:
	_find_target()
	_enter_initial_state()

func _collect_states() -> void:
	var container := get_node_or_null(^"StateMachine")
	if not container:
		return
	for child in container.get_children():
		if child is AIState:
			var s := child as AIState
			s.ai = self
			s.bb = blackboard
			s.owner_node = owner_node
			states[StringName(s.name.to_lower())] = s

func _find_target() -> void:
	if target_group != &"":
		target_node = get_tree().get_first_node_in_group(target_group)

func _enter_initial_state() -> void:
	var s: AIState = states.get(initial_state_name)
	if s:
		current_state = s
		current_state.enter()

# ---- 主循环 ----
func _physics_process(delta: float) -> void:
	_update_blackboard(delta)
	if current_state:
		current_state.physics_update(delta)
	_tick_accum += delta
	if _tick_accum >= safety_tick_interval:
		_tick_accum = 0.0
		_evaluate_conditional_transitions()

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

# ---- Blackboard 更新（仅计算值 — 属性用 bind）----
func _update_blackboard(delta: float) -> void:
	if is_instance_valid(target_node) and owner_node is Node2D:
		var dist: float = (owner_node as Node2D).global_position.distance_to(
			(target_node as Node2D).global_position)
		blackboard.set_var(&"distance", dist)
		blackboard.set_var(&"target_position", (target_node as Node2D).global_position)
		blackboard.set_var(&"target_alive",
			target_node.get("alive") if "alive" in target_node else true)
	else:
		blackboard.set_var(&"distance", INF)
		blackboard.set_var(&"target_alive", false)
	var atk_cd: float = blackboard.get_var(&"attack_cooldown", 0.0)
	if atk_cd > 0:
		blackboard.set_var(&"attack_cooldown", maxf(0.0, atk_cd - delta))
	var gcd: float = blackboard.get_var(&"global_cooldown", 0.0)
	if gcd > 0:
		blackboard.set_var(&"global_cooldown", maxf(0.0, gcd - delta))

# ---- 事件分派 ----
func dispatch(event: StringName) -> void:
	if current_state == null or event == &"":
		return
	for t in _transitions:
		if t.event != event:
			continue
		if t.from_state != null and t.from_state != current_state:
			continue
		if t.guard.is_valid() and not t.guard.call():
			continue
		_change_state(t.to_state)
		return

## 条件式转换评估（event 为空的规则，safety tick 时调用）
func _evaluate_conditional_transitions() -> void:
	if current_state == null:
		return
	for t in _transitions:
		if t.event != &"":
			continue
		if t.from_state != null and t.from_state != current_state:
			continue
		if t.guard.is_valid() and not t.guard.call():
			continue
		_change_state(t.to_state)
		return

func _change_state(new_state: AIState) -> void:
	if new_state == null:
		return
	if current_state:
		current_state.exit()
	current_state = new_state
	current_state.enter()
	DebugConfig.debug("[AI] → %s" % new_state.name, "", "state_machine")

func get_current_state_name() -> StringName:
	return StringName(current_state.name.to_lower()) if current_state else &""

func get_state(state_name: StringName) -> AIState:
	return states.get(state_name)
