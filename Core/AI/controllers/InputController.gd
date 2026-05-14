class_name InputController extends BaseController

## Player-input controller — turns Godot InputEvents into AI events.
## Action names per-character via Inspector @export.

@export var attack_action: StringName = &"attack"
@export var jump_action: StringName = &"jump"
@export var dash_action: StringName = &"dash"
@export var special_action: StringName = &"special"
@export var move_left_action: StringName = &"ui_left"
@export var move_right_action: StringName = &"ui_right"

## Horizontal axis read each tick. AgentBase consumes.
var input_dir: float = 0.0
## One-shot jump-press flag. AgentBase consumes via consume_jump().
var jump_pressed: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action(attack_action) and event.is_action_pressed(attack_action):
		dispatch(AIEvents.EV_INPUT_ATTACK)
	elif InputMap.has_action(jump_action) and event.is_action_pressed(jump_action):
		jump_pressed = true
		dispatch(AIEvents.EV_INPUT_JUMP)
	elif InputMap.has_action(dash_action) and event.is_action_pressed(dash_action):
		dispatch(AIEvents.EV_INPUT_DASH)
	elif InputMap.has_action(special_action) and event.is_action_pressed(special_action):
		dispatch(AIEvents.EV_INPUT_SPECIAL)

func tick(delta: float) -> void:
	state_controller.tick(delta)
	if InputMap.has_action(move_left_action) and InputMap.has_action(move_right_action):
		input_dir = Input.get_axis(move_left_action, move_right_action)
	else:
		input_dir = 0.0

## Take and clear the buffered jump press. Returns true if a jump was pending.
func consume_jump() -> bool:
	if jump_pressed:
		jump_pressed = false
		return true
	return false
