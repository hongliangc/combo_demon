extends BossState
class_name BossCounterState

## Boss 反击状态 — poise 归零后触发
## 流程：震退(stagger) + VFX → 选反击招式 → 执行攻击 → 重置 poise → 转出
##
## 优先级 REACTION + stun_immunity 保护，防止反击被眩晕打断

enum Phase { STAGGER, COUNTER_ATTACK }

@export var stagger_duration := 0.4  ## 震退阶段时长

var _phase: Phase = Phase.STAGGER
var _stagger_timer: SceneTreeTimer
var _counter_entry: Dictionary = {}

func _init() -> void:
	priority = StatePriority.REACTION
	can_be_interrupted = false

func enter() -> void:
	var boss := get_boss()
	if not boss:
		transitioned.emit(self, "idle")
		return

	_phase = Phase.STAGGER

	# 设置 stun_immunity 防止被打断
	boss.stun_immunity = stagger_duration + 2.0  # 留足反击动画时间
	boss.velocity = Vector2.ZERO
	boss.can_move = false

	# 播放 hit 动画作为震退
	enter_control_state("hit")

	# 触发红色闪光 VFX
	_spawn_counter_vfx(boss)

	# 震退计时器
	_stagger_timer = get_tree().create_timer(stagger_duration)
	_stagger_timer.timeout.connect(_on_stagger_finished)

	DebugConfig.debug("[BossCounter] 进入震退阶段", "", "combat")

func _spawn_counter_vfx(boss: BossBase) -> void:
	var sprite := boss.get_node_or_null("AnimatedSprite2D") as Node2D
	if not sprite:
		return
	CounterFlashEffect.create(sprite, boss.global_position, boss)

func _on_stagger_finished() -> void:
	_phase = Phase.COUNTER_ATTACK

	# 从攻击池选反击招式
	var mgr := get_attack_manager()
	if not mgr:
		_finish_counter()
		return

	var config := _get_phase_config()
	if not config:
		_finish_counter()
		return

	_counter_entry = config.pick_counter_attack()
	var mode: String = _counter_entry.get("mode", "attack")

	DebugConfig.debug("[BossCounter] 反击招式: %s" % mode, "", "combat")

	# 反击选定后立即重置 poise（攻击状态结束后不会回到 counter）
	var boss := get_boss()
	if boss:
		boss.reset_poise()
		boss.can_move = true

	# 面朝玩家
	_face_player()

	# 缓存到 last_picked_entry 供攻击状态读取
	mgr.last_picked_entry = _counter_entry

	# 转到攻击状态执行反击
	exit_control_state()
	transitioned.emit(self, _resolve_counter_state(mode))

func _resolve_counter_state(mode: String) -> String:
	match mode:
		"defend":
			return _resolve_state("defend", "attack")
		"projectile":
			return _resolve_state("projectile", "attack")
		"trap":
			return _resolve_state("trap", "attack")
		"roll":
			return _resolve_state("roll", "attack")
		_:
			# attack, combo, special, jump → 统一由 attack 状态处理
			return _resolve_state("attack", "idle")

func _finish_counter() -> void:
	var boss := get_boss()
	if boss:
		boss.reset_poise()
		boss.can_move = true
	exit_control_state()
	var next := evaluate_combat_transition(false)
	transitioned.emit(self, next)

func _face_player() -> void:
	var boss := get_boss()
	if not boss or not target_node:
		return
	var sprite := boss.get_node_or_null("AnimatedSprite2D") as Node2D
	if sprite and "flip_h" in sprite:
		sprite.flip_h = boss.global_position.x > target_node.global_position.x

func exit() -> void:
	exit_control_state()
	_phase = Phase.STAGGER

	if _stagger_timer and _stagger_timer.timeout.is_connected(_on_stagger_finished):
		_stagger_timer.timeout.disconnect(_on_stagger_finished)

	var boss := get_boss()
	if boss:
		boss.can_move = true

func on_damaged(_damage: Damage, _attacker_position: Vector2 = Vector2.ZERO) -> void:
	# 反击中不响应伤害（stun_immunity 已保护）
	pass
