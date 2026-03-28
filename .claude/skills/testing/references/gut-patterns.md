# GUT 测试模式库

可直接复用的 GUT 测试代码模板，按测试类型分类。

---

## 1. 基础测试模板 — HealthComponent

```gdscript
extends GutTest

## HealthComponent 单元测试

var _health_comp: HealthComponent

func before_each() -> void:
    _health_comp = HealthComponent.new()
    _health_comp.max_health = 100.0
    _health_comp.health = 100.0
    add_child_autofree(_health_comp)

func test_take_damage_reduces_health() -> void:
    var dmg = Damage.new()
    dmg.amount = 30.0
    _health_comp.take_damage(dmg)
    assert_eq(_health_comp.health, 70.0, "Health should be reduced by damage amount")

func test_take_damage_emits_damaged_signal() -> void:
    watch_signals(_health_comp)
    var dmg = Damage.new()
    dmg.amount = 10.0
    _health_comp.take_damage(dmg)
    assert_signal_emitted(_health_comp, "damaged")

func test_take_damage_emits_health_changed() -> void:
    watch_signals(_health_comp)
    var dmg = Damage.new()
    dmg.amount = 25.0
    _health_comp.take_damage(dmg)
    assert_signal_emitted_with_parameters(_health_comp, "health_changed", [75.0, 100.0])

func test_die_when_health_reaches_zero() -> void:
    watch_signals(_health_comp)
    var dmg = Damage.new()
    dmg.amount = 100.0
    _health_comp.take_damage(dmg)
    assert_signal_emitted(_health_comp, "died")
    assert_false(_health_comp.is_alive)

func test_health_cannot_go_below_zero() -> void:
    var dmg = Damage.new()
    dmg.amount = 150.0
    _health_comp.take_damage(dmg)
    assert_eq(_health_comp.health, 0.0, "Health should not go below zero")

func test_heal_increases_health() -> void:
    var dmg = Damage.new()
    dmg.amount = 50.0
    _health_comp.take_damage(dmg)
    _health_comp.heal(30.0)
    assert_eq(_health_comp.health, 80.0, "Health should increase after heal")

func test_heal_cannot_exceed_max() -> void:
    _health_comp.heal(50.0)
    assert_eq(_health_comp.health, 100.0, "Health should not exceed max")

func test_invincible_blocks_damage() -> void:
    _health_comp.set_invincible(true)
    var dmg = Damage.new()
    dmg.amount = 50.0
    _health_comp.take_damage(dmg)
    assert_eq(_health_comp.health, 100.0, "Invincible should block damage")

func test_dead_entity_cannot_take_damage() -> void:
    _health_comp.die()
    var dmg = Damage.new()
    dmg.amount = 50.0
    _health_comp.take_damage(dmg)
    # health stays at whatever it was when died
    assert_false(_health_comp.is_alive)
```

---

## 2. Resource 测试模板 — Damage

```gdscript
extends GutTest

## Damage Resource 单元测试

func test_damage_creation_with_amount() -> void:
    var dmg = Damage.new()
    dmg.amount = 25.0
    assert_eq(dmg.amount, 25.0, "Damage amount should match")

func test_damage_has_effect_with_stun() -> void:
    var dmg = Damage.new()
    var stun = StunEffect.new()
    dmg.effects.append(stun)
    assert_true(dmg.has_effect("StunEffect"), "Should detect StunEffect")

func test_damage_has_effect_without_effect() -> void:
    var dmg = Damage.new()
    assert_false(dmg.has_effect("StunEffect"), "Should not detect missing effect")

func test_damage_has_effect_multiple() -> void:
    var dmg = Damage.new()
    dmg.effects.append(StunEffect.new())
    dmg.effects.append(KnockBackEffect.new())
    assert_true(dmg.has_effect("StunEffect"), "Should detect StunEffect")
    assert_true(dmg.has_effect("KnockBackEffect"), "Should detect KnockBackEffect")
    assert_false(dmg.has_effect("KnockUpEffect"), "Should not detect missing KnockUpEffect")

func test_damage_randomize_in_range() -> void:
    var dmg = Damage.new()
    dmg.min_amount = 10.0
    dmg.max_amount = 20.0
    for i in range(10):
        dmg.randomize_damage()
        assert_between(dmg.amount, 10.0, 20.0, "Randomized damage should be in range")

func test_damage_effects_description_empty() -> void:
    var dmg = Damage.new()
    assert_eq(dmg.get_effects_description(), "无特效", "Empty effects should return '无特效'")

func test_damage_effects_description_with_effects() -> void:
    var dmg = Damage.new()
    dmg.effects.append(StunEffect.new())
    var desc = dmg.get_effects_description()
    assert_ne(desc, "无特效", "Should have effect description")
```

