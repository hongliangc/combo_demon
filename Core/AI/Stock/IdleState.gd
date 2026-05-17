extends AIState

## Stock Idle — stops movement. AnimationDriver auto-locomotion handles idle animation.
## Optional timer: when max_time > 0, dispatches EV_ATTACK_FINISHED after a
## random/fixed wait (mirrors WanderState) so idle↔wander cycles can be built.

@export var min_time: float = 0.0
@export var max_time: float = 0.0

var _timer: Timer

func enter() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	if max_time > 0.0:
		_ensure_timer()
		_timer.wait_time = randf_range(min_time, max_time)
		_timer.start()

func exit() -> void:
	if _timer:
		_timer.stop()

func _ensure_timer() -> void:
	if not _timer:
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.timeout.connect(func(): dispatch(AIEvents.EV_ATTACK_FINISHED))
		add_child(_timer)
