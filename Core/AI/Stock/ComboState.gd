# Core/AI/Stock/ComboState.gd
extends BaseAttackState

## 组合技执行器：按序播放子技能的动画 + 参数

var _combo: ComboSkill
var _step: int = 0
var _waiting_gap: bool = false
var _gap_timer: float = 0.0

func enter() -> void:
	var current: Skill = ai.current_skill
	_combo = current as ComboSkill
	if not _combo or _combo.sequence.is_empty():
		_finish()
		return
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	_step = 0
	_waiting_gap = false
	_play_step()

func physics_update(delta: float) -> void:
	if _waiting_gap:
		_gap_timer -= delta
		if _gap_timer <= 0:
			_waiting_gap = false
			_play_step()

func exit() -> void:
	if "anim_player" in owner_node and owner_node.anim_player:
		if owner_node.anim_player.animation_finished.is_connected(_on_sub_anim_done):
			owner_node.anim_player.animation_finished.disconnect(_on_sub_anim_done)

func _play_step() -> void:
	if _step >= _combo.sequence.size():
		_finish()
		return
	var sub_skill: Skill = _combo.sequence[_step]
	var anim_name = sub_skill.params.get(&"animation", &"")
	if anim_name and "anim_player" in owner_node and owner_node.anim_player:
		owner_node.anim_player.play(anim_name)
		if not owner_node.anim_player.animation_finished.is_connected(_on_sub_anim_done):
			owner_node.anim_player.animation_finished.connect(_on_sub_anim_done)
	var spd: float = sub_skill.params.get(&"speed", 0.0)
	if spd > 0 and owner_node is CharacterBody2D:
		var dir_key: StringName = sub_skill.params.get(&"direction", &"forward")
		(owner_node as CharacterBody2D).velocity.x = _resolve_direction(dir_key) * spd

func _on_sub_anim_done(_anim_name: StringName) -> void:
	_step += 1
	if _step >= _combo.sequence.size():
		if "anim_player" in owner_node and owner_node.anim_player:
			if owner_node.anim_player.animation_finished.is_connected(_on_sub_anim_done):
				owner_node.anim_player.animation_finished.disconnect(_on_sub_anim_done)
		_finish()
		return
	if _combo.gap > 0:
		_waiting_gap = true
		_gap_timer = _combo.gap
	else:
		_play_step()
