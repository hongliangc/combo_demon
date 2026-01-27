extends Node
class_name BaseStateMachine

## 通用状态机基类
## 可被 Enemy、Boss、Player 等任何需要状态机的实体复用
##
## 使用方法:
## 1. 继承此类或直接使用
## 2. 设置 owner_node_group 和 target_node_group
## 3. 添加状态节点作为子节点
## 4. 连接 owner 的 damaged 信号（如果需要）

# ============ 导出参数 ============
## 初始状态（在编辑器中设置）
@export var init_state: BaseState

## Owner 节点所在的组名（例如 "enemy", "boss", "player"）
@export var owner_node_group: String = ""

## Target 节点所在的组名（例如 "player"）
@export var target_node_group: String = "player"

# ============ 核心变量 ============
## 当前激活的状态
var current_state: BaseState

## 状态字典 {状态名: 状态节点}
var states: Dictionary = {}

## Owner 节点引用（如 Enemy, Boss）
var owner_node: Node

## Target 节点引用（通常是 Player）
var target_node: Node

# ============ 生命周期 ============
func _ready() -> void:
	# 获取 owner 节点（CharacterBody2D等）
	owner_node = get_owner()

	# 如果设置了 owner_node_group，从组中获取
	if owner_node_group != "":
		var nodes = get_tree().get_nodes_in_group(owner_node_group)
		if nodes.size() > 0:
			# 检查是否是当前场景树的一部分
			for node in nodes:
				if is_ancestor_of_node(node):
					owner_node = node
					break

	# 延迟获取 target 节点，避免初始化顺序问题
	if target_node_group != "":
		call_deferred("_find_target_node")

	# 初始化状态字典
	_setup_states()

	# 连接信号
	_setup_signals()

	# 进入初始状态
	if init_state:
		current_state = init_state
		current_state.enter()


func _process(delta: float) -> void:
	if current_state:
		current_state.process_state(delta)


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_process_state(delta)

# ============ 核心方法 ============
## 延迟查找 target 节点（在所有节点 ready 后执行）
func _find_target_node() -> void:
	if target_node_group != "":
		target_node = get_tree().get_first_node_in_group(target_node_group)

		# 更新所有已初始化状态的 target_node 引用
		for state in states.values():
			if state is BaseState:
				state.target_node = target_node


## 设置所有状态节点
func _setup_states() -> void:
	for child in get_children():
		if child is BaseState:
			# 添加到字典
			states[child.name.to_lower()] = child

			# 连接状态转换信号
			child.transitioned.connect(_on_state_transition)

			# 注入引用
			child.owner_node = owner_node
			child.target_node = target_node
			child.state_machine = self


## 设置信号连接（子类可重写）
func _setup_signals() -> void:
	# 连接 damaged 信号（如果 owner 有的话）
	if owner_node and owner_node.has_signal("damaged"):
		if not owner_node.is_connected("damaged", _on_owner_damaged):
			owner_node.damaged.connect(_on_owner_damaged)


## 状态转换处理
func _on_state_transition(from_state: BaseState, new_state_name: String) -> void:
	# 只处理当前状态的转换请求
	if from_state != current_state:
		return

	# 查找新状态
	var new_state = states.get(new_state_name.to_lower())
	if not new_state:
		push_warning("[StateMachine] 状态 '%s' 不存在" % new_state_name)
		return

	# 退出当前状态
	if current_state:
		current_state.exit()

	# 进入新状态
	new_state.enter()
	current_state = new_state

	# 打印状态转换日志
	var owner_name = str(owner_node.name) if owner_node else "Unknown"
	var from_name = str(from_state.name) if from_state else "None"
	DebugConfig.debug("[%s StateMachine] %s -> %s" % [owner_name, from_name, new_state_name], "", "state_machine")


## 当 owner 受到伤害时
func _on_owner_damaged(damage: Damage, attacker_position: Vector2 = Vector2.ZERO) -> void:
	if current_state and current_state.has_method("on_damaged"):
		current_state.on_damaged(damage, attacker_position)


## 强制切换到指定状态（用于外部控制）
func force_transition(new_state_name: String) -> void:
	_on_state_transition(current_state, new_state_name)


## 获取当前状态名称
func get_current_state_name() -> String:
	return current_state.name if current_state else ""


## 检查是否处于某个状态
func is_in_state(state_name: String) -> bool:
	return current_state and current_state.name.to_lower() == state_name.to_lower()

# ============ 工具方法 ============
## 检查 node 是否是当前场景树的祖先
func is_ancestor_of_node(node: Node) -> bool:
	var current = self
	while current:
		if current == node:
			return true
		current = current.get_parent()
	return false
