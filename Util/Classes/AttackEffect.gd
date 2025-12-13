extends Resource
class_name AttackEffect

## 攻击特效基类 - 用于扩展各种攻击特效（击飞、击退、冰冻、燃烧等）
## 所有特效子类都应该继承此类并实现 apply_effect() 方法

@export_group("基础配置")
## 特效类型名称（用于调试和显示）
@export var effect_name: String = "Base Effect"

## 特效持续时间（秒）
@export var duration: float = 1.0

## 是否在应用时显示特效名称（调试用）
@export var show_debug_info: bool = false

## 应用特效到目标敌人
## 此方法应该被子类覆盖以实现具体特效逻辑
## @param enemy: 受到特效影响的敌人节点
## @param damage_source_position: 伤害来源位置（用于计算击退方向等）
func apply_effect(enemy: Enemy, damage_source_position: Vector2) -> void:
	if show_debug_info:
		print("[AttackEffect] Applying %s to %s" % [effect_name, enemy.name])
	# 子类应该覆盖此方法实现具体逻辑
	pass

## 获取特效描述（用于UI显示）
func get_description() -> String:
	return "基础特效 - 持续时间: %.1f秒" % duration
