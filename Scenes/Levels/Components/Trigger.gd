extends Area2D
class_name LevelTrigger

## 触发器组件 - 通用区域触发器
##
## 功能：
## - 进入/离开信号
## - 单次/多次触发选项
## - 可绑定各种事件

signal triggered(body: Node2D)
signal untriggered(body: Node2D)

@export var one_shot: bool = true
@export var trigger_delay: float = 0.0
@export var only_player: bool = true
@export var show_debug: bool = false

var has_triggered: bool = false
var bodies_in_area: Array[Node2D] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if show_debug:
		_setup_debug_visual()


func _on_body_entered(body: Node2D) -> void:
	if only_player and not body.is_in_group("player"):
		return

	bodies_in_area.append(body)

	if one_shot and has_triggered:
		return

	if trigger_delay > 0:
		await get_tree().create_timer(trigger_delay).timeout
		if body in bodies_in_area:
			_trigger(body)
	else:
		_trigger(body)


func _on_body_exited(body: Node2D) -> void:
	bodies_in_area.erase(body)

	if only_player and not body.is_in_group("player"):
		return

	untriggered.emit(body)


func _trigger(body: Node2D) -> void:
	has_triggered = true
	triggered.emit(body)

	if show_debug:
		print("Trigger: Activated by ", body.name)

	if one_shot:
		# 禁用触发器
		set_deferred("monitoring", false)


## 重置触发器
func reset() -> void:
	has_triggered = false
	set_deferred("monitoring", true)


func _setup_debug_visual() -> void:
	var debug_rect = ColorRect.new()
	debug_rect.color = Color(1, 0, 0, 0.3)
	debug_rect.size = Vector2(32, 32)
	debug_rect.position = Vector2(-16, -16)
	add_child(debug_rect)
