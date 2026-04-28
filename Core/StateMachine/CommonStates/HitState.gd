extends BaseState
class_name HitState

## 统一受击反应状态 (legacy BaseStateMachine 用)
## Phase 5: 改为查询 BuffController.get_top_hit_buff() 选动画 + 锁时长
## effects 已由 DamagePipeline.post_apply 阶段处理，本状态不再 apply effects

func _init():
	priority = StatePriority.REACTION
	can_be_interrupted = false
	animation_state = "hit"

# ============ 配置 ============
@export_group("受击设置")
## 受击硬直默认持续时间（无 buff 覆盖时使用）
@export var hit_duration := 0.2
## 受伤时是否重新进入 hit（重置反应）
@export var reset_on_damage := true


func enter() -> void:
	stop_movement()

	var anim_key: StringName = &"hit"
	var duration: float = hit_duration

	var bc: BuffController = owner_node.get_node_or_null(^"BuffController") if owner_node else null
	if bc:
		var resolved := bc.resolve_hit_anim(anim_key, duration)
		anim_key = resolved[&"anim"]
		duration = resolved[&"duration"]

	enter_control_state(String(anim_key))
	start_timer(duration)
	DebugConfig.debug("受击: %s anim=%s %.2fs" % [owner_node.name, anim_key, duration], "", "state_machine")


func physics_process_state(_delta: float) -> void:
	stop_movement()


func exit() -> void:
	stop_timer()
	exit_control_state()
	DebugConfig.debug("受击结束: %s" % owner_node.name, "", "state_machine")


## 受到伤害时的回调 — 重新进入 hit
func on_damaged(_damage: Damage, _attacker_position: Vector2) -> void:
	if reset_on_damage:
		state_machine.force_transition("hit")


## 根据玩家距离决定下一个状态
## Boss: 使用 evaluate_transition() 统一决策
func decide_next_state() -> void:
	if owner_node is BossBase:
		var next := evaluate_transition()
		transition_to(next)
		return
	super.decide_next_state()
