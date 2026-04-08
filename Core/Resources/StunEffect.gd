extends AttackEffect
class_name StunEffect

## 眩晕特效 - 标记目标为眩晕状态
## 实际状态切换由 HitState 根据此效果类型决定

@export_group("眩晕参数")
## 眩晕持续时间
@export var stun_duration: float = 1.5

func _init():
	effect_name = "眩晕"
	duration = 1.5

func apply_effect(target: CharacterBody2D, _damage_source_position: Vector2) -> void:
	super.apply_effect(target, _damage_source_position)
	if "stunned" in target:
		target.stunned = true
	if show_debug_info:
		DebugConfig.info("眩晕: %s %.1fs" % [target.name, stun_duration], "", "effect")

func get_description() -> String:
	return "眩晕 - 持续: %.1f秒" % stun_duration
