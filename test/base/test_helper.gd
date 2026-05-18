extends RefCounted

## 测试工具类 — 提供 mock 工厂方法
## 用法: const H = preload("res://test/base/test_helper.gd")
##       var ctx = H.create_damage_ctx(target, 50.0)

# ============ Mock 工厂方法 ============

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


# ============ v2 BuffEntity helpers ============

static func create_damage_ctx(target: Node, amount: float, source: Node = null, tags: int = 0) -> DamageContext:
	var ctx := DamageContext.new()
	ctx.target = target
	ctx.source = source
	ctx.amount = amount
	ctx.raw_amount = amount
	ctx.tags = tags
	if source is Node2D:
		ctx.source_pos = (source as Node2D).global_position
	return ctx

static func create_buff_entity(id: StringName, duration: float = 0.0, effects: Array[BuffEffect] = []) -> BuffEntity:
	var b := BuffEntity.new()
	b.id = id
	b.duration = duration
	b.effects = effects
	return b

static func build_actor_with_pipeline() -> CharacterBody2D:
	var a := CharacterBody2D.new()
	a.name = "Actor"
	var p := DamagePipeline.new(); p.name = "DamagePipeline"; a.add_child(p)
	var bc := BuffController.new(); bc.name = "BuffController"; a.add_child(bc)
	var sc := StatusController.new(); sc.name = "StatusController"; a.add_child(sc)
	var hc := HealthComponent.new(); hc.name = "HealthComponent"
	hc.max_health = 100.0; hc.health = 100.0
	a.add_child(hc)
	return a
