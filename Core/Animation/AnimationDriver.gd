class_name AnimationDriver extends Node

## Runtime Animation Facade.
## AgentBase calls tick(velocity) every physics frame; Driver delegates locomotion to backend.
## States call play_action() for one-shot animations (attack / hit / death).
## future upgrade path: play_action() → ActionHandle; _backend → multi-slot Dictionary

signal action_finished(action_id: StringName)

var _backend: AnimationBackend

func setup() -> void:
	for child in get_children():
		if child is AnimationBackend:
			_backend = child
			break
	if _backend:
		_backend.action_finished.connect(_on_backend_finished)
	else:
		push_warning("AnimationDriver on '%s' has no AnimationBackend child — animations disabled." % [get_parent().name if get_parent() else name])

## Called by AgentBase._physics_process after move_and_slide(). Drives locomotion.
## Driver does not register its own _physics_process — keeps ownership explicit.
func tick(velocity: Vector2, on_floor: bool) -> void:
	if _backend:
		_backend.update_locomotion(velocity, on_floor)

## speed_scale: pass 2.0 for Hahashin combo attacks, 1.0 (default) otherwise.
func play_action(action_id: StringName, speed_scale: float = 1.0) -> void:
	if _backend:
		_backend.play_action(action_id, speed_scale)
	else:
		# 无 backend 时仍兑现 action_finished 契约,避免等待它的状态卡死。
		action_finished.emit.call_deferred(action_id)

func stop_action() -> void:
	if _backend:
		_backend.stop_action()

func set_flag(key: StringName, value: bool) -> void:
	if _backend:
		_backend.receive_flag(key, value)

func set_param(key: StringName, value: float) -> void:
	if _backend:
		_backend.receive_param(key, value)

func has_action(action_id: StringName) -> bool:
	return _backend != null and _backend.has_action(action_id)

func current_action() -> StringName:
	return _backend.current_action() if _backend else &""

func _on_backend_finished(action_id: StringName) -> void:
	action_finished.emit(action_id)
