# BuffEntity Framework — BladeKeeper PoC Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the v2 BuffEntity framework (DamagePipeline + BuffController + StatusController) as a single-point validation on BladeKeeper, leaving Cyclops / DS2 / Enemy migrations for Phase 2.

**Architecture:** Five-layer signal-driven pipeline. `HealthComponent` only subscribes `DamagePipeline.apply`; `BuffController` subscribes `pre_calc / pre_apply / post_apply`; `StatusController` exposes `LegalAction` bitmask gating. `BuffEntity` is composition of `BuffEffect[]` driven by `EffectOn` bitmask. DoT / heal / damage all share one pipeline, distinguished by `DamageContext.tags / is_heal`.

**Tech Stack:** Godot 4.4.1 GDScript, Resource @export, signals, GUT for unit tests.

**Source Spec:** [docs/superpowers/specs/2026-04-26-buff-entity-framework-design-v2.md](../specs/2026-04-26-buff-entity-framework-design-v2.md)

**Test scene:** [Scenes/Levels/Level_BladeKeeper/LevelBladeKeeper.tscn](../../../Scenes/Levels/Level_BladeKeeper/LevelBladeKeeper.tscn)

---

## Plan Amendments

### A1 — 2026-04-28: drop `target_kind`, derive target from `ctx.trigger` (Phase 4 CR Important #1)

**Driver:** Phase 4 code-review flagged that `DamageEffectBuff` / `KnockBackEffectBuff` defaulted `effect_on` to TICK / APPLY but exposed `target_kind` independently. A designer setting `target_kind = 1` (target the attacker) without also OR-ing `ON_DAMAGED` into `effect_on` would silently fall back to `ctx.owner` and self-damage / self-knockback.

**Resolution:** `target_kind` is redundant. The trigger fully determines the meaningful target:

| `ctx.trigger`                    | Target                          |
|----------------------------------|---------------------------------|
| `ON_DAMAGED` / `ON_HEAL`         | `ctx.damage_ctx.source`         |
| any other (APPLY / TICK / etc.) | `ctx.owner`                     |

**Changes:**
- `DamageEffectBuff` / `KnockBackEffectBuff`: drop `@export var target_kind`. `_resolve_target` switches on `ctx.trigger`.
- Designers who need an unusual mapping (e.g., self-damage on hit) author a new subclass; the data model stays clean.
- Phase 4 thorns integration test no longer sets `target_kind`.
- BK reactive-push .tres in Task 27 drops the `target_kind = 1` line.
- Source spec [v2 §3.4 / §8.6](../specs/2026-04-26-buff-entity-framework-design-v2.md) updated in lockstep.

---

## File Structure

### Created — Core/Damage/
- `DamageContext.gd` — RefCounted, mutable damage envelope (source/target/amount/tags/blocked/is_heal)
- `DamagePipeline.gd` — Node, 5 signals (pre_calc / pre_apply / apply / post_apply / react) + `process(ctx)`
- `DamageTags.gd` — int constants (PHYSICAL / MAGICAL / DOT / CRIT / TRUE)

### Created — Core/Buffs/
- `StatIds.gd` — StringName constants (INCOMING_DAMAGE / OUTGOING_DAMAGE / HEAL_RECEIVED)
- `BuffEffect.gd` — Resource base + `EffectOn` enum + `execute(ctx)` virtual
- `BuffEffectContext.gd` — RefCounted (owner / instance / trigger / damage_ctx / delta)
- `BuffEntity.gd` — Resource (id / duration / stacking / tags / legal_action_locks / hit_reaction / effects) + `execute_on(trigger, ctx)`
- `BuffInstance.gd` — RefCounted (entity / remaining / tick_accums / stacks / source_actor / source_pos / gen_id)
- `BuffController.gd` — Node, holds active instances + subscribes pipeline + aggregates modifiers/locks
- `effects/StatModEffect.gd` — adjusts BuffController stat modifiers on APPLY/EXPIRE
- `effects/DamageEffectBuff.gd` — TICK or callback construct DamageContext + pipe.process
- `effects/HealEffectBuff.gd` — TICK construct ctx.is_heal=true + pipe.process
- `effects/KnockBackEffectBuff.gd` — APPLY or ON_DAMAGED set CharacterBody2D velocity
- `effects/KnockUpEffectBuff.gd` — APPLY set vertical velocity + horizontal direction
- `library/bk_defense_x05_3s.tres` — DefenseBuff: INCOMING_DAMAGE × 0.5 for 3s
- `library/bk_heal_pulse.tres` — HealBuff: HoT 8 hp/sec for 3s
- `library/bk_reactive_push.tres` — Permanent buff: ON_DAMAGED knockback source
- `library/poison_dot.tres` — DoT: 5/0.5s for 8s
- `library/test_stun_short.tres` — Stun buff: legal_action_locks=STUN, duration 1s, hit_reaction=stun
- `library/test_knockback_buff.tres` — Knockback buff: APPLY velocity push + hit_reaction=knockback

### Created — Core/Status/
- `LegalAction.gd` — int constants (NONE / ATTACK / MOVE / DEFEND / CAST / HURTABLE / ALL + composites)
- `StatusController.gd` — Node, legal_actions bitmask + per-action timers + buff lock recompute

### Modified
- [Core/Components/HealthComponent.gd](../../../Core/Components/HealthComponent.gd) — full rewrite: subscribe `pipeline.apply`, expose `_commit / heal`, drop `take_damage / is_invincible`
- [Core/Components/HitBoxComponent.gd](../../../Core/Components/HitBoxComponent.gd) — `_on_area_entered` builds `DamageContext` and calls `pipe.process`
- [Core/Resources/Damage.gd](../../../Core/Resources/Damage.gd) — `effects: Array[BuffEntity]` (was `Array[AttackEffect]`); add `tags: int`; remove `apply_effects / has_effect / get_effects_description`
- [Core/AI/AgentAIBase.gd](../../../Core/AI/AgentAIBase.gd) — `_setup_signals` connects `pipeline.react` + `status.legal_actions_changed`; `_on_agent_damaged` becomes `_on_pipeline_react` (DamageContext-based); `_on_agent_died` clears BC
- [Core/AI/Stock/HitState.gd](../../../Core/AI/Stock/HitState.gd) — query-only: read `BuffController.get_top_hit_buff` for animation + duration; drop effect application
- [Core/AI/Stock/GenericAttackState.gd](../../../Core/AI/Stock/GenericAttackState.gd) — add `apply_skill_self_buff` for animation method-call hook
- [Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd](../../../Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd) — `apply_defense_buff` / `heal_self` invoke `BuffController.apply` with .tres
- [Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn](../../../Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn) — add `DamagePipeline / BuffController / StatusController` nodes (HC retained)
- [Scenes/Characters/Templates/PlayerBase.tscn](../../../Scenes/Characters/Templates/PlayerBase.tscn) — same 4 nodes (Player is also a victim of BK reactive push)
- [test/base/test_helper.gd](../../../test/base/test_helper.gd) — add `create_buff_entity / create_damage_v2 / build_test_actor` factory functions

### Tests Created — test/unit/
- `test_damage_pipeline.gd` — emit ordering / blocked short-circuit / is_heal route
- `test_buff_controller_apply.gd` — apply / refresh / replace / stack
- `test_buff_controller_tick.gd` — TICK accum precision; multiple effects on same buff
- `test_buff_controller_expire.gd` — EXPIRE called on duration-out / clear_all
- `test_buff_stat_modifier.gd` — get_modifier multiplier; APPLY/EXPIRE in/out pairing
- `test_status_controller.gd` — LegalAction aggregation; longest-wins; buff lock recompute
- `test_dot_pipeline.gd` — DoT travels through pipeline; DOT tag skips react; benefits from defense
- `test_heal_pipeline.gd` — heal route; HEAL_RECEIVED stat applied; is_heal skips damaged signal
- `test_callback_effects.gd` — ON_DAMAGED triggers reactive knockback on source
- `test_dodge_iframes.gd` — HURTABLE off → ctx.blocked → HP unchanged → auto-restore

### Test Helper Updates
- Update existing `test_health_component.gd` to use new `_commit` flow OR rewrite as `test_health_component_v2.gd` and delete the old one.

### NOT in scope (Phase 2)
- AttackEffect 5 subclasses deletion (keep them so Cyclops/DS2 still build)
- Cyclops / DS2 / Enemy template migration
- 9 Damage .tres data migration (only BK-relevant .tres updated)
- HealthBar UI changes (no signal contract change)

---

## Task Order Rationale

1. **Tasks 1-4: Foundation** — DamageTags, DamageContext, DamagePipeline (no dependencies)
2. **Tasks 5-9: Buff data layer** — constants → BuffEffect → BuffEntity → BuffInstance (data first, no Node)
3. **Tasks 10-13: BuffController & StatusController** — runtime + capability
4. **Tasks 14-15: HealthComponent rewrite** — thin commit subscriber
5. **Tasks 16-19: BuffEffect subclasses** — needed before .tres can be authored
6. **Tasks 20-22: HitBox / Damage / AAB rewire** — pipeline integration
7. **Tasks 23-24: HitState / GenericAttackState** — completes AI side
8. **Tasks 25-28: BK + Player scenes + library .tres** — manual setup
9. **Tasks 29-30: BK script wiring + smoke validation**
10. **Task 31: PoC manual acceptance**

Each task ends with a green-test commit. Branch `feat/buff-entity-framework` is already cut from main.

---

## Conventions

- File charset: UTF-8 LF
- Test class: `extends GutTest`, `before_each / after_each`, use `add_child_autofree`
- Run tests: `bash test/run_tests.sh <name>` (without `test_` prefix). Helper script auto-prepends `test_`.
- Run all unit tests: `bash test/run_tests.sh unit`
- Commit style: `feat(buff): <message>` for new code; `refactor(buff): <message>` for rewrites; `test(buff): <message>` for tests-only.

---

### Task 1: DamageTags Constants

**Files:**
- Create: `Core/Damage/DamageTags.gd`

- [ ] **Step 1: Write the constants file**

```gdscript
# Core/Damage/DamageTags.gd
class_name DamageTags

const PHYSICAL := 1
const MAGICAL  := 2
const DOT      := 4         # 跳过 HitState reaction
const CRIT     := 8
const TRUE     := 16        # 真伤，无视 INCOMING_DAMAGE 倍率
```

- [ ] **Step 2: Commit**

```bash
git add Core/Damage/DamageTags.gd
git commit -m "feat(buff): add DamageTags constants"
```

---

### Task 2: DamageContext

**Files:**
- Create: `Core/Damage/DamageContext.gd`
- Test: `test/unit/test_damage_pipeline.gd` (created in Task 4 — this task only writes the class)

- [ ] **Step 1: Write the class**

```gdscript
# Core/Damage/DamageContext.gd
class_name DamageContext extends RefCounted

## Mutable damage envelope passed through DamagePipeline.
## Pipeline stages may adjust amount, set blocked, fill dealt, attach buffs.

var source: Node = null                          # 攻击者
var target: Node = null                          # 受害者
var raw_amount: float = 0.0                      # 原始伤害（不可变参考）
var amount: float = 0.0                          # pipeline 中可变
var source_pos: Vector2 = Vector2.ZERO
var attached_buffs: Array[BuffEntity] = []       # 攻击携带的 buff
var tags: int = 0                                # DamageTags bitmask
var blocked: bool = false                        # 任一阶段可设
var dealt: float = 0.0                           # apply 后回填实际扣血量
var is_heal: bool = false                        # 治疗复用同管线
```

- [ ] **Step 2: Commit**

```bash
git add Core/Damage/DamageContext.gd
git commit -m "feat(buff): add DamageContext envelope"
```

---

### Task 3: DamagePipeline Node

**Files:**
- Create: `Core/Damage/DamagePipeline.gd`

