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
		"attack":
			pass  # 近战由 BKAttack 状态直接处理动画+伤害
		"special":
			pass  # sp_atk 由 BKAttack 状态处理
		"defend":
			pass  # 由 BKDefend 状态处理
		"roll_projectile":
			pass  # 由状态序列 BKRoll→BKProjectile 处理
		"roll_trap":
			pass  # 由状态序列 BKRoll→BKTrap 处理
		"combo":
			_execute_combo_entry(entry)

func _execute_combo_entry(entry: Dictionary) -> void:
	var factory_name: String = entry.get("factory", "")
	var combo := resolve_bk_combo(factory_name)
	if not combo.is_empty():
		# Combo 由 BKAttack 状态逐步执行，这里仅验证工厂名有效
		DebugConfig.debug("[BKAttackManager] combo resolved: %s" % factory_name, "", "combat")

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

## 组合技工厂 — BladeKeeper 使用状态序列式组合技（非 BossComboAttack.AttackStep 类型）
## 返回包含 combo_name 和 state_steps 的字典
static func resolve_bk_combo(factory_name: String) -> Dictionary:
	match factory_name:
		"blade_storm": return _create_blade_storm()
		"shadow_strike": return _create_shadow_strike()
		"ultimate_chain": return _create_ultimate_chain()
	return {}

## 剑刃风暴: atk_1 → atk_2 → atk_3 → projectile_cast (Phase 1+)
static func _create_blade_storm() -> Dictionary:
	return {
		"combo_name": "blade_storm",
		"state_steps": [
			{"state": "atk_1", "delay": 0.0},
			{"state": "atk_2", "delay": 0.1},
			{"state": "atk_3", "delay": 0.1},
			{"state": "projectile_cast", "delay": 0.2},
		]
	}

## 影步突袭: roll → atk_1 → atk_2 → defend (Phase 2+)
static func _create_shadow_strike() -> Dictionary:
	return {
		"combo_name": "shadow_strike",
		"state_steps": [
			{"state": "roll", "delay": 0.0},
			{"state": "atk_1", "delay": 0.1},
			{"state": "atk_2", "delay": 0.1},
			{"state": "defend", "delay": 0.2},
		]
	}

## 绝剑连环: roll → trap → atk_1 → atk_2 → atk_3 → sp_atk (Phase 3)
static func _create_ultimate_chain() -> Dictionary:
	return {
		"combo_name": "ultimate_chain",
		"state_steps": [
			{"state": "roll", "delay": 0.0},
			{"state": "trap_cast", "delay": 0.1},
			{"state": "atk_1", "delay": 0.2},
			{"state": "atk_2", "delay": 0.1},
			{"state": "atk_3", "delay": 0.1},
			{"state": "sp_atk", "delay": 0.3},
		]
	}

## ============ 默认阶段配置 ============
func _setup_default_phases() -> void:
	# Phase 1: 基础近战 + 偶尔防御
	var p1 := BossPhaseConfig.new()
	p1.cooldown = 1.5
	p1.attacks = [
		{"mode": "attack", "weight": 5},
		{"mode": "defend", "weight": 2},
		{"mode": "roll_projectile", "weight": 1},
	]
	phase_configs[BossBase.Phase.PHASE_1] = p1

	# Phase 2: 加入翻滚/陷阱 + 组合技
	var p2 := BossPhaseConfig.new()
	p2.cooldown = 1.2
	p2.attacks = [
		{"mode": "attack", "weight": 4},
		{"mode": "defend", "weight": 2},
		{"mode": "roll_projectile", "weight": 2},
		{"mode": "roll_trap", "weight": 2},
		{"mode": "special", "weight": 1},
		{"mode": "combo", "factory": "blade_storm", "weight": 1},
		{"mode": "combo", "factory": "shadow_strike", "weight": 1},
	]
	phase_configs[BossBase.Phase.PHASE_2] = p2

	# Phase 3: 全技能解锁 + 更激进
	var p3 := BossPhaseConfig.new()
	p3.cooldown = 0.8
	p3.attacks = [
		{"mode": "attack", "weight": 3},
		{"mode": "defend", "weight": 1},
		{"mode": "roll_projectile", "weight": 2},
		{"mode": "roll_trap", "weight": 2},
		{"mode": "special", "weight": 2},
		{"mode": "combo", "factory": "blade_storm", "weight": 2},
		{"mode": "combo", "factory": "shadow_strike", "weight": 2},
		{"mode": "combo", "factory": "ultimate_chain", "weight": 1},
	]
	phase_configs[BossBase.Phase.PHASE_3] = p3

	DebugConfig.debug("[BKAttackManager] 默认阶段配置已加载 (3 phases)", "", "combat")
