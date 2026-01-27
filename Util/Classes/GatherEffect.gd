extends AttackEffect
class_name GatherEffect

## 聚集特效 - 将敌人强制移动到指定位置
## 用于技能：将周围敌人聚集到第一个被击中的敌人位置

# ============ 预加载 ============
const GatherTrailEffectScript = preload("res://Util/Effects/GatherTrailEffect.gd")

@export_group("聚集参数")
## 聚集的目标位置（如果为空，则在 apply_effect 时设置）
var gather_target_position: Vector2 = Vector2.ZERO

## 聚集速度（移动速度）
@export var gather_speed: float = 500.0

## 聚集持续时间
@export var gather_duration: float = 0.3

## 是否立即传送（false则使用平滑移动）
@export var instant_teleport: bool = false

@export_group("轨迹线效果")
## 是否启用轨迹线效果
@export var enable_trail: bool = true

## 轨迹线实例引用
var _trail_effect: Node2D = null

func _init():
	effect_name = "聚集"
	duration = 0.3

## 设置聚集目标位置
func set_gather_position(position: Vector2) -> void:
	gather_target_position = position

func apply_effect(target: CharacterBody2D, damage_source_position: Vector2) -> void:
	super.apply_effect(target, damage_source_position)

	if show_debug_info:
		DebugConfig.debug("聚集: %s %v -> %v" % [target.name, target.global_position, gather_target_position], "", "effect")

	if instant_teleport:
		# 立即传送
		target.global_position = gather_target_position
		if show_debug_info:
			DebugConfig.debug("聚集: %s 立即传送至 %v" % [target.name, gather_target_position], "", "effect")
	else:
		# 平滑移动到目标位置
		_smooth_gather(target)

## 平滑聚集到目标位置
func _smooth_gather(target: CharacterBody2D) -> void:
	# 禁用敌人移动
	if "can_move" in target:
		target.can_move = false

	# 创建轨迹线效果
	if enable_trail:
		_create_trail(target)

	# 使用 Tween 进行平滑移动
	var tween = target.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	# 移动到目标位置
	tween.tween_property(target, "global_position", gather_target_position, gather_duration)

	# 使用信号连接处理Tween完成（避免await内存泄漏）
	tween.finished.connect(func():
		# 确保最终位置精确
		if is_instance_valid(target):
			target.global_position = gather_target_position

			# 只有在敌人没有被眩晕时才恢复移动能力
			# 如果敌人被 ForceStunEffect 眩晕，不要恢复移动
			var is_stunned = false
			if "stunned" in target:
				is_stunned = target.stunned

			if "can_move" in target and not is_stunned:
				target.can_move = true
				if show_debug_info:
					DebugConfig.info("聚集完成: %s at %v (移动已恢复)" % [target.name, target.global_position], "", "effect")
			elif show_debug_info and is_stunned:
				DebugConfig.info("聚集完成: %s at %v (保持眩晕)" % [target.name, target.global_position], "", "effect")

		# 渐隐并删除轨迹线
		if is_instance_valid(_trail_effect):
			_trail_effect.fade_out()
			_trail_effect = null
	, CONNECT_ONE_SHOT)

## 创建轨迹线效果
func _create_trail(target: CharacterBody2D) -> void:
	_trail_effect = GatherTrailEffectScript.new()

	# 添加到场景（使用目标的父节点，确保轨迹线在正确的坐标系中）
	var parent = target.get_parent()
	if parent:
		parent.add_child(_trail_effect)
		_trail_effect.create_trail(target, gather_target_position, true)

		if show_debug_info:
			DebugConfig.debug("创建聚集轨迹线: %s -> %v" % [target.name, gather_target_position], "", "effect")

func get_description() -> String:
	return "聚集 - 速度: %.0f, 持续: %.1f秒" % [gather_speed, gather_duration]
