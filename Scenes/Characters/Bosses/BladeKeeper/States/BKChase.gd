extends BossState

## BladeKeeper Chase 状态

func _init() -> void:
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true

func enter() -> void:
	pass  # locomotion 由 physics_process 驱动

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
		transitioned.emit(self, "attack")
		return

	# 移动
	var bk := boss as BladeKeeper
	var direction := (target_node.global_position - boss.global_position).normalized()
	boss.velocity = direction * bk.move_speed

	# 更新 locomotion 动画（使用 StateMachine locomotion）
	set_locomotion_state("walk")

func exit() -> void:
	var boss := get_boss()
	if boss:
		boss.velocity = Vector2.ZERO
	set_locomotion_state("idle")
