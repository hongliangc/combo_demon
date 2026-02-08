extends Node
class_name BaseState

## 通用状态基类
## 所有状态（Enemy、Boss、Player 等）都继承此类
##
## 使用方法:
## 1. 继承此类
## 2. 重写 enter(), exit(), process_state(), physics_process_state()
## 3. 使用 transitioned.emit(self, "new_state_name") 切换状态
## 4. 使用 start_timer() 创建状态定时器
## 5. 使用 decide_next_state() 根据玩家距离决定下一状态

# ============ 状态优先级枚举 ============
## 控制层 > 反应层 > 行为层
enum StatePriority {
	BEHAVIOR = 0,    # 行为层（idle, wander, chase, attack）
	REACTION = 1,    # 反应层（hit, knockback, launch）
	CONTROL = 2      # 控制层（stun, frozen）
}

# ============ 信号 ============
## 状态转换信号
signal transitioned(from_state: BaseState, new_state_name: String)

# ============ 状态属性 ============
## 状态优先级
@export var priority: StatePriority = StatePriority.BEHAVIOR

## 是否可被同优先级状态打断
@export var can_be_interrupted: bool = true

## 对应的动画状态名（用于动画同步）
@export var animation_state: String = ""

# ============ 恢复后状态决策配置 ============
@export_group("恢复后状态决策")
## 检测玩家的半径（优先使用 owner.detection_radius）
@export var detection_radius := 150.0
## 检测到玩家时切换的状态
@export var chase_state_name := "chase"
## 未检测到玩家时切换的默认状态
@export var default_state_name := "idle"

# ============ 引用（由状态机自动注入）============
## Owner 节点（如 Enemy, Boss, Player）
var owner_node: Node

## Target 节点（通常是玩家）
var target_node: Node

## 所属的状态机
var state_machine: BaseStateMachine

# ============ 内部状态 ============
## 当前状态定时器（由 start_timer 创建）
var _state_timer: Timer

# ============ 生命周期方法（子类重写）============
## 进入状态时调用
func enter() -> void:
	pass


## 状态激活时的 _process()
func process_state(_delta: float) -> void:
	pass


## 状态激活时的 _physics_process()
func physics_process_state(_delta: float) -> void:
	pass


## 退出状态时调用
func exit() -> void:
	pass

# ============ 工具方法 ============
## 获取到目标的距离
func get_distance_to_target() -> float:
	if owner_node and target_node:
		if owner_node is Node2D and target_node is Node2D:
			return (owner_node as Node2D).global_position.distance_to((target_node as Node2D).global_position)
	return INF


## 获取到目标的方向（归一化）
func get_direction_to_target() -> Vector2:
	if owner_node and target_node:
		if owner_node is Node2D and target_node is Node2D:
			var direction = (target_node as Node2D).global_position - (owner_node as Node2D).global_position
			return direction.normalized()
	return Vector2.ZERO


## 检查目标是否在范围内
func is_target_in_range(range_distance: float) -> bool:
	return get_distance_to_target() <= range_distance


## 检查目标是否存活（如果有 alive 属性）
func is_target_alive() -> bool:
	if target_node and "alive" in target_node:
		return target_node.alive
	return true


## 尝试转换到攻击状态（当目标在攻击范围内时跳过追击）
func try_attack(radius: float = -1.0) -> bool:
	var effective_radius = radius if radius > 0 else get_owner_property("follow_radius", -1.0)
	if effective_radius <= 0:
		return false
	if is_target_alive() and get_distance_to_target() <= effective_radius:
		if state_machine and state_machine.states.has("attack"):
			transitioned.emit(self, "attack")
			return true
	return false


## 尝试转换到追击状态（通用逻辑）
func try_chase(radius: float = -1.0) -> bool:
	var effective_radius = radius if radius > 0 else get_owner_property("detection_radius", detection_radius)
	if is_target_alive() and get_distance_to_target() <= effective_radius:
		transitioned.emit(self, chase_state_name)
		return true
	return false


## 受到伤害时的回调（子类可重写）
## 根据伤害类型决定转换到哪个状态：
## - 有眩晕效果 → stun
## - 有击退/击飞效果 → knockback
## - 普通伤害 → hit
func on_damaged(damage: Damage, _attacker_position: Vector2) -> void:
	if not state_machine:
		print("[BaseState] on_damaged: no state_machine for %s" % name)
		return

	var owner_name: String = str(owner_node.name) if owner_node else "?"
	print("[BaseState] %s on_damaged, state=%s" % [owner_name, name])

	# 检查眩晕效果（最高优先级）
	if damage and (damage.has_effect("StunEffect") or damage.has_effect("ForceStunEffect")):
		if state_machine.states.has("stun"):
			DebugConfig.debug("[%s] -> stun (has stun effect)" % name, "", "state_machine")
			transitioned.emit(self, "stun")
			return

	# 检查击退/击飞效果
	if damage and (damage.has_effect("KnockBackEffect") or damage.has_effect("KnockUpEffect")):
		if state_machine.states.has("knockback"):
			DebugConfig.debug("[%s] -> knockback (has knockback effect)" % name, "", "state_machine")
			transitioned.emit(self, "knockback")
			return

	# 默认：切换到 hit 状态
	if state_machine.states.has("hit"):
		print("[BaseState] %s -> hit (emitting transition)" % name)
		transitioned.emit(self, "hit")
	else:
		print("[BaseState] %s no hit state available, states=%s" % [name, state_machine.states.keys()])


