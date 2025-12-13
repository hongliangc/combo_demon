extends Node
class_name EnemyStates

# 状态结束通过signal通知进入下一个状态
signal transitioned(state: EnemyStates, new_state_name: String)

# 这些引用由状态机统一注入，不再在 _ready() 中获取
var enemy: Enemy
var player: Hahashin

# Useful for setting up the state to be used
# In Idle, we use this function to decide how long we will idle for
func enter():
	pass

# When the state is active, this is essentially the _process() function
func process_state(delta: float) -> void:
	pass

# When the state is active, this is essentially the _physics_process() function
func physics_process_state(delta: float) -> void:
	pass

# Useful for cleaning up the state
# For example, clearing any timers, disconnecting any signals, etc.
func exit():
	pass


###############################################
# Non FSM-specific methods. These are utility 
# methods that may be used by multiple states. 
###############################################

# Attempts to switch to chase state if it detects the player
func try_chase() -> bool:
	if player and player.alive and get_distance_to_player() <= enemy.detection_radius:
		transitioned.emit(self, "chase")
		return true
	
	return false


func get_distance_to_player() -> float:
	return player.global_position.distance_to(enemy.global_position)


# 基类的默认 on_damaged 实现：切换到 stun 状态
# Stun 状态会覆盖此方法来处理眩晕中再次受伤的情况
func on_damaged(_damage: Damage):
	# 切换到 stun 状态（Stun 状态自己不会调用这个基类方法）
	transitioned.emit(self, "stun")
