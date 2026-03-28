extends BossState

## DemonSlime Chase 状态

func _init() -> void:
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true

func physics_process_state(_delta: float) -> void:
	var boss := get_boss()
	if not boss or not is_target_alive():
		transitioned.emit(self, "idle")
		return

	var distance := get_distance_to_target()

	if distance > boss.detection_radius:
		transitioned.emit(self, "idle")
		return

	if distance <= boss.attack_range and boss.attack_cooldown <= 0:
		# 从攻击池选择
		var mgr := get_attack_manager()
		var entry := mgr.pick_attack() if mgr else {}
		var mode: String = entry.get("mode", "cleave")
		if mode == "slam":
			transitioned.emit(self, "slam")
		elif mode.begins_with("combo"):
			transitioned.emit(self, "cleave")  # combo 由 cleave 状态驱动
		else:
			transitioned.emit(self, "cleave")
		return

	var ds := boss as DemonSlime
	var direction := (target_node.global_position - boss.global_position).normalized()
	boss.velocity = direction * ds.move_speed
	set_locomotion(Vector2(direction.x, 1.0))

func exit() -> void:
	var boss := get_boss()
	if boss:
		boss.velocity = Vector2.ZERO
	set_locomotion(Vector2.ZERO)
