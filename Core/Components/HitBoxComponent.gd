extends Area2D
class_name HitBoxComponent

############################################################
# HitBoxComponent component - 用于检测攻击对象(如子弹、武器)的碰撞区域
# 是否与敌人的 HurtBoxComponent 区域重叠。如果重叠，则调用受击区域的伤害方法。
############################################################

@export_group("伤害配置")
## 伤害数据 - 可以在编辑器中配置预设的 Damage 资源
## 如果不配置，将使用下面的 min/max 参数创建默认伤害
@export var damage: Damage = null

func _ready() -> void:
	# 如果没有配置 damage 资源，创建默认的
	if damage == null:
		damage = Damage.new()

	# 连接信号（防止重复连接）
	if not area_entered.is_connected(_on_hitbox_area_entered_):
		area_entered.connect(_on_hitbox_area_entered_)

## 更新攻击伤害（默认生成随机伤害值）
## 子类可重写此方法实现自定义逻辑（如从 CombatComponent 获取伤害）
func update_attack() -> void:
	if damage:
		damage.randomize_damage()

## 获取攻击者位置（用于计算击飞/击退方向）
## 子类可重写此方法返回正确的攻击者位置
func get_attacker_position() -> Vector2:
	return global_position

## 碰撞处理 - 通用逻辑已在基类实现，子类通过重写钩子方法定制行为
func _on_hitbox_area_entered_(target: Area2D) -> void:
	update_attack()

	if target is HurtBoxComponent:
		target.take_damage(damage, get_attacker_position())
