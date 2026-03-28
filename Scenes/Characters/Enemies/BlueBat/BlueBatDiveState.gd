extends "res://Core/StateMachine/CommonStates/SpecialSkillState.gd"
class_name BlueBatDiveState

## BlueBat 特殊技能：俯冲突袭
## 红色预警 → 高速冲刺向玩家 → 命中造成击退 → 弹回
## 触发条件：60 < 距离 < 120，冷却 5s，25% 概率

@export var min_distance := 60.0
@export var max_distance := 120.0
@export var dive_speed_multiplier := 2.5
@export var dive_damage := 14.0
@export var dive_knockback := 260.0
@export var bounce_distance := 70.0
@export var flash_duration := 0.2


func _init() -> void:
	skill_cooldown = 5.0
	skill_probability = 0.25


func _check_condition(distance: float) -> bool:
	return distance >= min_distance and distance <= max_distance


func execute_skill() -> void:
	if not is_instance_valid(owner_node) or not is_instance_valid(target_node):
		finish_skill()
		return

	# 红色预警闪烁
	var sprite: Node2D = owner_node.sprite if "sprite" in owner_node else null
	if sprite:
		var flash := owner_node.create_tween()
		flash.tween_property(sprite, "modulate", Color(2.5, 0.2, 0.2, 1.0), flash_duration * 0.5)
		flash.tween_property(sprite, "modulate", Color(1, 1, 1, 1), flash_duration * 0.5)
		await flash.finished

	if not is_instance_valid(owner_node) or not is_instance_valid(target_node):
		finish_skill()
		return

	# 高速冲刺
	var chase_speed: float = get_owner_property("chase_speed", 100.0)
	var dive_speed := chase_speed * dive_speed_multiplier
	var dir: Vector2 = (target_node.global_position - owner_node.global_position).normalized()

	var dive_tween := owner_node.create_tween()
	dive_tween.tween_method(
		func(t: float) -> void:
			if is_instance_valid(owner_node):
				owner_node.velocity = dir * dive_speed * (1.0 - t * 0.3)
				owner_node.move_and_slide(),
		0.0, 1.0, 0.25
	)
	await dive_tween.finished

	if not is_instance_valid(owner_node):
		finish_skill()
		return

	# 命中判定
	if is_instance_valid(target_node):
		var dist: float = owner_node.global_position.distance_to(target_node.global_position)
		if dist < 50.0:
			_apply_damage_to_player(_make_damage(dive_damage, dive_knockback))
			# 命中红色火花
			VfxHelper.spawn_burst(owner_node.get_parent(), owner_node.global_position,
				"res://Assets/Art/FX/Particle/Spark.png", 8, Color(2.0, 0.2, 0.2), 75.0)

	# 弹回
	var bounce_dir := -dir
	var bounce_tween := owner_node.create_tween()
	bounce_tween.tween_property(
		owner_node, "global_position",
		owner_node.global_position + bounce_dir * bounce_distance,
		0.25
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await bounce_tween.finished

	if is_instance_valid(owner_node):
		owner_node.velocity = Vector2.ZERO

	finish_skill()
