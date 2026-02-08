extends BaseState
class_name ForestDiveAttackState

## 飞行敌人俯冲攻击状态
## 用于 ForestBee 等飞行敌人
## 朝玩家俯冲，到达后返回原位

enum DivePhase {
	DIVING,      # 俯冲中
	RETURNING    # 返回中
}

@export_group("攻击设置")
## 俯冲速度
@export var dive_speed := 150.0
## 返回速度
@export var return_speed := 80.0
## 到达目标的距离阈值
@export var reach_threshold := 20.0
## 返回等待时间
@export var return_delay := 0.5

@export_group("状态转换")
## 巡逻状态名
@export var patrol_state_name := "patrol"

var dive_phase: DivePhase = DivePhase.DIVING
var home_position: Vector2
var target_position: Vector2
var sprite: AnimatedSprite2D
var is_waiting: bool = false

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true
	animation_state = "attack"


func enter() -> void:
	dive_phase = DivePhase.DIVING
	is_waiting = false

	# 获取初始位置
	if owner_node is Node2D:
		if "home_position" in owner_node:
			home_position = owner_node.home_position
		else:
			home_position = (owner_node as Node2D).global_position

	# 锁定目标位置
	if target_node is Node2D:
		target_position = (target_node as Node2D).global_position

	sprite = owner_node.get_node_or_null("AnimatedSprite2D") if owner_node else null
	_play_animation("attack")


func physics_process_state(_delta: float) -> void:
	if owner_node is not CharacterBody2D:
		return

	if is_waiting:
		return

	var body = owner_node as CharacterBody2D

	match dive_phase:
		DivePhase.DIVING:
			_process_diving(body)

		DivePhase.RETURNING:
			_process_returning(body)


func _process_diving(body: CharacterBody2D) -> void:
	# 朝目标俯冲
	var direction = (target_position - body.global_position).normalized()
	body.velocity = direction * dive_speed

	# 更新精灵朝向
	_update_sprite_facing()

	# 检查是否到达目标
	if body.global_position.distance_to(target_position) < reach_threshold:
		_start_return()

	# 如果目标丢失也开始返回
	if not is_target_alive():
		_start_return()


func _process_returning(body: CharacterBody2D) -> void:
	# 返回原位
	var direction = (home_position - body.global_position).normalized()
	body.velocity = direction * return_speed

	# 更新精灵朝向
	_update_sprite_facing()

	# 检查是否到达原位
	if body.global_position.distance_to(home_position) < reach_threshold:
		transitioned.emit(self, patrol_state_name)


func _start_return() -> void:
	is_waiting = true

	# 短暂停顿后开始返回
	if owner_node and owner_node.is_inside_tree():
		var tree = owner_node.get_tree()
		if tree:
			await tree.create_timer(return_delay).timeout
			is_waiting = false
			dive_phase = DivePhase.RETURNING
			_play_animation("fly")


func exit() -> void:
	is_waiting = false


func _play_animation(anim_name: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)


func _update_sprite_facing() -> void:
	if sprite and owner_node is CharacterBody2D:
		var vel = (owner_node as CharacterBody2D).velocity
		if vel.x != 0:
			sprite.flip_h = vel.x < 0
