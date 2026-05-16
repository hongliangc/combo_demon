extends HitBoxComponent
class_name PlayerHitbox

## 玩家专用 HitBoxComponent - 从 CombatComponent 动态获取伤害类型
## 只需重写钩子方法，通用逻辑由基类处理
## 注意：不覆盖 _ready()，完全依赖基类的信号连接和初始化

@onready var player: AgentBase = get_owner()

## Phase 0 stub — base class no longer exposes `damage`. Hahashin migration in
## Phase 1 replaces this whole file with skill-driven configure_from_skill.
func update_attack() -> void:
	pass

## 重写：返回玩家位置作为攻击者位置
func get_attacker_position() -> Vector2:
	return player.global_position if player else global_position
