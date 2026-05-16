class_name AIState extends Node

## 纯执行器状态基类。子类只重写生命周期。
## 通过 dispatch(event) 通知 StateController（向上代理给 controller）。

## 同状态再次被切入时是否走 exit→enter（如 Hit 受连击需重置动画+计时）
@export var reentrant: bool = false

## 由 StateController.setup 注入 (new path)
var agent: AgentBase
var bb: AIBlackboard          ## AIController 注入；InputController 不注入（保持 null）
var owner_node: Node          ## == agent (legacy alias kept for stock states)

# Legacy alias — to be deleted in Phase 6 after stock states migrated
var ai: Variant:
	get: return agent.controller if agent else null

# ---- 生命周期（子类重写）----
func enter() -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

# ---- 向 StateController 发送事件 ----
func dispatch(event: StringName) -> void:
	if agent and agent.state_controller:
		agent.state_controller.dispatch(event)
