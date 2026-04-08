extends AttackEffect
class_name ForceStunEffect

## 强制眩晕特效 - 停止移动 + 标记眩晕
## 实际状态切换由 HitState 根据此效果类型决定

@export_group("眩晕参数")
## 眩晕持续时间
@export var stun_duration: float = 3.0

## 是否停止敌人移动
@export var stop_movement: bool = true

func _init():
	effect_name = "强制眩晕"
	duration = 3.0

func apply_effect(target: CharacterBody2D, damage_source_position: Vector2) -> void:
	super.apply_effect(target, damage_source_position)
	if stop_movement:
		target.velocity = Vector2.ZERO
	if "can_move" in target:
		target.can_move = false
	if "stunned" in target:
		target.stunned = true
	if show_debug_info:
		DebugConfig.info("强制眩晕: %s %.1fs" % [target.name, stun_duration], "", "effect")

func get_description() -> String:
	return "强制眩晕 - 持续: %.1f秒" % stun_duration
