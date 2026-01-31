extends Resource
class_name BossComboAttack

## Boss 连击配置 - 定义一个多段攻击序列

## 单次攻击步骤
class AttackStep:
	enum AttackType {
		PROJECTILE,      # 弹幕攻击
		PROJECTILE_FAN,  # 扇形弹幕
		PROJECTILE_SPIRAL, # 螺旋弹幕
		LASER,           # 激光
		AOE              # AOE冲击波
	}

	var type: AttackType
	var delay: float = 0.0  # 相对于前一步的延迟（秒）
	var params: Dictionary = {}  # 攻击参数

	func _init(_type: AttackType, _delay: float = 0.0, _params: Dictionary = {}):
		type = _type
		delay = _delay
		params = _params

## 连击名称
@export var combo_name: String = "Unknown Combo"

## 连击步骤（代码中构建）
var steps: Array[AttackStep] = []

## 连击总时长（自动计算）
var total_duration: float = 0.0

## 添加攻击步骤
func add_step(type: AttackStep.AttackType, delay: float = 0.0, params: Dictionary = {}) -> BossComboAttack:
	var step = AttackStep.new(type, delay, params)
	steps.append(step)
	total_duration += delay
	return self  # 链式调用

## 获取步骤数量
func get_step_count() -> int:
	return steps.size()

## 创建预设连击

## 快速三连击（弹幕）
static func create_triple_shot() -> BossComboAttack:
	var combo = BossComboAttack.new()
	combo.combo_name = "Triple Shot"
	combo.add_step(AttackStep.AttackType.PROJECTILE, 0.0, {"count": 1})
	combo.add_step(AttackStep.AttackType.PROJECTILE, 0.15, {"count": 1})
	combo.add_step(AttackStep.AttackType.PROJECTILE, 0.15, {"count": 1})
	return combo

## 扇形 -> 螺旋组合
static func create_fan_spiral() -> BossComboAttack:
	var combo = BossComboAttack.new()
	combo.combo_name = "Fan + Spiral"
	combo.add_step(AttackStep.AttackType.PROJECTILE_FAN, 0.0, {"count": 5, "spread": PI / 4})
	combo.add_step(AttackStep.AttackType.PROJECTILE_SPIRAL, 0.4, {"count": 12})
	return combo

## 激光扫射 -> AOE
static func create_laser_shockwave() -> BossComboAttack:
	var combo = BossComboAttack.new()
	combo.combo_name = "Laser + Shockwave"
	combo.add_step(AttackStep.AttackType.LASER, 0.0, {})
	combo.add_step(AttackStep.AttackType.AOE, 0.3, {})
	return combo

## 螺旋 -> 扇形 -> AOE（高级组合）
static func create_ultimate_combo() -> BossComboAttack:
	var combo = BossComboAttack.new()
	combo.combo_name = "Ultimate Barrage"
	combo.add_step(AttackStep.AttackType.PROJECTILE_SPIRAL, 0.0, {"count": 16})
	combo.add_step(AttackStep.AttackType.PROJECTILE_FAN, 0.3, {"count": 6, "spread": PI / 3})
	combo.add_step(AttackStep.AttackType.AOE, 0.4, {})
	combo.add_step(AttackStep.AttackType.LASER, 0.2, {})
	return combo

## 双重螺旋（第三阶段专用）
static func create_double_spiral() -> BossComboAttack:
	var combo = BossComboAttack.new()
	combo.combo_name = "Double Spiral"
	combo.add_step(AttackStep.AttackType.PROJECTILE_SPIRAL, 0.0, {"count": 16})
	combo.add_step(AttackStep.AttackType.PROJECTILE_SPIRAL, 0.3, {"count": 16, "offset": PI / 16})
	return combo
