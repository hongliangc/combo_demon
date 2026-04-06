extends BossAttackManager
class_name BKAttackManager

## BladeKeeper 攻击管理器 — 剑气/陷阱/近战/连击

@export var sword_projectile_scene: PackedScene
@export var trap_scene: PackedScene

@export_group("Damage Configs")
@export var melee_damage: Damage
@export var projectile_damage: Damage
@export var trap_damage: Damage
@export var special_damage: Damage

const MAX_TRAPS := 3
var _active_traps: Array[Node] = []

func _ready() -> void:
	# 如果编辑器没有配置 damage，使用代码默认值
	_setup_default_damage()
	# 如果编辑器没有配置 phase_configs，使用代码默认值
	if phase_configs.is_empty():
		_setup_default_phases()

func _setup_default_damage() -> void:
	if not melee_damage:
		melee_damage = Damage.new()
		melee_damage.amount = 15.0
		melee_damage.min_amount = 12.0
		melee_damage.max_amount = 18.0
	if not projectile_damage:
		projectile_damage = Damage.new()
		projectile_damage.amount = 20.0
		projectile_damage.min_amount = 16.0
		projectile_damage.max_amount = 24.0
	if not trap_damage:
		trap_damage = Damage.new()
		trap_damage.amount = 25.0
		trap_damage.min_amount = 20.0
		trap_damage.max_amount = 30.0
		var stun_eff := StunEffect.new()
		stun_eff.stun_duration = 1.0
		trap_damage.effects.append(stun_eff)
	if not special_damage:
		special_damage = Damage.new()
		special_damage.amount = 35.0
		special_damage.min_amount = 30.0
		special_damage.max_amount = 40.0
		var kb_eff := KnockBackEffect.new()
		kb_eff.knockback_force = 300.0
		special_damage.effects.append(kb_eff)

func _execute_attack(entry: Dictionary, _target_pos: Vector2) -> void:
	var mode: String = entry.get("mode", "")
	match mode:
		"attack", "combo", "special", "jump":
			pass  # 由 BKAttack 状态统一处理
		"defend":
			pass  # 由 BKDefend 状态处理
		"roll":
			pass  # 由 BKRoll 状态处理
		"projectile":
			pass  # 由 BKProjectile 状态处理
		"trap":
			pass  # 由 BKTrap 状态处理

func fire_sword_projectile(target_pos: Vector2) -> void:
	if not sword_projectile_scene:
		return
	var boss := _get_boss()
	if not boss:
		return
	var proj := sword_projectile_scene.instantiate()
	get_tree().root.add_child(proj)
	proj.global_position = boss.global_position
	var direction := (target_pos - boss.global_position).normalized()
	if proj.has_method("set_direction"):
		proj.set_direction(direction)
	if projectile_damage and "damage_config" in proj:
		proj.damage_config = projectile_damage.duplicate(true)

func place_trap(target_pos: Vector2) -> void:
	_cleanup_traps()
	if _active_traps.size() >= MAX_TRAPS:
		return
	if not trap_scene:
		return
	var trap := trap_scene.instantiate()
	get_tree().root.add_child(trap)
	trap.global_position = target_pos + Vector2(randf_range(-30, 30), randf_range(-20, 20))
	if trap_damage and "damage_config" in trap:
		trap.damage_config = trap_damage.duplicate(true)
	_active_traps.append(trap)

func _cleanup_traps() -> void:
	_active_traps = _active_traps.filter(func(t): return is_instance_valid(t))

## ============ 默认阶段配置 ============
func _setup_default_phases() -> void:
	# Phase 1: 基础近战
	var p1 := BossPhaseConfig.new()
	p1.cooldown = 1.5
	p1.attacks = [
		{"mode": "attack", "weight": 5},
		{"mode": "combo", "weight": 2, "counter": true},
		{"mode": "projectile", "weight": 1},
	]
	phase_configs[BossBase.Phase.PHASE_1] = p1

	# Phase 2: 加入陷阱/特殊
	var p2 := BossPhaseConfig.new()
	p2.cooldown = 1.2
	p2.attacks = [
		{"mode": "combo", "weight": 3},
		{"mode": "projectile", "weight": 2},
		{"mode": "trap", "weight": 2},
		{"mode": "special", "weight": 1, "counter": true},
	]
	phase_configs[BossBase.Phase.PHASE_2] = p2

	# Phase 3: 全技能 + 更激进
	var p3 := BossPhaseConfig.new()
	p3.cooldown = 0.8
	p3.attacks = [
		{"mode": "combo", "weight": 3, "counter": true},
		{"mode": "projectile", "weight": 2},
		{"mode": "trap", "weight": 2},
		{"mode": "special", "weight": 2},
	]
	phase_configs[BossBase.Phase.PHASE_3] = p3

	DebugConfig.debug("[BKAttackManager] 默认阶段配置已加载 (3 phases)", "", "combat")
