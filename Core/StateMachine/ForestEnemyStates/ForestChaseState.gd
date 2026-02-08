extends ForestEnemyState
class_name ForestChaseState

## 森林敌人追击状态
## 朝玩家方向冲刺，用于 ForestBoar 等敌人

@export_group("追击设置")
## 追击速度倍率
@export var chase_speed_multiplier := 2.0
## 丢失目标后返回巡逻的距离
@export var lose_target_distance := 300.0
## 巡逻状态名
@export var patrol_state_name := "patrol"
## 攻击状态名（可选）
@export var attack_state_name := "attack"
## 攻击范围（进入后切换到攻击状态）
@export var attack_range := 30.0

func _init():
	super._init()
	animation_state = "run"


func enter() -> void:
	super.enter()
	play_animation("run")


func physics_process_state(delta: float) -> void:
	if owner_node is not CharacterBody2D:
		return

	var body = owner_node as CharacterBody2D

	# 应用重力
	if not body.is_on_floor():
		if "gravity" in owner_node:
			body.velocity.y += owner_node.gravity * delta
		return

	# 检查目标是否存活且在范围内
	if not is_target_alive():
		transitioned.emit(self, patrol_state_name)
		return

	var distance = get_distance_to_target()

	# 目标太远，返回巡逻
	if distance > lose_target_distance:
		transitioned.emit(self, patrol_state_name)
		return

	# 进入攻击范围
	if distance <= attack_range and state_machine and state_machine.states.has(attack_state_name.to_lower()):
		transitioned.emit(self, attack_state_name)
		return

	# 追击玩家
	if target_node:
		# 更新朝向
		var target_pos = (target_node as Node2D).global_position
		var owner_pos = (owner_node as Node2D).global_position
		set_direction(1 if target_pos.x > owner_pos.x else -1)

	# 检查障碍物
	check_obstacles_and_turn()

	# 移动
	var chase_speed = owner_node.get("chase_speed") if "chase_speed" in owner_node else 120.0
	body.velocity.x = get_direction() * chase_speed * chase_speed_multiplier

	# 更新精灵朝向
	update_sprite_facing()


func exit() -> void:
	pass