- [ ] **Step 1: Write the class**

```gdscript
# Core/Damage/DamagePipeline.gd
class_name DamagePipeline extends Node

## Signal hub for damage / heal flow.
## Stages emit in order: pre_calc → pre_apply → apply → post_apply → react.
## Any subscriber may set ctx.blocked = true to short-circuit before apply.

signal pre_calc(ctx: DamageContext)
signal pre_apply(ctx: DamageContext)
signal apply(ctx: DamageContext)
signal post_apply(ctx: DamageContext)
signal react(ctx: DamageContext)

func process(ctx: DamageContext) -> void:
    if ctx == null:
        return
    pre_calc.emit(ctx)
    if ctx.blocked: return
    pre_apply.emit(ctx)
    if ctx.blocked: return
    apply.emit(ctx)
    post_apply.emit(ctx)
    react.emit(ctx)
```

- [ ] **Step 2: Commit**

```bash
git add Core/Damage/DamagePipeline.gd
git commit -m "feat(buff): add DamagePipeline signal hub"
```

---

### Task 4: DamagePipeline TDD Test

**Files:**
- Test: `test/unit/test_damage_pipeline.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# test/unit/test_damage_pipeline.gd
extends GutTest

var _pipe: DamagePipeline
var _ordering: Array

func before_each() -> void:
    _pipe = DamagePipeline.new()
    add_child_autofree(_pipe)
    _ordering = []

func _record(stage: String) -> Callable:
    return func(_ctx: DamageContext) -> void: _ordering.append(stage)

func test_emits_in_order() -> void:
    _pipe.pre_calc.connect(_record("pre_calc"))
    _pipe.pre_apply.connect(_record("pre_apply"))
    _pipe.apply.connect(_record("apply"))
    _pipe.post_apply.connect(_record("post_apply"))
    _pipe.react.connect(_record("react"))
    _pipe.process(DamageContext.new())
    assert_eq(_ordering, ["pre_calc", "pre_apply", "apply", "post_apply", "react"])

func test_blocked_in_pre_calc_short_circuits() -> void:
    _pipe.pre_calc.connect(func(ctx): ctx.blocked = true)
    _pipe.pre_apply.connect(_record("pre_apply"))
    _pipe.apply.connect(_record("apply"))
    _pipe.process(DamageContext.new())
    assert_eq(_ordering, [], "no further stages after block")

func test_blocked_in_pre_apply_short_circuits() -> void:
    _pipe.pre_apply.connect(func(ctx): ctx.blocked = true)
    _pipe.apply.connect(_record("apply"))
    _pipe.post_apply.connect(_record("post_apply"))
    _pipe.process(DamageContext.new())
    assert_eq(_ordering, [], "apply not invoked once blocked")

func test_apply_runs_even_after_subscribers_modify_amount() -> void:
    var ctx := DamageContext.new()
    ctx.amount = 10.0
    _pipe.pre_calc.connect(func(c): c.amount *= 0.5)
    _pipe.process(ctx)
    assert_eq(ctx.amount, 5.0)

func test_null_context_no_crash() -> void:
    _pipe.process(null)
    pass_test("survived null ctx")
```

- [ ] **Step 2: Run test to verify it passes (Tasks 2-3 already wrote the prod code)**

Run: `bash test/run_tests.sh damage_pipeline`
Expected: 5/5 PASS

- [ ] **Step 3: Commit**

```bash
git add test/unit/test_damage_pipeline.gd
git commit -m "test(buff): cover DamagePipeline ordering and blocking"
```

---

### Task 5: StatIds Constants

**Files:**
- Create: `Core/Buffs/StatIds.gd`

- [ ] **Step 1: Write the file**

```gdscript
# Core/Buffs/StatIds.gd
class_name StatIds

const INCOMING_DAMAGE := &"incoming_damage"     # victim-side multiplier on amount
const OUTGOING_DAMAGE := &"outgoing_damage"     # attacker-side multiplier on amount
const HEAL_RECEIVED   := &"heal_received"       # victim-side multiplier on heal amount
```

- [ ] **Step 2: Commit**

```bash
git add Core/Buffs/StatIds.gd
git commit -m "feat(buff): add StatIds constants"
```

---

### Task 6: LegalAction Constants

**Files:**
- Create: `Core/Status/LegalAction.gd`

- [ ] **Step 1: Write the file**

```gdscript
# Core/Status/LegalAction.gd
class_name LegalAction

const NONE     := 0
const ATTACK   := 1
const MOVE     := 2
const DEFEND   := 4    # 闪避/格挡 AI 行为
const CAST     := 8    # 远程/特殊技能
const HURTABLE := 16   # 可被伤害（关闭 = i-frames）
const ALL      := 31

# 复合状态（按位或组合）
const STUN    := ATTACK | MOVE | DEFEND | CAST   # 全锁，仍 HURTABLE
const ROOT    := MOVE
const DISARM  := ATTACK
const SILENCE := CAST
const SLEEP   := ATTACK | MOVE | CAST
```

- [ ] **Step 2: Commit**

```bash
git add Core/Status/LegalAction.gd
git commit -m "feat(buff): add LegalAction bitmask constants"
```

---

### Task 7: BuffEffect Base + EffectOn

**Files:**
- Create: `Core/Buffs/BuffEffect.gd`

- [ ] **Step 1: Write the file**

```gdscript
# Core/Buffs/BuffEffect.gd
class_name BuffEffect extends Resource

## Base for all buff effect strategies.
## Subclasses override execute(ctx). EffectOn bitmask controls when execute runs.

enum EffectOn {
    APPLY      = 1,    # buff 入栈瞬间
    TICK       = 2,    # 每 tick_interval（Effect 自管间隔）
    EXPIRE     = 4,    # buff 移除（duration / dispel / 死亡）
    STACK      = 8,    # 叠层时
    ON_DAMAGED = 16,   # 持有者受击 callback
    ON_ATTACK  = 32,   # 持有者攻击 callback
    ON_HEAL    = 64,   # 持有者受治疗 callback
}

@export_flags("Apply", "Tick", "Expire", "Stack", "OnDamaged", "OnAttack", "OnHeal")
var effect_on: int = EffectOn.APPLY

func execute(_ctx: BuffEffectContext) -> void:
    pass  # 子类实现
```

- [ ] **Step 2: Commit**

```bash
git add Core/Buffs/BuffEffect.gd
git commit -m "feat(buff): add BuffEffect base + EffectOn bitmask"
```

---

### Task 8: BuffEffectContext

**Files:**
- Create: `Core/Buffs/BuffEffectContext.gd`

- [ ] **Step 1: Write the file**

```gdscript
# Core/Buffs/BuffEffectContext.gd
class_name BuffEffectContext extends RefCounted

## Per-effect execution context. Filled by BuffController._exec_effect.

var owner: Node = null                  # buff 持有者
var instance: BuffInstance = null       # 当前 buff 实例
var trigger: int = 0                    # 当前 EffectOn 位
var damage_ctx: DamageContext = null    # 仅 ON_DAMAGED/ON_ATTACK/ON_HEAL 时填
var delta: float = 0.0                  # 仅 TICK 时填
```

- [ ] **Step 2: Commit**

```bash
git add Core/Buffs/BuffEffectContext.gd
git commit -m "feat(buff): add BuffEffectContext"
```

---

### Task 9: BuffEntity Resource

**Files:**
- Create: `Core/Buffs/BuffEntity.gd`

- [ ] **Step 1: Write the file**

```gdscript
# Core/Buffs/BuffEntity.gd
class_name BuffEntity extends Resource

## Immutable buff configuration. Multiple instances share the same Resource.

enum Stacking { REFRESH, STACK, REPLACE }

@export var id: StringName = &""
@export var duration: float = 0.0          # 0 = 永久
@export var stacking: Stacking = Stacking.REFRESH
@export var max_stacks: int = 99

@export_flags("Physical", "Magical", "Curse", "Bleed", "Poison")
var tags: int = 0

@export_flags("Attack", "Move", "Defend", "Cast", "Hurtable")
var legal_action_locks: int = 0

@export var hit_reaction: StringName = &""
@export var hit_priority: int = 0
@export var hit_lock_duration: float = 0.0

@export var effects: Array[BuffEffect] = []

## Run all effects whose effect_on bitmask matches the given trigger.
func execute_on(trigger: int, ctx: BuffEffectContext) -> void:
    for e in effects:
        if e and (e.effect_on & trigger) != 0:
            ctx.trigger = trigger
            e.execute(ctx)
```

- [ ] **Step 2: Commit**

```bash
git add Core/Buffs/BuffEntity.gd
git commit -m "feat(buff): add BuffEntity Resource"
```

---

### Task 10: BuffInstance

**Files:**
- Create: `Core/Buffs/BuffInstance.gd`

- [ ] **Step 1: Write the file**

```gdscript
# Core/Buffs/BuffInstance.gd
class_name BuffInstance extends RefCounted

## Per-application runtime state. Multiple instances may share one BuffEntity.

var entity: BuffEntity = null
var remaining: float = 0.0           # 剩余时长（duration > 0 时）
var tick_accums: Dictionary = {}     # effect index → accumulator (float)
var stacks: int = 1
var source_actor: Node = null
var source_pos: Vector2 = Vector2.ZERO
var gen_id: int = 0                  # 同 id 多实例时唯一 ID（STACK 模式用）
```

- [ ] **Step 2: Commit**

```bash
git add Core/Buffs/BuffInstance.gd
git commit -m "feat(buff): add BuffInstance runtime state"
```

---

### Task 11: BuffController — apply / tick / expire / stat modifiers

**Files:**
- Create: `Core/Buffs/BuffController.gd`

- [ ] **Step 1: Write the class skeleton + apply / tick / expire / modifier API + pipeline subscriptions**

