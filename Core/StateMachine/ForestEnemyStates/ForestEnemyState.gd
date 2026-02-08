extends BaseState
class_name ForestEnemyState

## Forest 敌人状态基类
## 提供地面敌人通用功能：边缘检测、墙壁检测、方向控制
## 适用于 ForestBoar, ForestSnail 等地面敌人

# ============ 导出参数 ============
@export_group("边缘检测")
## 地面检测射线节点名
@export var ground_ray_name := "RayGround"
## 墙壁检测射线节点名
@export var wall_ray_name := "RayWall"

# ============ 内部引用 ============
var ray_ground: RayCast2D
var ray_wall: RayCast2D
var sprite: AnimatedSprite2D

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true
	animation_state = "idle"


func enter() -> void:
	# 获取射线和精灵引用
	if owner_node:
		ray_ground = owner_node.get_node_or_null(ground_ray_name)
		ray_wall = owner_node.get_node_or_null(wall_ray_name)
		sprite = owner_node.get_node_or_null("AnimatedSprite2D")


## 检测前方是否有地面
func has_ground_ahead() -> bool:
	return ray_ground != null and ray_ground.is_colliding()


## 检测是否碰到墙壁
func is_hitting_wall() -> bool:
	return ray_wall != null and ray_wall.is_colliding()


## 更新移动方向（左/右）
func get_direction() -> int:
	if owner_node and owner_node.has_method("get") and owner_node.get("direction") != null:
		return owner_node.direction
	return 1


## 设置移动方向
func set_direction(dir: int) -> void:
	if owner_node and "direction" in owner_node:
		owner_node.direction = dir


## 翻转方向
func flip_direction() -> void:
	set_direction(-get_direction())
	_update_ray_direction()


## 更新射线方向（根据移动方向调整）
func _update_ray_direction() -> void:
	var dir = get_direction()

	if ray_ground:
		ray_ground.position.x = abs(ray_ground.position.x) * dir

	if ray_wall:
		ray_wall.target_position.x = abs(ray_wall.target_position.x) * dir


## 更新精灵朝向（覆写基类方法）
func update_sprite_facing(use_velocity: bool = true) -> void:
	if sprite:
		sprite.flip_h = get_direction() < 0


## 播放动画（AnimatedSprite2D）
func play_animation(anim_name: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)


## 检查障碍物并自动转向
## 返回 true 表示发生了转向
func check_obstacles_and_turn() -> bool:
	if owner_node is not CharacterBody2D:
		return false

	var body = owner_node as CharacterBody2D

	# 只在地面上检测
	if not body.is_on_floor():
		return false

	var turned = false

	# 检测前方是否有地面
	if ray_ground and not ray_ground.is_colliding():
		flip_direction()
		turned = true

	# 检测墙壁
	if ray_wall and ray_wall.is_colliding():
		flip_direction()
		turned = true

	return turned

