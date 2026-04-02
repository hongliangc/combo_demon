extends BaseState
class_name BossState

## Boss 状态基类 - 直接继承 BaseState
## 提供 Boss 通用功能：缓存引用、距离决策、攻击分派、动画控制

func _init():
	# 默认为行为层，子类可覆盖
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true
	animation_state = "idle"

# ============ 缓存的 Boss 引用 ============

var _boss_cache: BossBase

## 缓存的 Boss 类型引用（lazy 初始化，避免重复类型守卫）
var _boss: BossBase:
	get:
		if not is_instance_valid(_boss_cache) and owner_node is BossBase:
			_boss_cache = owner_node as BossBase
		return _boss_cache

# ============ 攻击管理器访问 ============

var _attack_manager_cache: BossAttackManager

## 获取 Boss 的攻击管理器（缓存）
func get_attack_manager() -> BossAttackManager:
	if is_instance_valid(_attack_manager_cache):
		return _attack_manager_cache
	if owner_node is BossBase:
		for child in (owner_node as BossBase).get_children():
			if child is BossAttackManager:
				_attack_manager_cache = child
				return child
	return null

## 获取当前 Boss 引用（返回 BossBase 类型，保留兼容）
func get_boss() -> BossBase:
	return owner_node as BossBase if owner_node is BossBase else null

# ============ 阶段配置访问 ============

## 获取当前阶段的 BossPhaseConfig（从 BossAttackManager 读取）
func _get_phase_config() -> BossPhaseConfig:
	var mgr := get_attack_manager()
	if mgr:
		return mgr.get_current_config()
	return null

# ============ 统一距离决策 ============

## 根据距离、冷却等条件评估应转换到的战斗状态
## @param include_attack: 是否考虑转换到 attack 状态
## @return 推荐的状态名（"patrol"/"retreat"/"attack"/"circle"/"chase"/"idle"）
func evaluate_combat_transition(include_attack: bool = true) -> String:
	if not _boss:
		return "idle"

	if not is_target_alive():
		return _resolve_state("patrol", "idle")

	var distance := get_distance_to_target()

	# 超出检测范围 → 脱离战斗
	if distance > _boss.detection_radius:
		return _resolve_state("patrol", "idle")

	# 太近 → 撤退
	if distance < _boss.min_distance:
		return _resolve_state("retreat", "chase")

	# 在攻击范围内
	if distance <= _boss.attack_range:
		if include_attack and _boss.attack_cooldown <= 0:
			return _resolve_state("attack", "idle")
		return _resolve_state("circle", "chase")

	# 攻击范围外但检测范围内 → 追击
	return _resolve_state("chase", "idle")

## 检查状态机是否拥有目标状态，不存在则降级到 fallback
func _resolve_state(preferred: String, fallback: String) -> String:
	if state_machine and state_machine.states.has(preferred):
		return preferred
	if state_machine and state_machine.states.has(fallback):
		return fallback
	return "idle"

# ============ 统一攻击分派 ============

## 根据攻击条目字典分派具体攻击（委托给 AttackManager）
func _dispatch_attack(attack_manager: BossAttackManager, entry: Dictionary) -> void:
	var target_pos: Vector2 = target_node.global_position if target_node else Vector2.ZERO
	DebugConfig.debug("[BossState] 执行: %s | %s" % [entry.get("mode", ""), entry], "", "combat")
	attack_manager.execute_attack(entry, target_pos)

# ============ 动画控制 ============

## 播放 Boss 动画（优先 AnimationTree，回退 AnimationPlayer）
func play_boss_anim(anim_name: String) -> void:
	var boss := get_boss()
	if not boss:
		return
	# 优先使用 AnimationTree 的 control_sm
	var tree = get_anim_tree()
	if tree:
		enter_control_state(anim_name)
		return
	# 回退到直接 AnimationPlayer
	if boss.anim_player and boss.anim_player.has_animation(anim_name):
		boss.anim_player.play(anim_name)

## 结束 Boss 控制动画（退出 control state 回到 locomotion）
func finish_boss_anim() -> void:
	var tree = get_anim_tree()
	if tree:
		exit_control_state()

# ============ 受伤响应 ============

## Boss 特有的 on_damaged 实现：第三阶段/眩晕免疫期间不会被击晕
func on_damaged(_damage: Damage, _attacker_position: Vector2 = Vector2.ZERO) -> void:
	var boss := get_boss()
	if not boss:
		return
	if boss.current_phase == BossBase.Phase.PHASE_3:
		return
	if boss.stun_immunity > 0:
		return
	transitioned.emit(self, "stun")