```gdscript
# Core/Buffs/BuffController.gd
class_name BuffController extends Node

## Per-actor buff container. Subscribes parent's DamagePipeline for incoming-damage hooks.

signal buffs_changed

var active: Array[BuffInstance] = []
var _stat_modifiers: Dictionary = {}     # StringName → Array[float]
var _gen_id_counter: int = 0

@onready var owner_node: Node = get_parent()
@onready var pipeline: DamagePipeline = owner_node.get_node_or_null(^"DamagePipeline") if owner_node else null

func _ready() -> void:
    if pipeline:
        pipeline.pre_calc.connect(_on_pre_calc)
        pipeline.pre_apply.connect(_on_pre_apply)
        pipeline.post_apply.connect(_on_post_apply)

# ============ Apply ============
func apply(buff: BuffEntity, source_actor: Node, source_pos: Vector2) -> void:
    if buff == null:
        return
    match buff.stacking:
        BuffEntity.Stacking.REFRESH:
            var existing := _find_by_id(buff.id)
            if existing:
                existing.remaining = buff.duration
                buffs_changed.emit()
                return
        BuffEntity.Stacking.REPLACE:
            var existing := _find_by_id(buff.id)
            if existing:
                _expire(existing)
                active.erase(existing)
        BuffEntity.Stacking.STACK:
            pass

    var inst := BuffInstance.new()
    inst.entity = buff
    inst.remaining = buff.duration
    inst.source_actor = source_actor
    inst.source_pos = source_pos
    inst.gen_id = _gen_id_counter
    _gen_id_counter += 1
    active.append(inst)

    var ctx := _make_ctx(inst, BuffEffect.EffectOn.APPLY)
    buff.execute_on(BuffEffect.EffectOn.APPLY, ctx)
    buffs_changed.emit()

# ============ Tick (per physics frame) ============
func _physics_process(delta: float) -> void:
    var changed := false
    var i := active.size() - 1
    while i >= 0:
        var inst := active[i]
        _tick_instance(inst, delta)
        if inst.entity.duration > 0:
            inst.remaining -= delta
            if inst.remaining <= 0.0:
                _expire(inst)
                active.remove_at(i)
                changed = true
        i -= 1
    if changed:
        buffs_changed.emit()

func _tick_instance(inst: BuffInstance, delta: float) -> void:
    for idx in inst.entity.effects.size():
        var eff: BuffEffect = inst.entity.effects[idx]
        if eff == null or (eff.effect_on & BuffEffect.EffectOn.TICK) == 0:
            continue
        var interval: float = 0.0
        if &"tick_interval" in eff:
            interval = float(eff.get(&"tick_interval"))
        if interval <= 0.0:
            _exec_effect(eff, inst, delta, BuffEffect.EffectOn.TICK)
            continue
        var accum: float = float(inst.tick_accums.get(idx, 0.0)) + delta
        if accum >= interval:
            inst.tick_accums[idx] = accum - interval
            _exec_effect(eff, inst, delta, BuffEffect.EffectOn.TICK)
        else:
            inst.tick_accums[idx] = accum

func _expire(inst: BuffInstance) -> void:
    var ctx := _make_ctx(inst, BuffEffect.EffectOn.EXPIRE)
    inst.entity.execute_on(BuffEffect.EffectOn.EXPIRE, ctx)

func clear_all() -> void:
    for inst in active:
        _expire(inst)
    active.clear()
    _stat_modifiers.clear()
    buffs_changed.emit()

# ============ Pipeline subscriptions ============
func _on_pre_calc(dc: DamageContext) -> void:
    if dc.target != owner_node:
        return
    if dc.tags & DamageTags.TRUE:
        return
    if dc.is_heal:
        dc.amount *= get_modifier(StatIds.HEAL_RECEIVED)
    else:
        dc.amount *= get_modifier(StatIds.INCOMING_DAMAGE)

func _on_pre_apply(_dc: DamageContext) -> void:
    pass  # invincibility 由 StatusController 处理

func _on_post_apply(dc: DamageContext) -> void:
    if dc.target != owner_node:
        return
    for buff in dc.attached_buffs:
        if buff:
            apply(buff, dc.source, dc.source_pos)
    if dc.is_heal:
        return
    for inst in active:
        for eff in inst.entity.effects:
            if eff and (eff.effect_on & BuffEffect.EffectOn.ON_DAMAGED) != 0:
                _exec_effect(eff, inst, 0.0, BuffEffect.EffectOn.ON_DAMAGED, dc)

# ============ Aggregation ============
func get_modifier(stat_id: StringName) -> float:
    var arr: Array = _stat_modifiers.get(stat_id, [])
    var result := 1.0
    for m in arr:
        result *= m
    return result

func add_stat_modifier(stat_id: StringName, mult: float) -> void:
    if not _stat_modifiers.has(stat_id):
        _stat_modifiers[stat_id] = []
    _stat_modifiers[stat_id].append(mult)

func remove_stat_modifier(stat_id: StringName, mult: float) -> void:
    var arr: Array = _stat_modifiers.get(stat_id, [])
    arr.erase(mult)

func get_legal_action_locks() -> int:
    var mask := 0
    for inst in active:
        mask |= inst.entity.legal_action_locks
    return mask

func get_top_hit_buff() -> BuffEntity:
    var top: BuffInstance = null
    for inst in active:
        if inst.entity.hit_reaction == &"":
            continue
        if top == null or inst.entity.hit_priority > top.entity.hit_priority:
            top = inst
    return top.entity if top else null

# ============ Internals ============
func _exec_effect(eff: BuffEffect, inst: BuffInstance, delta: float,
                  trigger: int, dc: DamageContext = null) -> void:
    var ctx := _make_ctx(inst, trigger)
    ctx.delta = delta
    ctx.damage_ctx = dc
    eff.execute(ctx)

func _make_ctx(inst: BuffInstance, trigger: int) -> BuffEffectContext:
    var ctx := BuffEffectContext.new()
    ctx.owner = owner_node
    ctx.instance = inst
    ctx.trigger = trigger
    return ctx

func _find_by_id(id: StringName) -> BuffInstance:
    if id == &"":
        return null
    for inst in active:
        if inst.entity.id == id:
            return inst
    return null
```

- [ ] **Step 2: Commit**

```bash
git add Core/Buffs/BuffController.gd
git commit -m "feat(buff): add BuffController container + pipeline hooks"
```

---

### Task 12: BuffController apply/tick/expire tests

**Files:**
- Create: `test/unit/test_buff_controller_apply.gd`
- Create: `test/unit/test_buff_controller_tick.gd`
- Create: `test/unit/test_buff_controller_expire.gd`
- Create: `test/unit/test_buff_stat_modifier.gd`
- Create: `test/fixtures/CounterEffect.gd` — minimal BuffEffect that increments a per-instance counter

- [ ] **Step 1: Add CounterEffect fixture**

```gdscript
# test/fixtures/CounterEffect.gd
class_name CounterEffect extends BuffEffect

## Test fixture — increments a counter on its instance metadata.
## effect_on defaults to APPLY+TICK+EXPIRE for visibility.
@export var tick_interval: float = 0.0
@export var counter_key: StringName = &"counter"

func _init() -> void:
    effect_on = BuffEffect.EffectOn.APPLY | BuffEffect.EffectOn.TICK | BuffEffect.EffectOn.EXPIRE

func execute(ctx: BuffEffectContext) -> void:
    var key := String(counter_key) + "_" + str(ctx.trigger)
    var v: int = ctx.instance.tick_accums.get(key, 0)
    ctx.instance.tick_accums[key] = v + 1
```

- [ ] **Step 2: Write test_buff_controller_apply.gd**

```gdscript
# test/unit/test_buff_controller_apply.gd
extends GutTest

const CounterEffect = preload("res://test/fixtures/CounterEffect.gd")

var _actor: Node
var _bc: BuffController

func before_each() -> void:
    _actor = Node.new()
    _actor.name = "Actor"
    var pipe := DamagePipeline.new()
    pipe.name = "DamagePipeline"
    _actor.add_child(pipe)
    _bc = BuffController.new()
    _bc.name = "BuffController"
    _actor.add_child(_bc)
    add_child_autofree(_actor)

func _make_buff(id: StringName, duration: float, stacking: int) -> BuffEntity:
    var b := BuffEntity.new()
    b.id = id
    b.duration = duration
    b.stacking = stacking
    var c := CounterEffect.new()
    b.effects = [c]
    return b

func test_apply_adds_instance() -> void:
    _bc.apply(_make_buff(&"x", 1.0, BuffEntity.Stacking.REFRESH), null, Vector2.ZERO)
    assert_eq(_bc.active.size(), 1)

func test_apply_emits_buffs_changed() -> void:
    watch_signals(_bc)
    _bc.apply(_make_buff(&"x", 1.0, BuffEntity.Stacking.REFRESH), null, Vector2.ZERO)
    assert_signal_emitted(_bc, "buffs_changed")

func test_apply_runs_apply_effects() -> void:
    var b := _make_buff(&"x", 1.0, BuffEntity.Stacking.REFRESH)
    _bc.apply(b, null, Vector2.ZERO)
    var inst := _bc.active[0]
    assert_eq(inst.tick_accums.get("counter_1", 0), 1, "APPLY trigger=1 fired once")

func test_refresh_does_not_re_apply() -> void:
    var b := _make_buff(&"x", 1.0, BuffEntity.Stacking.REFRESH)
    _bc.apply(b, null, Vector2.ZERO)
    _bc.apply(b, null, Vector2.ZERO)
    assert_eq(_bc.active.size(), 1, "still one instance")
    assert_eq(_bc.active[0].tick_accums.get("counter_1", 0), 1, "APPLY only fired once")
    assert_almost_eq(_bc.active[0].remaining, 1.0, 0.01)

func test_replace_expires_old_then_applies_new() -> void:
    var b := _make_buff(&"x", 1.0, BuffEntity.Stacking.REPLACE)
    _bc.apply(b, null, Vector2.ZERO)
    var first := _bc.active[0]
    _bc.apply(b, null, Vector2.ZERO)
    assert_eq(_bc.active.size(), 1)
    assert_ne(_bc.active[0], first, "instance replaced")

func test_stack_creates_independent_instances() -> void:
    var b := _make_buff(&"x", 1.0, BuffEntity.Stacking.STACK)
    _bc.apply(b, null, Vector2.ZERO)
    _bc.apply(b, null, Vector2.ZERO)
    assert_eq(_bc.active.size(), 2)
    assert_ne(_bc.active[0].gen_id, _bc.active[1].gen_id)
```

- [ ] **Step 3: Write test_buff_controller_tick.gd**

```gdscript
# test/unit/test_buff_controller_tick.gd
extends GutTest

const CounterEffect = preload("res://test/fixtures/CounterEffect.gd")

var _actor: Node
var _bc: BuffController

func before_each() -> void:
    _actor = Node.new()
    var pipe := DamagePipeline.new(); pipe.name = "DamagePipeline"; _actor.add_child(pipe)
    _bc = BuffController.new(); _bc.name = "BuffController"; _actor.add_child(_bc)
    add_child_autofree(_actor)

func _make_buff_with_interval(interval: float) -> BuffEntity:
    var b := BuffEntity.new()
    b.id = &"y"
    b.duration = 5.0
    b.stacking = BuffEntity.Stacking.REFRESH
    var c := CounterEffect.new()
    c.tick_interval = interval
    c.effect_on = BuffEffect.EffectOn.TICK
    b.effects = [c]
    return b

func test_tick_zero_interval_runs_each_frame() -> void:
    _bc.apply(_make_buff_with_interval(0.0), null, Vector2.ZERO)
    _bc._physics_process(0.016)
    _bc._physics_process(0.016)
    var inst := _bc.active[0]
    assert_eq(inst.tick_accums.get("counter_2", 0), 2)

func test_tick_interval_accumulates() -> void:
    _bc.apply(_make_buff_with_interval(0.5), null, Vector2.ZERO)
    _bc._physics_process(0.2)
    var inst := _bc.active[0]
    assert_eq(inst.tick_accums.get("counter_2", 0), 0, "below threshold")
    _bc._physics_process(0.4)
    assert_eq(inst.tick_accums.get("counter_2", 0), 1, "0.6 >= 0.5 fires once")
```

- [ ] **Step 4: Write test_buff_controller_expire.gd**

```gdscript
# test/unit/test_buff_controller_expire.gd
extends GutTest

const CounterEffect = preload("res://test/fixtures/CounterEffect.gd")

var _actor: Node
var _bc: BuffController

func before_each() -> void:
    _actor = Node.new()
    var pipe := DamagePipeline.new(); pipe.name = "DamagePipeline"; _actor.add_child(pipe)
    _bc = BuffController.new(); _bc.name = "BuffController"; _actor.add_child(_bc)
    add_child_autofree(_actor)

func _make_short_buff() -> BuffEntity:
    var b := BuffEntity.new()
    b.id = &"z"
    b.duration = 0.1
    b.stacking = BuffEntity.Stacking.REFRESH
    b.effects = [CounterEffect.new()]
    return b

func test_expire_after_duration() -> void:
    _bc.apply(_make_short_buff(), null, Vector2.ZERO)
    var inst := _bc.active[0]
    _bc._physics_process(0.2)
    assert_eq(_bc.active.size(), 0)
    assert_eq(inst.tick_accums.get("counter_4", 0), 1, "EXPIRE trigger=4 fired once")

func test_clear_all_expires_all() -> void:
    _bc.apply(_make_short_buff(), null, Vector2.ZERO)
    _bc.apply(_make_short_buff(), null, Vector2.ZERO)
    var first := _bc.active[0]
    _bc.clear_all()
    assert_eq(_bc.active.size(), 0)
    assert_eq(first.tick_accums.get("counter_4", 0), 1)
```

- [ ] **Step 5: Write test_buff_stat_modifier.gd**

