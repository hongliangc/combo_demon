class_name AIBlackboard extends RefCounted

## 动态黑板 — AI 决策的统一数据源
## 学 LimboAI blackboard.cpp：动态字典 + bind_var 属性同步 + parent scope

var _data: Dictionary = {}
var _bindings: Dictionary = {}   # StringName → { object: Object, property: StringName }
var parent: AIBlackboard = null

## 读变量（binding 实时同步 > 本地 > parent > default）
func get_var(var_name: StringName, default: Variant = null) -> Variant:
	if _bindings.has(var_name):
		var b: Dictionary = _bindings[var_name]
		if is_instance_valid(b.object):
			return b.object.get(b.property)
	if _data.has(var_name):
		return _data[var_name]
	if parent:
		return parent.get_var(var_name, default)
	return default

## 写变量
func set_var(var_name: StringName, value: Variant) -> void:
	_data[var_name] = value

func has_var(var_name: StringName) -> bool:
	if _data.has(var_name):
		return true
	if _bindings.has(var_name):
		return true
	if parent:
		return parent.has_var(var_name)
	return false

## 绑定变量到节点属性 — get_var 时实时读取 object.property
func bind_var(var_name: StringName, object: Object, property: StringName) -> void:
	_bindings[var_name] = { "object": object, "property": property }
	if is_instance_valid(object):
		_data[var_name] = object.get(property)

func unbind_var(var_name: StringName) -> void:
	_bindings.erase(var_name)
