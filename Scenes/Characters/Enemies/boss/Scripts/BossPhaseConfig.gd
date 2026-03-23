extends Resource

## Boss 阶段配置 Resource
## 定义单个阶段的攻击池、冷却、行为模式等参数
## 支持主攻击池、追击攻击池、撤退攻击池的分离配置

# ============ 攻击池 ============
## 主攻击池（BossAttack 状态使用）
## 格式: [{ "mode": "fan_spread", "count": 3, "spread": 0.5 }, ...]
@export var attacks: Array = []

## 追击攻击池（BossChase 状态使用，空则回退到 attacks）
@export var chase_attacks: Array = []

## 撤退攻击池（BossRetreat 状态使用，空则回退到 attacks）
@export var retreat_attacks: Array = []

# ============ 时间参数 ============
## 攻击冷却时间
@export var cooldown: float = 1.5

## 攻击持续时间（仅 timer 模式）
@export var attack_duration: float = 1.0

# ============ 行为模式 ============
## "timer" = 站桩开火后退出（Phase 1-2）
## "chase" = 边追边打持续循环（Phase 3）
@export_enum("timer", "chase") var behavior: String = "timer"

## 移动速度倍率（仅 chase 模式）
@export var speed_multiplier: float = 1.0

## 是否免疫伤害反应（受击不切换状态）
@export var immune: bool = false

# ============ 攻击池选择 ============

## 从主攻击池随机选取一个攻击条目
func pick_attack() -> Dictionary:
	if attacks.is_empty():
		return {}
	return attacks.pick_random()

## 从追击攻击池随机选取（空则回退到主攻击池）
func pick_chase_attack() -> Dictionary:
	var pool := chase_attacks if not chase_attacks.is_empty() else attacks
	if pool.is_empty():
		return {}
	return pool.pick_random()

## 从撤退攻击池随机选取（空则回退到主攻击池）
func pick_retreat_attack() -> Dictionary:
	var pool := retreat_attacks if not retreat_attacks.is_empty() else attacks
	if pool.is_empty():
		return {}
	return pool.pick_random()