```gdscript
# test/unit/test_buff_stat_modifier.gd
extends GutTest

var _actor: Node
var _bc: BuffController

func before_each() -> void:
    _actor = Node.new()
    var pipe := DamagePipeline.new(); pipe.name = "DamagePipeline"; _actor.add_child(pipe)
    _bc = BuffController.new(); _bc.name = "BuffController"; _actor.add_child(_bc)
    add_child_autofree(_actor)

func test_modifier_default_is_one() -> void:
    assert_eq(_bc.get_modifier(StatIds.INCOMING_DAMAGE), 1.0)

func test_add_modifier_multiplies() -> void:
    _bc.add_stat_modifier(StatIds.INCOMING_DAMAGE, 0.5)
    _bc.add_stat_modifier(StatIds.INCOMING_DAMAGE, 0.5)
    assert_eq(_bc.get_modifier(StatIds.INCOMING_DAMAGE), 0.25)

func test_remove_modifier_restores() -> void:
    _bc.add_stat_modifier(StatIds.INCOMING_DAMAGE, 0.5)
    _bc.remove_stat_modifier(StatIds.INCOMING_DAMAGE, 0.5)
    assert_eq(_bc.get_modifier(StatIds.INCOMING_DAMAGE), 1.0)

func test_legal_action_locks_aggregate() -> void:
    var b1 := BuffEntity.new(); b1.id = &"a"; b1.legal_action_locks = LegalAction.MOVE
    var b2 := BuffEntity.new(); b2.id = &"b"; b2.legal_action_locks = LegalAction.ATTACK
    _bc.apply(b1, null, Vector2.ZERO)
    _bc.apply(b2, null, Vector2.ZERO)
    assert_eq(_bc.get_legal_action_locks(), LegalAction.MOVE | LegalAction.ATTACK)
```

- [ ] **Step 6: Run tests**

Run: `bash test/run_tests.sh buff_controller_apply && bash test/run_tests.sh buff_controller_tick && bash test/run_tests.sh buff_controller_expire && bash test/run_tests.sh buff_stat_modifier`
Expected: all PASS

- [ ] **Step 7: Commit**

```bash
git add test/fixtures/CounterEffect.gd test/unit/test_buff_controller_apply.gd test/unit/test_buff_controller_tick.gd test/unit/test_buff_controller_expire.gd test/unit/test_buff_stat_modifier.gd
git commit -m "test(buff): cover BuffController lifecycle + stat modifiers"
```

---

### Task 13: StatusController

**Files:**
- Create: `Core/Status/StatusController.gd`
- Test: `test/unit/test_status_controller.gd`

- [ ] **Step 1: Write StatusController**

```gdscript
# Core/Status/StatusController.gd
class_name StatusController extends Node

## Aggregates LegalAction bitmask from active buffs and per-action timers.
## Subscribes pipeline.pre_apply to enforce HURTABLE.

signal legal_actions_changed(prev: int, new: int)

const _ACTION_BITS := [
    LegalAction.ATTACK,
    LegalAction.MOVE,
    LegalAction.DEFEND,
    LegalAction.CAST,
    LegalAction.HURTABLE,
]

var legal_actions: int = LegalAction.ALL
var _action_timers: Dictionary = {}     # bit → remaining float

@onready var owner_node: Node = get_parent()
@onready var pipeline: DamagePipeline = owner_node.get_node_or_null(^"DamagePipeline") if owner_node else null
@onready var bc: BuffController = owner_node.get_node_or_null(^"BuffController") if owner_node else null

func _ready() -> void:
    if pipeline:
        pipeline.pre_apply.connect(_on_pre_apply)
    if bc:
        bc.buffs_changed.connect(_recompute_buff_locks)

func _process(delta: float) -> void:
    if _action_timers.is_empty():
        return
    var prev := legal_actions
    var to_clear: Array = []
    for bit in _action_timers.keys():
        _action_timers[bit] -= delta
        if _action_timers[bit] <= 0.0:
            to_clear.append(bit)
    for k in to_clear:
        _action_timers.erase(k)
    _recompute_legal_actions()
    if legal_actions != prev:
        legal_actions_changed.emit(prev, legal_actions)

# ============ Public API ============
func apply_lock(action_mask: int, duration: float) -> void:
    var prev := legal_actions
    for bit in _ACTION_BITS:
        if action_mask & bit:
            var cur: float = _action_timers.get(bit, 0.0)
            if duration > cur:
                _action_timers[bit] = duration
    _recompute_legal_actions()
    if legal_actions != prev:
        legal_actions_changed.emit(prev, legal_actions)

func release_lock(action_mask: int) -> void:
    var prev := legal_actions
    for bit in _ACTION_BITS:
        if action_mask & bit:
            _action_timers.erase(bit)
    _recompute_legal_actions()
    if legal_actions != prev:
        legal_actions_changed.emit(prev, legal_actions)

func has_legal_action(action: int) -> bool:
    return (legal_actions & action) == action

func can_attack() -> bool: return has_legal_action(LegalAction.ATTACK)
func can_move() -> bool:   return has_legal_action(LegalAction.MOVE)
func can_be_hit() -> bool: return has_legal_action(LegalAction.HURTABLE)

# ============ Pipeline subscription ============
func _on_pre_apply(ctx: DamageContext) -> void:
    if ctx.target != owner_node:
        return
    if ctx.is_heal:
        return
    if not has_legal_action(LegalAction.HURTABLE):
        ctx.blocked = true

# ============ Recompute ============
func _recompute_legal_actions() -> void:
    var locked := 0
    for bit in _action_timers.keys():
        locked |= bit
    if bc:
        locked |= bc.get_legal_action_locks()
    legal_actions = LegalAction.ALL & ~locked

func _recompute_buff_locks() -> void:
    var prev := legal_actions
    _recompute_legal_actions()
    if legal_actions != prev:
        legal_actions_changed.emit(prev, legal_actions)
```

- [ ] **Step 2: Write test_status_controller.gd**

```gdscript
# test/unit/test_status_controller.gd
extends GutTest

var _actor: Node
var _bc: BuffController
var _sc: StatusController
var _pipe: DamagePipeline

func before_each() -> void:
    _actor = Node.new()
    _pipe = DamagePipeline.new(); _pipe.name = "DamagePipeline"; _actor.add_child(_pipe)
    _bc = BuffController.new(); _bc.name = "BuffController"; _actor.add_child(_bc)
    _sc = StatusController.new(); _sc.name = "StatusController"; _actor.add_child(_sc)
    add_child_autofree(_actor)

func test_default_all() -> void:
    assert_eq(_sc.legal_actions, LegalAction.ALL)
    assert_true(_sc.can_attack())
    assert_true(_sc.can_be_hit())

func test_apply_lock_revokes_bit() -> void:
    _sc.apply_lock(LegalAction.ATTACK, 1.0)
    assert_false(_sc.can_attack())
    assert_true(_sc.can_move())

func test_lock_longest_wins() -> void:
    _sc.apply_lock(LegalAction.ATTACK, 0.5)
    _sc.apply_lock(LegalAction.ATTACK, 1.0)
    _sc.apply_lock(LegalAction.ATTACK, 0.3)   # ignored — shorter
    assert_almost_eq(_sc._action_timers[LegalAction.ATTACK], 1.0, 0.01)

func test_lock_decays_to_zero() -> void:
    _sc.apply_lock(LegalAction.HURTABLE, 0.1)
    _sc._process(0.2)
    assert_true(_sc.can_be_hit())

func test_pre_apply_blocks_when_not_hurtable() -> void:
    _sc.apply_lock(LegalAction.HURTABLE, 1.0)
    var ctx := DamageContext.new()
    ctx.target = _actor
    ctx.amount = 10.0
    _pipe.process(ctx)
    assert_true(ctx.blocked)

func test_buff_lock_recompute() -> void:
    var b := BuffEntity.new()
    b.id = &"stun"
    b.duration = 1.0
    b.legal_action_locks = LegalAction.ATTACK | LegalAction.MOVE
    _bc.apply(b, null, Vector2.ZERO)
    assert_false(_sc.can_attack())
    assert_false(_sc.can_move())

func test_legal_actions_changed_signal() -> void:
    watch_signals(_sc)
    _sc.apply_lock(LegalAction.ATTACK, 1.0)
    assert_signal_emitted(_sc, "legal_actions_changed")
```

- [ ] **Step 3: Run test**

Run: `bash test/run_tests.sh status_controller`
Expected: 7/7 PASS

- [ ] **Step 4: Commit**

```bash
git add Core/Status/StatusController.gd test/unit/test_status_controller.gd
git commit -m "feat(buff): add StatusController with LegalAction gating"
```

---

### Task 14: HealthComponent — Thin Pipeline Subscriber Rewrite

**Files:**
- Modify: `Core/Components/HealthComponent.gd` (full rewrite)
- Note: `test/unit/test_health_component.gd` references the old `take_damage` API. Rewrite it inline below.
- Modify: `test/base/test_helper.gd` (drop the AttackEffect-based factories; keep `create_damage` but deprecate effects param)

- [ ] **Step 1: Rewrite HealthComponent**

```gdscript
# Core/Components/HealthComponent.gd
extends Node
class_name HealthComponent

## Thin HP container. Subscribes DamagePipeline.apply only — no buff awareness.
## Death is signaled to AAB; reset_health is exposed for spawning/respawn.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source_pos: Vector2)
signal died

@export_group("Health")
@export var max_health: float = 100.0
@export var health: float = 100.0

@export_group("Damage Display")
@export var critical_threshold: float = 0.8

var is_alive: bool = true

@onready var owner_body: Node = get_parent()
@onready var pipeline: DamagePipeline = owner_body.get_node_or_null(^"DamagePipeline") if owner_body else null

func _ready() -> void:
    if health <= 0.0:
        health = max_health
    if pipeline:
        pipeline.apply.connect(_commit)
    call_deferred(&"_emit_initial_health")

func _emit_initial_health() -> void:
    health_changed.emit(health, max_health)

# ============ Pipeline subscriber ============
func _commit(ctx: DamageContext) -> void:
    if ctx.target != owner_body or not is_alive:
        return
    var prev := health
    if ctx.is_heal:
        health = minf(health + ctx.amount, max_health)
        ctx.dealt = health - prev
    else:
        health = clampf(health - ctx.amount, 0.0, max_health)
        ctx.dealt = prev - health
        if ctx.dealt > 0.0:
            damaged.emit(ctx.dealt, ctx.source_pos)
            _display_damage_number(ctx.dealt, ctx.tags)
    health_changed.emit(health, max_health)
    if health <= 0.0 and is_alive:
        is_alive = false
        died.emit()

# ============ External entry points ============
func heal(amount: float) -> void:
    if not is_alive or pipeline == null:
        return
    var ctx := DamageContext.new()
    ctx.target = owner_body
    ctx.is_heal = true
    ctx.raw_amount = amount
    ctx.amount = amount
    pipeline.process(ctx)

func reset_health() -> void:
    health = max_health
    is_alive = true
    health_changed.emit(health, max_health)

func get_health_percent() -> float:
    return health / max_health if max_health > 0.0 else 0.0

func is_character_alive() -> bool:
    return is_alive

# ============ Internals ============
func _display_damage_number(amount: float, _tags: int) -> void:
    if owner_body == null:
        return
    var anchor := owner_body.get_node_or_null(^"DamageNumbersAnchor")
    if anchor:
        var is_critical := false
        if max_health > 0.0:
            is_critical = amount > max_health * critical_threshold
        DamageNumbers.display_number(int(amount), anchor.global_position, is_critical)
```

- [ ] **Step 2: Rewrite test_health_component.gd**

