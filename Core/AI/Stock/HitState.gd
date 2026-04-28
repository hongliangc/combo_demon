extends AIState

## Stock Hit — 受击反应：查询 BuffController.get_top_hit_buff() 选动画 + 锁时长
## 不再 apply effects（已由 DamagePipeline.post_apply 阶段处理）

@export var default_duration: float = 0.3

var _timer: Timer

func _init() -> void:
	reentrant = true

func enter() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO

	var anim_key: StringName = &"hit"
	var duration: float = default_duration

	var bc: BuffController = owner_node.get_node_or_null(^"BuffController")
	if bc:
		var resolved := bc.resolve_hit_anim(anim_key, duration)
		anim_key = resolved[&"anim"]
		duration = resolved[&"duration"]

	if "anim_player" in owner_node and owner_node.anim_player:
		if owner_node.anim_player.has_animation(anim_key):
			owner_node.anim_player.play(anim_key)
			owner_node.anim_player.seek(0.0, true)

	_ensure_timer()
	_timer.wait_time = duration
	_timer.start()

func physics_update(delta: float) -> void:
	if owner_node is CharacterBody2D:
		var body := owner_node as CharacterBody2D
		body.velocity = body.velocity.lerp(Vector2.ZERO, 8.0 * delta)

func exit() -> void:
	if _timer:
		_timer.stop()
	bb.set_var(&"recently_hit", false)

func _ensure_timer() -> void:
	if not _timer:
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.timeout.connect(func(): dispatch(AIEvents.EV_HIT_RECOVERED))
		add_child(_timer)