# ============ Timer 管理方法 ============
## 创建并启动状态定时器
## @param duration: 定时器持续时间
## @param callback: 超时回调函数（可选，默认调用 _on_timer_timeout）
## @param one_shot: 是否单次触发（默认 true）
func start_timer(duration: float, callback: Callable = Callable(), one_shot: bool = true) -> Timer:
	# 清理旧定时器
	stop_timer()

	# 创建新定时器
	_state_timer = Timer.new()
	_state_timer.wait_time = duration
	_state_timer.one_shot = one_shot
	_state_timer.autostart = true

	# 连接回调
	if callback.is_valid():
		_state_timer.timeout.connect(callback)
	else:
		_state_timer.timeout.connect(_on_timer_timeout)

	add_child(_state_timer)
	return _state_timer


## 停止并清理状态定时器
func stop_timer() -> void:
	if _state_timer:
		_state_timer.stop()
		if _state_timer.timeout.is_connected(_on_timer_timeout):
			_state_timer.timeout.disconnect(_on_timer_timeout)
		_state_timer.queue_free()
		_state_timer = null


## 重置定时器（重新开始计时）
func reset_timer() -> void:
	if _state_timer:
		_state_timer.start()


## 定时器超时回调（子类可重写）
func _on_timer_timeout() -> void:
	print("[BaseState] timer timeout: %s" % name)
	decide_next_state()


# ============ 状态决策方法 ============
## 根据玩家距离决定下一个状态（常用于恢复后的状态转换）
## 子类可重写此方法实现自定义逻辑
func decide_next_state() -> void:
	var effective_radius = get_owner_property("detection_radius", detection_radius)

	if is_target_alive() and get_distance_to_target() <= effective_radius:
		transition_to(chase_state_name)
	else:
		transition_to(default_state_name)


## 安全的状态转换（检查目标状态是否存在）
func transition_to(state_name: String) -> bool:
	if state_machine and state_machine.states.has(state_name.to_lower()):
		transitioned.emit(self, state_name)
		return true
	push_warning("[%s] 目标状态 '%s' 不存在" % [name, state_name])
	return false


# ============ 移动控制方法 ============
## 速度减速（通用工具方法）
## @param rate: 减速率（0-1），越大减速越快
## @param delta: 帧间隔时间
func decelerate_velocity(rate: float, delta: float) -> void:
	if owner_node is CharacterBody2D:
		var body = owner_node as CharacterBody2D
		body.velocity = body.velocity.lerp(Vector2.ZERO, rate * delta)


## 停止移动（立即将速度设为零）
func stop_movement() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO


## 向目标移动
## @param speed: 移动速度
## @param call_move_slide: 是否调用 move_and_slide（默认 true）
func move_toward_target(speed: float, call_move_slide: bool = true) -> void:
	if owner_node is CharacterBody2D:
		var body = owner_node as CharacterBody2D
		var direction = get_direction_to_target()
		body.velocity = direction * speed
		if call_move_slide:
			body.move_and_slide()


## 远离目标移动
## @param speed: 移动速度
## @param call_move_slide: 是否调用 move_and_slide（默认 true）
func move_away_from_target(speed: float, call_move_slide: bool = true) -> void:
	if owner_node is CharacterBody2D:
		var body = owner_node as CharacterBody2D
		var direction = -get_direction_to_target()
		body.velocity = direction * speed
		if call_move_slide:
			body.move_and_slide()


## 更新精灵朝向（根据速度或目标方向）
## @param use_velocity: true=根据速度方向，false=根据目标方向
func update_sprite_facing(use_velocity: bool = true) -> void:
	if not owner_node:
		return

	var sprite: Sprite2D = null
	if "sprite" in owner_node and owner_node.sprite is Sprite2D:
		sprite = owner_node.sprite

	if not sprite:
		return

	var direction_x: float
	if use_velocity and owner_node is CharacterBody2D:
		direction_x = (owner_node as CharacterBody2D).velocity.x
	else:
		direction_x = get_direction_to_target().x

	if abs(direction_x) > 0.1:
		sprite.flip_h = direction_x < 0


## 播放动画（如果 owner 支持）
func play_animation(anim_name: String) -> void:
	if owner_node and owner_node.has_method("play_animation"):
		owner_node.play_animation(anim_name)