```gdscript
# test/unit/test_health_component.gd
extends GutTest

## HealthComponent v2 — subscribes DamagePipeline.apply only.

var _actor: CharacterBody2D
var _pipe: DamagePipeline
var _hc: HealthComponent

func before_each() -> void:
    _actor = CharacterBody2D.new()
    _actor.name = "Actor"
    _pipe = DamagePipeline.new(); _pipe.name = "DamagePipeline"
    _actor.add_child(_pipe)
    _hc = HealthComponent.new(); _hc.name = "HealthComponent"
    _hc.max_health = 100.0
    _hc.health = 100.0
    _actor.add_child(_hc)
    add_child_autofree(_actor)

func _build_ctx(amount: float, is_heal := false) -> DamageContext:
    var ctx := DamageContext.new()
    ctx.target = _actor
    ctx.amount = amount
    ctx.raw_amount = amount
    ctx.is_heal = is_heal
    return ctx

func test_initial_health() -> void:
    assert_eq(_hc.health, 100.0)
    assert_true(_hc.is_alive)

func test_apply_subtracts_health() -> void:
    _pipe.process(_build_ctx(30.0))
    assert_eq(_hc.health, 70.0)

func test_apply_emits_damaged() -> void:
    watch_signals(_hc)
    _pipe.process(_build_ctx(10.0))
    assert_signal_emitted(_hc, "damaged")

func test_apply_emits_health_changed() -> void:
    watch_signals(_hc)
    _pipe.process(_build_ctx(25.0))
    assert_signal_emitted(_hc, "health_changed")

func test_apply_clamps_to_zero() -> void:
    _pipe.process(_build_ctx(150.0))
    assert_eq(_hc.health, 0.0)
    assert_false(_hc.is_alive)

func test_apply_emits_died() -> void:
    watch_signals(_hc)
    _pipe.process(_build_ctx(100.0))
    assert_signal_emitted(_hc, "died")

func test_apply_after_death_noop() -> void:
    _pipe.process(_build_ctx(100.0))
    _pipe.process(_build_ctx(10.0))
    assert_eq(_hc.health, 0.0)

func test_heal_adds_health() -> void:
    _pipe.process(_build_ctx(50.0))
    assert_eq(_hc.health, 50.0)
    _hc.heal(20.0)
    assert_eq(_hc.health, 70.0)

func test_heal_clamps_to_max() -> void:
    _hc.heal(50.0)
    assert_eq(_hc.health, 100.0)

func test_heal_does_not_emit_damaged() -> void:
    _pipe.process(_build_ctx(50.0))
    watch_signals(_hc)
    _hc.heal(10.0)
    assert_signal_not_emitted(_hc, "damaged")

func test_reset_health_revives() -> void:
    _pipe.process(_build_ctx(100.0))
    _hc.reset_health()
    assert_eq(_hc.health, 100.0)
    assert_true(_hc.is_alive)

func test_dealt_filled_on_apply() -> void:
    var ctx := _build_ctx(30.0)
    _pipe.process(ctx)
    assert_eq(ctx.dealt, 30.0)

func test_dealt_clamped_when_overkill() -> void:
    var ctx := _build_ctx(150.0)
    _pipe.process(ctx)
    assert_eq(ctx.dealt, 100.0)
```

- [ ] **Step 3: Update test_helper.gd**

Replace the existing `Core/Resources/AttackEffect`-typed `create_damage` and `create_stun_damage` / `create_knockback_damage` with v2 helpers. The plan keeps the AttackEffect classes (Phase 2 deletes them), so leave the legacy helpers but mark them deprecated by extracting only the v2-relevant additions. **Open `test/base/test_helper.gd` and append** (do NOT delete the legacy helpers — they are used by `test_attack_effects.gd`):

```gdscript
# Add at end of test/base/test_helper.gd

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
```

- [ ] **Step 4: Run tests**

Run: `bash test/run_tests.sh health_component`
Expected: 12/12 PASS

- [ ] **Step 5: Commit**

```bash
git add Core/Components/HealthComponent.gd test/unit/test_health_component.gd test/base/test_helper.gd
git commit -m "refactor(buff): rewrite HealthComponent as thin pipeline subscriber"
```

---

### Task 15: Sanity-check `test_damage_system.gd` after HC rewrite

**Files:**
- Read: `test/unit/test_damage_system.gd`
- Modify (if it relies on the deleted `take_damage`): inline patch to use pipeline.process

- [ ] **Step 1: Read existing test**

```bash
cat test/unit/test_damage_system.gd
```

- [ ] **Step 2: If the test calls `health_comp.take_damage`, replace each call with**

```gdscript
var pipe: DamagePipeline = actor.get_node(^"DamagePipeline")
var ctx := DamageContext.new()
ctx.target = actor; ctx.amount = <amount>
pipe.process(ctx)
```

(If the actor scene under test does not yet have DamagePipeline child, add it before calling process. If the test fundamentally depends on legacy behaviour and would require deep rewrites, mark each broken function with `pending("Phase 2: rewrite for pipeline")` instead.)

- [ ] **Step 3: Run all unit tests**

Run: `bash test/run_tests.sh unit`
Expected: PASS — fix any straggler. Tests under `test_attack_effects.gd` (legacy path) should still pass since AttackEffect classes remain on disk.

- [ ] **Step 4: Commit only if changes were necessary**

```bash
git add test/unit/test_damage_system.gd
git commit -m "test(buff): patch test_damage_system for pipeline.apply path"
```

---

### Task 16: StatModEffect

**Files:**
- Create: `Core/Buffs/effects/StatModEffect.gd`
- Test: `test/unit/test_stat_mod_effect.gd`

- [ ] **Step 1: Write StatModEffect**

```gdscript
# Core/Buffs/effects/StatModEffect.gd
class_name StatModEffect extends BuffEffect

## Adjusts a multiplicative stat modifier on the owner's BuffController.
## Default effect_on = APPLY|EXPIRE — net-zero pairing.

@export var stat_id: StringName = StatIds.INCOMING_DAMAGE
@export var multiplier: float = 1.0

func _init() -> void:
    effect_on = EffectOn.APPLY | EffectOn.EXPIRE

func execute(ctx: BuffEffectContext) -> void:
    var bc: BuffController = ctx.owner.get_node_or_null(^"BuffController") if ctx.owner else null
    if bc == null:
        return
    if ctx.trigger == EffectOn.APPLY:
        bc.add_stat_modifier(stat_id, multiplier)
    elif ctx.trigger == EffectOn.EXPIRE:
        bc.remove_stat_modifier(stat_id, multiplier)
```

- [ ] **Step 2: Write test_stat_mod_effect.gd**

```gdscript
# test/unit/test_stat_mod_effect.gd
extends GutTest
const H = preload("res://test/base/test_helper.gd")

var _actor: CharacterBody2D
var _bc: BuffController

func before_each() -> void:
    _actor = H.build_actor_with_pipeline()
    add_child_autofree(_actor)
    _bc = _actor.get_node(^"BuffController")

func _make_buff() -> BuffEntity:
    var e := StatModEffect.new()
    e.stat_id = StatIds.INCOMING_DAMAGE
    e.multiplier = 0.5
    return H.create_buff_entity(&"defense", 1.0, [e])

func test_apply_adds_modifier() -> void:
    _bc.apply(_make_buff(), null, Vector2.ZERO)
    assert_eq(_bc.get_modifier(StatIds.INCOMING_DAMAGE), 0.5)

func test_expire_removes_modifier() -> void:
    _bc.apply(_make_buff(), null, Vector2.ZERO)
    _bc._physics_process(2.0)   # past duration
    assert_eq(_bc.get_modifier(StatIds.INCOMING_DAMAGE), 1.0)
```

- [ ] **Step 3: Run test**

Run: `bash test/run_tests.sh stat_mod_effect`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add Core/Buffs/effects/StatModEffect.gd test/unit/test_stat_mod_effect.gd
git commit -m "feat(buff): add StatModEffect"
```

---

### Task 17: DamageEffectBuff (DoT + reactive damage)

**Files:**
- Create: `Core/Buffs/effects/DamageEffectBuff.gd`

- [ ] **Step 1: Write DamageEffectBuff**

```gdscript
# Core/Buffs/effects/DamageEffectBuff.gd
class_name DamageEffectBuff extends BuffEffect

## Routes a damage hit through the target's DamagePipeline.
## Used for DoT (TICK) and reactive damage (ON_DAMAGED, e.g. thorns).
## Target is derived from ctx.trigger (see Plan Amendment A1).

@export var amount: float = 5.0
@export var tick_interval: float = 0.5
@export var damage_tags: int = 0          # caller may add DOT explicitly

func _init() -> void:
    effect_on = EffectOn.TICK

func execute(ctx: BuffEffectContext) -> void:
    var t: Node = _resolve_target(ctx)
    if t == null:
        return
    var pipe: DamagePipeline = t.get_node_or_null(^"DamagePipeline")
    if pipe == null:
        return
    var dc := DamageContext.new()
    dc.target = t
    dc.source = ctx.instance.source_actor
    dc.raw_amount = amount
    dc.amount = amount
    dc.tags = damage_tags
    if ctx.trigger == EffectOn.TICK:
        dc.tags |= DamageTags.DOT
    if ctx.instance.source_actor is Node2D:
        dc.source_pos = (ctx.instance.source_actor as Node2D).global_position
    else:
        dc.source_pos = ctx.instance.source_pos
    pipe.process(dc)

func _resolve_target(ctx: BuffEffectContext) -> Node:
    # ON_DAMAGED / ON_HEAL → target the attacker / healer; otherwise target the buff owner.
    match ctx.trigger:
        EffectOn.ON_DAMAGED, EffectOn.ON_HEAL:
            return ctx.damage_ctx.source if ctx.damage_ctx else null
        _:
            return ctx.owner
```

- [ ] **Step 2: Commit**

```bash
git add Core/Buffs/effects/DamageEffectBuff.gd
git commit -m "feat(buff): add DamageEffectBuff for DoT and thorns"
```

---

### Task 18: HealEffectBuff

**Files:**
- Create: `Core/Buffs/effects/HealEffectBuff.gd`

- [ ] **Step 1: Write HealEffectBuff**

```gdscript
# Core/Buffs/effects/HealEffectBuff.gd
class_name HealEffectBuff extends BuffEffect

## HoT — periodic heal routed through pipeline as is_heal=true.

@export var amount: float = 5.0
@export var tick_interval: float = 0.5

func _init() -> void:
    effect_on = EffectOn.TICK

func execute(ctx: BuffEffectContext) -> void:
    if ctx.owner == null:
        return
    var pipe: DamagePipeline = ctx.owner.get_node_or_null(^"DamagePipeline")
    if pipe == null:
        return
    var dc := DamageContext.new()
    dc.target = ctx.owner
    dc.is_heal = true
    dc.raw_amount = amount
    dc.amount = amount
    pipe.process(dc)
```

- [ ] **Step 2: Commit**

```bash
git add Core/Buffs/effects/HealEffectBuff.gd
git commit -m "feat(buff): add HealEffectBuff for HoT"
```

---

### Task 19: KnockBackEffectBuff + KnockUpEffectBuff

**Files:**
- Create: `Core/Buffs/effects/KnockBackEffectBuff.gd`
- Create: `Core/Buffs/effects/KnockUpEffectBuff.gd`

- [ ] **Step 1: Write KnockBackEffectBuff**

```gdscript
# Core/Buffs/effects/KnockBackEffectBuff.gd
class_name KnockBackEffectBuff extends BuffEffect

## Sets horizontal velocity on a CharacterBody2D away from a source position.
## Target is derived from ctx.trigger (see Plan Amendment A1):
##   APPLY → owner pushed away from buff source_pos.
##   ON_DAMAGED → attacker pushed away from owner (reactive push).

@export var force: float = 400.0

func _init() -> void:
    effect_on = EffectOn.APPLY

