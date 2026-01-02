extends Resource
class_name AttackEffect

## 攻击特效基类 - 可应用到任何 CharacterBody2D（Player, Boss, Enemy）
## 支持击飞、击退、冰冻、燃烧等各种特效

@export_group("基础配置")
## 特效类型名称（用于调试和显示）
@export var effect_name: String = "Base Effect"

## 特效持续时间（秒）
@export var duration: float = 1.0

## 是否在应用时显示特效名称（调试用）
@export var show_debug_info: bool = false

## 应用特效到目标角色
## @param target: 受到特效影响的角色节点（CharacterBody2D）
## @param damage_source_position: 伤害来源位置（用于计算击退方向等）
func apply_effect(target: CharacterBody2D, damage_source_position: Vector2) -> void:
	if show_debug_info:
		print("[GenericAttackEffect] Applying %s to %s" % [effect_name, target.name])
	# 子类应该覆盖此方法实现具体逻辑
	pass

## 获取特效描述（用于UI显示）
func get_description() -> String:
	return "基础特效 - 持续时间: %.1f秒" % duration
