extends ForestEnemyState
class_name ForestHideState

## 森林敌人躲藏状态
## 用于 ForestSnail 的缩壳防御
## 属于反应层，优先级高于行为层

@export_group("躲藏设置")
## 躲藏持续时间
@export var hide_duration := 2.0
## 躲藏时的减伤比例（0.5 = 减少50%伤害）
@export var damage_reduction := 0.5
## 恢复后的状态
@export var recover_state_name := "patrol"

var hide_timer: float = 0.0

func _init():
	super._init()
	priority = StatePriority.REACTION  # 反应层
	can_be_interrupted = false  # 躲藏期间不可被打断
	animation_state = "hide"


func enter() -> void:
	super.enter()
	hide_timer = hide_duration

	# 停止移动
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity.x = 0

	play_animation("hide")

	# 设置减伤标记（owner 需要检查此标记）
	if "is_hiding" in owner_node:
		owner_node.is_hiding = true


func physics_process_state(delta: float) -> void:
	hide_timer -= delta

	# 保持静止
	if owner_node is CharacterBody2D:
		var body = owner_node as CharacterBody2D
		body.velocity.x = 0

		# 应用重力
		if not body.is_on_floor() and "gravity" in owner_node:
			body.velocity.y += owner_node.gravity * delta

	# 躲藏时间结束
	if hide_timer <= 0:
		transitioned.emit(self, recover_state_name)


func exit() -> void:
	# 清除减伤标记
	if owner_node and "is_hiding" in owner_node:
		owner_node.is_hiding = false


## 受伤回调 - 躲藏状态下不切换状态，但可以延长躲藏时间
func on_damaged(_damage: Damage, _attacker_position: Vector2 = Vector2.ZERO) -> void:
	# 受伤时重置躲藏计时器（可选行为）
	hide_timer = hide_duration