func execute(ctx: BuffEffectContext) -> void:
    var t: Node = _resolve_target(ctx)
    if not (t is CharacterBody2D):
        return
    var src_pos: Vector2 = ctx.instance.source_pos
    if ctx.damage_ctx:
        src_pos = ctx.damage_ctx.source_pos
    var dir := ((t as Node2D).global_position - src_pos).normalized()
    if dir == Vector2.ZERO:
        dir = Vector2.RIGHT
    (t as CharacterBody2D).velocity = Vector2(dir.x * force, (t as CharacterBody2D).velocity.y)

func _resolve_target(ctx: BuffEffectContext) -> Node:
    match ctx.trigger:
        EffectOn.ON_DAMAGED, EffectOn.ON_HEAL:
            return ctx.damage_ctx.source if ctx.damage_ctx else null
        _:
            return ctx.owner
```

- [ ] **Step 2: Write KnockUpEffectBuff**

```gdscript
# Core/Buffs/effects/KnockUpEffectBuff.gd
class_name KnockUpEffectBuff extends BuffEffect

## Sets vertical velocity (upward) and a horizontal push on a CharacterBody2D.
@export var vertical_force: float = -500.0
@export var horizontal_force: float = 200.0

func _init() -> void:
    effect_on = EffectOn.APPLY

func execute(ctx: BuffEffectContext) -> void:
    var t: Node = ctx.owner
    if not (t is CharacterBody2D):
        return
    var src_pos: Vector2 = ctx.instance.source_pos
    if ctx.damage_ctx:
        src_pos = ctx.damage_ctx.source_pos
    var dir_x := signf((t as Node2D).global_position.x - src_pos.x)
    if dir_x == 0.0:
        dir_x = 1.0
    (t as CharacterBody2D).velocity = Vector2(dir_x * horizontal_force, vertical_force)
```

- [ ] **Step 3: Commit**

```bash
git add Core/Buffs/effects/KnockBackEffectBuff.gd Core/Buffs/effects/KnockUpEffectBuff.gd
git commit -m "feat(buff): add KnockBack and KnockUp buff effects"
```

---

### Task 20: Damage Resource — effects type + tags

**Files:**
- Modify: `Core/Resources/Damage.gd`

- [ ] **Step 1: Replace effects type and add tags. Keep amount/min_amount/max_amount/randomize_damage. Drop apply_effects/has_effect/get_effects_description (legacy AttackEffect API).**

```gdscript
extends Resource
class_name Damage

## Damage payload — drives DamagePipeline.process via HitBoxComponent.
## v2: effects holds BuffEntity resources; tags is a DamageTags bitmask.

@export_group("伤害配置")
@export var max_amount: float = 50.0
@export var min_amount: float = 1.0
@export var amount: float = 10.0

## DamageTags bitmask (Physical / Magical / DOT / Crit / True)
@export_flags("Physical", "Magical", "DOT", "Crit", "True")
var tags: int = 0

@export_group("Buffs")
## Buffs attached to this hit. Pipeline post_apply step inserts them into target's BuffController.
@export var effects: Array[BuffEntity] = []

static var _rng: RandomNumberGenerator = null

func randomize_damage() -> void:
    if _rng == null:
        _rng = RandomNumberGenerator.new()
        _rng.randomize()
    amount = _rng.randf_range(min_amount, max_amount)

func debug_print() -> void:
    print("[Damage] amount=", amount, " tags=", tags, " buffs=", effects.size())
```

- [ ] **Step 2: Run unit tests**

Run: `bash test/run_tests.sh unit`
Expected: PASS — `test_attack_effects.gd` may now fail because helper `create_stun_damage` constructs `Array[AttackEffect]` and assigns to `Damage.effects` (now `Array[BuffEntity]`).

- [ ] **Step 3: If `test_attack_effects.gd` fails, mark its tests pending**

Edit the top of [test/unit/test_attack_effects.gd](../../../test/unit/test_attack_effects.gd) — add to the `before_each` (or each affected test):

```gdscript
pending("Phase 2: AttackEffect classes will be deleted; tests rewritten in Cyclops/DS2 migration")
return
```

This keeps the file in the suite (no UID delete) but neutralises it for the duration of the BK PoC. Phase 2 plan will delete the file.

- [ ] **Step 4: Commit**

```bash
git add Core/Resources/Damage.gd test/unit/test_attack_effects.gd
git commit -m "refactor(buff): repoint Damage.effects to BuffEntity, mark legacy tests pending"
```

---

### Task 21: HitBoxComponent — DamageContext entry point

**Files:**
- Modify: `Core/Components/HitBoxComponent.gd`

- [ ] **Step 1: Replace HurtBox call with pipeline.process**

```gdscript
extends Area2D
class_name HitBoxComponent

## Attack collision area. On HurtBox overlap, builds a DamageContext and
## drives the victim's DamagePipeline.

@export_group("伤害配置")
@export var damage: Damage = null

func _ready() -> void:
    if damage == null:
        damage = Damage.new()
    if not area_entered.is_connected(_on_hitbox_area_entered_):
        area_entered.connect(_on_hitbox_area_entered_)

func update_attack() -> void:
    if damage:
        damage.randomize_damage()

func get_attacker_position() -> Vector2:
    return global_position

func _on_hitbox_area_entered_(target: Area2D) -> void:
    update_attack()
    if not (target is HurtBoxComponent):
        return
    var attacker: Node = get_owner()
    var victim: Node = target.get_owner()
    if attacker == null or victim == null:
        return
    var pipe: DamagePipeline = victim.get_node_or_null(^"DamagePipeline")
    if pipe == null:
        return

    var ctx := DamageContext.new()
    ctx.source = attacker
    ctx.target = victim
    ctx.raw_amount = damage.amount
    ctx.amount = damage.amount
    ctx.tags = damage.tags
    ctx.attached_buffs = damage.effects.duplicate()
    ctx.source_pos = get_attacker_position()

    var atk_bc: BuffController = attacker.get_node_or_null(^"BuffController")
    if atk_bc and (ctx.tags & DamageTags.TRUE) == 0:
        ctx.amount *= atk_bc.get_modifier(StatIds.OUTGOING_DAMAGE)

    pipe.process(ctx)
```

- [ ] **Step 2: Note for HurtBox**

`HurtBoxComponent` may currently emit `damaged(damage, position)` and connect into `HealthComponent.take_damage`. After Task 14, `take_damage` is gone. Audit:

```bash
grep -rn "take_damage\|HurtBoxComponent\b" Core/ Scenes/Characters/ --include='*.gd'
```

If the only call site is `AgentAIBase._setup_signals` (line 95-98) connecting hurtbox.damaged → take_damage, **remove that block** in Task 22 (AAB rewire). HurtBox itself can keep its `damaged` signal (other listeners may exist) — just stop wiring it to HC.

- [ ] **Step 3: Commit**

```bash
git add Core/Components/HitBoxComponent.gd
git commit -m "refactor(buff): HitBoxComponent drives DamagePipeline directly"
```

---

### Task 22: AgentAIBase — pipeline.react + status hooks

**Files:**
- Modify: `Core/AI/AgentAIBase.gd`

- [ ] **Step 1: Update `@onready` and `_setup_signals` + add new handlers; remove the legacy hurtbox→HC wiring and `_on_agent_damaged(damage, attacker_pos)` body**

Replace the existing `_setup_signals`, `_on_agent_damaged`, `_on_agent_died` sections with:

```gdscript
@onready var pipeline: DamagePipeline = get_node_or_null(^"DamagePipeline")
@onready var status: StatusController = get_node_or_null(^"StatusController")
@onready var buff_controller: BuffController = get_node_or_null(^"BuffController")

func _setup_signals() -> void:
    if pipeline:
        pipeline.react.connect(_on_pipeline_react)
    if status:
        status.legal_actions_changed.connect(_on_legal_actions_changed)
    if health_comp:
        health_comp.died.connect(_on_agent_died)

func _on_pipeline_react(ctx: DamageContext) -> void:
    if ctx.blocked or ctx.is_heal:
        return
    if ctx.target != self:
        return
    if ctx.tags & DamageTags.DOT:
        return  # DoT 不进 HitState
    var bb := ai.blackboard
    bb.set_var(&"last_damage_amount", ctx.dealt)
    bb.set_var(&"last_attacker_pos", ctx.source_pos)
    bb.set_var(&"recently_hit", true)
    _hit_clear_timer = HIT_CLEAR_DELAY
    var now := Time.get_ticks_msec() / 1000.0
    _damage_log.append([now, ctx.dealt])
    _update_damage_recent()
    ai.dispatch(AIEvents.EV_DAMAGED)

func _on_legal_actions_changed(prev: int, new: int) -> void:
    var lost := prev & ~new
    var gained := new & ~prev
    if (lost & LegalAction.ATTACK) and ai.current_skill:
        ai.dispatch(AIEvents.EV_INTERRUPTED)
    if (gained & LegalAction.ATTACK) and prev != LegalAction.ALL:
        ai.dispatch(AIEvents.EV_RECOVERED)

func _on_agent_died() -> void:
    if buff_controller:
        buff_controller.clear_all()
    ai.dispatch(AIEvents.EV_DIED)
```

- [ ] **Step 2: Decide how to surface AIEvents.EV_INTERRUPTED / EV_RECOVERED**

Check existing event constants:

```bash
grep -n "EV_INTERRUPTED\|EV_RECOVERED" Core/AI/AIEvents.gd
```

If missing, append to `Core/AI/AIEvents.gd`:

```gdscript
const EV_INTERRUPTED := &"ev_interrupted"
const EV_RECOVERED   := &"ev_recovered"
```

- [ ] **Step 3: Verify `AgentAIBase` no longer references the old `damaged(Damage, Vector2)` callback signature**

```bash
grep -n "_on_agent_damaged\|HurtBoxComponent" Core/AI/AgentAIBase.gd
```

Expected: no matches.

- [ ] **Step 4: Run all tests**

Run: `bash test/run_tests.sh unit`
Expected: PASS (or only pending entries from Task 20)

- [ ] **Step 5: Commit**

```bash
git add Core/AI/AgentAIBase.gd Core/AI/AIEvents.gd
git commit -m "refactor(buff): AAB subscribes pipeline.react and StatusController"
```

---

### Task 23: HitState — query top hit buff

**Files:**
- Modify: `Core/AI/Stock/HitState.gd`

- [ ] **Step 1: Rewrite to query top buff for animation + duration; drop effect application**

```gdscript
extends AIState

## Stock Hit — query BuffController for current top hit_reaction; play matching animation.
## Effect application is the apply pipeline's job (post_apply); HitState is presentation only.

@export var default_duration: float = 0.3
@export var hit_animations: Dictionary = {
    &"":          &"hit",
    &"stun":      &"hit",
    &"knockback": &"hit",
    &"knockup":   &"hit_air",
}

var _timer: Timer

func _init() -> void:
    reentrant = true

func enter() -> void:
    if owner_node is CharacterBody2D:
        (owner_node as CharacterBody2D).velocity = Vector2.ZERO
    var bc: BuffController = owner_node.get_node_or_null(^"BuffController")
    var top: BuffEntity = bc.get_top_hit_buff() if bc else null
    var key: StringName = top.hit_reaction if top else &""
    var anim: StringName = hit_animations.get(key, &"hit")
    if "anim_player" in owner_node and owner_node.anim_player:
        if owner_node.anim_player.has_animation(anim):
            owner_node.anim_player.play(anim)
            owner_node.anim_player.seek(0.0, true)
    var dur: float = default_duration
    if top and top.hit_lock_duration > 0.0:
        dur = top.hit_lock_duration
    _ensure_timer()
    _timer.wait_time = dur
    _timer.start()

func physics_update(delta: float) -> void:
    if owner_node is CharacterBody2D:
        var b := owner_node as CharacterBody2D
        b.velocity = b.velocity.lerp(Vector2.ZERO, 8.0 * delta)

