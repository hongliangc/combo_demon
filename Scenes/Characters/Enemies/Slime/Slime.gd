extends EnemyBase
class_name Slime

## Slime 自定义脚本
## 负责监听 HP 降至 50% 以下时触发一次性分裂技能
## can_split 可被 SlimeSplitState 设为 false 以防止递归

var can_split := true


func _ready() -> void:
	super._ready()
	var health_comp: Node = get_node_or_null("HealthComponent")
	if health_comp and health_comp.has_signal("health_changed"):
		health_comp.health_changed.connect(_on_health_changed)


func _on_health_changed(current_health: float, _max_health: float) -> void:
	if not can_split:
		return
	if _max_health <= 0.0:
		return
	if current_health / _max_health < 0.5:
		can_split = false
		var sm: Node = get_node_or_null("EnemyStateMachine")
		if sm and sm.has_method("transition_to"):
			sm.transition_to("specialskill")
