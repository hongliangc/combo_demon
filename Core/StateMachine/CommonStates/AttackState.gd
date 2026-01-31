extends BaseState

## 通用 Attack（攻击）状态
## 适用于所有使用 AttackComponent 的实体

## 动画设置
@export var attack_animation := "attack"

## 攻击设置
@export var attack_interval := 3.0  # 攻击间隔
@export var attack_duration := 1.0  # 攻击动作时长
@export var attack_name := "basic_attack"  # 攻击名称（传给 AttackComponent）

## 距离设置
@export var attack_range := 50.0  # 攻击范围
@export var use_owner_range := true  # 使用 owner.follow_radius 作为范围

## AttackComponent 设置
@export var use_attack_component := true  # 使用 AttackComponent
@export var attack_anchor_path := "../../AttackAnchor"  # AttackAnchor 节点路径（相对状态节点）

## 移动设置
@export var stop_movement := true  # 攻击时停止移动
@export var deceleration_rate := 10.0  # 减速率（如果不立即停止）

## 状态转换设置
@export var chase_state_name := "chase"  # 目标离开范围后的状态
@export var idle_state_name := "wander"  # 目标丢失后的状态

var attack_component: AttackComponent
var attack_anchor: Node2D
var attack_timer: float = 0.0

func enter() -> void:
	attack_timer = 0.0

	# 获取 AttackComponent
	if use_attack_component:
		if not attack_component:
			attack_component = AttackComponent.new()

		# 获取 AttackAnchor
		if not attack_anchor and attack_anchor_path != "":
			attack_anchor = get_node_or_null(attack_anchor_path)

	# 播放动画
	if owner_node and owner_node.has_method("play_animation"):
		owner_node.play_animation(attack_animation)

	# 停止移动
	if stop_movement and owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO


func physics_process_state(delta: float) -> void:
	# 检查目标是否存活
	if not is_target_alive():
		transitioned.emit(self, idle_state_name)
		return

	# 获取攻击范围
	var effective_range = attack_range
	if use_owner_range and "follow_radius" in owner_node:
		effective_range = owner_node.follow_radius

	var distance = get_distance_to_target()

	# 离开攻击范围，继续追击
	if distance > effective_range:
		transitioned.emit(self, chase_state_name)
		return

	# 渐进减速（如果不立即停止）
	if not stop_movement and owner_node is CharacterBody2D:
		var body = owner_node as CharacterBody2D
		body.velocity = body.velocity.lerp(Vector2.ZERO, deceleration_rate * delta)

	# 攻击冷却
	attack_timer -= delta
	if attack_timer <= 0:
		attack_timer = attack_interval
		perform_attack()


## 执行攻击 - 可被子类重载
func perform_attack() -> void:
	if use_attack_component and attack_component:
		var direction = get_direction_to_target()
		attack_component.perform_attack(attack_name, direction, attack_anchor)
	else:
		# 如果不使用 AttackComponent，子类可以重载此方法
		on_custom_attack()


## 自定义攻击逻辑 - 子类重载
func on_custom_attack() -> void:
	# 默认实现：什么都不做
	# 子类可以重载此方法实现自定义攻击
	pass


func exit() -> void:
	pass