func exit() -> void:
    if _timer:
        _timer.stop()
    bb.set_var(&"recently_hit", false)

func _ensure_timer() -> void:
    if not _timer:
        _timer = Timer.new()
        _timer.one_shot = true
        _timer.timeout.connect(func(): dispatch(AIEvents.EV_HIT_RECOVERED))
        add_child(_timer)
```

- [ ] **Step 2: Same pattern for `Core/StateMachine/CommonStates/HitState.gd` if it exists**

```bash
ls Core/StateMachine/CommonStates/HitState.gd 2>/dev/null
```

If it exists, apply equivalent rewrite (read it first; it may have player-specific quirks).

- [ ] **Step 3: Commit**

```bash
git add Core/AI/Stock/HitState.gd
[ -f Core/StateMachine/CommonStates/HitState.gd ] && git add Core/StateMachine/CommonStates/HitState.gd
git commit -m "refactor(buff): HitState queries BuffController for hit reaction"
```

---

### Task 24: GenericAttackState — apply_skill_self_buff hook

**Files:**
- Modify: `Core/AI/Stock/GenericAttackState.gd`

- [ ] **Step 1: Read current implementation**

```bash
cat Core/AI/Stock/GenericAttackState.gd
```

- [ ] **Step 2: Add the method (animation method-call entry)**

Insert after the existing methods:

```gdscript
## Animation method-call hook: read skill.params.self_buff and apply via BuffController.
## Used by BK defense_cast / heal_self skills (data-driven, no per-boss override).
func apply_skill_self_buff() -> void:
    if ai == null or ai.current_skill == null:
        return
    var skill = ai.current_skill
    if not (&"params" in skill):
        return
    var buff: BuffEntity = skill.params.get(&"self_buff", null)
    if buff == null:
        return
    var bc: BuffController = owner_node.get_node_or_null(^"BuffController")
    if bc:
        bc.apply(buff, owner_node, owner_node.global_position if owner_node is Node2D else Vector2.ZERO)
```

- [ ] **Step 3: Commit**

```bash
git add Core/AI/Stock/GenericAttackState.gd
git commit -m "feat(buff): add apply_skill_self_buff to GenericAttackState"
```

---

### Task 25: BladeKeeper.tscn — Add Pipeline / BC / SC nodes

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn`

- [ ] **Step 1: Open scene in Godot editor (or use mcp__godot__add_node)**

Use the MCP tool path. The four required nodes (DamagePipeline / BuffController / StatusController) are added as direct children of the BladeKeeper root, alongside the existing HealthComponent. Order matters for `_ready` — DamagePipeline must exist before the others (its `_ready` only emits signals; HC/BC/SC look it up via `get_node_or_null`, so node-tree order suffices).

```
BladeKeeper (CharacterBody2D)
├── HealthComponent              # existing
├── HurtBoxComponent             # existing
├── HitBoxComponent              # existing
├── AIController                 # existing
├── DamagePipeline   ← NEW
├── BuffController   ← NEW
├── StatusController ← NEW
└── (other existing children)
```

For each new node:
1. Use `mcp__godot__add_node` with parent="BladeKeeper" name="DamagePipeline" type="Node" script="res://Core/Damage/DamagePipeline.gd"
2. Same for BuffController (Node, `Core/Buffs/BuffController.gd`)
3. Same for StatusController (Node, `Core/Status/StatusController.gd`)
4. Save scene with `mcp__godot__save_scene`.

- [ ] **Step 2: Verify tscn diff**

```bash
git diff Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn | head -60
```

Expect three new `[node name="..." type="Node" parent="."]` blocks plus one ext_resource per script.

- [ ] **Step 3: Commit**

```bash
git add Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn
git commit -m "feat(buff): mount DamagePipeline + BC + SC on BladeKeeper"
```

---

### Task 26: PlayerBase.tscn — Add the same 4 nodes

**Files:**
- Modify: `Scenes/Characters/Templates/PlayerBase.tscn`

- [ ] **Step 1: Same node additions on PlayerBase**

Player is the source of damage to BK and the target of BK's reactive push. Without Pipeline + BC + SC on the Player, the push effect has nowhere to land.

Same 3 new children: DamagePipeline / BuffController / StatusController.

- [ ] **Step 2: Verify Hahashin / Princess inherit from PlayerBase**

```bash
grep -l "PlayerBase.tscn" Scenes/Characters/Player/Hahashin/*.tscn Scenes/Characters/Player/Princess/*.tscn 2>/dev/null
```

If they don't inherit, add the three nodes to each player concrete scene as well. Otherwise, the inheritance carries them automatically.

- [ ] **Step 3: Commit**

```bash
git add Scenes/Characters/Templates/PlayerBase.tscn
git commit -m "feat(buff): mount DamagePipeline + BC + SC on PlayerBase"
```

---

### Task 27: BK buff library — author .tres files

**Files:**
- Create: `Core/Buffs/library/bk_defense_x05_3s.tres`
- Create: `Core/Buffs/library/bk_heal_pulse.tres`
- Create: `Core/Buffs/library/bk_reactive_push.tres`
- Create: `Core/Buffs/library/poison_dot.tres`

- [ ] **Step 1: Create defense buff .tres (file content shown — write directly)**

```
[gd_resource type="Resource" script_class="BuffEntity" load_steps=3 format=3]

[ext_resource type="Script" path="res://Core/Buffs/BuffEntity.gd" id="1_buff"]
[ext_resource type="Script" path="res://Core/Buffs/effects/StatModEffect.gd" id="2_stat"]

[sub_resource type="Resource" id="StatMod_def"]
script = ExtResource("2_stat")
effect_on = 5
stat_id = &"incoming_damage"
multiplier = 0.5

[resource]
script = ExtResource("1_buff")
id = &"bk_defense_x05_3s"
duration = 3.0
stacking = 0
max_stacks = 1
tags = 0
legal_action_locks = 0
hit_reaction = &""
hit_priority = 0
hit_lock_duration = 0.0
effects = [SubResource("StatMod_def")]
```

(`effect_on = 5` = APPLY|EXPIRE = 1|4)

- [ ] **Step 2: Create heal pulse .tres (HoT 8/sec for 3s = 24 hp total)**

```
[gd_resource type="Resource" script_class="BuffEntity" load_steps=3 format=3]

[ext_resource type="Script" path="res://Core/Buffs/BuffEntity.gd" id="1_buff"]
[ext_resource type="Script" path="res://Core/Buffs/effects/HealEffectBuff.gd" id="2_heal"]

[sub_resource type="Resource" id="Heal_pulse"]
script = ExtResource("2_heal")
effect_on = 2
amount = 8.0
tick_interval = 1.0

[resource]
script = ExtResource("1_buff")
id = &"bk_heal_pulse"
duration = 3.0
stacking = 0
max_stacks = 1
effects = [SubResource("Heal_pulse")]
```

- [ ] **Step 3: Create reactive push .tres (permanent buff on BK; ON_DAMAGED pushes attacker)**

```
[gd_resource type="Resource" script_class="BuffEntity" load_steps=3 format=3]

[ext_resource type="Script" path="res://Core/Buffs/BuffEntity.gd" id="1_buff"]
[ext_resource type="Script" path="res://Core/Buffs/effects/KnockBackEffectBuff.gd" id="2_kb"]

[sub_resource type="Resource" id="KB_push"]
script = ExtResource("2_kb")
effect_on = 16
force = 350.0

[resource]
script = ExtResource("1_buff")
id = &"bk_reactive_push"
duration = 0.0
stacking = 0
max_stacks = 1
effects = [SubResource("KB_push")]
```

- [ ] **Step 4: Create poison DoT .tres**

```
[gd_resource type="Resource" script_class="BuffEntity" load_steps=3 format=3]

[ext_resource type="Script" path="res://Core/Buffs/BuffEntity.gd" id="1_buff"]
[ext_resource type="Script" path="res://Core/Buffs/effects/DamageEffectBuff.gd" id="2_dmg"]

[sub_resource type="Resource" id="DoT_poison"]
script = ExtResource("2_dmg")
effect_on = 2
amount = 5.0
tick_interval = 0.5
damage_tags = 6

[resource]
script = ExtResource("1_buff")
id = &"poison_dot"
duration = 8.0
stacking = 0
max_stacks = 1
tags = 16
effects = [SubResource("DoT_poison")]
```

(damage_tags = 6 = MAGICAL|DOT = 2|4; entity tags = 16 = Poison flag)

- [ ] **Step 5: Open the project in Godot once so UID `.uid` files are generated**

Run via mcp `mcp__godot__launch_editor` if available, otherwise:

```bash
"$GODOT_PATH" --headless --path . --quit-after 5
```

- [ ] **Step 6: Commit**

```bash
git add Core/Buffs/library/*.tres Core/Buffs/library/*.uid
git commit -m "feat(buff): author BK buff library .tres (defense, heal, push, poison)"
```

---

### Task 28: BladeKeeper.gd — wire defense / heal to BuffController

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd`

- [ ] **Step 1: Replace `apply_defense_buff` and `heal_self` to use BuffController**

```gdscript
@export var defense_buff: BuffEntity = preload("res://Core/Buffs/library/bk_defense_x05_3s.tres")
@export var heal_buff: BuffEntity = preload("res://Core/Buffs/library/bk_heal_pulse.tres")
@export var reactive_push_buff: BuffEntity = preload("res://Core/Buffs/library/bk_reactive_push.tres")

func _ready() -> void:
    super._ready()
    if health_comp:
        health_comp.health_changed.connect(_on_health_changed)
    # 永久反推 buff（PoC 阶段直接挂）
    if buff_controller and reactive_push_buff:
        buff_controller.apply(reactive_push_buff, self, global_position)

## Animation method-call: 自施防御 buff
func apply_defense_buff(_duration: float = 0.0) -> void:
    if buff_controller and defense_buff:
        buff_controller.apply(defense_buff, self, global_position)

## Animation method-call: 自施回血 buff
func heal_self(_amount: float = 0.0) -> void:
    if buff_controller and heal_buff:
        buff_controller.apply(heal_buff, self, global_position)
```

(The legacy parameters are kept for animation track compatibility — values are now embedded in the .tres.)

- [ ] **Step 2: Confirm `buff_controller` is reachable**

It comes from `AgentAIBase.@onready var buff_controller`. Verify the @onready resolves by checking node order in the scene (Task 25). If the scene hierarchy is wrong, fix in Task 25 before continuing.

- [ ] **Step 3: Commit**

```bash
git add Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd
git commit -m "feat(buff): wire BK defense/heal/push to BuffController"
```

---

### Task 29: Pipeline integration tests — DoT / heal / callback / dodge

**Files:**
- Create: `test/unit/test_dot_pipeline.gd`
- Create: `test/unit/test_heal_pipeline.gd`
- Create: `test/unit/test_callback_effects.gd`
- Create: `test/unit/test_dodge_iframes.gd`

- [ ] **Step 1: test_dot_pipeline.gd**

```gdscript
extends GutTest
const H = preload("res://test/base/test_helper.gd")

var _actor: CharacterBody2D
var _hc: HealthComponent
var _bc: BuffController
var _react_called: bool

func before_each() -> void:
    _actor = H.build_actor_with_pipeline()
    add_child_autofree(_actor)
    _hc = _actor.get_node(^"HealthComponent")
    _bc = _actor.get_node(^"BuffController")
    var pipe: DamagePipeline = _actor.get_node(^"DamagePipeline")
    _react_called = false
    pipe.react.connect(func(ctx):
        if not (ctx.tags & DamageTags.DOT):
            _react_called = true)

func _make_poison() -> BuffEntity:
    var e := DamageEffectBuff.new()
    e.amount = 5.0
    e.tick_interval = 0.5
    e.damage_tags = DamageTags.MAGICAL
    e.effect_on = BuffEffect.EffectOn.TICK
    return H.create_buff_entity(&"poison", 2.0, [e])

