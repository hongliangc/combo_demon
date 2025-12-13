extends Resource
class_name Damage

## 伤害数据类 - 存储伤害值和攻击特效配置

@export_group("伤害配置")
## 最大伤害值（用于暴击计算）
@export var max_amount: float = 50.0

## 最小伤害值
@export var min_amount: float = 1.0

## 实际伤害值
@export var amount: float = 10.0

## 伤害类型（保留用于兼容性，建议使用effects数组）
@export_enum("Physical", "KnockUp", "KnockBack") var type: String = "Physical"

## 随机数生成器（静态共享，避免重复创建）
static var _rng: RandomNumberGenerator = null

@export_group("攻击特效")
## 攻击特效列表 - 可以附加多个特效（击飞、击退、冰冻等）
## 所有特效将在命中时按顺序应用
@export var effects: Array[AttackEffect] = []

## 应用所有特效到目标敌人
## @param enemy: 受到攻击的敌人节点
## @param damage_source_position: 伤害来源位置（用于计算击退方向等）
func apply_effects(enemy: Enemy, damage_source_position: Vector2) -> void:
	for effect in effects:
		if effect != null:
			effect.apply_effect(enemy, damage_source_position)

## 检查是否包含指定类型的特效
## @param effect_type: 特效类型，可以是类名字符串（如"KnockUpEffect"）或Script对象
func has_effect(effect_type) -> bool:
	for effect in effects:
		if effect == null:
			continue
		# 如果传入的是字符串，比较类名
		if effect_type is String:
			if effect.get_script() and effect.get_script().get_global_name() == effect_type:
				return true
		# 如果传入的是Script或类，使用is检查
		else:
			if is_instance_of(effect, effect_type):
				return true
	return false

## 获取所有特效的描述文本
func get_effects_description() -> String:
	if effects.is_empty():
		return "无特效"
	var descriptions = []
	for effect in effects:
		if effect != null:
			descriptions.append(effect.get_description())
	return ", ".join(descriptions)

## 生成随机伤害值（基于min_amount和max_amount）
## 调用此方法会更新amount为随机值
func randomize_damage() -> void:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	amount = _rng.randf_range(min_amount, max_amount)

## 调试打印伤害信息
func debug_print() -> void:
	print("---------- 伤害信息 ----------")
	print("伤害类型: ", type)
	print("伤害值: ", amount, " (范围: ", min_amount, "-", max_amount, ")")
	print("特效数量: ", effects.size())
	print("特效描述: ", get_effects_description())
	print("------------------------------")