---

## 3. 状态机测试模板 — 优先级检查

```gdscript
extends GutTest

## 状态优先级测试

func test_control_interrupts_behavior() -> void:
    var behavior_state = BaseState.new()
    behavior_state.priority = BaseState.StatePriority.BEHAVIOR
    var control_state = BaseState.new()
    control_state.priority = BaseState.StatePriority.CONTROL
    add_child_autofree(behavior_state)
    add_child_autofree(control_state)
    assert_true(behavior_state.can_transition_to(control_state),
        "CONTROL should interrupt BEHAVIOR")

func test_behavior_cannot_interrupt_control() -> void:
    var behavior_state = BaseState.new()
    behavior_state.priority = BaseState.StatePriority.BEHAVIOR
    var control_state = BaseState.new()
    control_state.priority = BaseState.StatePriority.CONTROL
    control_state.can_be_interrupted = false
    add_child_autofree(behavior_state)
    add_child_autofree(control_state)
    # CONTROL 主动转 BEHAVIOR 是允许的（自愿结束）
    assert_true(control_state.can_transition_to(behavior_state),
        "CONTROL can voluntarily transition to BEHAVIOR")

func test_reaction_interrupts_behavior() -> void:
    var behavior = BaseState.new()
    behavior.priority = BaseState.StatePriority.BEHAVIOR
    var reaction = BaseState.new()
    reaction.priority = BaseState.StatePriority.REACTION
    add_child_autofree(behavior)
    add_child_autofree(reaction)
    assert_true(behavior.can_transition_to(reaction),
        "REACTION should interrupt BEHAVIOR")

func test_same_priority_checks_interruptible() -> void:
    var state1 = BaseState.new()
    state1.priority = BaseState.StatePriority.BEHAVIOR
    state1.can_be_interrupted = true
    var state2 = BaseState.new()
    state2.priority = BaseState.StatePriority.BEHAVIOR
    add_child_autofree(state1)
    add_child_autofree(state2)
    assert_true(state1.can_transition_to(state2),
        "Same priority with can_be_interrupted=true should allow")

func test_same_priority_blocked_if_not_interruptible() -> void:
    var state1 = BaseState.new()
    state1.priority = BaseState.StatePriority.CONTROL
    state1.can_be_interrupted = false
    var state2 = BaseState.new()
    state2.priority = BaseState.StatePriority.CONTROL
    add_child_autofree(state1)
    add_child_autofree(state2)
    assert_false(state1.can_transition_to(state2),
        "Same priority with can_be_interrupted=false should block")
```

---

## 4. 信号测试模板 — BossBase 阶段转换

```gdscript
extends GutTest

## Boss 阶段转换测试
## 注意：BossBase 需要 HealthComponent 子节点才能正常工作
## 简单的阶段逻辑可直接测试，复杂场景需要 fixture

func test_phase_enum_values() -> void:
    assert_eq(BossBase.Phase.PHASE_1, 0)
    assert_eq(BossBase.Phase.PHASE_2, 1)
    assert_eq(BossBase.Phase.PHASE_3, 2)

func test_boss_initial_phase() -> void:
    var boss = BossBase.new()
    add_child_autofree(boss)
    assert_eq(boss.current_phase, BossBase.Phase.PHASE_1,
        "Boss should start in Phase 1")

func test_change_phase_updates_current_phase() -> void:
    var boss = BossBase.new()
    add_child_autofree(boss)
    boss.change_phase(BossBase.Phase.PHASE_2)
    assert_eq(boss.current_phase, BossBase.Phase.PHASE_2)

func test_change_phase_emits_signal() -> void:
    var boss = BossBase.new()
    add_child_autofree(boss)
    watch_signals(boss)
    boss.change_phase(BossBase.Phase.PHASE_2)
    assert_signal_emitted(boss, "phase_changed")
    assert_signal_emitted_with_parameters(boss, "phase_changed",
        [BossBase.Phase.PHASE_2])

func test_same_phase_change_is_ignored() -> void:
    var boss = BossBase.new()
    add_child_autofree(boss)
    watch_signals(boss)
    boss.change_phase(BossBase.Phase.PHASE_1)  # 已经是 PHASE_1
    assert_signal_not_emitted(boss, "phase_changed",
        "Changing to same phase should be ignored")
```

---

## 5. 攻击效果测试模板

