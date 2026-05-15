extends GutTest

func _make_driver_with_backend() -> Dictionary:
	var driver := AnimationDriver.new()
	var backend := AnimationBackend.new()
	backend.name = "Backend"
	driver.add_child(backend)
	add_child_autofree(driver)
	return {driver = driver, backend = backend}

func test_setup_finds_first_animationbackend_child() -> void:
	var d := _make_driver_with_backend()
	d.driver.setup()
	assert_eq(d.driver._backend, d.backend)

func test_tick_without_backend_does_not_crash() -> void:
	var driver := AnimationDriver.new()
	add_child_autofree(driver)
	driver.setup()
	driver.tick(Vector2(100, 0))   # no backend — must not crash
	assert_true(true, "no crash — null-safe tick guard works")

func test_action_finished_propagates_from_backend() -> void:
	var d := _make_driver_with_backend()
	d.driver.setup()
	var propagated: Array[StringName] = []
	d.driver.action_finished.connect(func(id): propagated.append(id))
	d.backend.action_finished.emit(&"attack")
	assert_eq(propagated.size(), 1)
	assert_eq(propagated[0], &"attack")

func test_no_backend_set_flag_does_not_crash() -> void:
	var driver := AnimationDriver.new()
	add_child_autofree(driver)
	driver.setup()
	driver.set_flag(&"combat", true)
	driver.set_param(&"aim", 0.5)
	driver.play_action(&"attack")
	driver.stop_action()
	assert_true(true, "no crash — all delegation methods null-safe")

func test_has_action_returns_false_without_backend() -> void:
	var driver := AnimationDriver.new()
	add_child_autofree(driver)
	driver.setup()
	assert_false(driver.has_action(&"attack"))

func test_tick_delegates_velocity_to_backend() -> void:
	## Verify Driver.tick(velocity) calls backend.update_locomotion(velocity).
	## Uses AnimationPlayerBackend (already tested) as concrete stub.
	var driver := AnimationDriver.new()
	var ap := AnimationPlayer.new()
	ap.name = "AP"
	driver.add_child(ap)
	var lib := AnimationLibrary.new()
	for n in [&"idle", &"walk"]:
		var a := Animation.new()
		a.length = 0.5
		lib.add_animation(n, a)
	ap.add_animation_library(&"", lib)
	var b := AnimationPlayerBackend.new()
	b.player = ap
	driver.add_child(b)
	add_child_autofree(driver)
	driver.setup()
	driver.tick(Vector2(100, 0))
	assert_eq(ap.current_animation, "walk", "tick(walk velocity) → walk anim")
	driver.tick(Vector2.ZERO)
	assert_eq(ap.current_animation, "idle", "tick(zero velocity) → idle anim")
