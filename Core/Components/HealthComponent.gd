extends Node
class_name HealthComponent

## 健康组件 - 管理角色的生命值、受伤、死亡逻辑
## 适用于 Player、Boss、Enemy
##
## 使用方法:
##   1. 将此组件添加为 CharacterBody2D 的子节点
##   2. 连接 Hurtbox.damaged 信号到 take_damage 方法
##   3. 监听 health_changed 信号更新血条 UI
##   4. 监听 damaged/died 信号处理后续逻辑
##
## 信号流:
##   Hurtbox.damaged → HealthComponent.take_damage()
##       ├─→ 扣血
##       ├─→ 显示伤害数字
##       ├─→ 应用攻击特效
##       ├─→ 发出 health_changed 信号 → 血条 UI
##       └─→ 发出 damaged 信号 → 状态机响应

# ============ 信号 ============
## 生命值变化时发出（用于血条 UI 更新、阶段检测等）
signal health_changed(current: float, maximum: float)

## 受到伤害时发出（用于状态机、特效响应等）
signal damaged(damage: Damage, attacker_position: Vector2)

## 死亡时发出
signal died()

# ============ 配置参数 ============
@export_group("Health")
@export var max_health: float = 100.0
@export var health: float = 100.0

@export_group("Invincibility")
## 是否处于无敌状态（无敌时不受伤害）
@export var is_invincible: bool = false

@export_group("Damage Display")
## 暴击伤害阈值（超过最大伤害的此比例显示为暴击）
@export var critical_threshold: float = 0.8

# ============ 运行时变量 ============
var is_alive: bool = true

# ============ 节点引用 ============
@onready var owner_body: CharacterBody2D = get_parent()

func _ready() -> void:
	# 初始化生命值
	if health <= 0:
		health = max_health

	# 发出初始生命值信号（让血条初始化）
	call_deferred("_emit_initial_health")

func _emit_initial_health() -> void:
	health_changed.emit(health, max_health)

## 接收伤害
## @param damage_data: 伤害数据
## @param attacker_position: 攻击者位置（用于计算击退方向）
func take_damage(damage_data: Damage, attacker_position: Vector2 = Vector2.ZERO) -> void:
	if not is_alive:
		return

	# 无敌状态检查
	if is_invincible:
		DebugConfig.debug("%s 处于无敌状态，忽略伤害" % owner_body.name, "", "combat")
		return

	# 扣除生命值
	var damage_amount = damage_data.amount
	health -= damage_amount
	health = max(0, health)

	# 显示伤害数字
	display_damage_number(damage_data)

	# 应用攻击特效（击退、击飞等）- 必须在发出 damaged 信号之前
	# 因为状态机响应 damaged 信号时会设置 velocity=0，
	# 如果先发信号再应用特效，击退速度会被覆盖
	apply_attack_effects(damage_data, attacker_position)

	# 发出信号（让状态机等监听者响应）
	health_changed.emit(health, max_health)
	damaged.emit(damage_data, attacker_position)

	# 检查死亡
	if health <= 0:
		die()

## 显示伤害数字（支持暴击显示）
func display_damage_number(damage_data: Damage) -> void:
	var damage_anchor = owner_body.get_node_or_null("DamageNumbersAnchor")
	if damage_anchor:
		# 检查是否暴击
		var is_critical = false
		if damage_data.max_amount > 0:
			is_critical = damage_data.amount > damage_data.max_amount * critical_threshold
		DamageNumbers.display_number(int(damage_data.amount), damage_anchor.global_position, is_critical)

## 应用攻击特效
func apply_attack_effects(damage_data: Damage, attacker_position: Vector2) -> void:
	for effect in damage_data.effects:
		if effect != null and effect.has_method("apply_effect"):
			effect.apply_effect(owner_body, attacker_position)

## 治疗
## @param amount: 治疗量
func heal(amount: float) -> void:
	if not is_alive:
		return

	health += amount
	health = min(health, max_health)

	# 发出信号
	health_changed.emit(health, max_health)

## 死亡处理
func die() -> void:
	if not is_alive:
		return

	is_alive = false

	# 发出死亡信号
	died.emit()

	DebugConfig.debug("%s 死亡!" % owner_body.name, "", "combat")

## 设置无敌状态
## @param duration: 无敌持续时间（秒），0 表示永久无敌直到手动关闭
func set_invincible(enabled: bool, duration: float = 0.0) -> void:
	is_invincible = enabled
	if enabled and duration > 0:
		get_tree().create_timer(duration).timeout.connect(func():
			is_invincible = false
		)

## 获取当前生命值百分比
func get_health_percent() -> float:
	return health / max_health if max_health > 0 else 0.0

## 是否存活
func is_character_alive() -> bool:
	return is_alive

## 重置生命值（用于复活、重新开始等）
func reset_health() -> void:
	health = max_health
	is_alive = true
	health_changed.emit(health, max_health)
