extends BossAttackManager
class_name DSAttackManager

## DemonSlime 攻击管理器 — 冲击波生成 + 组合技

@export var shockwave_scene: PackedScene

@export_group("Damage Configs")
@export var cleave_damage: Damage
@export var slam_damage: Damage

func _execute_attack(entry: Dictionary, _target_pos: Vector2) -> void:
	var mode: String = entry.get("mode", "")
	match mode:
		"cleave", "slam":
			pass  # 由 DSCleave/DSSlam 状态调用 spawn 方法
		"combo":
			_execute_combo_entry(entry)

func spawn_fan_shockwave(origin: Vector2, facing_dir: Vector2) -> void:
	if not shockwave_scene:
		return
	var sw := shockwave_scene.instantiate()
	get_tree().root.add_child(sw)
	sw.global_position = origin
	if sw.has_method("setup_fan"):
		var radius := _get_cleave_radius()
		sw.setup_fan(facing_dir, deg_to_rad(120), radius)
	if cleave_damage and "damage_config" in sw:
		sw.damage_config = cleave_damage.duplicate(true)

func spawn_ring_shockwave(origin: Vector2) -> void:
	if not shockwave_scene:
		return
	var sw := shockwave_scene.instantiate()
	get_tree().root.add_child(sw)
	sw.global_position = origin
	if sw.has_method("setup_ring"):
		sw.setup_ring(250.0)
	if slam_damage and "damage_config" in sw:
		sw.damage_config = slam_damage.duplicate(true)

func _get_cleave_radius() -> float:
	var boss := _get_boss()
	if boss and boss.current_phase == BossBase.Phase.PHASE_3:
		return 260.0
	return 200.0

func _execute_combo_entry(_entry: Dictionary) -> void:
	# combo 通过状态序列执行，由状态机驱动
	pass

## DemonSlime 组合技数据（使用 Dictionary 数组，不依赖 BossComboAttack.AttackStep）
class DSCombo:
	var combo_name: String
	var steps: Array[Dictionary] = []

	func _init(_name: String, _steps: Array[Dictionary]) -> void:
		combo_name = _name
		steps = _steps

## 组合技工厂
static func resolve_ds_combo(factory_name: String) -> Variant:
	match factory_name:
		"earthquake": return _create_earthquake()
		"devastation": return _create_devastation()
		"annihilation": return _create_annihilation()
	return null

## 大地震颤: cleave(fan) → 0.3s → cleave(fan, 反方向)
static func _create_earthquake() -> DSCombo:
	return DSCombo.new("earthquake", [
		{"type": "attack", "mode": "cleave", "params": {"direction": "forward"}, "delay": 0.0},
		{"type": "attack", "mode": "cleave", "params": {"direction": "backward"}, "delay": 0.3},
	])

## 毁灭重压: slam(ring) → 0.5s → cleave(fan, 加大范围)
static func _create_devastation() -> DSCombo:
	return DSCombo.new("devastation", [
		{"type": "attack", "mode": "slam", "delay": 0.0},
		{"type": "attack", "mode": "cleave", "params": {"radius_multiplier": 1.3}, "delay": 0.5},
	])

## 灭世连击: cleave → cleave → slam(加大范围)
static func _create_annihilation() -> DSCombo:
	return DSCombo.new("annihilation", [
		{"type": "attack", "mode": "cleave", "delay": 0.0},
		{"type": "attack", "mode": "cleave", "delay": 0.2},
		{"type": "attack", "mode": "slam", "params": {"radius_multiplier": 1.3}, "delay": 0.2},
	])
