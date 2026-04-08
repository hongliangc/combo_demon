extends BaseState
class_name HitState

## 统一受击反应状态
## 处理所有伤害反应：硬直、眩晕、击退、击飞
## 属于反应层，可打断行为层状态
##
## 流程：
## 1. enter() 从 state_machine 读取缓存的 Damage
## 2. 遍历 effects 应用属性修改（velocity、stunned 等）
## 3. 根据最高优先级效果选择动画和持续时间
## 4. 到期/速度归零后 decide_next_state() 恢复

func _init():
	priority = StatePriority.REACTION
	can_be_interrupted = false
	animation_state = "hit"

# ============ 配置 ============
@export_group("受击设置")
## 受击硬直持续时间（无特殊效果时使用）
@export var hit_duration := 0.2
## 受伤时是否重新进入 hit（重置效果）
@export var reset_on_damage := true

@export_group("击退物理")
## 击退摩擦力系数，越大减速越快
@export var knockback_friction := 8.0
## 最小速度阈值（低于此值视为停止）
@export var min_velocity := 10.0

# ============ 运行时状态 ============
var _is_stunned := false
var _has_knockback := false


func enter() -> void:
	_is_stunned = false
	_has_knockback = false

	var damage: Damage = state_machine.last_damage
	var attacker_pos: Vector2 = state_machine.last_attacker_position

	if damage and not damage.effects.is_empty():
		_apply_effects(damage, attacker_pos)
	else:
		_start_hit_stagger()


func _apply_effects(damage: Damage, attacker_pos: Vector2) -> void:
	# 应用所有效果（修改属性、设置 velocity、启动 tween 等）
	for effect in damage.effects:
		if effect:
			effect.apply_effect(owner_node as CharacterBody2D, attacker_pos)

	# 根据效果类型选择动画和持续时间
	# 优先级: ForceStunEffect > StunEffect > KnockBack/KnockUp > 普通硬直
	var stun_effect := _find_effect(damage, "ForceStunEffect")
	if not stun_effect:
		stun_effect = _find_effect(damage, "StunEffect")

	if stun_effect:
		# 眩晕模式
		var duration: float = stun_effect.stun_duration if "stun_duration" in stun_effect else 1.5
		_is_stunned = true
		enter_control_state("stunned")
		start_timer(duration)
		if "stunned" in owner_node:
			owner_node.stunned = true
		DebugConfig.debug("受击眩晕: %s %.1fs" % [owner_node.name, duration], "", "state_machine")
	elif damage.has_effect("KnockBackEffect") or damage.has_effect("KnockUpEffect"):
		# 击退/击飞模式：效果已设置 velocity/tween，由 physics 处理减速
		_has_knockback = true
		enter_control_state("hit")
		# 不启动定时器，由 physics_process_state 检测速度归零后结束
		DebugConfig.debug("受击击退: %s" % owner_node.name, "", "state_machine")
	else:
		# 其他效果（如 GatherEffect）：普通硬直
		_start_hit_stagger()


func _start_hit_stagger() -> void:
	stop_movement()
	enter_control_state("hit")
	start_timer(hit_duration)
	DebugConfig.debug("受击硬直: %s %.2fs" % [owner_node.name, hit_duration], "", "state_machine")


func physics_process_state(delta: float) -> void:
	if not _has_knockback:
		# 非击退模式：保持静止
		stop_movement()
		return

	if owner_node is not CharacterBody2D:
		return
	var body := owner_node as CharacterBody2D

	# 击退减速
	if body.velocity.length() > min_velocity:
		body.velocity = body.velocity.lerp(Vector2.ZERO, knockback_friction * delta)
		body.move_and_slide()
	else:
		body.velocity = Vector2.ZERO
		_has_knockback = false
		# 击退结束：如果不是眩晕，结束 hit
		if not _is_stunned:
			decide_next_state()


func exit() -> void:
	stop_timer()
	exit_control_state()

	# 清除眩晕标记
	if _is_stunned:
		if "stunned" in owner_node:
			owner_node.stunned = false
		if "can_move" in owner_node:
			owner_node.can_move = true
		_on_stun_exit()

	_is_stunned = false
	_has_knockback = false

	DebugConfig.debug("受击结束: %s" % owner_node.name, "", "state_machine")


## 眩晕退出钩子（Boss: 设置眩晕免疫计时器）
func _on_stun_exit() -> void:
	if owner_node is BossBase:
		var boss := owner_node as BossBase
		var config := _get_config()
		var immunity := config.stun_immunity_duration if config and config.is_boss else 1.5
		boss.stun_immunity = immunity


## 受到伤害时的回调 — 重新进入 hit（完整 exit + enter 流程）
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


## 在 damage.effects 中查找指定类型的效果
func _find_effect(damage: Damage, effect_class_name: String) -> AttackEffect:
	for effect in damage.effects:
		if effect and effect.get_script() and effect.get_script().get_global_name() == effect_class_name:
			return effect
	return null