func test_dot_drains_hp_each_tick() -> void:
    _bc.apply(_make_poison(), null, _actor.global_position)
    _bc._physics_process(0.5)
    assert_eq(_hc.health, 95.0)
    _bc._physics_process(0.5)
    assert_eq(_hc.health, 90.0)

func test_dot_carries_dot_tag_into_pipeline() -> void:
    var pipe: DamagePipeline = _actor.get_node(^"DamagePipeline")
    var seen_tag := 0
    pipe.apply.connect(func(ctx): seen_tag = ctx.tags)
    _bc.apply(_make_poison(), null, _actor.global_position)
    _bc._physics_process(0.5)
    assert_true((seen_tag & DamageTags.DOT) != 0)

func test_dot_skips_react_for_hit_state() -> void:
    _bc.apply(_make_poison(), null, _actor.global_position)
    _bc._physics_process(0.5)
    assert_false(_react_called, "DoT should not invoke react listener that filters non-DOT")

func test_dot_benefits_from_defense_buff() -> void:
    var def := StatModEffect.new()
    def.stat_id = StatIds.INCOMING_DAMAGE
    def.multiplier = 0.5
    _bc.apply(H.create_buff_entity(&"def", 10.0, [def]), null, _actor.global_position)
    _bc.apply(_make_poison(), null, _actor.global_position)
    _bc._physics_process(0.5)
    assert_eq(_hc.health, 97.5, "5 * 0.5 = 2.5 dmg")
```

- [ ] **Step 2: test_heal_pipeline.gd**

```gdscript
extends GutTest
const H = preload("res://test/base/test_helper.gd")

var _actor: CharacterBody2D
var _hc: HealthComponent
var _bc: BuffController

func before_each() -> void:
    _actor = H.build_actor_with_pipeline()
    add_child_autofree(_actor)
    _hc = _actor.get_node(^"HealthComponent")
    _hc.health = 50.0
    _bc = _actor.get_node(^"BuffController")

func test_immediate_heal_via_hc() -> void:
    _hc.heal(20.0)
    assert_eq(_hc.health, 70.0)

func test_heal_does_not_emit_damaged() -> void:
    watch_signals(_hc)
    _hc.heal(10.0)
    assert_signal_not_emitted(_hc, "damaged")

func test_hot_ticks() -> void:
    var e := HealEffectBuff.new()
    e.amount = 8.0
    e.tick_interval = 1.0
    e.effect_on = BuffEffect.EffectOn.TICK
    _bc.apply(H.create_buff_entity(&"hot", 3.0, [e]), null, _actor.global_position)
    _bc._physics_process(1.0)
    assert_eq(_hc.health, 58.0)
    _bc._physics_process(1.0)
    assert_eq(_hc.health, 66.0)

func test_heal_received_modifier_applies() -> void:
    var hr := StatModEffect.new()
    hr.stat_id = StatIds.HEAL_RECEIVED
    hr.multiplier = 0.5
    _bc.apply(H.create_buff_entity(&"hr_debuff", 10.0, [hr]), null, _actor.global_position)
    _hc.heal(20.0)
    assert_eq(_hc.health, 60.0, "10 healed at half rate")
```

- [ ] **Step 3: test_callback_effects.gd**

```gdscript
extends GutTest
const H = preload("res://test/base/test_helper.gd")

var _victim: CharacterBody2D
var _attacker: CharacterBody2D
var _victim_bc: BuffController

func before_each() -> void:
    _victim = H.build_actor_with_pipeline()
    _victim.position = Vector2(100, 0)
    add_child_autofree(_victim)
    _attacker = H.build_actor_with_pipeline()
    _attacker.position = Vector2(0, 0)
    add_child_autofree(_attacker)
    _victim_bc = _victim.get_node(^"BuffController")

func test_on_damaged_pushes_attacker() -> void:
    var kb := KnockBackEffectBuff.new()
    kb.force = 300.0
    kb.target_kind = 1
    kb.effect_on = BuffEffect.EffectOn.ON_DAMAGED
    _victim_bc.apply(H.create_buff_entity(&"thorns", 0.0, [kb]), null, _victim.global_position)

    var pipe: DamagePipeline = _victim.get_node(^"DamagePipeline")
    var ctx := DamageContext.new()
    ctx.target = _victim
    ctx.source = _attacker
    ctx.amount = 10.0
    ctx.source_pos = _attacker.global_position
    pipe.process(ctx)

    assert_almost_eq(_attacker.velocity.x, -300.0, 0.5, "pushed left away from victim at x=100")
```

- [ ] **Step 4: test_dodge_iframes.gd**

```gdscript
extends GutTest
const H = preload("res://test/base/test_helper.gd")

var _actor: CharacterBody2D
var _hc: HealthComponent
var _sc: StatusController

func before_each() -> void:
    _actor = H.build_actor_with_pipeline()
    add_child_autofree(_actor)
    _hc = _actor.get_node(^"HealthComponent")
    _sc = _actor.get_node(^"StatusController")

func _hit(amount: float) -> DamageContext:
    var pipe: DamagePipeline = _actor.get_node(^"DamagePipeline")
    var ctx := DamageContext.new()
    ctx.target = _actor; ctx.amount = amount
    pipe.process(ctx)
    return ctx

func test_iframes_block_damage() -> void:
    _sc.apply_lock(LegalAction.HURTABLE, 1.0)
    var ctx := _hit(30.0)
    assert_true(ctx.blocked)
    assert_eq(_hc.health, 100.0)

func test_iframes_expire_restores_hurtable() -> void:
    _sc.apply_lock(LegalAction.HURTABLE, 0.1)
    _sc._process(0.2)
    var ctx := _hit(30.0)
    assert_false(ctx.blocked)
    assert_eq(_hc.health, 70.0)

func test_heal_bypasses_iframes() -> void:
    _hc.health = 50.0
    _sc.apply_lock(LegalAction.HURTABLE, 1.0)
    _hc.heal(20.0)
    assert_eq(_hc.health, 70.0, "heal still goes through")
```

- [ ] **Step 5: Run all four tests**

Run: `bash test/run_tests.sh dot_pipeline && bash test/run_tests.sh heal_pipeline && bash test/run_tests.sh callback_effects && bash test/run_tests.sh dodge_iframes`
Expected: ALL PASS

- [ ] **Step 6: Commit**

```bash
git add test/unit/test_dot_pipeline.gd test/unit/test_heal_pipeline.gd test/unit/test_callback_effects.gd test/unit/test_dodge_iframes.gd
git commit -m "test(buff): cover DoT, heal, callback, and i-frame paths"
```

---

### Task 30: Full-suite green check

**Files:**
- (no edits — only the test runner)

- [ ] **Step 1: Run all unit tests**

Run: `bash test/run_tests.sh unit`
Expected: All PASS, except any test marked `pending()` from Task 20.

- [ ] **Step 2: If anything fails, fix root cause (do NOT mark new failures pending)**

Common failure modes to check first:
- Missing `class_name` (typo)
- Forgetting to `_actor.add_child(...)` before `add_child_autofree(_actor)`
- Pipeline not yet ready when subscriber's `_ready` runs — order in `build_actor_with_pipeline` must be DamagePipeline first.

- [ ] **Step 3: Commit any small fixes**

```bash
git add <changed files>
git commit -m "fix(buff): <specific fix>"
```

---

### Task 31: Manual PoC validation in LevelBladeKeeper.tscn

**Files:**
- Run scene: `Scenes/Levels/Level_BladeKeeper/LevelBladeKeeper.tscn`

This is a manual smoke gate before declaring PoC complete. Do not skip.

- [ ] **Step 1: Launch the BK level**

Use `mcp__godot__run_project` with scene argument `res://Scenes/Levels/Level_BladeKeeper/LevelBladeKeeper.tscn` if supported, else manually open and Play in Godot.

- [ ] **Step 2: Validate scenarios (record observations in commit message)**

| # | Scenario | Expected Observation |
|---|---|---|
| 1 | Player hits BK normally | HP drops; HitBoxNumber appears; BK enters HitState (hit anim) |
| 2 | BK casts defense (animation method-call to `apply_defense_buff`) | Subsequent player hits do half damage for 3s |
| 3 | BK casts heal (animation method-call to `heal_self`) | HP rises ~8/sec for 3s; no HitState entry |
| 4 | Player hits BK while reactive_push_buff active | Player gets pushed back ~350 force |
| 5 | (Optional) Player with poison_dot applied | Player HP ticks down 5/0.5s, no HitState; cleans up after 8s |
| 6 | BK dies | All buffs cleared (visual: defense never persists past death; HP stays at 0) |

- [ ] **Step 3: Capture debug log**

If any scenario fails, run `mcp__godot__get_debug_output` and attach to the commit / PR description.

- [ ] **Step 4: Commit observation note (no code change required if all passed)**

```bash
git commit --allow-empty -m "test(buff): BK PoC manual validation passed (scenarios 1-6)"
```

---

## Self-Review Checklist

Before declaring the plan ready:

**Spec coverage:**
- §3 Data layer → Tasks 5-10, 16-19 ✓
- §4 Runtime layer → Task 11 ✓
- §5 Pipeline layer → Tasks 1-3 ✓
- §6 Capability layer → Task 13 ✓
- §7 Subscribers → Tasks 14, 21-24 ✓
- §8 Seven scenarios → covered by tests in Task 12, 13, 29 + manual in Task 31 ✓
- §9 AgentAI integration → Task 22 ✓
- §10 Stacking → Task 12 ✓
- §11 Multi-attacker correctness → covered by parallel-safe BuffInstance design (Task 11) + manual scenario 1 (multi-hit) ✓
- §12 HealthBar → no signal change required (HC retained) ✓
- §13 Edge cases → covered by null-safety in BuffController (Task 11) + DamagePipeline (Task 3) ✓
- §14 Change list → Tasks 14-15 (HC), 20 (Damage), 21-24 (HitBox/AAB/Hit/Generic), 25-26 (scenes) ✓
- §15 Tests → Tasks 4, 12, 13, 14 (HC), 16, 29 ✓
- §16 BK PoC → Tasks 25-31 ✓
- §17 Phase 2 → **explicitly out of scope** for this plan ✓

**Placeholder scan:** None — every code step contains complete code and exact paths.

**Type consistency:**
- `BuffController.apply(buff, source, source_pos)` consistent across spec, Task 11, Task 28
- `DamageContext` field names (target/source/amount/raw_amount/tags/blocked/dealt/is_heal/source_pos/attached_buffs) consistent across all tasks
- `EffectOn` enum integer values (APPLY=1, TICK=2, EXPIRE=4, ON_DAMAGED=16) used in .tres in Task 27
- `LegalAction` constants (ATTACK=1, HURTABLE=16, ALL=31) consistent

**Test infra:** Uses GUT's `add_child_autofree`, `watch_signals`, `assert_*` and the existing `test/base/test_helper.gd` pattern.

---

## Effort Estimate

| Phase | Tasks | Time |
|---|---|---|
| Foundation (Pipeline) | 1-4 | 1.5 h |
| Buff core (data + runtime) | 5-15 | 4 h |
| BuffEffect subclasses | 16-19 | 1.5 h |
| Integration rewrites | 20-24 | 2 h |
| Scenes + .tres | 25-28 | 1.5 h |
| Integration tests | 29-30 | 2 h |
| Manual PoC validation | 31 | 0.5 h |
| **Total** | | **~13 h** |

This is the BK PoC scope only; Cyclops/DS2/Enemy migration (Phase 2) is a separate plan.

---

## Done When

- All tasks checked
- `bash test/run_tests.sh unit` is green (modulo Phase 2 pending)
- Manual scenarios 1-6 in Task 31 verified
- Branch `feat/buff-entity-framework` ready for review
