extends ForestEnemyState
class_name ForestPatrolState

## 森林敌人巡逻状态
## 左右移动，遇到墙壁或边缘自动转向
## 适用于 ForestBoar, ForestSnail 等地面敌人

@export_group("巡逻设置")
## 巡逻移动速度倍率
@export var patrol_speed_multiplier := 1.0

func _init():
	super._init()
	animation_state = "walk"


func enter() -> void:
	super.enter()
	play_animation("walk")


func physics_process_state(delta: float) -> void:
	if owner_node is not CharacterBody2D:
		return

	var body = owner_node as CharacterBody2D

	# 应用重力
	if not body.is_on_floor():
		if "gravity" in owner_node:
			body.velocity.y += owner_node.gravity * delta
		return

	# 检测玩家
	if is_target_alive():
		var detection_range = owner_node.get("detection_range") if "detection_range" in owner_node else 200.0
		if is_target_in_range(detection_range):
			transitioned.emit(self, chase_state_name)
			return

	# 检查障碍物并转向
	check_obstacles_and_turn()

	# 移动
	var move_speed = owner_node.get("move_speed") if "move_speed" in owner_node else 60.0
	body.velocity.x = get_direction() * move_speed * patrol_speed_multiplier

	# 更新精灵朝向
	update_sprite_facing()


func exit() -> void:
	pass
