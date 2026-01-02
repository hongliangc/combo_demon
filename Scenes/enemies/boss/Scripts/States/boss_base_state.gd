extends Node
class_name BossState

## Boss 状态基类

# 状态结束通过signal通知进入下一个状态
signal transitioned(state: BossState, new_state_name: String)

# 这些引用由状态机统一注入
var boss: Boss
var player: Hahashin

# 进入状态
func enter():
	pass

# 状态的 _process() 逻辑
func process_state(_delta: float) -> void:
	pass

# 状态的 _physics_process() 逻辑
func physics_process_state(_delta: float) -> void:
	pass

# 退出状态
func exit():
	pass

# ============ 工具方法 ============

# 获取到玩家的距离
func get_distance_to_player() -> float:
	if player:
		return player.global_position.distance_to(boss.global_position)
	return INF

# 获取到玩家的方向
func get_direction_to_player() -> Vector2:
	if player:
		return (player.global_position - boss.global_position).normalized()
	return Vector2.ZERO

# 检测玩家是否在范围内
func is_player_in_range(range: float) -> bool:
	return get_distance_to_player() <= range

# 基类的默认 on_damaged 实现：切换到 stun 状态（如果有的话）
func on_damaged(_damage: Damage):
	# Boss 某些状态可能不会眩晕（如狂暴状态）
	# 子类可以覆盖此方法来自定义行为
	if boss.current_phase != Boss.Phase.PHASE_3:  # 第三阶段不会被击晕
		transitioned.emit(self, "stun")
