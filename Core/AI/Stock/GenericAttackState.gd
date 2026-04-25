# Core/AI/Stock/GenericAttackState.gd
extends BaseAttackState

## 通用攻击执行器：播动画 + 可选位移 + 动画结束退出
## 覆盖：普通攻击、后撤、闪避等简单技能

func enter() -> void:
	var skill: Skill = ai.current_skill
	if not skill:
		_finish()
		return
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	var anim_name = skill.params.get(&"animation", &"")
	if anim_name and "anim_player" in owner_node and owner_node.anim_player:
		owner_node.anim_player.play(anim_name)
		owner_node.anim_player.animation_finished.connect(_on_anim_done, CONNECT_ONE_SHOT)
	else:
		_finish()
		return
	var spd: float = skill.params.get(&"speed", 0.0)
	if spd > 0 and owner_node is CharacterBody2D:
		var dir_key: StringName = skill.params.get(&"direction", &"forward")
		(owner_node as CharacterBody2D).velocity.x = _resolve_direction(dir_key) * spd

func exit() -> void:
	if "anim_player" in owner_node and owner_node.anim_player:
		if owner_node.anim_player.animation_finished.is_connected(_on_anim_done):
			owner_node.anim_player.animation_finished.disconnect(_on_anim_done)

func _on_anim_done(_anim_name: StringName) -> void:
	_finish()

## 动画 method call track 调用：生成投射物
func spawn_projectile() -> void:
	var skill: Skill = ai.current_skill
	if not skill:
		return
	var scene: PackedScene = skill.params.get(&"projectile_scene")
	if not scene:
		return
	var proj := scene.instantiate()
	owner_node.get_tree().root.add_child(proj)
	proj.global_position = (owner_node as Node2D).global_position + skill.params.get(&"spawn_offset", Vector2.ZERO)
	var target_pos: Vector2 = bb.get_var(&"target_position", (owner_node as Node2D).global_position)
	if proj.has_method(&"set_direction"):
		proj.set_direction((target_pos - proj.global_position).normalized())

## 动画 method call track 调用：生成实体（陷阱、特效等）
func spawn_entity() -> void:
	var skill: Skill = ai.current_skill
	if not skill:
		return
	var scene: PackedScene = skill.params.get(&"spawn_scene")
	if not scene:
		return
	var entity := scene.instantiate()
	owner_node.get_tree().root.add_child(entity)
	entity.global_position = (owner_node as Node2D).global_position + skill.params.get(&"spawn_offset", Vector2.ZERO)

## 动画 method call track 调用：调用 owner_node 上的方法
## 用于 BuffEntity 框架到位前的过渡方案
func call_skill_method() -> void:
	var skill: Skill = ai.current_skill
	if not skill:
		return
	var method_name: StringName = skill.params.get(&"method", &"")
	if method_name == &"" or not owner_node.has_method(method_name):
		return
	var arg = skill.params.get(&"method_arg", null)
	if arg == null:
		owner_node.call(method_name)
	else:
		owner_node.call(method_name, arg)
