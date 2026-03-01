extends BaseState
class_name PlayerBaseState

## 玩家状态基类 - 提供玩家专用 helper
## 动画控制使用 BaseState 内置方法: set_locomotion_state, enter_control_state, exit_control_state

func get_movement() -> MovementComponent:
	if owner_node and "movement_component" in owner_node:
		return owner_node.movement_component
	return null

## 根据是否在地面回到 Ground 或 Air
func return_to_locomotion() -> void:
	var body = owner_node as CharacterBody2D
	if body and body.is_on_floor():
		transitioned.emit(self, "ground")
	else:
		transitioned.emit(self, "air")
