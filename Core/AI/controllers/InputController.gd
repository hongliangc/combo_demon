class_name InputController extends BaseController

## Player-input controller — turns Godot InputEvents into AI events.
## Action names per-character via Inspector @export.

@export var attack_action: StringName = &"attack"
@export var jump_action: StringName = &"jump"
@export var dash_action: StringName = &"dash"
@export var special_action: StringName = &"special"
@export var move_left_action: StringName = &"ui_left"
@export var move_right_action: StringName = &"ui_right"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(attack_action):
		dispatch(AIEvents.EV_INPUT_ATTACK)
	elif event.is_action_pressed(jump_action):
		dispatch(AIEvents.EV_INPUT_JUMP)
	elif event.is_action_pressed(dash_action):
		dispatch(AIEvents.EV_INPUT_DASH)
	elif event.is_action_pressed(special_action):
		dispatch(AIEvents.EV_INPUT_SPECIAL)

func tick(delta: float) -> void:
	state_controller.tick(delta)
	# Movement axis read directly (not event-driven)
	var dir := Input.get_axis(move_left_action, move_right_action)
	agent.set_meta("input_dir", dir)
