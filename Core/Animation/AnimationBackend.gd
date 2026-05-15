class_name AnimationBackend extends Node

signal action_finished(action_id: StringName)

var _current_action: StringName = &""

## Called each physics frame by AnimationDriver with agent velocity.
func update_locomotion(_velocity: Vector2) -> void:
	pass

## Execute a one-shot action animation.
## speed_scale: 1.0 = normal, 2.0 = double-speed (Hahashin combos).
func play_action(_action_id: StringName, _speed_scale: float = 1.0) -> void:
	pass

## Cancel current action and return to auto-locomotion.
func stop_action() -> void:
	_current_action = &""

func has_action(_action_id: StringName) -> bool:
	return false

## Returns the currently playing action id, or &"" if locomotion / no action.
func current_action() -> StringName:
	return _current_action

## Semantic flag (combat / injured / aiming...). Backend maps to Godot path.
func receive_flag(_key: StringName, _value: bool) -> void:
	pass

## Semantic float param (aim_weight / blend_amount...). Backend maps to Godot path.
func receive_param(_key: StringName, _value: float) -> void:
	pass

## runtime → semantic event conversion.
## Subclasses MAY override (e.g. to reset speed_scale) but MUST call super._on_anim_finished(anim_name).
func _on_anim_finished(anim_name: StringName) -> void:
	if anim_name != _current_action:
		return
	var done := _current_action
	_current_action = &""
	action_finished.emit(done)
