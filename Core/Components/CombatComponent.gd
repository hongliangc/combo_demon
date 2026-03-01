extends Node
class_name CombatComponent

## 伤害类型管理组件
## 管理角色可用的伤害类型，供 HitBox 读取当前伤害
## 由动画 method track 通过 PlayerBase 委托调用 switch_to_*()

# ============ 信号 ============
## 伤害类型切换时发出
signal damage_type_changed(new_damage: Damage)

# ============ 配置参数 ============
@export_group("Damage")
## 可用的伤害类型列表
@export var damage_types: Array[Damage] = []

# ============ 运行时变量 ============
## 当前使用的伤害类型
var current_damage: Damage = null
## 当前伤害类型索引
var current_damage_index: int = 0

# ============ 生命周期 ============
func _ready() -> void:
	# 初始化为第一个伤害类型
	if damage_types.size() > 0:
		switch_to_damage_type(0)

# ============ 公共 API ============
## 切换到指定索引的伤害类型
func switch_to_damage_type(index: int) -> void:
	if index < 0 or index >= damage_types.size():
		push_warning("CombatComponent: 无效的伤害类型索引 %d" % index)
		return
	current_damage_index = index
	current_damage = damage_types[index]
	damage_type_changed.emit(current_damage)

## 切换到物理伤害（索引0）
func switch_to_physical() -> void:
	switch_to_damage_type(0)

## 切换到击飞伤害（索引1）
func switch_to_knockup() -> void:
	switch_to_damage_type(1)

## 切换到特殊攻击伤害（索引2）
func switch_to_special_attack() -> void:
	if damage_types.size() > 2:
		switch_to_damage_type(2)
	else:
		push_warning("CombatComponent: 没有配置特殊攻击伤害类型")

## 获取当前伤害类型
func get_current_damage() -> Damage:
	return current_damage