## 从 owner 节点获取属性值（支持动态参数）
## @param property_name: 属性名
## @param default_value: 默认值（如果属性不存在）
func get_owner_property(property_name: String, default_value: Variant) -> Variant:
	if owner_node and property_name in owner_node:
		return owner_node.get(property_name)
	return default_value

# ============ 状态优先级方法 ============
## 检查是否可以转换到目标状态
## 规则：
## 1. 高优先级总是可以打断低优先级（外部中断）
## 2. 同优先级检查当前状态的 can_be_interrupted
## 3. 当前状态可以主动转换到任意低优先级状态（自愿结束）
func can_transition_to(new_state: BaseState) -> bool:
	if not new_state:
		return false
	# 高优先级总是可以打断低优先级
	if new_state.priority > priority:
		return true
	# 同优先级检查可打断性
	if new_state.priority == priority:
		return can_be_interrupted
	# 当前状态可以主动转换到低优先级状态（自愿结束控制）
	# 例如：StunState 结束后转换到 WanderState
	return true


## 获取当前状态的动画参数（子类可重写）
## 返回用于 AnimationTree 或 AnimationHandler 的参数
func get_animation_params() -> Dictionary:
	return {
		"velocity": owner_node.velocity if owner_node is CharacterBody2D else Vector2.ZERO,
		"animation_state": animation_state,
		"priority": priority,
		"can_be_interrupted": can_be_interrupted
	}


# ============ AnimationTree 控制方法 ============
## 获取 AnimationTree 节点（优先使用 StateMachine 缓存的引用）
func get_anim_tree() -> AnimationTree:
	if state_machine and state_machine.anim_tree:
		return state_machine.anim_tree
	if owner_node and "anim_tree" in owner_node:
		return owner_node.anim_tree
	if owner_node:
		return owner_node.get_node_or_null("AnimationTree")
	return null


## 设置 locomotion 混合位置（用于移动动画）
## blend_position.x: -1(左) 到 1(右) 的方向
## blend_position.y: 0(idle) 到 1(run) 的速度比例
func set_locomotion(blend: Vector2) -> void:
	var tree = get_anim_tree()
	if tree:
		tree.set("parameters/control_blend/blend_amount", 0.0)
		tree.set("parameters/locomotion/blend_position", blend)
		print("[ANIMATION] set_locomotion: blend=(%.2f, %.2f) owner=%s" % [blend.x, blend.y, owner_node.name if owner_node else "null"])
	else:
		print("[ANIMATION] set_locomotion FAILED: no anim_tree for %s" % (owner_node.name if owner_node else "null"))


## 触发攻击动画（使用 OneShot）
func fire_attack() -> void:
	var tree = get_anim_tree()
	if tree:
		tree.set("parameters/attack_oneshot/request",
			AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## 中止攻击动画
func abort_attack() -> void:
	var tree = get_anim_tree()
	if tree:
		tree.set("parameters/attack_oneshot/request",
			AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)


## 进入控制状态（hit / stun / death）
## 通过 control_blend 节点将动画从 locomotion 切换到 control_sm
func enter_control_state(state_name: String) -> void:
	var tree = get_anim_tree()
	if tree:
		# 先激活 control_blend，确保 control_sm 被处理
		tree.set("parameters/control_blend/blend_amount", 1.0)
		# 再启动 control_sm 的动画播放
		var playback = tree.get("parameters/control_sm/playback")
		if playback:
			playback.start(state_name, true)
		DebugConfig.debug("[BaseState] enter_control_state: %s" % state_name, "", "animation")


## 退出控制状态，返回到正常行为
func exit_control_state() -> void:
	var tree = get_anim_tree()
	if tree:
		tree.set("parameters/control_blend/blend_amount", 0.0)
		DebugConfig.debug("[BaseState] exit_control_state", "", "animation")


# ============ TimeScale 控制方法 ============
## 设置 locomotion 动画播放速度
## @param scale: 播放速度倍率（1.0=正常, 0.5=半速, 2.0=两倍速）
func set_locomotion_time_scale(scale: float) -> void:
	var tree = get_anim_tree()
	if tree:
		tree.set("parameters/loco_timescale/scale", scale)


## 设置 control（hit/stun/death）动画播放速度
## @param scale: 播放速度倍率（1.0=正常, 0.5=半速, 2.0=两倍速）
func set_control_time_scale(scale: float) -> void:
	var tree = get_anim_tree()
	if tree:
		tree.set("parameters/ctrl_timescale/scale", scale)


## 重置所有 TimeScale 为正常速度
func reset_time_scale() -> void:
	set_locomotion_time_scale(1.0)
	set_control_time_scale(1.0)


## 直接播放 AnimationPlayer 中的动画（用于特殊情况）
func play_anim_player(anim_name: String) -> void:
	if owner_node and owner_node.has_method("play_anim_player"):
		owner_node.play_anim_player(anim_name)
	elif owner_node and "anim_player" in owner_node:
		var player = owner_node.anim_player
		if player is AnimationPlayer:
			player.play(anim_name)
