extends BossState

## BladeKeeper Defend 状态 — 格挡 + 反击

@export var defend_duration := 1.5
@export var counter_damage_multiplier := 1.5

var _timer: SceneTreeTimer
var _took_hit := false
var _anim_tree_ref: AnimationTree

func _init() -> void:
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true

func enter() -> void:
	_took_hit = false
	_anim_tree_ref = get_anim_tree()
	enter_control_state("defend")
	_timer = get_tree().create_timer(defend_duration)
	_timer.timeout.connect(_on_defend_timeout)

func on_damaged(damage: Damage, _attacker_position: Vector2 = Vector2.ZERO) -> void:
	# 格挡期间受击：减半伤害 + 标记反击
	_took_hit = true
	var boss := get_boss()
	if boss and boss.health_component:
		# 恢复 50% 伤害（模拟减伤）
		boss.health_component.heal(damage.amount * 0.5)

func _on_defend_timeout() -> void:
	exit_control_state()
	if _took_hit:
		# 反击：立即进入攻击（伤害加成由 BKAttack 读取）
		transitioned.emit(self, "attack")
	else:
		var next := evaluate_combat_transition()
		transitioned.emit(self, next)

func exit() -> void:
	if _timer and _timer.timeout.is_connected(_on_defend_timeout):
		_timer.timeout.disconnect(_on_defend_timeout)
