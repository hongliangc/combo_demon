extends Node
class_name BaseState

## 通用状态基类
## 所有状态（Enemy、Boss、Player 等）都继承此类
##
## 使用方法:
## 1. 继承此类
## 2. 重写 enter(), exit(), process_state(), physics_process_state()
## 3. 使用 transitioned.emit(self, "new_state_name") 切换状态

# ============ 信号 ============
## 状态转换信号
signal transitioned(from_state: BaseState, new_state_name: String)

# ============ 引用（由状态机自动注入）============
## Owner 节点（如 Enemy, Boss, Player）
var owner_node: Node

## Target 节点（通常是玩家）
var target_node: Node

## 所属的状态机
var state_machine: BaseStateMachine

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


## 尝试转换到追击状态（通用逻辑）
func try_chase(detection_radius: float) -> bool:
	if is_target_alive() and get_distance_to_target() <= detection_radius:
		transitioned.emit(self, "chase")
		return true
	return false


## 受到伤害时的回调（子类可重写）
func on_damaged(_damage: Damage, attacker_position: Vector2) -> void:
	# 默认：切换到 stun 状态
	if state_machine and state_machine.states.has("stun"):
		transitioned.emit(self, "stun")
