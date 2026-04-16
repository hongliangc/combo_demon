extends AIState

## Stock Hit — 受击反应：应用 effects，播 hit 动画，timer → dispatch hit_recovered

@export var default_duration: float = 0.3

var _timer: Timer

func enter() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	var damage: Damage = bb.get_var(&"last_damage")
	var attacker_pos: Vector2 = bb.get_var(&"last_attacker_pos", Vector2.ZERO) as Vector2
	if damage and not damage.effects.is_empty():
		for effect in damage.effects:
			if effect:
				effect.apply_effect(owner_node as CharacterBody2D, attacker_pos)
	if "anim_player" in owner_node and owner_node.anim_player:
		if owner_node.anim_player.has_animation(&"hit"):
			owner_node.anim_player.play(&"hit")
	_ensure_timer()
	_timer.wait_time = default_duration
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
