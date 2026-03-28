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

func _execute_attack(entry: Dictionary, target_pos: Vector2) -> void:
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
