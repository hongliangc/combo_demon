extends GutTest
const H = preload("res://test/base/test_helper.gd")

## 伤害链路集成测试
## 验证 Damage → HealthComponent → 信号 → 状态机 完整流程

var _owner: CharacterBody2D
var _health_comp: HealthComponent
var _pipe: DamagePipeline
var _sm: BaseStateMachine
var _states: Dictionary

func before_each() -> void:
	# 构建最小完整链路:
	# CharacterBody2D (with damaged signal)
	#   ├─ DamagePipeline
	#   ├─ HealthComponent
	#   └─ BaseStateMachine
	#       ├─ idle (BEHAVIOR)
	#       └─ hit (REACTION)

	_owner = CharacterBody2D.new()
	_owner.name = "TestEnemy"
	_owner.set_meta("alive", true)

	# DamagePipeline (Phase 3 — HealthComponent now subscribes pipeline.apply)
	_pipe = DamagePipeline.new()
	_pipe.name = "DamagePipeline"
	_owner.add_child(_pipe)

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
	_pipe = null
	_sm = null
	_states = {}

# Phase 3: HC.take_damage() removed. Damage now flows through DamagePipeline.
func _deal(amount: float) -> void:
	var ctx := DamageContext.new()
	ctx.target = _owner
	ctx.amount = amount
	ctx.raw_amount = amount
	_pipe.process(ctx)

# ============ 伤害 → 扣血 ============

func test_damage_reduces_health() -> void:
	_deal(30.0)
	assert_eq(_health_comp.health, 70.0)

# ============ 伤害 → 信号链 ============

func test_damage_emits_health_changed_and_damaged() -> void:
	watch_signals(_health_comp)
	_deal(10.0)
	assert_signal_emitted(_health_comp, "health_changed")
	assert_signal_emitted(_health_comp, "damaged")

# ============ 致死伤害 → 死亡信号 ============

func test_lethal_damage_emits_died() -> void:
	watch_signals(_health_comp)
	_deal(100.0)
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
	# Phase 5: legacy on_damaged(Damage, Vector2) slot is dead — AAB now subscribes
	# pipeline.react. H.create_stun_damage builds Array[AttackEffect] Damage which
	# Damage v2 (Array[BuffEntity]) rejects. Buff-driven hit reactions covered by
	# test_buff_pipeline_integration.gd / test_buff_effects_integration.gd.
	pending("Phase 5: legacy state-machine on_damaged slot dead; rewrite via pipeline.react in Cyclops/DS2 migration")

func test_on_damaged_with_knockback_routes_to_hit() -> void:
	pending("Phase 5: legacy state-machine on_damaged slot dead; rewrite via pipeline.react in Cyclops/DS2 migration")

# ============ 伤害缓存 ============

func test_damage_cached_in_state_machine() -> void:
	# Phase 5: BaseStateMachine._on_owner_damaged is dead code (BaseCharacter no
	# longer emits damaged). Damage caching now belongs to AAB._on_pipeline_react.
	pending("Phase 5: BaseStateMachine damaged-cache path dead; AAB pipeline.react covers in Cyclops/DS2 migration")

# ============ 多次伤害序列 ============

func test_multiple_damages_track_health_correctly() -> void:
	_deal(20.0)
	_deal(30.0)
	_deal(10.0)
	assert_eq(_health_comp.health, 40.0)

# ============ 致死/死后伤害：HC 标 blocked，react 下游可早退 ============

func test_lethal_blow_marks_ctx_blocked() -> void:
	var ctx := DamageContext.new()
	ctx.target = _owner
	ctx.amount = 100.0
	ctx.raw_amount = 100.0
	_pipe.process(ctx)
	assert_false(_health_comp.is_alive)
	assert_true(ctx.blocked, "lethal blow should mark ctx.blocked so react skips Hit transition")

func test_posthumous_damage_marks_ctx_blocked() -> void:
	_deal(100.0)
	assert_false(_health_comp.is_alive)
	var ctx := DamageContext.new()
	ctx.target = _owner
	ctx.amount = 10.0
	ctx.raw_amount = 10.0
	_pipe.process(ctx)
	assert_true(ctx.blocked, "HC should mark ctx.blocked when target is dead")
	assert_eq(_health_comp.health, 0.0)
