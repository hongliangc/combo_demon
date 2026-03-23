extends BossState

## Boss 追击状态

@export var chase_attack_cooldown := 1.2  # 追击时的攻击冷却

# 追击时攻击冷却计时器
var chase_attack_timer := 0.0

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true
	animation_state = "chase"

func enter():
	DebugConfig.debug("Boss: 进入追击状态", "", "ai")
	chase_attack_timer = 0.0

func physics_process_state(delta: float) -> void:
	if not _boss:
		return

	chase_attack_timer -= delta

	# 统一距离决策
	var next := evaluate_combat_transition()
	if next != "chase":
		transitioned.emit(self, next)
		return

	# 追击玩家，添加一些随机性避免直线追击
	var direction := get_direction_to_target()
	var random_offset := Vector2(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))
	direction = (direction + random_offset).normalized()

	_boss.velocity = direction * _boss.move_speed

	# 追击时发动攻击（边追边打）
	if chase_attack_timer <= 0:
		_perform_chase_attack()
		chase_attack_timer = chase_attack_cooldown

## 追击时发动攻击（从 phase_configs 的 chase_attacks 池中随机选取）
func _perform_chase_attack() -> void:
	var attack_manager := get_attack_manager()
	if not attack_manager:
		return

	var config = _get_phase_config()
	if not config:
		return

	var entry = config.pick_chase_attack()
	if entry.is_empty():
		return

	DebugConfig.debug("Boss 追击时发动攻击", "", "ai")
	_dispatch_attack(attack_manager, entry)

func exit():
	pass
