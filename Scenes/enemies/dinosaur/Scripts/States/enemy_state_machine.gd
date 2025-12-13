extends Node

@export var init_state: EnemyStates
var current_state: EnemyStates
var states: Dictionary = {}

@onready var enemy: Enemy = get_owner()
@onready var player: Hahashin = get_tree().get_first_node_in_group("player")

# 接收 enemy.damaged 信号并转发给当前活动状态
func on_damaged(damage: Damage):
	if current_state and current_state.has_method("on_damaged"):
		current_state.on_damaged(damage)

func _ready() -> void:
	# 遍历子节点，添加状态节点到字典中，并注入 enemy 和 player 引用
	for child in get_children():
		if child is EnemyStates:
			states[child.name.to_lower()] = child
			child.transitioned.connect(on_transition)
			# 统一注入引用，避免每个状态重复获取
			child.enemy = enemy
			child.player = player

	# 状态机统一连接 enemy.damaged 信号，并转发给当前活动状态
	if enemy:
		enemy.damaged.connect(on_damaged)

	if init_state:
		current_state = init_state
		current_state.enter()

func _process(delta: float) -> void:
	if current_state:
		current_state.process_state(delta)
	
func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_process_state(delta)

func on_transition(state: EnemyStates, new_state_name: String):
	if state != current_state:
		return
	var new_state = states[new_state_name.to_lower()]
	if !new_state:
		return
	# 退出上个状态
	if current_state:
		current_state.exit()
	 # 进入下一个状态
	new_state.enter()
	current_state = new_state
