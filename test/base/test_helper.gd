extends RefCounted

## 测试工具类 — 提供 mock 工厂方法
## 用法: const H = preload("res://test/base/test_helper.gd")
##       var dmg = H.create_damage(50.0)

# ============ Mock 工厂方法 ============

static func create_damage(amount: float = 10.0, effects: Array[AttackEffect] = []) -> Damage:
	var dmg = Damage.new()
	dmg.amount = amount
	dmg.min_amount = amount * 0.5
	dmg.max_amount = amount * 1.5
	dmg.effects = effects
	return dmg


static func create_stun_damage(amount: float = 10.0, stun_duration: float = 1.5) -> Damage:
	var stun = StunEffect.new()
	stun.stun_duration = stun_duration
	return create_damage(amount, [stun])


static func create_knockback_damage(amount: float = 10.0, force: float = 300.0) -> Damage:
	var kb = KnockBackEffect.new()
	kb.knockback_force = force
	return create_damage(amount, [kb])


static func create_behavior_config(overrides: Dictionary = {}) -> BehaviorConfig:
	var config = BehaviorConfig.new()
	config.max_health = overrides.get("max_health", 100)
	config.health = overrides.get("health", 100)
	config.min_idle_time = overrides.get("min_idle_time", 1.0)
	config.max_idle_time = overrides.get("max_idle_time", 3.0)
	config.min_wander_time = overrides.get("min_wander_time", 2.5)
	config.max_wander_time = overrides.get("max_wander_time", 10.0)
	config.wander_speed = overrides.get("wander_speed", 50.0)
	config.detection_radius = overrides.get("detection_radius", 100.0)
	config.chase_abandon_distance = overrides.get("chase_abandon_distance", 200.0)
	config.attack_activation_radius = overrides.get("attack_activation_radius", 25.0)
	config.chase_speed = overrides.get("chase_speed", 75.0)
	config.stun_duration = overrides.get("stun_duration", 1.0)
	config.hit_duration = overrides.get("hit_duration", 0.3)
	config.ground_only = overrides.get("ground_only", false)
	config.has_gravity = overrides.get("has_gravity", false)
	config.is_boss = overrides.get("is_boss", false)
	return config
