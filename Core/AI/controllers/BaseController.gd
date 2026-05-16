class_name BaseController extends Node

## Abstract controller — decides which events get dispatched to StateController.
## Three concrete subclasses: AIController, InputController, PossessionController (future).

var agent: AgentBase
var state_controller: StateController
var skill_set: SkillSet

func bind(a: AgentBase, sc: StateController, ss: SkillSet) -> void:
	agent = a
	state_controller = sc
	skill_set = ss

func tick(_delta: float) -> void:
	pass

func dispatch(event: StringName) -> void:
	if state_controller:
		state_controller.dispatch(event)
