extends BossState

## DemonSlime Stun 状态

@export var stun_duration := 1.5

var _timer: SceneTreeTimer

func _init() -> void:
	priority = StatePriority.CONTROL
	can_be_interrupted = false

func enter() -> void:
	var boss := get_boss()
	if boss:
		boss.stunned = true
		boss.velocity = Vector2.ZERO
	enter_control_state("stun")
	_timer = get_tree().create_timer(stun_duration)
	_timer.timeout.connect(_on_stun_timeout)

func _on_stun_timeout() -> void:
	var boss := get_boss()
	if boss:
		boss.stunned = false
		boss.stun_immunity = 1.5
	exit_control_state()
	var next := evaluate_combat_transition()
	transitioned.emit(self, next)

func on_damaged(damage: Damage, _attacker_position: Vector2 = Vector2.ZERO) -> void:
	# Phase 3 免疫眩晕
	var boss := get_boss()
	if boss and boss.current_phase == BossBase.Phase.PHASE_3:
		return
	# 刷新眩晕
	for effect in damage.effects:
		if effect is StunEffect:
			if _timer and _timer.timeout.is_connected(_on_stun_timeout):
				_timer.timeout.disconnect(_on_stun_timeout)
			_timer = get_tree().create_timer(stun_duration)
			_timer.timeout.connect(_on_stun_timeout)
			return

func exit() -> void:
	if _timer and _timer.timeout.is_connected(_on_stun_timeout):
		_timer.timeout.disconnect(_on_stun_timeout)
	var boss := get_boss()
	if boss:
		boss.stunned = false
