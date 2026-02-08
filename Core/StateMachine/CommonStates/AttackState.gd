extends BaseState

## 通用 Attack（攻击）状态
## 适用于所有使用 AttackComponent 的实体

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true
	animation_state = "attack"

# ============ 攻击设置 ============
@export_group("攻击设置")
@export var attack_interval := 3.0
@export var attack_name := "basic_attack"

# ============ 距离设置 ============
@export_group("距离设置")
@export var default_attack_range := 50.0

# ============ AttackComponent 设置 ============
@export_group("AttackComponent")
@export var use_attack_component := true
@export var attack_anchor_path := "../../AttackAnchor"

# ============ 移动设置 ============
@export_group("移动设置")
@export var stop_on_attack := true
@export var deceleration_rate := 10.0

var attack_component: AttackComponent
var attack_anchor: Node2D
var attack_timer: float = 0.0


func enter() -> void:
	attack_timer = 0.0

	if use_attack_component and not attack_component:
		attack_component = AttackComponent.new()
		if attack_anchor_path != "":
			attack_anchor = get_node_or_null(attack_anchor_path)

	if stop_on_attack:
		stop_movement()

	# 重置 locomotion 到 idle，避免从 chase 过来仍播放 run 动画
	set_locomotion(Vector2.ZERO)

	# 使用 AnimationTree 触发攻击
	fire_attack()


func physics_process_state(delta: float) -> void:
	if not is_target_alive():
		transition_to(default_state_name)
		return

	var effective_range = get_owner_property("follow_radius", default_attack_range)
	var distance = get_distance_to_target()

	if distance > effective_range:
		transition_to(chase_state_name)
		return

	if not stop_on_attack:
		decelerate_velocity(deceleration_rate, delta)
		if owner_node is CharacterBody2D:
			owner_node.move_and_slide()
	else:
		if owner_node is CharacterBody2D:
			owner_node.velocity = Vector2.ZERO
			owner_node.move_and_slide()

	attack_timer -= delta
	if attack_timer <= 0:
		attack_timer = attack_interval
		perform_attack()


func perform_attack() -> void:
	# 执行攻击逻辑
	if use_attack_component and attack_component:
		attack_component.perform_attack(attack_name, get_direction_to_target(), attack_anchor)
	else:
		on_custom_attack()


func on_custom_attack() -> void:
	pass


func exit() -> void:
	# 中止攻击动画
	abort_attack()
