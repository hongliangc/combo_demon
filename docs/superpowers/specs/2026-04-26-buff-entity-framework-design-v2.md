# BuffEntity 框架设计 v2 — Pipeline 解耦 + Bitmask 状态系统

**日期**：2026-04-26
**状态**：设计稿（取代 v1 [2026-04-26-buff-entity-framework-design.md](2026-04-26-buff-entity-framework-design.md)）
**前置依赖**：
- [Skill 系统设计](2026-04-16-skill-system-design.md) 已实现并通过 CR
- [BladeKeeper 迁移设计](2026-04-18-bladekeeper-migration-design.md) §6 路线图（v2 取代）
- 参考开源库：[ModiBuff](https://github.com/Chillu1/ModiBuff)（C# zero-GC modifier engine）、[broken_seals](https://github.com/Relintai/broken_seals)（GDScript+C++ Entity Spell System）

**适用范围**：项目级通用持续状态框架。BK / Cyclops / 玩家 / Enemy 全部走同一管线。

---

## 0. 与 v1 的差异

| 维度 | v1 | v2 |
|---|---|---|
| HealthComponent ↔ BuffComponent 耦合 | 直查 `bc.get_modifier` + `bc.apply` | **零耦合**——都订阅 DamagePipeline |
| 行为锁字段 | `locks_actions / locks_movement / grants_invincibility` 三 bool | **LegalAction bitmask + 独立计时器**（最长生效） |
| Effect 触发时机 | 三钩子 on_apply/on_tick/on_expire | **EffectOn bitmask** 7 种时机任意组合 |
| 子类爆炸 | StunBuff/KnockBackBuff/DoTBuff 各一类 | **BuffEntity = compose BuffEffect[]**——同一 buff 可同时是 stat-mod + DoT + 锁 |
| DoT 跳过 HitState | `trigger_hit_reaction=false` bool 参数 | `ctx.tags & DOT` 标签过滤，无特殊路径 |
| 治疗 / 伤害 | 两条独立路径 | **同 pipeline + is_heal 标志** |
| 闪避 / 无敌 | `HC.is_invincible` bool | `LegalAction.HURTABLE` bit + 倒计时自动释放 |
| 反推 / 反伤 | 硬编码 in `_on_agent_damaged` | `effect_on=ON_DAMAGED` callback effect 数据驱动 |
| AI guard | `owner.stunned` 各处检查 | `status.has_legal_action(ATTACK)` 统一接口 |

**总成本**：+1 天（pipeline + StatusController 抽象）；**收益**：后续 buff/锁/管线钩子全部零代码扩展。

---

## 1. 设计目标

| 目标 | 落地手段 |
|---|---|
| 优雅、解耦、可扩展 | 五层职责分离 + 信号订阅 + 数据驱动 |
| HealthComponent 零 buff 知识 | DamagePipeline 信号枢纽，HC 仅订阅 apply 阶段 |
| Effect 时机灵活 | EffectOn bitmask（来自 ModiBuff） |
| 行为锁聚合优雅 | LegalAction bitmask + 独立计时器（来自 ModiBuff，longest wins） |
| 与 AgentAI 框架融合 | AAB 订阅 pipeline.react，StatusController 暴露 guard |
| 不兼容存量 | AttackEffect 五子类全删，Damage.effects 类型重定向 |

---

## 2. 五层架构

```
┌── 1. 数据层（Resource, immutable）────────────────────────┐
│  BuffEntity                                               │
│    ├ id / duration / stacking / max_stacks                │
│    ├ tags: int (Magical/Physical/Curse 用于驱散/抗性)     │
│    ├ legal_action_locks: int (LegalAction bitmask)        │
│    ├ hit_reaction / hit_priority / hit_lock_duration      │
│    └ effects: Array[BuffEffect]                           │
│  BuffEffect (子类: StatMod/Damage/Heal/KnockBack/...)     │
│    ├ effect_on: int (EffectOn bitmask)                    │
│    └ execute(ctx, inst, owner)                            │
└───────────────────────────────────────────────────────────┘
                  ↓ apply
┌── 2. 运行时层（per-entity Node）─────────────────────────┐
│  BuffInstance (RefCounted): entity / remaining /           │
│                              tick_accum / stacks / source │
│  BuffController                                            │
│    ├ active: Array[BuffInstance]                          │
│    ├ apply / tick(_physics) / expire                      │
│    ├ get_modifier(stat_id) → 聚合乘法                     │
│    ├ get_legal_action_locks() → bitmask 并集               │
│    ├ get_top_hit_buff() → 选 hit_priority 最大            │
│    └ 订阅父节点 DamagePipeline 三阶段                       │
└───────────────────────────────────────────────────────────┘
                  ↓ subscribes
┌── 3. 管线层（per-entity Node, 信号驱动）─────────────────┐
│  DamageContext (RefCounted, mutable)                      │
│  DamagePipeline                                            │
│    signals (按序 emit):                                    │
│    ├ pre_calc(ctx)    ─ outgoing/incoming 倍率注入         │
│    ├ pre_apply(ctx)   ─ 闪避/无敌/格挡（block ctx）        │
│    ├ apply(ctx)       ─ HealthComponent 在此提交 HP        │
│    ├ post_apply(ctx)  ─ 反伤/吸血/buff 入栈/反推           │
│    └ react(ctx)       ─ HitState 派发 EV_DAMAGED           │
│  process(ctx) → 顺序 emit；任何阶段设 ctx.blocked 终止    │
└───────────────────────────────────────────────────────────┘
                  ↓ 各自独立订阅
┌── 4. 订阅者（互不知情）─────────────────────────────────┐
│  HealthComponent  → connect apply       (改 HP)            │
│  BuffController   → connect pre_calc    (mult)             │
│                   → connect pre_apply   (无敌 block)       │
│                   → connect post_apply  (attach + cb)      │
│  StatusController → connect pre_apply   (闪避 block)       │
│  AgentAIBase      → connect react       (dispatch EV_*)    │
│  HitBoxComponent  → 攻击侧 process(ctx) (调用方)           │
└───────────────────────────────────────────────────────────┘
                  ↓ 暴露能力
┌── 5. 能力层（per-entity Node）──────────────────────────┐
│  StatusController                                          │
│    ├ legal_actions: int (LegalAction bitmask, 默认 ALL)    │
│    ├ legal_action_timers: PackedFloat32Array               │
│    ├ has_legal_action(LegalAction.Attack) → bool           │
│    ├ apply_lock(action_mask, duration) (longest wins)      │
│    ├ _process(dt) 倒计时；归零释放对应 bit                  │
│    ├ signal: legal_actions_changed(prev, new)              │
│    └ 监听 BuffController.buffs_changed → 重算锁             │
└───────────────────────────────────────────────────────────┘
```

**单向依赖**：1 不知 2/3/4/5；2 知 1 + 订阅 3；3 仅是信号枢纽；4 各自只知 3；5 知 2 (buffs_changed) + 订阅 3。

---

## 3. 数据层

### 3.1 BuffEntity

```gdscript
# Core/Buffs/BuffEntity.gd
class_name BuffEntity extends Resource

enum Stacking { REFRESH, STACK, REPLACE }

@export var id: StringName
@export var duration: float = 0.0          # 0 = 永久
@export var stacking: Stacking = Stacking.REFRESH
@export var max_stacks: int = 99

# 元数据（驱散/抗性/UI 着色）
@export_flags("Physical", "Magical", "Curse", "Bleed", "Poison")
var tags: int = 0

# 行为锁声明（StatusController 聚合）
@export_flags("Attack", "Move", "Defend", "Cast", "Hurtable")
var legal_action_locks: int = 0

# Hit 表现语义（被攻击触发时使用；自施 buff 留空）
@export var hit_reaction: StringName = &""
@export var hit_priority: int = 0
@export var hit_lock_duration: float = 0.0

# 组合层 — 一个 buff 可挂多个 effect
@export var effects: Array[BuffEffect] = []

func execute_on(trigger: int, ctx: BuffEffectContext) -> void:
    for e in effects:
        if e and (e.effect_on & trigger) != 0:
            e.execute(ctx)
```

### 3.2 BuffEffect 基类 + EffectOn bitmask

```gdscript
# Core/Buffs/BuffEffect.gd
class_name BuffEffect extends Resource

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

func execute(ctx: BuffEffectContext) -> void:
    pass  # 子类实现
```

### 3.3 BuffEffectContext（子类执行上下文）

```gdscript
# Core/Buffs/BuffEffectContext.gd
class_name BuffEffectContext extends RefCounted

var owner: Node                       # buff 持有者
var instance: BuffInstance            # 当前 buff 实例
var trigger: int                      # 当前 EffectOn 位
var damage_ctx: DamageContext = null  # 仅 ON_DAMAGED/ON_ATTACK/ON_HEAL 时填充
var delta: float = 0.0                # 仅 TICK 时填充
```

### 3.4 BuffEffect 子类

```gdscript
# Core/Buffs/effects/StatModEffect.gd
class_name StatModEffect extends BuffEffect
@export var stat_id: StringName       # StatIds.INCOMING_DAMAGE / OUTGOING_DAMAGE / HEAL_RECEIVED
@export var multiplier: float = 1.0
# 默认 effect_on = APPLY | EXPIRE：apply 时入账，expire 时退账

func execute(ctx: BuffEffectContext) -> void:
    var bc: BuffController = ctx.owner.get_node(^"BuffController")
    if ctx.trigger == EffectOn.APPLY:
        bc.add_stat_modifier(stat_id, multiplier)
    elif ctx.trigger == EffectOn.EXPIRE:
        bc.remove_stat_modifier(stat_id, multiplier)
```

```gdscript
# Core/Buffs/effects/DamageEffect.gd
class_name DamageEffectBuff extends BuffEffect
@export var amount: float = 5.0
@export var tick_interval: float = 0.5
@export var damage_tags: int = 0      # DamageTags.DOT / Magical / ...
# 目标由 ctx.trigger 决定（见 Plan Amendment A1）：
#   ON_DAMAGED / ON_HEAL → ctx.damage_ctx.source（攻击者 / 治疗者）
#   其他（APPLY / TICK / ...）  → ctx.owner

func execute(ctx: BuffEffectContext) -> void:
    var t: Node = _resolve_target(ctx)
    if t == null: return
    var dc := DamageContext.new()
    dc.target = t
    dc.source = ctx.instance.source_actor
    dc.raw_amount = amount
    dc.amount = amount
    dc.tags = damage_tags
    if ctx.trigger == EffectOn.TICK:
        dc.tags |= DamageTags.DOT
    dc.source_pos = ctx.instance.source_pos
    var pipe: DamagePipeline = t.get_node(^"DamagePipeline")
    if pipe: pipe.process(dc)

func _resolve_target(ctx: BuffEffectContext) -> Node:
    match ctx.trigger:
        EffectOn.ON_DAMAGED, EffectOn.ON_HEAL:
            return ctx.damage_ctx.source if ctx.damage_ctx else null
        _:
            return ctx.owner
```

```gdscript
# Core/Buffs/effects/HealEffect.gd
class_name HealEffectBuff extends BuffEffect
@export var amount: float = 5.0
@export var tick_interval: float = 0.5

func execute(ctx: BuffEffectContext) -> void:
    var dc := DamageContext.new()
    dc.target = ctx.owner
    dc.is_heal = true
    dc.raw_amount = amount
    dc.amount = amount
    var pipe: DamagePipeline = ctx.owner.get_node(^"DamagePipeline")
    if pipe: pipe.process(dc)
```

```gdscript
# Core/Buffs/effects/KnockBackEffect.gd
class_name KnockBackEffectBuff extends BuffEffect
@export var force: float = 400.0
# 目标由 ctx.trigger 决定（Plan Amendment A1）：
#   APPLY → ctx.owner（默认击退自身）
#   ON_DAMAGED → ctx.damage_ctx.source（反推攻击者）

func execute(ctx: BuffEffectContext) -> void:
    var t: Node = _resolve_target(ctx)
    if not t is CharacterBody2D: return
    var src_pos: Vector2 = ctx.damage_ctx.source_pos if ctx.damage_ctx else ctx.instance.source_pos
    var dir := (t.global_position - src_pos).normalized()
    (t as CharacterBody2D).velocity = dir * force

func _resolve_target(ctx: BuffEffectContext) -> Node:
    match ctx.trigger:
        EffectOn.ON_DAMAGED, EffectOn.ON_HEAL:
            return ctx.damage_ctx.source if ctx.damage_ctx else null
        _:
            return ctx.owner
```

### 3.5 StatIds / DamageTags / LegalAction 常量

```gdscript
# Core/Buffs/StatIds.gd
class_name StatIds
const INCOMING_DAMAGE := &"incoming_damage"
const OUTGOING_DAMAGE := &"outgoing_damage"
const HEAL_RECEIVED   := &"heal_received"

# Core/Damage/DamageTags.gd
class_name DamageTags
const PHYSICAL := 1
const MAGICAL  := 2
const DOT      := 4         # 跳过 HitState reaction
const CRIT     := 8
const TRUE     := 16        # 真伤，无视 INCOMING_DAMAGE

# Core/Status/LegalAction.gd
class_name LegalAction
enum {
    NONE     = 0,
    ATTACK   = 1,
    MOVE     = 2,
    DEFEND   = 4,    # 闪避/格挡 AI 行为
    CAST     = 8,    # 远程/特殊技能
    HURTABLE = 16,   # 可被伤害（关闭 = i-frames）
    ALL      = 31,
}
const STUN    := ATTACK | MOVE | DEFEND | CAST   # 全锁（仍 HURTABLE）
const ROOT    := MOVE
const DISARM  := ATTACK
const SILENCE := CAST
const SLEEP   := ATTACK | MOVE | CAST
```

---

## 4. 运行时层

### 4.1 BuffInstance

```gdscript
# Core/Buffs/BuffInstance.gd
class_name BuffInstance extends RefCounted

var entity: BuffEntity              # immutable 配置
var remaining: float                # 剩余时长
var tick_accums: Dictionary = {}    # effect 索引 → tick_accum
var stacks: int = 1
var source_actor: Node              # 施加者
var source_pos: Vector2
var gen_id: int = 0                 # 同 id 多实例时唯一 ID（STACK 模式用）
```

### 4.2 BuffController

```gdscript
# Core/Buffs/BuffController.gd
class_name BuffController extends Node

signal buffs_changed

var active: Array[BuffInstance] = []
var _stat_modifiers: Dictionary = {}   # stat_id → Array[multiplier]
var _gen_id_counter: int = 0

@onready var owner_node: Node = get_parent()
@onready var pipeline: DamagePipeline = owner_node.get_node_or_null(^"DamagePipeline")

func _ready() -> void:
    if pipeline:
        pipeline.pre_calc.connect(_on_pre_calc)
        pipeline.pre_apply.connect(_on_pre_apply)
        pipeline.post_apply.connect(_on_post_apply)

# ---- Apply ----
func apply(buff: BuffEntity, source_actor: Node, source_pos: Vector2) -> void:
    match buff.stacking:
        BuffEntity.Stacking.REFRESH:
            var existing := _find_by_id(buff.id)
            if existing:
                existing.remaining = buff.duration
                return
        BuffEntity.Stacking.REPLACE:
            var existing := _find_by_id(buff.id)
            if existing: _expire(existing)
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
    
    var ctx := BuffEffectContext.new()
    ctx.owner = owner_node
    ctx.instance = inst
    ctx.trigger = BuffEffect.EffectOn.APPLY
    buff.execute_on(BuffEffect.EffectOn.APPLY, ctx)
    
    buffs_changed.emit()

# ---- Tick (per-frame) ----
func _physics_process(delta: float) -> void:
    var i := active.size() - 1
    while i >= 0:
        var inst := active[i]
        _tick_instance(inst, delta)
        if inst.entity.duration > 0:
            inst.remaining -= delta
            if inst.remaining <= 0:
                _expire(inst)
                active.remove_at(i)
                buffs_changed.emit()
        i -= 1

func _tick_instance(inst: BuffInstance, delta: float) -> void:
    for idx in inst.entity.effects.size():
        var eff: BuffEffect = inst.entity.effects[idx]
        if not eff or (eff.effect_on & BuffEffect.EffectOn.TICK) == 0: continue
        var interval: float = eff.get(&"tick_interval") if &"tick_interval" in eff else 0.0
        if interval <= 0:
            _exec_effect(eff, inst, delta, BuffEffect.EffectOn.TICK)
            continue
        var accum: float = inst.tick_accums.get(idx, 0.0) + delta
        if accum >= interval:
            inst.tick_accums[idx] = accum - interval
            _exec_effect(eff, inst, delta, BuffEffect.EffectOn.TICK)
        else:
            inst.tick_accums[idx] = accum

func _exec_effect(eff: BuffEffect, inst: BuffInstance, delta: float,
                  trigger: int, dc: DamageContext = null) -> void:
    var ctx := BuffEffectContext.new()
    ctx.owner = owner_node
    ctx.instance = inst
    ctx.trigger = trigger
    ctx.delta = delta
    ctx.damage_ctx = dc
    eff.execute(ctx)

func _expire(inst: BuffInstance) -> void:
    var ctx := BuffEffectContext.new()
    ctx.owner = owner_node
    ctx.instance = inst
    ctx.trigger = BuffEffect.EffectOn.EXPIRE
    inst.entity.execute_on(BuffEffect.EffectOn.EXPIRE, ctx)

# ---- Pipeline 订阅 ----
func _on_pre_calc(dc: DamageContext) -> void:
    if dc.target != owner_node: return
    if dc.tags & DamageTags.TRUE: return  # 真伤无视
    if dc.is_heal:
        dc.amount *= get_modifier(StatIds.HEAL_RECEIVED)
    else:
        dc.amount *= get_modifier(StatIds.INCOMING_DAMAGE)

func _on_pre_apply(dc: DamageContext) -> void:
    # invincibility 由 StatusController 处理（HURTABLE bit）
    pass

func _on_post_apply(dc: DamageContext) -> void:
    if dc.target != owner_node: return
    # 1. 入栈携带 buff
    for buff in dc.attached_buffs:
        if buff: apply(buff, dc.source, dc.source_pos)
    # 2. 触发 ON_DAMAGED callback effect（反伤/反推）
    if dc.is_heal: return
    for inst in active:
        for eff in inst.entity.effects:
            if eff and (eff.effect_on & BuffEffect.EffectOn.ON_DAMAGED) != 0:
                _exec_effect(eff, inst, 0.0, BuffEffect.EffectOn.ON_DAMAGED, dc)

# ---- 聚合查询 ----
func get_modifier(stat_id: StringName) -> float:
    var arr: Array = _stat_modifiers.get(stat_id, [])
    var result := 1.0
    for m in arr: result *= m
    return result

func add_stat_modifier(stat_id: StringName, mult: float) -> void:
    if not _stat_modifiers.has(stat_id): _stat_modifiers[stat_id] = []
    _stat_modifiers[stat_id].append(mult)

func remove_stat_modifier(stat_id: StringName, mult: float) -> void:
    var arr: Array = _stat_modifiers.get(stat_id, [])
    arr.erase(mult)

func get_legal_action_locks() -> int:
    var mask := 0
    for inst in active: mask |= inst.entity.legal_action_locks
    return mask

func get_top_hit_buff() -> BuffEntity:
    var top: BuffInstance = null
    for inst in active:
        if inst.entity.hit_reaction == &"": continue
        if top == null or inst.entity.hit_priority > top.entity.hit_priority:
            top = inst
    return top.entity if top else null

func _find_by_id(id: StringName) -> BuffInstance:
    for inst in active:
        if inst.entity.id == id: return inst
    return null

func clear_all() -> void:
    for inst in active: _expire(inst)
    active.clear()
    _stat_modifiers.clear()
    buffs_changed.emit()
```

---

## 5. 管线层

### 5.1 DamageContext

```gdscript
# Core/Damage/DamageContext.gd
class_name DamageContext extends RefCounted

var source: Node                       # 攻击者
var target: Node                       # 受害者
var raw_amount: float = 0.0
var amount: float = 0.0                # pipeline 中可变
var source_pos: Vector2
var attached_buffs: Array[BuffEntity] = []  # 攻击携带的 buff
var tags: int = 0                      # DamageTags bitmask
var blocked: bool = false              # 任一阶段可设
var dealt: float = 0.0                 # commit 后回填
var is_heal: bool = false              # 治疗复用同管线
```

### 5.2 DamagePipeline

```gdscript
# Core/Damage/DamagePipeline.gd
class_name DamagePipeline extends Node

signal pre_calc(ctx: DamageContext)
signal pre_apply(ctx: DamageContext)
signal apply(ctx: DamageContext)
signal post_apply(ctx: DamageContext)
signal react(ctx: DamageContext)

func process(ctx: DamageContext) -> void:
    pre_calc.emit(ctx);    if ctx.blocked: return
    pre_apply.emit(ctx);   if ctx.blocked: return
    apply.emit(ctx)
    post_apply.emit(ctx)
    react.emit(ctx)
```

---

## 6. 能力层 — StatusController + LegalAction

```gdscript
# Core/Status/StatusController.gd
class_name StatusController extends Node

signal legal_actions_changed(prev: int, new: int)

var legal_actions: int = LegalAction.ALL
var _action_timers: Dictionary = {}    # action_bit → remaining_time

@onready var owner_node: Node = get_parent()
@onready var pipeline: DamagePipeline = owner_node.get_node_or_null(^"DamagePipeline")
@onready var bc: BuffController = owner_node.get_node_or_null(^"BuffController")

func _ready() -> void:
    if pipeline: pipeline.pre_apply.connect(_on_pre_apply)
    if bc: bc.buffs_changed.connect(_recompute_buff_locks)

func _process(delta: float) -> void:
    var prev := legal_actions
    var keys_to_clear: Array = []
    for bit in _action_timers.keys():
        _action_timers[bit] -= delta
        if _action_timers[bit] <= 0:
            keys_to_clear.append(bit)
    for k in keys_to_clear: _action_timers.erase(k)
    _recompute_legal_actions()
    if legal_actions != prev:
        legal_actions_changed.emit(prev, legal_actions)

# ---- 主动加锁（DodgeState / 技能动画期间用）----
## longest wins：对同 bit 多次加锁，取最大 duration
func apply_lock(action_mask: int, duration: float) -> void:
    var prev := legal_actions
    for bit in [LegalAction.ATTACK, LegalAction.MOVE,
                LegalAction.DEFEND, LegalAction.CAST, LegalAction.HURTABLE]:
        if action_mask & bit:
            var cur: float = _action_timers.get(bit, 0.0)
            if duration > cur: _action_timers[bit] = duration
    _recompute_legal_actions()
    if legal_actions != prev: legal_actions_changed.emit(prev, legal_actions)

# ---- 解锁特定 action（可选）----
func release_lock(action_mask: int) -> void:
    var prev := legal_actions
    for bit in [LegalAction.ATTACK, LegalAction.MOVE,
                LegalAction.DEFEND, LegalAction.CAST, LegalAction.HURTABLE]:
        if action_mask & bit: _action_timers.erase(bit)
    _recompute_legal_actions()
    if legal_actions != prev: legal_actions_changed.emit(prev, legal_actions)

# ---- 查询接口（AI guard 用）----
func has_legal_action(action: int) -> bool:
    return (legal_actions & action) == action

func can_attack() -> bool: return has_legal_action(LegalAction.ATTACK)
func can_move() -> bool:   return has_legal_action(LegalAction.MOVE)
func can_be_hit() -> bool: return has_legal_action(LegalAction.HURTABLE)

# ---- Pipeline 订阅：HURTABLE bit 控制无敌 ----
func _on_pre_apply(ctx: DamageContext) -> void:
    if ctx.target != owner_node: return
    if ctx.is_heal: return
    if not has_legal_action(LegalAction.HURTABLE):
        ctx.blocked = true

# ---- 内部：重算 legal_actions ----
func _recompute_legal_actions() -> void:
    var locked := 0
    # 主动锁（timers）
    for bit in _action_timers.keys(): locked |= bit
    # buff 锁（聚合）
    if bc: locked |= bc.get_legal_action_locks()
    legal_actions = LegalAction.ALL & ~locked

func _recompute_buff_locks() -> void:
    var prev := legal_actions
    _recompute_legal_actions()
    if legal_actions != prev: legal_actions_changed.emit(prev, legal_actions)
```

**关键语义**：HURTABLE 默认 ON。i-frames / 闪避 = 临时关闭 HURTABLE bit；倒计时归零自动恢复，无需手动 unlock。

---

## 7. 订阅者（业务层）

### 7.1 HealthComponent — 完全瘦身

```gdscript
# Core/Components/HealthComponent.gd
class_name HealthComponent extends Node

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source_pos: Vector2)
signal died

@export var max_health: float = 100.0
var health: float
var is_alive: bool = true

@onready var pipeline: DamagePipeline = get_parent().get_node_or_null(^"DamagePipeline")

func _ready() -> void:
    health = max_health
    if pipeline: pipeline.apply.connect(_commit)

func _commit(ctx: DamageContext) -> void:
    if ctx.target != get_parent() or not is_alive: return
    var prev := health
    if ctx.is_heal:
        health = minf(health + ctx.amount, max_health)
        ctx.dealt = health - prev
    else:
        health = clampf(health - ctx.amount, 0.0, max_health)
        ctx.dealt = prev - health
        if ctx.dealt > 0:
            damaged.emit(ctx.dealt, ctx.source_pos)
    health_changed.emit(health, max_health)
    if health <= 0.0 and is_alive:
        is_alive = false
        died.emit()

# 外部入口（治疗药水 / 即时疗法）
func heal(amount: float) -> void:
    var ctx := DamageContext.new()
    ctx.target = get_parent()
    ctx.is_heal = true
    ctx.raw_amount = amount
    ctx.amount = amount
    if pipeline: pipeline.process(ctx)
```

### 7.2 HitBoxComponent — 攻击侧入口

```gdscript
# Core/Components/HitBoxComponent.gd
@export var damage: Damage   # Damage 资源含 amount + tags + effects: Array[BuffEntity]

func _on_area_entered(hurtbox: Area2D) -> void:
    var attacker: Node = get_owner()
    var victim: Node = hurtbox.get_owner()
    var pipe: DamagePipeline = victim.get_node_or_null(^"DamagePipeline") if victim else null
    if not pipe: return

    var ctx := DamageContext.new()
    ctx.source = attacker
    ctx.target = victim
    ctx.raw_amount = damage.amount
    ctx.amount = damage.amount
    ctx.attached_buffs = damage.effects.duplicate()
    ctx.source_pos = (attacker as Node2D).global_position
    ctx.tags = damage.tags

    # 攻击者侧 outgoing 倍率（自检 BC）
    var atk_bc: BuffController = attacker.get_node_or_null(^"BuffController")
    if atk_bc and (ctx.tags & DamageTags.TRUE) == 0:
        ctx.amount *= atk_bc.get_modifier(StatIds.OUTGOING_DAMAGE)

    pipe.process(ctx)
```

### 7.3 AgentAIBase — react 阶段订阅

```gdscript
# Core/AI/AgentAIBase.gd（关键改动）
@onready var pipeline: DamagePipeline = $DamagePipeline
@onready var status: StatusController = $StatusController

func _setup_signals() -> void:
    pipeline.react.connect(_on_pipeline_react)
    health_comp.died.connect(_on_died)
    status.legal_actions_changed.connect(_on_legal_actions_changed)

func _on_pipeline_react(ctx: DamageContext) -> void:
    if ctx.blocked: return
    if ctx.target != self: return
    if ctx.is_heal: return
    if ctx.tags & DamageTags.DOT: return    # DoT 不进 HitState
    
    var bb := ai.blackboard
    bb.set_var(&"last_damage_amount", ctx.dealt)
    bb.set_var(&"last_attacker_pos", ctx.source_pos)
    bb.set_var(&"recently_hit", true)
    _hit_clear_timer = HIT_CLEAR_DELAY
    _damage_log.append([Time.get_ticks_msec() / 1000.0, ctx.dealt])
    _update_damage_recent()
    ai.dispatch(AIEvents.EV_DAMAGED)

func _on_legal_actions_changed(prev: int, new: int) -> void:
    var lost := prev & ~new
    var gained := new & ~prev
    if lost & LegalAction.ATTACK and ai.current_skill:
        ai.dispatch(AIEvents.EV_INTERRUPTED)
    if (gained & LegalAction.ATTACK) and prev != LegalAction.ALL:
        ai.dispatch(AIEvents.EV_RECOVERED)

func _on_died() -> void:
    var bc: BuffController = $BuffController
    if bc: bc.clear_all()
    ai.dispatch(AIEvents.EV_DIED)
```

### 7.4 HitState — react 阶段入场

HitState 不直接订阅 pipeline——由 AAB 统一接收 react，dispatch EV_DAMAGED 让状态机切到 HitState。HitState 的 enter 逻辑只查 BuffController.get_top_hit_buff（与 v1 同）。

```gdscript
# Core/AI/Stock/HitState.gd（重写）
extends AIState

@export var default_duration: float = 0.3
@export var hit_animations: Dictionary = {
    &"":          &"hit",
    &"stun":      &"hit",
    &"knockback": &"hit",
    &"knockup":   &"hit_air",
}

var _timer: Timer

func _init() -> void: reentrant = true

func enter() -> void:
    if owner_node is CharacterBody2D:
        (owner_node as CharacterBody2D).velocity = Vector2.ZERO
    var bc: BuffController = owner_node.get_node_or_null(^"BuffController")
    var top: BuffEntity = bc.get_top_hit_buff() if bc else null
    var anim: StringName = hit_animations.get(top.hit_reaction if top else &"", &"hit")
    if owner_node.anim_player.has_animation(anim):
        owner_node.anim_player.play(anim)
        owner_node.anim_player.seek(0.0, true)
    var dur: float = top.hit_lock_duration if (top and top.hit_lock_duration > 0) else default_duration
    _ensure_timer()
    _timer.wait_time = dur
    _timer.start()

func physics_update(delta: float) -> void:
    if owner_node is CharacterBody2D:
        var b := owner_node as CharacterBody2D
        b.velocity = b.velocity.lerp(Vector2.ZERO, 8.0 * delta)

func exit() -> void:
    if _timer: _timer.stop()
    bb.set_var(&"recently_hit", false)
```

---

## 8. 7 个场景完整时序

### 8.1 普通攻击

```
[player.HitBox] → ctx 套 OUTGOING → bk.pipeline.process(ctx)
  pre_calc:    bc 套 INCOMING (×0.5 防御 buff)
  pre_apply:   status 检查 HURTABLE → pass
  apply:       hc 提交 HP → emit health_changed
  post_apply:  bc 入栈 attached_buffs (无)；ON_DAMAGED 触发反推/反伤
  react:       AAB dispatch EV_DAMAGED → HitState.enter
```

### 8.2 中毒 DoT

```
攻击命中后，bc 通过 post_apply 入栈 PoisonBuff
PoisonBuff.effects = [DamageEffectBuff(amount=5, tick_interval=0.5,
                       damage_tags=DOT|MAGICAL, effect_on=TICK)]
BuffController._physics_process 每 0.5s:
  DamageEffectBuff.execute → 构 ctx.is_heal=false, ctx.tags|=DOT → pipe.process(ctx)
  pre_calc:    bc 套 INCOMING (×0.5)  ← DoT 也享受防御
  apply:       hc 扣 5*0.5=2.5
  react:       AAB 检查 ctx.tags & DOT → 提前 return（不 dispatch）
```

### 8.3 虚弱 debuff

```
WeaknessBuff.effects = [StatModEffect(OUTGOING_DAMAGE, 0.5, effect_on=APPLY|EXPIRE)]
APPLY:  bc.add_stat_modifier(OUTGOING_DAMAGE, 0.5)
EXPIRE: bc.remove_stat_modifier(OUTGOING_DAMAGE, 0.5)
BK 攻击时 HitBox 套 attacker_bc.get_modifier(OUTGOING) → 0.5 倍输出
```

### 8.4 治疗（即时 + HoT）

```
即时：HC.heal(50) 直接构 ctx.is_heal=true → pipeline
HoT：HoTBuff.effects = [HealEffectBuff(amount=5, tick_interval=1.0, effect_on=TICK)]
  TICK 时构 ctx.is_heal=true → pipe.process
  pre_calc: bc 套 HEAL_RECEIVED
  apply:    hc.health += ctx.amount
  react:    AAB 检查 is_heal → return
```

### 8.5 闪避（i-frames + 主动决策）

```gdscript
# AI 主动闪避决策（BK / DS2 高压闪避）
func should_dodge() -> bool:
    return (bb.get_var("damage_recent", 0.0) >= 50.0
            and bb.get_var("dodge_cooldown", 0.0) <= 0.0
            and status.can_be_hit())

# DodgeState.enter
func enter() -> void:
    play("dodge")
    status.apply_lock(LegalAction.HURTABLE, 0.4)   # i-frames 0.4s
    velocity = -target_dir * dodge_speed
    bb.set_var("dodge_cooldown", 2.0)
# 0.4s 后 HURTABLE bit 自动恢复，legal_actions_changed → EV_RECOVERED → 回 chase
# 闪避期间被命中：pipeline.pre_apply → status.on_pre_apply → ctx.blocked
```

### 8.6 弹开（受击反推 player）

```
ReactivePushBuff.effects = [
    KnockBackEffectBuff(force=400, effect_on=ON_DAMAGED)
]
BC.on_post_apply(ctx) 时遍历 active：
  effect.effect_on & ON_DAMAGED → execute(ctx)
  → ctx.target = ctx.damage_ctx.source（即 player）
  → 推开方向 = (player.pos - bk.pos).normalized() * force
```

### 8.7 防御 buff（伤害减半 3s）

```
DefenseBuff.duration = 3.0, stacking = REFRESH
DefenseBuff.effects = [StatModEffect(INCOMING_DAMAGE, 0.5, effect_on=APPLY|EXPIRE)]
APPLY:  bc.add_stat_modifier(INCOMING, 0.5)
EXPIRE: bc.remove_stat_modifier(INCOMING, 0.5)
受击 pipeline.pre_calc 自动套 0.5 倍
```

---

## 9. AgentAI 决策层集成

### 9.1 BladeKeeper 转换表（v2）

```gdscript
# Scenes/Characters/Bosses/BladeKeeper/BK.gd
func _setup_transitions() -> void:
    _register_rules([
        # 行为锁优先级最高
        ["*",      "stun",   "ev_stunned",     "",            10],
        # 受击 → HitState（reactive 层）
        ["*",      "hit",    "ev_damaged",     "can_be_hit",  9],
        # 死亡
        ["*",      "die",    "ev_died",        "",            10],
        # 主动闪避（damage_recent 高时）
        ["chase",  "dodge",  "",                "should_dodge", 5],
        ["attack", "dodge",  "",                "should_dodge", 5],
        # 攻击启动（无锁）
        ["chase",  "attack", "",                "can_attack",   3],
        # 防御 buff 自施（HP < 50%）
        ["chase",  "defend_cast", "",           "should_defend", 4],
    ])

func can_be_hit() -> bool: return $StatusController.can_be_hit()
func can_attack() -> bool: return $StatusController.can_attack()
func should_dodge() -> bool:
    var bb = ai.blackboard
    return (bb.get_var("damage_recent", 0.0) >= 50.0
            and bb.get_var("dodge_cooldown", 0.0) <= 0.0
            and $StatusController.can_be_hit())
func should_defend() -> bool:
    return health_comp.health / health_comp.max_health < 0.5
```

### 9.2 自施 buff（GenericAttackState 增强）

```gdscript
# Core/AI/Stock/GenericAttackState.gd
## 动画 method call：从 skill.params.self_buff 读 BuffEntity 应用到自身
func apply_skill_self_buff() -> void:
    var skill: Skill = ai.current_skill
    if not skill: return
    var buff: BuffEntity = skill.params.get(&"self_buff", null)
    if not buff: return
    var bc: BuffController = owner_node.get_node_or_null(^"BuffController")
    if bc: bc.apply(buff, owner_node, owner_node.global_position)
```

```
# bk_defend_cast.tres（Skill）
state = "generic_attack"
params = {
    "animation": "buff_cast",
    "self_buff": ExtResource("res://Core/Buffs/library/bk_defense_x05_3s.tres")
}
```

---

## 10. Stacking 三策略

| 策略 | 同 id 已存在时 | APPLY hook | EXPIRE hook | 适用 |
|---|---|---|---|---|
| `REFRESH` | 仅刷 remaining；保留旧实例 | **不重入** | 仅 expire 时一次 | 大多数 debuff |
| `STACK` | 新增独立 BuffInstance；多实例并存（gen_id 区分） | 每次新增都调 | 各自 expire | 叠层 DoT、护盾 |
| `REPLACE` | 旧实例先 expire；新实例 apply | 新实例 apply | 旧实例先 expire | 不同强度同类（弱毒→强毒） |

---

## 11. 多攻击者并行正确性

Godot 单线程同步派发，所有 area_entered 在物理 step 后依次同步处理。5 个保证点：

| # | 风险 | 解决方案 |
|---|---|---|
| 1 | 共享 .tres state 污染 | runtime state 全在 BuffInstance；BuffEntity / BuffEffect 永远 immutable |
| 2 | KnockBack 后 Stun 覆盖 velocity | velocity "后来者覆盖" 是物理预期；动画用 hit_priority 选最强 |
| 3 | REFRESH 时 APPLY 重入 | REFRESH 仅刷 remaining，不重入 APPLY |
| 4 | 死亡后 DoT 还在 tick | died → BC.clear_all；HC._commit 先查 is_alive |
| 5 | 同帧多 emit health_changed | OK：HealthBar 取最后值；过程值同帧不可见 |

### 11.1 验算：3 个攻击者同帧 + 后续 DoT

```
T=0.0 Frame N (BK initial HP=100):
  玩家A 击退攻击 (Damage{20, [KnockBackBuff]}):
    pipe.process: pre_calc(×0.5) → amount=10 → apply: HP 100→90
    post_apply: bc.apply(KnockBackBuff)（APPLY 时 set velocity）
    react: AAB.dispatch(EV_DAMAGED) → HitState.enter

  玩家B 中毒攻击 (Damage{15, [PoisonBuff_5/0.5s_8s]}):
    pipe.process: pre_calc(×0.5) → amount=7.5 → apply: HP 90→82.5
    post_apply: bc.apply(PoisonBuff)
    react: HitState 重入（reentrant）→ timer 重置

  玩家C 击飞攻击 (Damage{10, [KnockUpBuff(prio=2)]}):
    pipe.process: pre_calc(×0.5) → amount=5 → apply: HP 82.5→77.5
    post_apply: bc.apply(KnockUpBuff)
    react: HitState.enter → 重新查 top_hit_buff → KnockUp 胜 → 播 hit_air

Frame N 末: HP=77.5, buffs=[KnockBack, Poison, KnockUp], 状态=HitState
HealthBar: 77.5%（最终 emit 的值）

T=0.5: PoisonBuff.TICK → DamageEffectBuff 构 ctx (tags|=DOT)
       pipe: pre_calc(×0.5) → 2.5 → apply: HP 77.5→75
       react: AAB 检查 tags&DOT → return（不进 HitState）
T=1.0: PoisonBuff.TICK → HP 72.5
... 每 0.5s 减 2.5（含防御减伤）
T=8.5: PoisonBuff EXPIRE → bc 移除 inst → buffs_changed
```

---

## 12. HealthBar 实时性

| 场景 | 触发 | 时序 |
|---|---|---|
| 受击 / DoT / 真伤 | HC._commit 末 emit health_changed | 同帧即时 |
| 即时治疗 / HoT | 同上 | 同帧即时 |
| Buff apply / expire | **不**触发（HP 不变） | 正确 |
| 死亡 | HP→0 → emit health_changed → emit died | HealthBar 归零再触发死亡 UI |

HealthBar 端无需改动：
```gdscript
health_comp.health_changed.connect(func(cur, max_v):
    progress_bar.max_value = max_v
    progress_bar.value = cur)
```

---

## 13. 边界情况

| 情形 | 行为 |
|---|---|
| pipeline 缺失 | HC.heal 静默无效；HitBox 跳过 process |
| BC 缺失 | get_modifier 默认 1.0；attached_buffs 静默丢失 |
| StatusController 缺失 | 所有伤害命中（无 HURTABLE 校验）；AI guard 默认 true |
| ctx.target ≠ owner_node | 各订阅者早退（防订阅级联） |
| Damage.effects 含 null | apply 时 `if buff:` 跳过 |
| BuffEntity.id 为空 | REFRESH/REPLACE 退化为 STACK |
| Duration < 0 | 永久（需 manual remove） |
| TICK 在 die 期间 | HC._commit is_alive 早退，无副作用 |
| 同 .tres 多角色 | 各自独立 BuffInstance |
| TRUE 真伤 | INCOMING_DAMAGE 不套；HURTABLE 仍校验（无敌时仍免疫） |

---

## 14. 改动清单

### 14.1 新增

**`Core/Damage/`**
| 文件 | 估行 |
|---|---|
| `DamageContext.gd` | ~25 |
| `DamagePipeline.gd` | ~25 |
| `DamageTags.gd` | ~10 |

**`Core/Buffs/`**
| 文件 | 估行 |
|---|---|
| `BuffEntity.gd` | ~35 |
| `BuffEffect.gd` | ~20 |
| `BuffEffectContext.gd` | ~10 |
| `BuffInstance.gd` | ~15 |
| `BuffController.gd` | ~180 |
| `StatIds.gd` | ~10 |
| `effects/StatModEffect.gd` | ~15 |
| `effects/DamageEffectBuff.gd` | ~25 |
| `effects/HealEffectBuff.gd` | ~20 |
| `effects/KnockBackEffectBuff.gd` | ~20 |
| `effects/KnockUpEffectBuff.gd` | ~20 |
| `library/*.tres` | ~10 个预设 |

**`Core/Status/`**
| 文件 | 估行 |
|---|---|
| `LegalAction.gd` | ~25 |
| `StatusController.gd` | ~100 |

### 14.2 改写

| 文件 | 改动 |
|---|---|
| [HealthComponent.gd](../../../Core/Components/HealthComponent.gd) | 重写：仅订阅 pipeline.apply；删 take_damage / heal 现行逻辑 |
| [HitBoxComponent.gd](../../../Core/Components/HitBoxComponent.gd) | _on_area_entered 构 DamageContext + pipeline.process |
| [Damage.gd](../../../Core/Resources/Damage.gd) | `effects: Array[BuffEntity]` + `tags: int`（DamageTags bitmask） |
| [AgentAIBase.gd](../../../Core/AI/AgentAIBase.gd) | _setup_signals 接 pipeline.react / status.legal_actions_changed |
| [Stock/HitState.gd](../../../Core/AI/Stock/HitState.gd) | 重写为查询型（删 effect apply） |
| [CommonStates/HitState.gd](../../../Core/StateMachine/CommonStates/HitState.gd) | 同步重写（玩家用） |
| [GenericAttackState.gd](../../../Core/AI/Stock/GenericAttackState.gd) | 加 apply_skill_self_buff |

### 14.3 全删

- `Core/Resources/AttackEffect.gd`
- `Core/Resources/StunEffect.gd`
- `Core/Resources/ForceStunEffect.gd`
- `Core/Resources/KnockBackEffect.gd`
- `Core/Resources/KnockUpEffect.gd`
- `Core/Resources/GatherEffect.gd`
- `test/unit/test_attack_effects.gd`

### 14.4 .tscn 挂载

每个角色场景（Player + 4 Boss + Enemy 模板）新增 4 个子节点：
- `DamagePipeline`
- `BuffController`
- `StatusController`
- `HealthComponent`（已有，保留）

### 14.5 .tres 数据迁移

9 个 Damage .tres 重连 effects 字段：
- `Core/Data/SkillBook/SpecialAttack.tres`
- `Core/Data/SkillBook/KnockUp.tres`
- `Core/Data/SkillBook/Physical.tres`
- `Scenes/Characters/Bosses/Cyclops/Resources/BossProjectileDamage.tres`
- 3 × BK combo skill .tres
- 1 × DS2 combo skill .tres

---

## 15. 测试策略

### 15.1 单测

| 测试 | 覆盖 |
|---|---|
| `test_damage_pipeline.gd` | 5 阶段顺序；blocked 短路；is_heal 路径 |
| `test_buff_controller.gd` | apply/tick/expire；REFRESH/STACK/REPLACE；BuffInstance 隔离 |
| `test_buff_effect_on.gd` | EffectOn bitmask 多时机触发；tick_interval 精度 |
| `test_stat_modifier.gd` | get_modifier 多 buff 乘法；APPLY/EXPIRE 进出账配对 |
| `test_status_controller.gd` | LegalAction bitmask 聚合；longest wins；buff 锁 + 主动锁混合 |
| `test_dot_pipeline.gd` | DoT 走 pipeline；DOT 标签跳过 react；防御 buff 减免 DoT |
| `test_heal_pipeline.gd` | HoT 走 pipeline；HEAL_RECEIVED 套用；is_heal 跳过 react |
| `test_callback_effects.gd` | ON_DAMAGED 反推 / 反伤 |
| `test_dodge_iframes.gd` | HURTABLE 关闭 → ctx.blocked → HP 不扣；倒计时归零 → 自动恢复 |
| `test_buff_lifecycle_on_death.gd` | died → clear_all → EXPIRE 全调用 + 锁清理 |

### 15.2 手动场景

1. **BK 防御 buff**：连续受击伤害减半
2. **多攻击者并行**：3 个 attacker 同帧 → 验最终 HP + buff 列表
3. **DoT 边界**：中毒到死，HP 与 buff 表干净
4. **闪避 i-frames**：DodgeState 期间命中无效
5. **反推 callback**：BK 受击瞬间 player 后退
6. **行为锁聚合**：StunBuff + 主动 lock 同时生效

---

## 16. BK 单点 PoC（Phase 1）

### 16.1 验证目标
基于 `Scenes/Levels/Level_BladeKeeper/LevelBladeKeeper.tscn` 跑通完整管线，验证：

- HC 与 BC 解耦
- 防御 buff (StatModEffect) 正确减伤
- HoT (HealEffectBuff) 自疗 HP 上涨
- DoT (DamageEffectBuff) 中毒持续掉血 + 不进 HitState
- 闪避 i-frames（StatusController.HURTABLE）
- 反推 callback effect（ON_DAMAGED）
- AI guard 经 status.can_attack 正确响应锁定

### 16.2 改动范围（BK only）
- 新建 `Core/Damage/`、`Core/Buffs/`、`Core/Status/` 全套基础
- BK.tscn 挂 4 个新节点
- BK 旧 `apply_defense_buff` / `heal_self` 占位 → .tres 配 BuffEntity
- Player.tscn 也需挂相同 4 节点（伤害是双向流）
- 旧 AttackEffect 留着不删（避免破坏 Cyclops/DS2）

### 16.3 验收
- BK 战斗：防御 buff 生效（伤害减半）、自疗生效（HP 涨）
- 玩家中毒（玩 BK skill 加中毒）→ 持续掉血、不进 HitState
- BK 闪避：DodgeState 期间无敌；恢复后正常受击
- BK 反推：受击瞬间 player 后退
- 多攻击者并行（3 个测试 attacker）：HP 与 buff 列表正确

## 17. Phase 2 全面铺开（PoC 通过后）

- 改造 Cyclops / DemonSlime2 → 替换 AttackEffect 引用
- 改造剩余 Enemy 模板
- 全删旧 AttackEffect 五子类
- 数据迁移：9 个 Damage .tres 重指 buff 资源
- HealthBar 信号验证
- AI guard 全部走 status.can_*

---

## 18. 工作量估算

| 阶段 | 工时 |
|---|---|
| Phase 0：管线骨架（DamagePipeline + HC 重写 + DamageContext） | 0.5 天 |
| Phase 1：BC + BuffEffect + StatusController | 1 天 |
| Phase 2：5 个 BuffEffect 子类（StatMod/Damage/Heal/KnockBack/KnockUp） | 0.5 天 |
| Phase 3：BK 单点 PoC（含 AAB / HitState / GenericAttackState 接线） | 1 天 |
| Phase 4：单测 10 套 | 1 天 |
| Phase 5：Cyclops / DS2 / Enemy 全面铺开 + .tres 迁移 | 1 天 |
| **合计** | **5 天** |

---

## 19. 范围外（YAGNI）

| 项 | 推迟原因 |
|---|---|
| Max HP 修改型 buff | 涉及"过期是否同步降 HP"策略，需求来时再设计 |
| 加法型 modifier | 当前需求全是百分比，乘法够用 |
| 元素抗性表（火/冰/物理） | tags 字段已铺好，处理逻辑后做 |
| Buff icon UI / `buffs_changed` 接 HUD | 信号已铺好，HUD 下迭代 |
| Save/Load buff 状态 | 战斗内 buff，关卡切换全清 |
| Multi-target buff (Aura) | 当前需求未出现 |
| Dispel system | tags 字段已铺好，dispel 逻辑后做 |

---

## 20. 验收标准

- 所有单测通过
- BK 战斗 PoC 全场景验证通过（§16.3）
- Cyclops / DS2 / Enemy 全面铺开后零回归
- HealthBar：每次 HP 变化（受击 / DoT / heal）即时反映
- 死亡时 BC.active / status._action_timers 自动清空
- AAB / HitState 不再直接引用 HealthComponent.is_invincible 或 BuffComponent.apply
- AttackEffect 五子类 + test_attack_effects.gd 全删，git status 干净
- 与新 AgentAI 框架（[AgentAIBase.gd](../../../Core/AI/AgentAIBase.gd)）零回归
