extends PlayerBaseState
class_name PlayerSpecialAttackState

## V 技能状态：协调 SkillManager 各阶段特效 + 状态机驱动攻击动画
## priority = REACTION(1), can_be_interrupted = false（仅 Hit CONTROL(2) 可打断）
##
## 流程:
##   Phase 1: create_effects — 残影放大 + 心跳 + 漩涡
##   Phase 2: detect_enemies — 扇形检测敌人
##   Phase 3: gather_enemies — 镜头 + 子弹时间 + 聚集
##   Phase 4: dash_to_target — 残影冲刺
##   Phase 5: enter_control_state("atk_sp") — 状态机驱动攻击动画
##   Phase 6: cleanup — unstun 敌人、隐藏漩涡

var _flow_active := false

func _init() -> void:
	priority = StatePriority.REACTION
	can_be_interrupted = false

func enter() -> void:
	_flow_active = true
	_set_movement_enabled(false)
	# V技能释放时切换到idle姿态
	set_locomotion_state("idle")
	# V技能期间无敌
	_set_invincible(true)
	_run_flow()

func exit() -> void:
	var was_active = _flow_active
	_flow_active = false

	# 断开动画信号
	var tree = get_anim_tree()
	if tree and tree.is_connected("animation_finished", _on_animation_finished):
		tree.animation_finished.disconnect(_on_animation_finished)

	# 清理特效（仅在流程仍活跃时，避免重复清理）
	if was_active:
		var sm = _get_skill_manager()
		if sm:
			sm.cleanup()

	# 恢复动画速度、移动和无敌状态
	set_control_time_scale(1.0)
	_set_movement_enabled(true)
	_set_invincible(false)

func _run_flow() -> void:
	var sm = _get_skill_manager()
	if not sm:
		return_to_locomotion()
		return

	var body = owner_node as CharacterBody2D
	if not body:
		return_to_locomotion()
		return

	var face_direction = sm.get_face_direction()

	# Phase 1: 创建特效
	await sm.create_effects(body, face_direction)
	if not _flow_active:
		return

	# Phase 2: 检测敌人
	if not sm.detect_enemies(body.global_position, face_direction):
		DebugConfig.debug("V技能: 前方无敌人，取消", "", "combat")
		sm.cleanup()
		_flow_active = false
		_set_movement_enabled(true)
		return_to_locomotion()
		return

	if not _flow_active:
		return

	# Phase 3: 聚集敌人
	await sm.gather_enemies()
	if not _flow_active:
		return

	# Phase 4: 残影冲刺
	await sm.dash_to_target(body)
	if not _flow_active:
		return

	# Phase 5: 状态机驱动攻击动画
	enter_control_state("atk_sp")
	set_control_time_scale(2.0)
	sm.play_attack_sound()

	# 监听动画结束
	var tree = get_anim_tree()
	if tree and not tree.is_connected("animation_finished", _on_animation_finished):
		tree.animation_finished.connect(_on_animation_finished)

func _on_animation_finished(anim_name: StringName) -> void:
	if not _flow_active:
		return
	if anim_name != "atk_sp":
		return

	_flow_active = false

	# Phase 6: 清理
	var sm = _get_skill_manager()
	if sm:
		sm.cleanup()

	set_control_time_scale(1.0)
	return_to_locomotion()

func _set_movement_enabled(enabled: bool) -> void:
	var mov = get_movement()
	if mov:
		mov.can_move = enabled

## 设置无敌状态（禁用/启用 HurtBoxComponent 的碰撞）
func _set_invincible(invincible: bool) -> void:
	if not owner_node:
		return
	var hurtbox = owner_node.get_node_or_null("HurtBoxComponent") as HurtBoxComponent
	if hurtbox:
		hurtbox.monitorable = not invincible

func _get_skill_manager() -> SkillManager:
	if owner_node and "skill_manager" in owner_node:
		return owner_node.skill_manager
	return null
