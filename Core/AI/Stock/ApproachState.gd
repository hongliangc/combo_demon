# Core/AI/Stock/ApproachState.gd
extends BaseAttackState

## 突进执行器：高速接近目标，到达 stop_distance 或动画结束即退出
## params:
##   animation: StringName     播放动画名（可选）
##   speed: float              冲刺速度
##   direction: StringName     方向键（默认 toward_target）
##   stop_distance: float      距目标 ≤ 此值时提前结束（0 = 不提前结束）
## 注意：enter() 不重置 velocity，以保持从 Chase 状态进入时的速度连续性（避免突进前闪顿）

func enter() -> void:
	var skill: Skill = ai.current_skill
	if not skill:
		_finish()
		return
	var anim_name = skill.params.get(&"animation", &"")
	if anim_name and "anim_player" in owner_node and owner_node.anim_player:
		owner_node.anim_player.play(anim_name)
		owner_node.anim_player.animation_finished.connect(_on_anim_done, CONNECT_ONE_SHOT)

func physics_update(_delta: float) -> void:
	var skill: Skill = ai.current_skill
	if not skill or not (owner_node is CharacterBody2D):
		return
	var spd: float = skill.params.get(&"speed", 0.0)
	var dir_key: StringName = skill.params.get(&"direction", &"toward_target")
	(owner_node as CharacterBody2D).velocity.x = _resolve_direction(dir_key) * spd
	var stop_dist: float = skill.params.get(&"stop_distance", 0.0)
	if stop_dist > 0 and bb.get_var(&"distance", INF) <= stop_dist:
		_finish()

func exit() -> void:
	if "anim_player" in owner_node and owner_node.anim_player:
		if owner_node.anim_player.animation_finished.is_connected(_on_anim_done):
			owner_node.anim_player.animation_finished.disconnect(_on_anim_done)

func _on_anim_done(_anim_name: StringName) -> void:
	_finish()
