extends GutTest

## 项目测试基类
## 提供 mock 工厂方法、通用断言、信号监听工具
## 所有单元测试和集成测试都应继承此类

const _SignalTracker = preload("res://test/base/signal_tracker.gd")

# ============ Mock 工厂方法 ============

## 创建一个最小化的 Damage Resource
func create_damage(amount: float = 10.0, effects: Array[AttackEffect] = []) -> Damage:
	var dmg = Damage.new()
	dmg.amount = amount
	dmg.min_amount = amount * 0.5
	dmg.max_amount = amount * 1.5
	dmg.effects = effects
	return dmg


## 创建带眩晕效果的 Damage
func create_stun_damage(amount: float = 10.0, stun_duration: float = 1.5) -> Damage:
	var stun = StunEffect.new()
	stun.stun_duration = stun_duration
	return create_damage(amount, [stun])


## 创建带击退效果的 Damage
func create_knockback_damage(amount: float = 10.0, force: float = 300.0) -> Damage:
	var kb = KnockBackEffect.new()
	kb.knockback_force = force
	return create_damage(amount, [kb])


## 创建一个 BehaviorConfig Resource
func create_behavior_config(overrides: Dictionary = {}) -> BehaviorConfig:
	var config = BehaviorConfig.new()
	# 设置合理的默认值
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


# ============ 信号断言工具 ============

## 监听信号并记录调用次数和参数
## 用法:
##   var tracker = track_signal(obj, "my_signal")
##   obj.my_signal.emit(42)
##   assert_eq(tracker.count, 1)
##   assert_eq(tracker.last_args, [42])
func track_signal(obj: Object, signal_name: String) -> RefCounted:
	var tracker = _SignalTracker.new()
	# GUT 的 watch_signals 只能计数，这里提供更完整的追踪
	var callable = tracker._on_signal_received
	if obj.has_signal(signal_name):
		obj.connect(signal_name, callable)
	return tracker


## 断言信号在指定时间内被发出
## 注意：此方法是协程，需要 await
func assert_signal_emitted_within(obj: Object, signal_name: String, timeout: float = 1.0, msg: String = "") -> void:
	watch_signals(obj)
	await wait_for_signal(obj.get(signal_name), timeout)
	assert_signal_emitted(obj, signal_name, msg if msg != "" else "Signal '%s' should be emitted" % signal_name)


# ============ 场景树工具 ============
# GUT 已提供: add_child_autofree(), wait_frames(), wait_seconds()
# 直接使用父类方法即可，无需重写

## 等待指定物理帧数
func wait_physics_frames(count: int = 1) -> void:
	for i in count:
		await get_tree().physics_frame


# ============ 自定义断言 ============

## 断言值在指定范围内（含边界）
func assert_between(value: float, low: float, high: float, msg: String = "") -> void:
	var text = msg if msg != "" else "Expected %f between %f and %f" % [value, low, high]
	assert_true(value >= low and value <= high, text)


## 断言两个 Vector2 近似相等
func assert_vector2_approx(actual: Vector2, expected: Vector2, tolerance: float = 0.01, msg: String = "") -> void:
	var text = msg if msg != "" else "Expected %s ≈ %s (tolerance=%f)" % [actual, expected, tolerance]
	assert_true(actual.distance_to(expected) <= tolerance, text)


## 断言节点存在且类型正确
func assert_node_exists(parent: Node, path: String, expected_type = null, msg: String = "") -> void:
	var node = parent.get_node_or_null(path)
	assert_not_null(node, msg if msg != "" else "Node '%s' should exist" % path)
	if node and expected_type:
		assert_is(node, expected_type, "Node '%s' should be type %s" % [path, expected_type])
