extends Hitbox
class_name PlayerHitbox

## 玩家专用 Hitbox - 从 CombatComponent 动态获取伤害类型
## 只需重写钩子方法，通用逻辑由基类处理
## 注意：不覆盖 _ready()，完全依赖基类的信号连接和初始化

@onready var player: Hahashin = get_owner()

## 重写：从 CombatComponent 获取当前伤害类型
func update_attack() -> void:
	if player and player.combat_component:
		damage = player.combat_component.current_damage

## 重写：返回玩家位置作为攻击者位置
func get_attacker_position() -> Vector2:
	return player.global_position if player else global_position
