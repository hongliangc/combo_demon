extends "res://Core/StateMachine/CommonStates/SpecialSkillState.gd"
class_name SpiritTeleportState

## Spirit 特殊技能：幽灵瞬移
## 淡出 → 瞬移到玩家背后 → 淡入 → 立即攻击
## 触发条件：玩家距离 > 100，冷却 8s，20% 概率

@export var min_trigger_distance := 100.0
@export var appear_offset := 40.0
@export var fade_duration := 0.3
@export var attack_damage := 12.0


func _init() -> void:
	skill_cooldown = 8.0
	skill_probability = 0.2


func _check_condition(distance: float) -> bool:
	return distance > min_trigger_distance


func execute_skill() -> void:
	if not is_instance_valid(owner_node) or not is_instance_valid(target_node):
		finish_skill()
		return

	var sprite: Node2D = owner_node.sprite if "sprite" in owner_node else null

	# 淡出
	if sprite:
		var tween := owner_node.create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, fade_duration)
		await tween.finished

	if not is_instance_valid(owner_node) or not is_instance_valid(target_node):
		if is_instance_valid(owner_node) and sprite:
			sprite.modulate.a = 1.0
		finish_skill()
		return

	# 离开位置留下传送特效
	VfxHelper.spawn_teleport(owner_node.get_parent(), owner_node.global_position)

	# 瞬移到玩家背后（玩家面向的反方向）
	var player_facing := Vector2.RIGHT
	if target_node is CharacterBody2D and (target_node as CharacterBody2D).velocity.x < 0:
		player_facing = Vector2.LEFT
	var offset := -player_facing * appear_offset
	owner_node.global_position = target_node.global_position + offset

	# 出现位置留下传送特效
	VfxHelper.spawn_teleport(owner_node.get_parent(), owner_node.global_position)

	# 淡入
	if sprite:
		var tween2 := owner_node.create_tween()
		tween2.tween_property(sprite, "modulate:a", 1.0, fade_duration)
		await tween2.finished

	if not is_instance_valid(owner_node) or not is_instance_valid(target_node):
		finish_skill()
		return

	# 立即攻击
	var tree := get_anim_tree()
	if tree:
		tree.set("parameters/attack_oneshot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

	var dist: float = owner_node.global_position.distance_to(target_node.global_position)
	if dist < 60.0:
		_apply_damage_to_player(_make_damage(attack_damage))

	finish_skill()
