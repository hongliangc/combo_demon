class_name AIState extends Node

## 纯执行器状态基类。子类只重写生命周期。
## 通过 dispatch(event) 通知 StateController（向上代理给 controller）。

## 同状态再次被切入时是否走 exit→enter（如 Hit 受连击需重置动画+计时）
@export var reentrant: bool = false

## 由 AIController 注入 (legacy) — 在 0.6b 转为 getter
var ai  # AIController — 不声明类型避免循环引用

## 由 StateController.setup 注入 (new path)
var agent: AgentBase
var bb: AIBlackboard          ## AIController 注入；InputController 不注入（保持 null）
var owner_node: Node          ## == agent (legacy alias kept for stock states)

# ---- 生命周期（子类重写）----
func enter() -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

# ---- 向 StateController 或 AIController 发送事件 ----
func dispatch(event: StringName) -> void:
	# New path: route via agent.state_controller (0.6b+)
	if agent and agent.get("state_controller") and agent.state_controller:
		agent.state_controller.dispatch(event)
		return
	# Legacy path: route via ai (AIController)
	if ai and ai.has_method("dispatch"):
		ai.dispatch(event)
