extends GutTest

var backend: AnimationBackend

func before_each() -> void:
	backend = AnimationBackend.new()
	add_child_autofree(backend)

func test_stale_guard_ignores_old_action() -> void:
	## _on_anim_finished must not emit when anim_name != _current_action
	var emitted := false
	backend.action_finished.connect(func(_id): emitted = true)
	backend._current_action = &"death"           # simulate new action took over
	backend._on_anim_finished(&"attack")          # stale callback
	assert_false(emitted, "stale callback must not emit action_finished")

func test_stale_guard_emits_for_current_action() -> void:
	# Use Array to work around GDScript StringName lambda capture copy semantics
	var received: Array[StringName] = []
	backend.action_finished.connect(func(id): received.append(id))
	backend._current_action = &"hit"
	backend._on_anim_finished(&"hit")
	assert_eq(received.size(), 1)
	assert_eq(received[0], &"hit")

func test_stop_action_clears_current_action() -> void:
	var emitted := false
	backend.action_finished.connect(func(_id): emitted = true)
	backend._current_action = &"attack"
	backend.stop_action()
	assert_eq(backend._current_action, &"")
	assert_false(emitted, "stop_action must not emit action_finished")


# --- AnimationPlayerBackend tests ---

func _make_player_backend() -> AnimationPlayerBackend:
	var ap := AnimationPlayer.new()
	ap.name = "AP"
	add_child_autofree(ap)
	var lib := AnimationLibrary.new()
	for anim_name in [&"idle", &"walk", &"attack", &"hit", &"death"]:
		var a := Animation.new()
		a.length = 0.5
		lib.add_animation(anim_name, a)
	ap.add_animation_library(&"", lib)
	var b := AnimationPlayerBackend.new()
	b.player = ap
	add_child_autofree(b)
	return b

func test_player_backend_plays_idle_when_stopped() -> void:
	var b := _make_player_backend()
	b.update_locomotion(Vector2.ZERO, true)
	assert_eq(b.player.current_animation, "idle")

func test_player_backend_plays_walk_when_moving() -> void:
	var b := _make_player_backend()
	b.update_locomotion(Vector2(100, 0), true)
	assert_eq(b.player.current_animation, "walk")

func test_player_backend_sets_current_action_on_play() -> void:
	var b := _make_player_backend()
	b.play_action(&"attack")
	assert_eq(b._current_action, &"attack")

func test_player_backend_skips_locomotion_during_action() -> void:
	var b := _make_player_backend()
	b.play_action(&"attack")
	b.update_locomotion(Vector2.ZERO, true)
	assert_eq(b.player.current_animation, "attack",
		"locomotion must not override an active action")

func test_player_backend_has_action_returns_false_for_missing_anim() -> void:
	var b := _make_player_backend()
	assert_false(b.has_action(&"nonexistent"))

func test_player_backend_has_action_returns_true_for_existing() -> void:
	var b := _make_player_backend()
	assert_true(b.has_action(&"attack"))

func test_player_backend_stop_action_resets_speed_scale() -> void:
	var b := _make_player_backend()
	b.play_action(&"attack", 2.0)
	assert_eq(b.player.speed_scale, 2.0)
	b.stop_action()
	assert_eq(b.player.speed_scale, 1.0)
