class_name AIState extends Node

## 纯执行器状态基类
## 只执行行为，不做决策。通过 dispatch(event) 通知 AIController。

## 同状态再次被切入时是否走 exit→enter（如 Hit 受连击需重置动画+计时）
@export var reentrant: bool = false

## 由 AIController 注入
var ai  # AIController — 不声明类型避免循环引用
var bb: AIBlackboard
var owner_node: Node

# ---- 生命周期（子类重写）----
func enter() -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

# ---- 向 AIController 发送事件 ----
func dispatch(event: StringName) -> void:
	if ai and ai.has_method("dispatch"):
		ai.dispatch(event)
