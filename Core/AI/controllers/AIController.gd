class_name AIController extends BaseController

## AI brain — owns blackboard, finds target, polls guards, picks skills.
## Drives StateController.tick on physics frames.

@export var target_group: StringName = &"player"

var blackboard: AIBlackboard
var target_node: Node

# Legacy passthrough — stock states use ai.current_skill until Phase 6 migration
var current_skill: Skill:
	get: return state_controller.current_skill if state_controller else null
	set(v): if state_controller: state_controller.current_skill = v

func bind(a: AgentBase, sc: StateController, ss: SkillSet) -> void:
	super.bind(a, sc, ss)
	blackboard = AIBlackboard.new()
	# Inject blackboard into every state already collected by StateController.setup()
	for state in sc.states.values():
		(state as AIState).bb = blackboard

func _ready() -> void:
	call_deferred("_deferred_init")

func _deferred_init() -> void:
	_find_target()
	if state_controller:
		state_controller.enter_initial()

func _find_target() -> void:
	if target_group != &"":
		target_node = agent.get_tree().get_first_node_in_group(target_group)

func tick(delta: float) -> void:
	_update_blackboard(delta)
	state_controller.tick(delta)

func _update_blackboard(_delta: float) -> void:
	if is_instance_valid(target_node) and agent is Node2D:
		var dist: float = (agent as Node2D).global_position.distance_to(
			(target_node as Node2D).global_position)
		blackboard.set_var(&"distance", dist)
		blackboard.set_var(&"target_position", (target_node as Node2D).global_position)
		blackboard.set_var(&"target_alive",
			target_node.get("alive") if "alive" in target_node else true)
	else:
		blackboard.set_var(&"distance", INF)
		blackboard.set_var(&"target_alive", false)

func pick_skill(scope: StringName = &"") -> Skill:
	if scope == &"":
		return skill_set.pick(agent, blackboard)
	return skill_set.pick_tagged(scope, agent, blackboard)

# Legacy passthrough — AttackDispatcher uses ai.goto() until Phase 6 migration
func goto(state_name: StringName) -> void:
	if state_controller:
		state_controller.goto(state_name)
