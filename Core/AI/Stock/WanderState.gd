extends AIState

## Stock Wander — 水平随机巡逻,遇边缘/墙自动掉头,定时结束

@export var default_speed: float = 50.0
@export var min_time: float = 2.0
@export var max_time: float = 5.0

var _dir: int = 1
var _timer: Timer

func enter() -> void:
	_dir = 1 if randf() < 0.5 else -1
	if "anim_player" in owner_node and owner_node.anim_player:
		if owner_node.anim_player.has_animation(&"walk"):
			owner_node.anim_player.play(&"walk")
	_ensure_timer()
	_timer.wait_time = randf_range(min_time, max_time)
	_timer.start()

func physics_update(_delta: float) -> void:
	if owner_node is not CharacterBody2D:
		return
	var body := owner_node as CharacterBody2D
	var speed := float(bb.get_var(&"wander_speed", default_speed))
	if owner_node.has_method(&"can_move_dir") and not owner_node.can_move_dir(_dir):
		_dir = -_dir
	body.velocity.x = float(_dir) * speed

func exit() -> void:
	if _timer:
		_timer.stop()
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity.x = 0.0

func _ensure_timer() -> void:
	if not _timer:
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.timeout.connect(func(): dispatch(AIEvents.EV_ATTACK_FINISHED))
		add_child(_timer)
