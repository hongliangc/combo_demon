# GUT 测试模式库

可直接复用的 GUT 测试代码模板。

---

## 基础结构

```gdscript
extends GutTest

var _comp: HealthComponent

func before_each() -> void:
    _comp = HealthComponent.new()
    _comp.max_health = 100.0
    _comp.health = 100.0
    add_child_autofree(_comp)

func test_take_damage_reduces_health() -> void:
    var dmg = Damage.new(); dmg.amount = 30.0
    _comp.take_damage(dmg)
    assert_eq(_comp.health, 70.0, "减少血量")

func test_health_clamps_to_zero() -> void:
    var dmg = Damage.new(); dmg.amount = 150.0
    _comp.take_damage(dmg)
    assert_eq(_comp.health, 0.0)

func test_heal_cannot_exceed_max() -> void:
    _comp.heal(50.0)
    assert_eq(_comp.health, 100.0)

func test_invincible_blocks_damage() -> void:
    _comp.set_invincible(true)
    var dmg = Damage.new(); dmg.amount = 50.0
    _comp.take_damage(dmg)
    assert_eq(_comp.health, 100.0)
```

---

## 信号测试

```gdscript
func test_damage_emits_signal() -> void:
    watch_signals(_comp)
    var dmg = Damage.new(); dmg.amount = 10.0
    _comp.take_damage(dmg)
    assert_signal_emitted(_comp, "damaged")
    assert_signal_emitted_with_parameters(_comp, "health_changed", [90.0, 100.0])

func test_die_emits_signal() -> void:
    watch_signals(_comp)
    var dmg = Damage.new(); dmg.amount = 100.0
    _comp.take_damage(dmg)
    assert_signal_emitted(_comp, "died")
    assert_false(_comp.is_alive)

func test_same_phase_change_ignored() -> void:
    watch_signals(_boss)
    _boss.change_phase(BossBase.Phase.PHASE_1)
    assert_signal_not_emitted(_boss, "phase_changed")
```

---

## Resource 测试 (Damage)

```gdscript
func test_has_effect() -> void:
    var dmg = Damage.new()
    dmg.effects.append(StunEffect.new())
    assert_true(dmg.has_effect("StunEffect"))
    assert_false(dmg.has_effect("KnockUpEffect"))

func test_randomize_in_range() -> void:
    var dmg = Damage.new()
    dmg.min_amount = 10.0; dmg.max_amount = 20.0
    for i in range(10):
        dmg.randomize_damage()
        assert_between(dmg.amount, 10.0, 20.0)
```

---

## 状态机优先级测试

```gdscript
func test_control_interrupts_behavior() -> void:
    var b = _make_state(BaseState.StatePriority.BEHAVIOR)
    var c = _make_state(BaseState.StatePriority.CONTROL)
    assert_true(b.can_transition_to(c))

func test_same_priority_respects_interruptible() -> void:
    var s1 = _make_state(BaseState.StatePriority.CONTROL, false)
    var s2 = _make_state(BaseState.StatePriority.CONTROL)
    assert_false(s1.can_transition_to(s2))
    s1.can_be_interrupted = true
    assert_true(s1.can_transition_to(s2))

func _make_state(priority, interruptible := true) -> BaseState:
    var s = BaseState.new()
    s.priority = priority; s.can_be_interrupted = interruptible
    add_child_autofree(s); return s
```

---

## SpecialSkillState 测试

```gdscript
func test_cannot_trigger_during_cooldown() -> void:
    var skill = SpecialSkillState.new()
    skill.skill_probability = 1.0; skill._cooldown_remaining = 3.0
    add_child_autofree(skill)
    assert_false(skill.can_trigger(100.0))

func test_finish_skill_sets_cooldown() -> void:
    var skill = SpecialSkillState.new(); skill.skill_cooldown = 8.0
    add_child_autofree(skill); skill.finish_skill()
    assert_eq(skill._cooldown_remaining, 8.0)

func test_make_damage_with_knockback() -> void:
    var skill = SpecialSkillState.new(); add_child_autofree(skill)
    var dmg = skill._make_damage(25.0, 300.0)
    assert_eq(dmg.amount, 25.0)
    assert_true(dmg.has_effect("KnockBackEffect"))
```

---

## Fixture 场景测试

```gdscript
# test/fixtures/: test_enemy.tscn, test_player.tscn, test_damage.tres
func test_enemy_takes_damage_in_scene() -> void:
    var enemy = preload("res://test/fixtures/test_enemy.tscn").instantiate()
    add_child_autofree(enemy)
    await get_tree().process_frame
    var hp = enemy.get_node("HealthComponent")
    var initial = hp.health
    var dmg = Damage.new(); dmg.amount = 20.0
    hp.take_damage(dmg)
    assert_lt(hp.health, initial)
```

Fixture 原则：最小节点集、无 Sprite/Animation、物理层配置正确。

---

## GUT API 速查

| 断言 | 用途 |
|------|------|
| `assert_eq(a, b, msg)` | 相等 |
| `assert_ne(a, b, msg)` | 不等 |
| `assert_true/false(expr, msg)` | 布尔 |
| `assert_null/not_null(val, msg)` | null 检查 |
| `assert_gt/lt(a, b, msg)` | 大于/小于 |
| `assert_between(val, lo, hi, msg)` | 范围内 |
| `assert_signal_emitted(obj, sig)` | 信号已发出 |
| `assert_signal_not_emitted(obj, sig)` | 信号未发出 |
| `assert_signal_emitted_with_parameters(obj, sig, params)` | 信号参数 |
| `assert_signal_emit_count(obj, sig, n)` | 信号次数 |
| `watch_signals(obj)` | 监听信号（断言前调用） |
| `add_child_autofree(node)` | 添加并自动释放 |

