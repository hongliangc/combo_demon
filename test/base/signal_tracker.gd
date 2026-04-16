extends RefCounted
class_name SignalTracker

## 信号追踪器 — 记录信号发射次数和参数
## 由 GutTestBase.track_signal() 创建

## 信号被调用的次数
var count: int = 0

## 最后一次调用的参数
var last_args: Array = []

## 所有调用记录 [{args: [...]}]
var calls: Array[Dictionary] = []

## 信号回调（支持 0-5 个参数）
func _on_signal_received(a1 = "__NONE__", a2 = "__NONE__", a3 = "__NONE__", a4 = "__NONE__", a5 = "__NONE__") -> void:
	count += 1
	var args: Array = []
	for arg in [a1, a2, a3, a4, a5]:
		if arg is String and arg == "__NONE__":
			break
		args.append(arg)
	last_args = args
	calls.append({"args": args})


## 重置追踪数据
func reset() -> void:
	count = 0
	last_args = []
	calls = []


## 检查是否被调用过
func was_called() -> bool:
	return count > 0


## 获取第 N 次调用的参数
func get_call_args(index: int) -> Array:
	if index >= 0 and index < calls.size():
		return calls[index].args
	return []
