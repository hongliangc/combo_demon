extends "res://Core/StateMachine/CommonStates/SpecialSkillState.gd"
class_name DragonBreathState

## Dragon 特殊技能：火焰吐息
## 停止移动 → 扇形发射 3 发火球（±20°）
## 触发条件：玩家距离 < 150，冷却 6s，30% 概率

const FIREBALL_SCENE := "res://Scenes/Characters/Enemies/Dragon/DragonFireball.tscn"

@export var max_trigger_distance := 150.0
@export var spread_angle_deg := 20.0
@export var fireball_count := 3
@export var pre_fire_delay := 0.4


func _init() -> void:
	skill_cooldown = 6.0
	skill_probability = 0.3


func _check_condition(distance: float) -> bool:
	return distance < max_trigger_distance


func execute_skill() -> void:
	if not is_instance_valid(owner_node) or not is_instance_valid(target_node):
		finish_skill()
		return

	owner_node.velocity = Vector2.ZERO

	# 面向玩家
	update_sprite_facing(false)

	# 蓄气：橙色脉冲提示
	var sprite: Node2D = owner_node.sprite if "sprite" in owner_node else null
	if sprite:
		var charge_tween := owner_node.create_tween().set_loops(2)
		charge_tween.tween_property(sprite, "modulate", Color(2.0, 0.8, 0.1, 1.0), 0.1)
		charge_tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.1)

	# 蓄气短暂延迟
	await owner_node.get_tree().create_timer(pre_fire_delay).timeout

	if not is_instance_valid(owner_node) or not is_instance_valid(target_node):
		finish_skill()
		return

	# 发射扇形火球
	var base_dir: Vector2 = (target_node.global_position - owner_node.global_position).normalized()
	var fireball_scene: PackedScene = load(FIREBALL_SCENE)

	for i in fireball_count:
		var angle_offset := deg_to_rad(
			-spread_angle_deg + spread_angle_deg * (float(i) / (fireball_count - 1)) * 2.0
		)
		var dir := base_dir.rotated(angle_offset)
		var fireball: DragonFireball = fireball_scene.instantiate()
		fireball.global_position = owner_node.global_position
		fireball.setup(dir, owner_node.global_position)
		owner_node.get_parent().add_child(fireball)

	await owner_node.get_tree().create_timer(0.3).timeout

	if not is_instance_valid(owner_node):
		return

	finish_skill()
