extends GutTest
const H = preload("res://test/base/test_helper.gd")

## BehaviorConfig Resource 单元测试
## 验证配置默认值、Boss 扩展、工厂方法

# ============ 默认值 ============

func test_default_health() -> void:
	var config = BehaviorConfig.new()
	assert_eq(config.max_health, 100)
	assert_eq(config.health, 100)

func test_default_wander() -> void:
	var config = BehaviorConfig.new()
	assert_eq(config.min_wander_time, 2.5)
	assert_eq(config.max_wander_time, 10.0)
	assert_eq(config.wander_speed, 50.0)

func test_default_chase() -> void:
	var config = BehaviorConfig.new()
	assert_eq(config.detection_radius, 100.0)
	assert_eq(config.chase_abandon_distance, 200.0)
	assert_eq(config.attack_activation_radius, 25.0)
	assert_eq(config.chase_speed, 75.0)

func test_default_stun() -> void:
	var config = BehaviorConfig.new()
	assert_eq(config.stun_duration, 1.0)
	assert_eq(config.stun_anim_speed, 1.0)

func test_default_not_boss() -> void:
	var config = BehaviorConfig.new()
	assert_false(config.is_boss)
	assert_false(config.ground_only)
	assert_false(config.has_gravity)

# ============ Boss 配置 ============

func test_boss_config_fields() -> void:
	var config = BehaviorConfig.new()
	config.is_boss = true
	config.attack_range = 300.0
	config.min_distance = 150.0
	assert_true(config.is_boss)
	assert_eq(config.attack_range, 300.0)
	assert_eq(config.min_distance, 150.0)

# ============ 工厂方法 ============

func test_create_config_with_defaults() -> void:
	var config = H.create_behavior_config()
	assert_eq(config.max_health, 100)
	assert_eq(config.detection_radius, 100.0)
	assert_false(config.is_boss)

func test_create_config_with_overrides() -> void:
	var config = H.create_behavior_config({
		"max_health": 500,
		"detection_radius": 250.0,
		"is_boss": true,
		"ground_only": true
	})
	assert_eq(config.max_health, 500)
	assert_eq(config.detection_radius, 250.0)
	assert_true(config.is_boss)
	assert_true(config.ground_only)

func test_create_config_partial_override() -> void:
	var config = H.create_behavior_config({"chase_speed": 120.0})
	assert_eq(config.chase_speed, 120.0)
	# 其余保持默认
	assert_eq(config.max_health, 100)
	assert_eq(config.wander_speed, 50.0)
