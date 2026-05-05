class_name StateController extends Node

## Transition table + dispatch + tick. Owned by AgentBase as a child node.
## States are direct children of this node (no nested StateMachine container).

@export var initial_state_name: StringName = &"idle"
@export var safety_tick_interval: float = 0.2

var agent: AgentBase
var current_state: AIState
var states: Dictionary = {}        # StringName → AIState
var transitions: Array = []        # Array of _Transition

# Currently executing skill (set by AttackDispatcher / ComboState; cleared on attack_finished)
var current_skill: Skill = null

var _tick_accum: float = 0.0

class _Transition:
	var from_state: AIState
	var to_state: AIState
	var event: StringName
	var guard: Callable
	var priority: int

func setup(a: AgentBase) -> void:
	agent = a
	for child in get_children():
		if child is AIState:
			var s := child as AIState
			s.agent = a
			s.bb = null   # blackboard (if any) injected later by AIController
			s.owner_node = a
			states[StringName(s.name.to_lower())] = s

func add_transition(from: AIState, to: AIState, event: StringName = &"",
		guard: Callable = Callable(), priority: int = 0) -> void:
	var t := _Transition.new()
	t.from_state = from
	t.to_state = to
	t.event = event
	t.guard = guard
	t.priority = priority
	transitions.append(t)
	transitions.sort_custom(func(a, b): return a.priority > b.priority)

func enter_initial() -> void:
	var s: AIState = states.get(initial_state_name)
	if s:
		current_state = s
		current_state.enter()

func get_state(state_name: StringName) -> AIState:
	return states.get(state_name)

func get_current_state_name() -> StringName:
	return StringName(current_state.name.to_lower()) if current_state else &""

func goto(state_name: StringName) -> void:
	var s: AIState = get_state(state_name)
	if s:
		_change_state(s)

func dispatch(event: StringName) -> void:
	if current_state == null or event == &"":
		return
	if current_skill and not current_skill.interruptible:
		if event != AIEvents.EV_DIED and event != AIEvents.EV_ATTACK_FINISHED:
			return
	for t in transitions:
		if t.event != event:
			continue
		if t.from_state != null and t.from_state != current_state:
			continue
		if t.guard.is_valid() and not t.guard.call():
			continue
		_change_state(t.to_state)
		return

func tick(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)
		current_state.update(delta)
	_tick_accum += delta
	if _tick_accum >= safety_tick_interval:
		_tick_accum = 0.0
		_evaluate_conditional_transitions()

func _evaluate_conditional_transitions() -> void:
	if current_state == null:
		return
	for t in transitions:
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
	if new_state == current_state and not new_state.reentrant:
		return
	if current_state:
		current_state.exit()
	current_state = new_state
	current_state.enter()
