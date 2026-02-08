extends BaseState
class_name ForestDeadState

## 森林敌人死亡状态
## 处理死亡动画和清理

@export_group("死亡设置")
## 死亡动画时长
@export var death_duration := 0.5
## 是否播放下落效果（飞行敌人）
@export var fall_on_death := false
## 下落距离
@export var fall_distance := 50.0

var sprite: AnimatedSprite2D

func _init():
	priority = StatePriority.CONTROL  # 最高优先级
	can_be_interrupted = false  # 死亡不可被打断
	animation_state = "dead"


func enter() -> void:
	# 停止移动
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO

	sprite = owner_node.get_node_or_null("AnimatedSprite2D") if owner_node else null

	# 设置死亡标记
	if owner_node and "is_dead" in owner_node:
		owner_node.is_dead = true

	# 发送死亡信号
	if owner_node and owner_node.has_signal("died"):
		owner_node.died.emit()

	# 播放死亡效果
	if fall_on_death:
		_play_fall_death()
	else:
		_play_ground_death()


func _play_fall_death() -> void:
	if not owner_node or not owner_node.is_inside_tree():
		return

	_play_animation("hit")

	# 下落动画
	var tween = owner_node.create_tween()
	tween.tween_property(owner_node, "position:y", owner_node.position.y + fall_distance, 0.3)
	tween.tween_property(owner_node, "modulate:a", 0.0, 0.2)
	tween.tween_callback(owner_node.queue_free)


func _play_ground_death() -> void:
	if not owner_node or not owner_node.is_inside_tree():
		return

	_play_animation("dead")

	# 等待后删除
	await owner_node.get_tree().create_timer(death_duration).timeout
	if is_instance_valid(owner_node):
		owner_node.queue_free()


func physics_process_state(_delta: float) -> void:
	# 死亡状态下不移动
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO


func exit() -> void:
	pass


func _play_animation(anim_name: String) -> void:
	if sprite and sprite.sprite_frames:
		if sprite.sprite_frames.has_animation(anim_name):
			sprite.play(anim_name)
		elif sprite.sprite_frames.has_animation("hit"):
			sprite.play("hit")
