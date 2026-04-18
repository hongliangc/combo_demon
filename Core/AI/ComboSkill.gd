# Core/AI/ComboSkill.gd
class_name ComboSkill extends Skill

## 组合技 Resource — 按序执行子技能的动画 + 参数

## 子技能列表（ComboState 读取每项的 params）
@export var sequence: Array[Skill] = []
## 每步之间的间隔（秒）
@export var gap: float = 0.1

func _init() -> void:
	interruptible = false
	state_name = &"combo"
