extends AIState

## DS2 Roll — 翻滚回避

@export var roll_speed: float = 200.0
@export var roll_duration: float = 0.4

var _direction: Vector2
var _timer: Timer

func enter() -> void:
	var attacker_pos: Vector2 = bb.get_var(&"last_attacker_pos", Vector2.ZERO)
	if owner_node is CharacterBody2D and attacker_pos != Vector2.ZERO:
		_direction = ((owner_node as CharacterBody2D).global_position - attacker_pos).normalized()
	else:
		_direction = Vector2.RIGHT
	_ensure_timer()
	_timer.wait_time = roll_duration
	_timer.start()

func physics_update(_delta: float) -> void:
	if owner_node is CharacterBody2D:
		var body := owner_node as CharacterBody2D
		body.velocity = _direction * roll_speed
		body.move_and_slide()

func exit() -> void:
	if _timer:
		_timer.stop()
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO

func _ensure_timer() -> void:
	if not _timer:
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.timeout.connect(func(): dispatch(AIEvents.EV_REACTION_DONE))
		add_child(_timer)
