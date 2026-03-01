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

@export_group("行为配置")
## 命中后销毁父节点（用于子弹等一次性攻击）
@export var destroy_owner_on_hit: bool = false

## 忽略特定碰撞组（避免同阵营伤害）
@export var ignore_collision_groups: Array[String] = []

@export_group("碰撞配置")
## 碰撞层（哪些层上的物体可以被这个Hitbox检测到）
## 设置为0表示使用场景中配置的默认值
@export_flags_2d_physics var collision_layer_override: int = 0

## 碰撞掩码（这个Hitbox可以检测哪些层上的物体）
## 设置为0表示使用场景中配置的默认值
@export_flags_2d_physics var collision_mask_override: int = 0

func _ready() -> void:
	# 如果配置了碰撞层覆盖，应用它
	if collision_layer_override > 0:
		collision_layer = collision_layer_override
	if collision_mask_override > 0:
		collision_mask = collision_mask_override

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
func _on_hitbox_area_entered_(area: Area2D) -> void:
	# 检查是否需要忽略此碰撞组
	for group in ignore_collision_groups:
		if area.is_in_group(group):
			return

	# 更新攻击伤害（子类可重写 update_attack）
	update_attack()

	if area is HurtBoxComponent:
		# 传递攻击者位置（子类可重写 get_attacker_position）
		area.take_damage(damage, get_attacker_position())

	# 如果配置了命中后销毁，则销毁父节点
	if destroy_owner_on_hit:
		get_owner().queue_free()
