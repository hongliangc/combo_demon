extends BossState

## BladeKeeper Idle 状态

@export var idle_time := 2.0
var _timer: SceneTreeTimer

func _init() -> void:
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true

func enter() -> void:
	var boss := get_boss()
	if boss:
		boss.velocity = Vector2.ZERO
	set_locomotion(Vector2.ZERO)
	_timer = get_tree().create_timer(idle_time)
	_timer.timeout.connect(_on_idle_timeout)

func process_state(_delta: float) -> void:
	var next := evaluate_combat_transition()
	if next != "idle" and next != "patrol":
		transitioned.emit(self, next)

func _on_idle_timeout() -> void:
	if is_target_alive():
		transitioned.emit(self, "chase")

func exit() -> void:
	if _timer and _timer.timeout.is_connected(_on_idle_timeout):
		_timer.timeout.disconnect(_on_idle_timeout)
