# Core/AI/Stock/GenericAttackState.gd
extends BaseAttackState

## 通用攻击执行器：播动画 + 可选位移 + 动画结束退出
## 覆盖：普通攻击、后撤、闪避等简单技能

func enter() -> void:
	var skill: Skill = ai.current_skill
	if not skill:
		_finish()
		return
	if skill and agent and agent.hitbox is HitBoxComponent:
		(agent.hitbox as HitBoxComponent).configure_from_skill(skill)
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	var anim_name: StringName = skill.params.get(&"animation", &"")
	if anim_name == &"" or not agent.anim.has_action(anim_name):
		_finish()
		return
	agent.anim.action_finished.connect(_on_anim_done, CONNECT_ONE_SHOT)
	agent.anim.play_action(anim_name)
	var spd: float = skill.params.get(&"speed", 0.0)
	if spd > 0 and owner_node is CharacterBody2D:
		var dir_key: StringName = skill.params.get(&"direction", &"forward")
		(owner_node as CharacterBody2D).velocity.x = _resolve_direction(dir_key) * spd

func exit() -> void:
	if agent.anim.action_finished.is_connected(_on_anim_done):
		agent.anim.action_finished.disconnect(_on_anim_done)
	agent.anim.stop_action()

func _on_anim_done(_action_id: StringName) -> void:
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
	var proj_hitbox: HitBoxComponent = proj.get_node_or_null(^"HitBoxComponent")
	if proj_hitbox:
		proj_hitbox.configure_from_skill(skill)
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
	var entity_hitbox: HitBoxComponent = entity.get_node_or_null(^"HitBoxComponent")
	if entity_hitbox:
		entity_hitbox.configure_from_skill(skill)

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

## Animation method-call hook: read skill.params.self_buff and apply via BuffController.
## Used by BK defense_cast / heal_self skills (data-driven, no per-boss override).
func apply_skill_self_buff() -> void:
	if owner_node == null or ai == null or ai.current_skill == null:
		return
	var skill = ai.current_skill
	if not (&"params" in skill) or not (skill.params is Dictionary):
		return
	var buff: BuffEntity = skill.params.get(&"self_buff", null)
	if buff == null:
		return
	var bc: BuffController = owner_node.get_node_or_null(^"BuffController")
	if bc:
		bc.apply(buff, owner_node, owner_node.global_position if owner_node is Node2D else Vector2.ZERO)
