extends Node

@export var init_state: EnemyStates
var current_state: EnemyStates
var states: Dictionary = {}

func _ready() -> void:
	# 遍历子节点，添加状态节点到字典中
	for child in get_children():
		if child is EnemyStates:
			states[child.name.to_lower()] = child
			child.transitioned.connect(on_transition)
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
