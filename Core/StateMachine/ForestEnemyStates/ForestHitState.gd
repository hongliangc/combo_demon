extends ForestEnemyState
class_name ForestHitState

## 森林敌人受击状态
## 短暂硬直，然后根据情况转换状态
## 属于反应层

@export_group("受击设置")
## 受击硬直时间
@export var hit_duration := 0.15
## 受击闪烁颜色
@export var flash_color := Color.RED

@export_group("状态转换")
## 恢复后巡逻状态
@export var patrol_state_name := "patrol"
## 注意：chase_state_name 和 detection_radius 继承自 BaseState

var hit_timer: float = 0.0
var original_color: Color

func _init():
	super._init()
	priority = StatePriority.REACTION  # 反应层
	can_be_interrupted = false  # 受击硬直期间不可被打断
	animation_state = "hit"


func enter() -> void:
	super.enter()
	hit_timer = hit_duration

	# 停止移动
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity.x = 0

	# 闪烁效果
	_flash_start()

	# 播放受击动画（如果有）
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("hit"):
		play_animation("hit")


func physics_process_state(delta: float) -> void:
	hit_timer -= delta

	# 保持静止
	if owner_node is CharacterBody2D:
		var body = owner_node as CharacterBody2D
		body.velocity.x = 0

		# 应用重力
		if not body.is_on_floor() and "gravity" in owner_node:
			body.velocity.y += owner_node.gravity * delta

	# 硬直结束
	if hit_timer <= 0:
		_recover()


func _recover() -> void:
	# 恢复颜色
	_flash_end()

	# 根据玩家距离决定下一个状态
	if is_target_alive() and get_distance_to_target() <= detection_radius:
		transitioned.emit(self, chase_state_name)
	else:
		transitioned.emit(self, patrol_state_name)


func exit() -> void:
	_flash_end()


func _flash_start() -> void:
	if sprite:
		original_color = sprite.modulate
		sprite.modulate = flash_color


func _flash_end() -> void:
	if sprite:
		sprite.modulate = original_color if original_color != Color() else Color.WHITE


## 受伤回调 - 重置硬直时间
func on_damaged(_damage: Damage, _attacker_position: Vector2 = Vector2.ZERO) -> void:
	hit_timer = hit_duration
	_flash_start()
