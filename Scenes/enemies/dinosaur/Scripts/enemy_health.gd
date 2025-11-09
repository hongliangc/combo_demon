extends Health
class_name EnemyHealth


##############################
# node节点继承基类Health基类，子类实例化对象
# 1. 通过died signal通知enemy节点死亡
# 2. 通过health_changed/ max_health_changed 通知progbar血量变化
##############################

@export var enemy: Enemy = get_owner()

func _ready() -> void:
	max_health = enemy.max_health
	health = enemy.health
	# 调用基类方法Health._ready
	super()


func on_damaged(damage: Damage):
	if !enemy.alive:
		return
	# 调用基类方法Health.on_damaged
	super(damage)
	if health <= 0:
		died.emit()
		enemy.alive = false
	
