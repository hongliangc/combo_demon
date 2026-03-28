extends "res://Core/StateMachine/CommonStates/SpecialSkillState.gd"
class_name SlimeSplitState

## Slime 特殊技能：分裂
## HP < 50% 时触发一次：震动 → 分裂为 2 个小 Slime → 自身消失
## 注意：由 Slime.gd 监听 health_changed 信号强制触发，不走常规 can_trigger()

const SLIME_SCENE := "res://Scenes/Characters/Enemies/Slime/Slime.tscn"

@export var mini_scale := 0.65
@export var mini_hp_ratio := 0.3
@export var mini_speed_multiplier := 1.3
@export var spawn_offset := 32.0


func _init() -> void:
	skill_cooldown = 9999.0  # 实际由 Slime.gd 控制一次性触发
	skill_probability = 1.0


func execute_skill() -> void:
	if not is_instance_valid(owner_node):
		return

	# 震动效果
	var sprite: Node2D = owner_node.sprite if "sprite" in owner_node else null
	if sprite:
		var tween := owner_node.create_tween()
		for _i in 4:
			tween.tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.07)
			tween.tween_property(sprite, "scale", Vector2(0.7, 1.3), 0.07)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.05)
		await tween.finished

	if not is_instance_valid(owner_node):
		return

	# 生成 2 个小 Slime
	var slime_scene: PackedScene = load(SLIME_SCENE)
	var parent := owner_node.get_parent()
	var spawn_pos: Vector2 = owner_node.global_position
	var max_hp: float = owner_node.max_health if "max_health" in owner_node else 60.0
	var base_speed: float = owner_node.chase_speed if "chase_speed" in owner_node else 50.0

	for i in 2:
		var mini_slime: Node = slime_scene.instantiate()
		mini_slime.global_position = spawn_pos + Vector2((i * 2 - 1) * spawn_offset, 0)
		parent.add_child(mini_slime)

		# 配置小 Slime 属性
		mini_slime.scale = Vector2(mini_scale, mini_scale)
		if "max_health" in mini_slime:
			mini_slime.max_health = max_hp * mini_hp_ratio
		if "health" in mini_slime:
			mini_slime.health = max_hp * mini_hp_ratio
		if "chase_speed" in mini_slime:
			mini_slime.chase_speed = base_speed * mini_speed_multiplier
		if "can_split" in mini_slime:
			mini_slime.can_split = false  # 防止递归分裂

	# 分裂绿色粒子爆发
	VfxHelper.spawn_burst(owner_node.get_parent(), owner_node.global_position,
		"res://Assets/Art/FX/Particle/Leaf.png", 10, Color(0.4, 1.6, 0.4), 65.0)

	# 删除原 Slime
	owner_node.queue_free()
