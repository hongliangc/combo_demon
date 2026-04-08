extends BossState

## Boss 攻击状态 - 按阶段驱动（BossPhaseConfig Resource）
## 每个 Phase 自包含：技能池、冷却、行为模式、免疫
## Phase 1-2: timer 行为（站桩开火 → 退出）
## Phase 3: chase 行为（边追边打，持续循环）

const PhaseConfig = preload("res://Scenes/Characters/Bosses/Shared/BossPhaseConfig.gd")
const CHASE_DECELERATION := 5.0
const TIMER_DECELERATION := 10.0

# ============ 阶段配置（Phase → BossPhaseConfig） ============
var phase_configs: Dictionary = {}

# ============ 运行时状态 ============
var _config                          # 当前阶段配置 (BossPhaseConfig)
var _attack_timer: float = 0.0      # timer 模式倒计时
var _has_attacked: bool = false     # timer 模式是否已开火

# ============ 初始化 ============
func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true
	animation_state = "attack"


func _ready():
	_build_phase_configs()
	_resolve_callables()


## 构建各阶段配置（代码初始化，未来可迁移为 .tres）
func _build_phase_configs() -> void:
	# Phase 1
	var p1 = PhaseConfig.new()
	p1.attacks = [
		{ "mode": "fan_spread", "count": 3, "spread": deg_to_rad(30) },
		{ "mode": "rapid_fire", "count": 3 },
		{ "mode": "combo", "factory": "create_triple_shot" },
	]
	p1.chase_attacks = [
		{ "mode": "rapid_fire", "count": 1 },
	]
	p1.retreat_attacks = [
		{ "mode": "rapid_fire", "count": 1 },
	]
	p1.cooldown = 1.5
	p1.attack_duration = 1.0
	p1.behavior = "timer"
	p1.immune = false

	# Phase 2
	var p2 := PhaseConfig.new()
	p2.attacks = [
		{ "mode": "fan_spread", "count": 5, "spread": deg_to_rad(45) },
		{ "mode": "spiral", "count": 16 },
		{ "mode": "laser" },
		{ "mode": "combo", "factory": "create_fan_spiral" },
		{ "mode": "combo", "factory": "create_laser_shockwave" },
	]
	p2.chase_attacks = [
		{ "mode": "fan_spread", "count": 3, "spread": PI / 8 },
	]
	p2.retreat_attacks = [
		{ "mode": "fan_spread", "count": 3, "spread": PI / 6 },
	]
	p2.cooldown = 1.0
	p2.attack_duration = 1.0
	p2.behavior = "timer"
	p2.immune = false

	# Phase 3
	var p3 := PhaseConfig.new()
	p3.attacks = [
		{ "mode": "fan_spread", "count": 8, "spread": deg_to_rad(60) },
		{ "mode": "combo", "factory": "create_spiral_aoe" },
		{ "mode": "combo", "factory": "create_laser_barrage" },
		{ "mode": "aoe" },
		{ "mode": "combo", "factory": "create_ultimate_combo" },
		{ "mode": "combo", "factory": "create_double_spiral" },
	]
	p3.chase_attacks = [
		{ "mode": "fan_spread", "count": 5, "spread": PI / 4 },
	]
	p3.retreat_attacks = [
		{ "mode": "spiral", "count": 8 },
	]
	p3.cooldown = 0.5
	p3.behavior = "chase"
	p3.speed_multiplier = 1.8
	p3.immune = true

	phase_configs = {
		BossBase.Phase.PHASE_1: p1,
		BossBase.Phase.PHASE_2: p2,
		BossBase.Phase.PHASE_3: p3,
	}


## 将所有攻击池中的字符串 factory 解析为 Callable
func _resolve_callables() -> void:
	for config in phase_configs.values():
		for pool in [config.attacks, config.chase_attacks, config.retreat_attacks]:
			for entry in pool:
				if entry.get("mode") == "combo" and entry.get("factory") is String:
					var callable: Callable = CyclopsAttackManager.resolve_combo_factory(entry["factory"])
					if callable.is_valid():
						entry["factory"] = callable

# ============ 状态生命周期 ============

func enter():
	if not _boss:
		return

	_config = phase_configs.get(_boss.current_phase, phase_configs[BossBase.Phase.PHASE_1])

	if _config.behavior == "timer":
		can_be_interrupted = true
		_attack_timer = _config.attack_duration
		_has_attacked = false
		_boss.velocity = Vector2.ZERO
	else:
		can_be_interrupted = false

	var owner_name = str(owner_node.name) if owner_node else "?"
	DebugConfig.debug("[%s] Attack phase=%d behavior=%s" % [owner_name, _boss.current_phase, _config.behavior], "", "state_machine")


func process_state(delta: float) -> void:
	if not _config or _config.behavior != "timer":
		return

	# Timer 行为：倒计时 → 中点开火 → 结束退出
	_attack_timer -= delta

	if not _has_attacked and _attack_timer <= _config.attack_duration * 0.5:
		_fire_attack()
		play_boss_anim("attack")
		_has_attacked = true

	if _attack_timer <= 0:
		_finish_timer_attack()


func physics_process_state(delta: float) -> void:
	if not _boss or not _config:
		return

	if _config.behavior == "chase":
		# Chase 行为：追击 + 循环开火
		if not is_target_alive():
			transitioned.emit(self, "patrol")
			return

		var distance := get_distance_to_target()

		var cyclops := _boss as Cyclops
		var spd: float = cyclops.move_speed if cyclops else 150.0

		# 距离管理
		if distance < _boss.min_distance:
			var away_dir := -get_direction_to_target()
			_boss.velocity = away_dir * spd
			set_locomotion(Vector2(away_dir.x, 1.0))
		elif distance > _boss.attack_range:
			var direction := get_direction_to_target()
			_boss.velocity = direction * spd * _config.speed_multiplier
			set_locomotion(Vector2(direction.x, 1.0))
		else:
			_boss.velocity = _boss.velocity.lerp(Vector2.ZERO, CHASE_DECELERATION * delta)
			set_locomotion(Vector2.ZERO)

		# 普通攻击：cooldown 循环
		if _boss.attack_cooldown <= 0:
			_fire_attack()
			play_boss_anim("attack")
			_boss.attack_cooldown = _config.cooldown
	else:
		# Timer 行为：减速
		_boss.velocity = _boss.velocity.lerp(Vector2.ZERO, TIMER_DECELERATION * delta)


func exit():
	set_locomotion(Vector2.ZERO)


func on_damaged(_damage: Damage, _attacker_position: Vector2 = Vector2.ZERO):
	if _config and _config.immune:
		return
	transitioned.emit(self, "hit")

# ============ 攻击执行 ============

## 从攻击池随机选一个并执行
func _fire_attack() -> void:
	if not _config:
		return
	var entry = _config.pick_attack()
	if entry.is_empty():
		return
	var attack_manager := get_attack_manager()
	if attack_manager:
		_dispatch_attack(attack_manager, entry)


## Timer 模式攻击结束后处理
func _finish_timer_attack() -> void:
	if not _boss or not _config:
		return

	# 设置冷却
	_boss.attack_cooldown = _config.cooldown

	# 根据距离选择下一个状态
	var next := evaluate_combat_transition()
	transitioned.emit(self, next)
