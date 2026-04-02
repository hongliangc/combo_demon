extends EnemyStateMachine
class_name BossStateMachine

## 通用 Boss 状态机基类
## 提供阶段转换保护，子类只需实现 _get_phase_route()

var is_transitioning_phase := false

@export var phase_transition_duration := 0.3  ## 阶段转换保护时长

func _setup_signals() -> void:
	super._setup_signals()
	if owner_node and owner_node.has_signal("phase_changed"):
		if not owner_node.is_connected("phase_changed", _on_phase_changed):
			owner_node.phase_changed.connect(_on_phase_changed)

func _on_owner_damaged(damage: Damage, attacker_position: Vector2 = Vector2.ZERO) -> void:
	if is_transitioning_phase:
		return
	super._on_owner_damaged(damage, attacker_position)

func _on_phase_changed(new_phase: int) -> void:
	is_transitioning_phase = true

	var target_state := _get_phase_route(new_phase)
	if target_state != "" and states.has(target_state):
		force_transition(target_state)

	await get_tree().create_timer(phase_transition_duration).timeout
	if not is_instance_valid(self):
		return
	is_transitioning_phase = false

## 子类钩子：返回阶段切换时的目标状态名，空字符串表示不强制切换
func _get_phase_route(_new_phase: int) -> String:
	return ""