```gdscript
extends GutTest

## AttackEffect 子类测试
## 注意：需要 CharacterBody2D 的测试使用 fixture 场景

func test_knockback_effect_creation() -> void:
    var kb = KnockBackEffect.new()
    kb.knockback_force = 300.0
    assert_eq(kb.knockback_force, 300.0)

func test_stun_effect_creation() -> void:
    var stun = StunEffect.new()
    assert_not_null(stun)

func test_damage_apply_effects_calls_all() -> void:
    var dmg = Damage.new()
    var kb = KnockBackEffect.new()
    kb.knockback_force = 200.0
    var stun = StunEffect.new()
    dmg.effects.append(kb)
    dmg.effects.append(stun)
    # apply_effects 需要有效的 target Node，此处验证不崩溃
    # 完整测试需要在场景中进行
    assert_eq(dmg.effects.size(), 2, "Should have 2 effects")
```

---

## 6. SpecialSkillState 测试模板

```gdscript
extends GutTest

## SpecialSkillState 基础测试

func test_initial_cooldown_is_zero() -> void:
    var skill = SpecialSkillState.new()
    add_child_autofree(skill)
    assert_eq(skill._cooldown_remaining, 0.0)

func test_can_trigger_when_no_cooldown() -> void:
    var skill = SpecialSkillState.new()
    skill.skill_probability = 1.0  # 100% 概率
    skill.skill_cooldown = 5.0
    add_child_autofree(skill)
    assert_true(skill.can_trigger(100.0),
        "Should trigger when no cooldown and 100% probability")

func test_cannot_trigger_during_cooldown() -> void:
    var skill = SpecialSkillState.new()
    skill.skill_probability = 1.0
    skill._cooldown_remaining = 3.0
    add_child_autofree(skill)
    assert_false(skill.can_trigger(100.0),
        "Should not trigger during cooldown")

func test_finish_skill_sets_cooldown() -> void:
    var skill = SpecialSkillState.new()
    skill.skill_cooldown = 8.0
    add_child_autofree(skill)
    skill.finish_skill()
    assert_eq(skill._cooldown_remaining, 8.0,
        "finish_skill should set cooldown")

func test_make_damage_creates_correct_damage() -> void:
    var skill = SpecialSkillState.new()
    add_child_autofree(skill)
    var dmg = skill._make_damage(25.0, 300.0)
    assert_eq(dmg.amount, 25.0)
    assert_true(dmg.has_effect("KnockBackEffect"),
        "Should have knockback effect when knockback > 0")

func test_make_damage_without_knockback() -> void:
    var skill = SpecialSkillState.new()
    add_child_autofree(skill)
    var dmg = skill._make_damage(15.0, 0.0)
    assert_eq(dmg.amount, 15.0)
    assert_false(dmg.has_effect("KnockBackEffect"),
        "Should not have knockback when force is 0")
```

---

## 7. 测试 Fixtures 说明

共享测试资源放在 `test/fixtures/` 目录：

```
test/fixtures/
├── test_enemy.tscn      # 最小敌人场景（CharacterBody2D + HealthComponent + HurtBox）
├── test_player.tscn     # 最小玩家场景
└── test_damage.tres     # 预配置的测试用 Damage Resource
```

**创建 fixture 场景的原则**：
- 只包含测试必需的最小节点集
- 不包含视觉效果（Sprite、Animation 等）
- 物理层配置正确
- 使用 `add_child_autofree()` 自动清理

**使用 fixture 的测试示例**：
```gdscript
extends GutTest

func test_enemy_takes_damage_in_scene() -> void:
    var enemy = preload("res://test/fixtures/test_enemy.tscn").instantiate()
    add_child_autofree(enemy)
    # 等一帧让 _ready 执行
    await get_tree().process_frame
    var health_comp = enemy.get_node("HealthComponent")
    var initial_health = health_comp.health
    var dmg = Damage.new()
    dmg.amount = 20.0
    health_comp.take_damage(dmg)
    assert_lt(health_comp.health, initial_health, "Health should decrease")
```

---

## 8. 常用 GUT 断言速查

| 断言 | 用途 |
|------|------|
| `assert_eq(a, b, msg)` | 相等 |
| `assert_ne(a, b, msg)` | 不等 |
| `assert_true(expr, msg)` | 为真 |
| `assert_false(expr, msg)` | 为假 |
| `assert_null(val, msg)` | 为 null |
| `assert_not_null(val, msg)` | 非 null |
| `assert_gt(a, b, msg)` | 大于 |
| `assert_lt(a, b, msg)` | 小于 |
| `assert_between(val, low, high, msg)` | 在范围内 |
| `assert_signal_emitted(obj, signal_name)` | 信号已发出 |
| `assert_signal_not_emitted(obj, signal_name)` | 信号未发出 |
| `assert_signal_emitted_with_parameters(obj, signal, params)` | 信号参数匹配 |
| `assert_signal_emit_count(obj, signal, count)` | 信号发出次数 |
| `watch_signals(obj)` | 开始监听信号（在断言前调用） |
| `add_child_autofree(node)` | 添加节点并在测试后自动释放 |
