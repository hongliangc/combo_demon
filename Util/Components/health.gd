extends Node
class_name Health

##############################
# Health Component for enemies
##############################

#通知血量显示变化
signal health_changed(health: float)
signal max_health_changed(max_health: float)
# 基类实例中用于通知销毁enemy或其它对象
signal died()

# 受攻击区域信号处理, 发送signal to health减少血量
@export var hurtbox: Hurtbox

# 设置属性
var max_health: = 100.0:
	set(val):
		max_health = val
		max_health_changed.emit(max_health)
		health = max_health

var health := max_health:
	set(val):
		health =val
		health_changed.emit(health)
		
func _ready() -> void:
	if hurtbox:
		hurtbox.damaged.connect(on_damaged)

	max_health_changed.emit(max_health)
	health_changed.emit(health)
		
func on_damaged(attack: Attack):
	health -= attack.damage
	health = max(0, health)
	if health <= 0:
		died.emit()
		
