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
	var _boss_dbg := owner_node as BossBase
	var _st_name: String = str(current_state.name) if current_state else "null"
	if _boss_dbg:
		print("[BossSM] _on_owner_damaged: boss=%s state=%s phase_lock=%s poise=%s/%s(on=%s) evasion=%s stun_imm=%.2f" % [
			_boss_dbg.name, _st_name, is_transitioning_phase,
			_boss_dbg.current_poise, _boss_dbg.max_poise, _boss_dbg.poise_enabled,
			_boss_dbg.evasion_enabled, _boss_dbg.stun_immunity])
	if is_transitioning_phase:
		return

	# Boss 受伤拦截：poise/evasion 检查必须在这里执行
	# 原因：HealthComponent.apply_attack_effects() 在 damaged 信号之前执行，
	# StunEffect 会 force_transition("stun")，导致 current_state 已变成 StunState。
	# StunState 继承 BaseState 而非 BossState，不包含 poise/evasion 逻辑。
	# 因此将检查提升到状态机层面，直接读取 Boss 数据判断。
	var boss := owner_node as BossBase
	if boss:
		if boss.stun_immunity > 0:
			return

		# Poise 检查（优先于闪避和 stun）
		if boss.poise_enabled and boss.take_poise_hit():
			print("[BossStateMachine] poise broken → counter")
			force_transition("counter")
			return

		# 闪避检查：概率触发 defend 或 roll
		if boss.evasion_enabled:
			var chance: float = boss.evasion_chance_per_phase.get(boss.current_phase, 0.0)
			if chance > 0 and randf() < chance:
				var evasion_state: String = ["defend", "roll"].pick_random()
				print("[BossStateMachine] evasion triggered → %s" % evasion_state)
				force_transition(evasion_state)
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
