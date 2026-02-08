extends Area2D
class_name Portal

## 传送门组件 - 关卡出口/入口
##
## 功能：
## - 检查通关条件
## - 激活状态切换
## - 传送特效
## - 调用LevelManager切换场景

signal activated()
signal player_entered()

@export var is_exit: bool = true  # true=出口, false=入口
@export var auto_activate: bool = false  # 是否自动激活
@export var activation_hint: String = "Complete the objective to unlock!"

var is_active: bool = false
var player_in_range: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var particles: GPUParticles2D = $GPUParticles2D if has_node("GPUParticles2D") else null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# 监听目标完成
	LevelManager.objective_updated.connect(_on_objective_updated)
	LevelManager.boss_defeated.connect(_on_boss_defeated)

	if auto_activate:
		activate()
	else:
		_set_inactive_visuals()


func _on_objective_updated(_type: String, current: int, required: int) -> void:
	if current >= required and is_exit:
		activate()


func _on_boss_defeated() -> void:
	if is_exit:
		activate()


## 激活传送门
func activate() -> void:
	if is_active:
		return

	is_active = true
	activated.emit()
	_set_active_visuals()
	print("Portal: Activated!")


## 设置激活状态视觉效果
func _set_active_visuals() -> void:
	if sprite:
		sprite.play("active")
	if particles:
		particles.emitting = true

	# 发光效果
	modulate = Color(1.2, 1.2, 1.5)


## 设置未激活状态视觉效果
func _set_inactive_visuals() -> void:
	if sprite:
		sprite.play("inactive")
	if particles:
		particles.emitting = false

	modulate = Color(0.5, 0.5, 0.5)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	player_in_range = true

	if is_active:
		_teleport_player(body)
	else:
		UIManager.show_toast(activation_hint, 2.0, "warning")


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false


## 传送玩家
func _teleport_player(player: Node2D) -> void:
	player_entered.emit()

	# 播放传送特效
	_play_teleport_effect()

	# 等待特效
	await get_tree().create_timer(0.5).timeout

	# 完成关卡
	if is_exit:
		LevelManager.complete_level()


func _play_teleport_effect() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.3)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
