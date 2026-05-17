class_name SlimeSplitState extends AIState

## Slime 特殊技能:分裂 — HP<50% 由 Slime.gd 派发 EV_PHASE_CHANGED 进入
## 震动 → 生成 2 个小 Slime → 自身 queue_free
## v2: max_health/health 在 HealthComponent 子节点; chase_speed/can_split 在根节点

const SLIME_SCENE := "res://Scenes/Characters/Enemies/Slime/Slime.tscn"

@export var mini_scale := 0.65
@export var mini_hp_ratio := 0.3
@export var mini_speed_multiplier := 1.3
@export var spawn_offset := 32.0

func enter() -> void:
	if not is_instance_valid(owner_node):
		return
	_do_split()

func _do_split() -> void:
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

	# 父 Slime 的 HP 上限 (HealthComponent 子节点)
	var parent := owner_node.get_parent()
	var spawn_pos: Vector2 = owner_node.global_position
	var owner_hc: Node = owner_node.get_node_or_null(^"HealthComponent")
	var max_hp: float = owner_hc.max_health if owner_hc else 60.0
	var mini_hp: float = max_hp * mini_hp_ratio

	var slime_scene: PackedScene = load(SLIME_SCENE)
	for i in 2:
		var mini_slime: Node = slime_scene.instantiate()
		mini_slime.global_position = spawn_pos + Vector2((i * 2 - 1) * spawn_offset, 0)
		parent.add_child(mini_slime)
		mini_slime.scale = Vector2(mini_scale, mini_scale)
		# HP 设到 HealthComponent 子节点 (v2 位置)
		var mini_hc: Node = mini_slime.get_node_or_null(^"HealthComponent")
		if mini_hc:
			mini_hc.max_health = mini_hp
			mini_hc.health = mini_hp
		# chase_speed / can_split 在根节点
		if "chase_speed" in mini_slime:
			mini_slime.chase_speed = mini_slime.chase_speed * mini_speed_multiplier
			# 黑板在 mini_slime._ready 时已快照旧速度, 需同步更新
			if mini_slime.has_method(&"_get_blackboard"):
				var mini_bb = mini_slime._get_blackboard()
				if mini_bb:
					mini_bb.set_var(&"chase_speed", mini_slime.chase_speed)
		if "can_split" in mini_slime:
			mini_slime.can_split = false

	# 分裂绿色粒子爆发
	VfxHelper.spawn_burst(parent, spawn_pos,
		"res://Assets/Art/FX/Particle/Leaf.png", 10, Color(0.4, 1.6, 0.4), 65.0)

	# 删除原 Slime
	owner_node.queue_free()
