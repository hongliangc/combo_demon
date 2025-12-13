extends Area2D
class_name Hitbox

############################################################
# Hitbox component - 用于检测攻击对象(如子弹、武器)的碰撞区域
# 是否与敌人的 Hurtbox 区域重叠。如果重叠，则调用受击区域的伤害方法。
############################################################

@export_group("伤害配置")
## 伤害数据 - 可以在编辑器中配置预设的 Damage 资源
## 如果不配置，将使用下面的 min/max 参数创建默认伤害
@export var damage: Damage = null

## 最小伤害值（当 damage 为 null 时使用）
@export var min_damage: float = 10.0

## 最大伤害值（当 damage 为 null 时使用）
@export var max_damage: float = 50.0

## 伤害类型（当 damage 为 null 时使用）
@export_enum("Physical", "KnockUp", "KnockBack") var damage_type: String = "Physical"

func _ready() -> void:
	# 如果没有配置 damage 资源，创建默认的
	if damage == null:
		damage = Damage.new()
		damage.min_amount = min_damage
		damage.max_amount = max_damage
		damage.type = damage_type

	# 使用Area节点自带的区域area_entered signal连接回调接口，检测碰撞
	area_entered.connect(_on_hitbox_area_entered_)

## 更新攻击伤害（默认生成随机伤害值）
## 子类可以覆盖此方法来实现自定义逻辑（如使用玩家的固定伤害）
func update_attack():
	if damage:
		damage.randomize_damage()

# 建议子类覆盖该方法，然后get_owner().queue_free()
func _on_hitbox_area_entered_(area: Area2D):
	# 更新子类的攻击、伤害等属性
	update_attack()
	if area is Hurtbox:
		area.take_damage(damage)
