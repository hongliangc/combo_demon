extends BaseState
class_name ForestFlyPatrolState

## 飞行敌人巡逻状态
## 用于 ForestBee 等飞行敌人
## 在原点周围做正弦波动飞行

@export_group("飞行设置")
## 飞行速度
@export var fly_speed := 80.0
## 水平巡逻范围
@export var patrol_range_x := 100.0
## 垂直波动范围
@export var patrol_range_y := 20.0
## 波动频率
@export var wave_frequency := 2.0

@export_group("检测设置")
## 检测到玩家后切换的状态
@export var attack_state_name := "attack"
## 检测范围（从 owner 获取或使用默认值）
@export var default_detection_range := 150.0

var home_position: Vector2
var patrol_offset: float = 0.0
var sprite: AnimatedSprite2D

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true
	animation_state = "fly"


func enter() -> void:
	# 记录初始位置
	if owner_node is Node2D:
		# 如果 owner 有 home_position，使用它；否则使用当前位置
		if "home_position" in owner_node:
			home_position = owner_node.home_position
		else:
			home_position = (owner_node as Node2D).global_position

	sprite = owner_node.get_node_or_null("AnimatedSprite2D") if owner_node else null
	_play_animation("fly")


func physics_process_state(delta: float) -> void:
	if owner_node is not CharacterBody2D:
		return

	var body = owner_node as CharacterBody2D

	# 检测玩家
	if is_target_alive():
		var detection_range = owner_node.get("detection_range") if "detection_range" in owner_node else default_detection_range
		if is_target_in_range(detection_range):
			transitioned.emit(self, attack_state_name)
			return

	# 正弦波动飞行
	patrol_offset += delta * wave_frequency

	var target_pos = home_position + Vector2(
		sin(patrol_offset) * patrol_range_x,
		cos(patrol_offset * 0.5) * patrol_range_y
	)

	var direction = (target_pos - body.global_position).normalized()
	body.velocity = direction * fly_speed

	# 更新精灵朝向
	_update_sprite_facing()


func exit() -> void:
	pass


func _play_animation(anim_name: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)


func _update_sprite_facing() -> void:
	if sprite and owner_node is CharacterBody2D:
		var vel = (owner_node as CharacterBody2D).velocity
		if vel.x != 0:
			sprite.flip_h = vel.x < 0
