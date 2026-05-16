extends AIState

## Stock Stun — 眩晕动画 + timer → dispatch stun_recovered

@export var default_duration: float = 1.5

var _timer: Timer

func enter() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	if agent and agent.anim.has_action(&"stunned"):
		agent.anim.play_action(&"stunned")
	_ensure_timer()
	_timer.wait_time = default_duration
	_timer.start()

func exit() -> void:
	if _timer:
		_timer.stop()

func _ensure_timer() -> void:
	if not _timer:
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.timeout.connect(func(): dispatch(AIEvents.EV_STUN_RECOVERED))
		add_child(_timer)
