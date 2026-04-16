extends GutTest
const H = preload("res://test/base/test_helper.gd")

## 伤害链路集成测试
## 验证 Damage → HealthComponent → 信号 → 状态机 完整流程

var _owner: CharacterBody2D
var _health_comp: HealthComponent
var _sm: BaseStateMachine
var _states: Dictionary

func before_each() -> void:
	# 构建最小完整链路:
	# CharacterBody2D (with damaged signal)
	#   ├─ HealthComponent
	#   └─ BaseStateMachine
	#       ├─ idle (BEHAVIOR)
	#       └─ hit (REACTION)

	_owner = CharacterBody2D.new()
	_owner.name = "TestEnemy"
	_owner.set_meta("alive", true)

	# HealthComponent
	_health_comp = HealthComponent.new()
	_health_comp.name = "HealthComponent"
	_health_comp.max_health = 100.0
	_health_comp.health = 100.0
	_owner.add_child(_health_comp)

	# StateMachine
	_sm = BaseStateMachine.new()
	_sm.name = "StateMachine"
	_sm.owner_node_group = ""
	_sm.target_node_group = ""

	_states = {}
	for entry in [
		["idle", BaseState.StatePriority.BEHAVIOR],
		["hit", BaseState.StatePriority.REACTION],
	]:
		var state = BaseState.new()
		state.name = entry[0]
		state.priority = entry[1]
		_sm.add_child(state)
		_states[entry[0]] = state

	_sm.init_state = _states["idle"]
	_owner.add_child(_sm)

	add_child_autofree(_owner)
	await wait_frames(1)

func after_each() -> void:
	_owner = null
	_health_comp = null
	_sm = null
	_states = {}

# ============ 伤害 → 扣血 ============

func test_damage_reduces_health() -> void:
	var dmg = H.create_damage(30.0)
	_health_comp.take_damage(dmg, Vector2.ZERO)
	assert_eq(_health_comp.health, 70.0)

# ============ 伤害 → 信号链 ============

func test_damage_emits_health_changed_and_damaged() -> void:
	watch_signals(_health_comp)
	_health_comp.take_damage(H.create_damage(10.0), Vector2.ZERO)
	assert_signal_emitted(_health_comp, "health_changed")
	assert_signal_emitted(_health_comp, "damaged")

# ============ 致死伤害 → 死亡信号 ============

func test_lethal_damage_emits_died() -> void:
	watch_signals(_health_comp)
	_health_comp.take_damage(H.create_damage(100.0), Vector2.ZERO)
	assert_signal_emitted(_health_comp, "died")
	assert_false(_health_comp.is_alive)

# ============ 状态机集成 ============

func test_state_machine_starts_in_idle() -> void:
	assert_eq(_sm.current_state.name, "idle")

func test_on_damaged_routes_to_hit_state() -> void:
	var idle: BaseState = _states["idle"]
	idle.state_machine = _sm
	idle.on_damaged(H.create_damage(10.0), Vector2.ZERO)
	assert_eq(_sm.current_state.name, "hit")

func test_on_damaged_with_stun_routes_to_hit() -> void:
	# StunEffect 不再路由到单独的 stun 状态，统一进入 hit
	var idle: BaseState = _states["idle"]
	idle.state_machine = _sm
	idle.on_damaged(H.create_stun_damage(10.0, 2.0), Vector2.ZERO)
	assert_eq(_sm.current_state.name, "hit")

func test_on_damaged_with_knockback_routes_to_hit() -> void:
	# KnockBackEffect 不再路由到单独的 knockback 状态，统一进入 hit
	var idle: BaseState = _states["idle"]
	idle.state_machine = _sm
	idle.on_damaged(H.create_knockback_damage(10.0, 300.0), Vector2.ZERO)
	assert_eq(_sm.current_state.name, "hit")

# ============ 伤害缓存 ============

func test_damage_cached_in_state_machine() -> void:
	var dmg = H.create_stun_damage(15.0, 2.0)
	var pos = Vector2(50, 100)
	_sm._on_owner_damaged(dmg, pos)
	assert_eq(_sm.last_damage, dmg)
	assert_eq(_sm.last_attacker_position, pos)

# ============ 多次伤害序列 ============

func test_multiple_damages_track_health_correctly() -> void:
	_health_comp.take_damage(H.create_damage(20.0), Vector2.ZERO)
	_health_comp.take_damage(H.create_damage(30.0), Vector2.ZERO)
	_health_comp.take_damage(H.create_damage(10.0), Vector2.ZERO)
	assert_eq(_health_comp.health, 40.0)
