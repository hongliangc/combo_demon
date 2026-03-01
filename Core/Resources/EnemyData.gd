@tool
extends Resource
class_name EnemyData

## 敌人配置资源 - 数据驱动的敌人参数配置
## 用于 EnemyBase.enemy_data 导出属性
##
## 使用方法:
##   1. 在 FileSystem 中右键 → New Resource → EnemyData
##   2. 配置参数并保存为 .tres 文件
##   3. 在敌人场景的 Inspector 中将 .tres 拖入 enemy_data 属性
##   4. EnemyBase._ready() 会自动应用这些参数

@export_group("Health")
@export var max_health := 100
@export var health := 100

@export_group("Wander")
@export var min_wander_time := 2.5
@export var max_wander_time := 10.0
@export var wander_speed := 50.0

@export_group("Chase")
@export var detection_radius := 100.0
@export var chase_radius := 200.0
@export var follow_radius := 25.0
@export var chase_speed := 75

@export_group("Physics")
@export var has_gravity := false
@export var gravity := 800.0

## 调试打印
func debug_print() -> void:
	print("========== EnemyData ==========")
	print("Health: %d / %d" % [health, max_health])
	print("Wander: speed=%.1f time=%.1f~%.1f" % [wander_speed, min_wander_time, max_wander_time])
	print("Chase: speed=%d detect=%.1f chase=%.1f follow=%.1f" % [chase_speed, detection_radius, chase_radius, follow_radius])
	print("Physics: gravity=%s (%.1f)" % [has_gravity, gravity])
	print("===============================")
