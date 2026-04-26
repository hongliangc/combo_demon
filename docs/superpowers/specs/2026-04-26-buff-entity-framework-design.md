# BuffEntity 框架设计 — 持续状态、伤害链与并行正确性

**日期**：2026-04-26
**前置依赖**：
- [Skill 系统设计](2026-04-16-skill-system-design.md) 已实现并通过 CR
- [BladeKeeper 迁移设计](2026-04-18-bladekeeper-migration-design.md) 中 §6 BuffEntity 路线图（本设计**取代**该路线图，BK 直接落地终态）

**适用范围**：项目级通用持续状态框架。BK / Cyclops / 玩家 / Enemy 全部走同一条管线。

---

## 1. 设计目标

| 目标 | 落地手段 |
|---|---|
| 框架实用、简单 | 三层职责分离 + StatModifier 通用聚合 + 数据驱动配置 |
| 逻辑分层清晰、不耦合 | 单向依赖：HitState → BuffComponent → BuffEntity |
| 不兼容存量代码 | AttackEffect 五子类全删，Damage.effects 类型重定向到 BuffEntity |
| 与新 AgentAI 框架完美融合 | buff 应用挂在 `AgentAIBase._on_agent_damaged` 事件入口 |
| 可扩展（DoT/HoT/Buff/Debuff） | StatModifier 通用化 + tick 钩子 + immutable resource |
| 取消 BK 迁移占位方案 | BK 防御 buff / heal 直接配 .tres，无 `apply_defense_buff` / `heal_self` 占位方法 |

---

## 2. 三层架构

```
┌─ Layer 1 ── BuffEntity (Resource, immutable) ─ 数据 ───┐
│  纯配置：id / duration / stacking / 行为锁 / hit 语义   │
│  跨角色/跨实例零状态污染                                 │
└────────────────────────────────────────────────────────┘
                       ↓ apply
┌─ Layer 2 ── BuffComponent (Node) ─ 生命周期 ───────────┐
│  active: Array[BuffInstance]                          │
│  apply / tick / expire / stacking 决策                 │
│  自动写 owner.stunned / can_move（声明式行为锁）        │
│  聚合查询：get_modifier / get_top_hit_buff             │
│  监听 owner died → clear_all                          │
│  signal: buffs_changed                                │
└────────────────────────────────────────────────────────┘
                       ↑ 查询
┌─ Layer 3 ── HitState / HealthComponent / HitBox ─ 表现/集成 ┐
│  HitState: 查 top_hit_buff → 选动画 → timer            │
│  HealthComponent.take_damage: 套 INCOMING_DAMAGE 倍率  │
│  HealthComponent.heal: 套 HEAL_RECEIVED 倍率           │
│  HitBox.update_attack: 套 OUTGOING_DAMAGE 倍率         │
└────────────────────────────────────────────────────────┘
```

**单向依赖** 保证每层可独立测试，且 BuffEntity（Layer 1）对 Layer 2/3 一无所知。

---

## 3. 数据层 — BuffEntity

### 3.1 基类

```gdscript
# Core/Buffs/BuffEntity.gd
class_name BuffEntity extends Resource

enum Stacking { REFRESH, STACK, REPLACE }

@export var id: StringName                           # 唯一标识，stacking 合并依据
@export var duration: float = 0.0                    # 0 = 永久；DoT 用 0+ 配 tick_interval
@export var stacking: Stacking = Stacking.REFRESH

# 行为锁声明（BuffComponent 自动 set/clear 这些字段）
@export var locks_actions: bool = false              # → owner.stunned
@export var locks_movement: bool = false             # → owner.can_move = false
@export var grants_invincibility: bool = false       # → health_comp.is_invincible（闪避 i-frames）

# Hit 表现语义（被攻击触发时使用；自施 buff 留空）
@export var hit_reaction: StringName = &""           # &""/&"stun"/&"knockback"/&"knockup"
@export var hit_priority: int = 0                    # 多 buff 同时存在时排序
@export var hit_lock_duration: float = 0.0           # HitState 锁定时间，0 = 用 default

# 子类钩子（接收 instance，避免污染共享 resource）
func on_apply(target: Node, instance: BuffInstance) -> void: pass
func on_tick(target: Node, instance: BuffInstance, dt: float) -> void: pass
func on_expire(target: Node, instance: BuffInstance) -> void: pass
```

### 3.2 子类清单

| 类 | 用途 | 关键字段 | 是否需要 .gd |
|---|---|---|---|
| `StatModifierBuff` | 防御/易伤/虚弱/治疗效率 | `stat_id`, `multiplier` | 是（薄） |
| `KnockBackBuff` | 击退（设 velocity） | `force` | 是 |
| `KnockUpBuff` | 击飞 | `force` | 是 |
| `StunBuff` | 纯眩晕 | — | **否**（仅 .tres：`locks_actions=true` + `hit_reaction=&"stun"`） |
| `ForceStunBuff` | 强眩晕（更高 hit_priority） | — | 否 |
| `GatherBuff` | 拖拽（tick 改位置） | `target_pos`, `speed` | 是 |
| `DamageOverTimeBuff` | 中毒/灼烧 | `damage_per_tick`, `tick_interval`, `damage_template` | 是 |
| `HealOverTimeBuff` | 持续回血 / 即时治疗 | `heal_per_tick`, `tick_interval` | 是 |

### 3.3 Stat ID 常量集中

```gdscript
# Core/Buffs/StatIds.gd
class_name StatIds
const INCOMING_DAMAGE := &"incoming_damage"   # 防御 / 易伤
const OUTGOING_DAMAGE := &"outgoing_damage"   # 攻击力 / 虚弱
const HEAL_RECEIVED   := &"heal_received"     # 治疗效率 / 重伤
```

防止字符串拼写错。后续新 stat 加常量即可，无需改框架。

---

## 4. 生命周期层 — BuffComponent

### 4.1 BuffInstance（runtime state，独立 class_name）

**关键设计**：BuffEntity 是共享 Resource（immutable），所有 mutable runtime 状态放在独立的 `BuffInstance`。这避免同一 .tres 给多个角色用时的状态污染。

> **注意**：BuffInstance 必须是独立 `class_name` 文件，**不能**写成 BuffComponent 的内部类——否则 BuffEntity.on_apply 签名引用 BuffInstance 时类型不可解析。

```gdscript
# Core/Buffs/BuffInstance.gd
class_name BuffInstance extends RefCounted

var buff: BuffEntity         # immutable 配置（跨实例共享）
var remaining: float         # per-instance 剩余时长
var tick_accum: float = 0.0  # per-instance tick 累积
var stacks: int = 1          # STACK 模式层数
var source_pos: Vector2      # 应用源位置（计算击退方向用）
```

### 4.2 BuffComponent 完整接口

```gdscript
# Core/Buffs/BuffComponent.gd
class_name BuffComponent extends Node

signal buffs_changed

@onready var owner_node: Node = get_parent()
@onready var _health: HealthComponent = owner_node.get_node_or_null(^"HealthComponent")
var active: Array[BuffInstance] = []

func _ready():
    if _health: _health.died.connect(_on_owner_died)

# ---- 应用 ----
func apply(buff: BuffEntity, source_pos: Vector2 = Vector2.ZERO) -> void:
    match buff.stacking:
        BuffEntity.Stacking.REFRESH:
            var existing := _find_by_id(buff.id)
            if existing:
                existing.remaining = buff.duration
                return                                    # 不重入 on_apply
        BuffEntity.Stacking.REPLACE:
            var existing := _find_by_id(buff.id)
            if existing:
                buff.on_expire(owner_node, existing)
                _clear_locks_of(existing)
                active.erase(existing)
        BuffEntity.Stacking.STACK:
            pass                                          # 总是新增

    var inst := BuffInstance.new()
    inst.buff = buff
    inst.remaining = buff.duration
    inst.source_pos = source_pos
    active.append(inst)
    _apply_locks_of(inst)
    buff.on_apply(owner_node, inst)
    buffs_changed.emit()

# ---- 主循环 ----
func _physics_process(delta: float) -> void:
    var i := active.size() - 1
    while i >= 0:
        var inst := active[i]
        inst.buff.on_tick(owner_node, inst, delta)
        if inst.buff.duration > 0:
            inst.remaining -= delta
            if inst.remaining <= 0:
                inst.buff.on_expire(owner_node, inst)
                _clear_locks_of(inst)
                active.remove_at(i)
                buffs_changed.emit()
        i -= 1

# ---- 聚合查询（HealthComponent / HitBox 用）----
func get_modifier(stat_id: StringName, default: float = 1.0) -> float:
    var result := default
    for inst in active:
        if inst.buff is StatModifierBuff and inst.buff.stat_id == stat_id:
            result *= inst.buff.multiplier
    return result

# ---- HitState 用 ----
func get_top_hit_buff() -> BuffEntity:
    var top: BuffInstance = null
    for inst in active:
        if inst.buff.hit_reaction == &"": continue
        if top == null or inst.buff.hit_priority > top.buff.hit_priority:
            top = inst
    return top.buff if top else null

# ---- 死亡清理 ----
func _on_owner_died() -> void:
    for inst in active:
        inst.buff.on_expire(owner_node, inst)
        _clear_locks_of(inst)
    active.clear()
    buffs_changed.emit()

# ---- 行为锁聚合（多 buff 锁定时取并集）----
func _apply_locks_of(inst: BuffInstance) -> void:
    if inst.buff.locks_actions and "stunned" in owner_node:
        owner_node.stunned = true
    if inst.buff.locks_movement and "can_move" in owner_node:
        owner_node.can_move = false
    if inst.buff.grants_invincibility and _health:
        _health.is_invincible = true

func _clear_locks_of(inst: BuffInstance) -> void:
    if inst.buff.locks_actions and "stunned" in owner_node:
        owner_node.stunned = _any_locks(&"locks_actions")
    if inst.buff.locks_movement and "can_move" in owner_node:
        owner_node.can_move = not _any_locks(&"locks_movement")
    if inst.buff.grants_invincibility and _health:
        _health.is_invincible = _any_locks(&"grants_invincibility")

func _any_locks(field: StringName) -> bool:
    for inst in active:
        if inst.buff.get(field): return true
    return false

func _find_by_id(id: StringName) -> BuffInstance:
    for inst in active:
        if inst.buff.id == id: return inst
    return null
```

---

## 5. 表现层 — HitState（新 AI 框架版）

### 5.1 重写后的 Stock HitState

```gdscript
# Core/AI/Stock/HitState.gd（重写）
extends AIState

@export var default_duration: float = 0.3
## hit_reaction → 角色动画名（每个角色场景里配置）
@export var hit_animations: Dictionary = {
    &"":          &"hit",
    &"stun":      &"hit",
    &"knockback": &"hit",
    &"knockup":   &"hit_air",
}

var _timer: Timer

func _init(): reentrant = true                       # 同帧多次受击重入

func enter() -> void:
    if owner_node is CharacterBody2D:
        (owner_node as CharacterBody2D).velocity = Vector2.ZERO

    var buffs: BuffComponent = owner_node.get_node_or_null(^"BuffComponent")
    var top: BuffEntity = buffs.get_top_hit_buff() if buffs else null

    var anim: StringName = hit_animations.get(top.hit_reaction if top else &"", &"hit")
    if owner_node.anim_player.has_animation(anim):
        owner_node.anim_player.play(anim)
        owner_node.anim_player.seek(0.0, true)

    var dur: float = top.hit_lock_duration if (top and top.hit_lock_duration > 0) else default_duration
    _ensure_timer()
    _timer.wait_time = dur
    _timer.start()

func physics_update(delta):
    if owner_node is CharacterBody2D:
        var b := owner_node as CharacterBody2D
        b.velocity = b.velocity.lerp(Vector2.ZERO, 8.0 * delta)

func exit():
    if _timer: _timer.stop()
    bb.set_var(&"recently_hit", false)
```

### 5.2 关键变化

- HitState 不再 apply effects（已上移到 AgentAIBase）
- 没有任何 `if buff is StunBuff` 之类硬编码分类
- 加新 hit_reaction 类型：只改 `hit_animations` 映射 + 配新 .tres，HitState 一字符不动

---

## 6. AgentAI 融合 — 关键集成点

### 6.1 AgentAIBase 不需改动

Buff 应用统一挂在 `HealthComponent.take_damage`（见 §7.2），玩家与 AI 走同一管线。AgentAIBase 的 `_on_agent_damaged` 保持原状，只负责更新 blackboard + dispatch 事件。

### 6.2 Buff 应用入口的设计权衡

放在 `HealthComponent.take_damage` 而非 HitState / AgentAIBase 的理由：

| 风险 | 放 HitState | 放 HealthComponent |
|---|---|---|
| AI dispatch gate 拦截（un-interruptible 技能）| DoT/debuff 丢失 | ✓ 不受影响 |
| DoT 内部 take_damage 不进 HitState | 嵌套 effects 永不应用 | ✓ 内部 trigger=false 自然控制 |
| 致死攻击 EV_DIED 抢占 EV_DAMAGED | 致死攻击的 buff 丢失 | ✓ 死前已 apply |
| 玩家 / AI 路径对称 | 各写一套 | ✓ 一处管线 |

HitState 退化为**纯查询表现层**：查 top_hit_buff → 选动画 → timer。

### 6.3 自施 buff（GenericAttackState 增强）

技能动画 method track 触发：

```gdscript
# Core/AI/Stock/GenericAttackState.gd
## 动画 method call：从 skill.params.self_buff 读 BuffEntity 应用到自身
func apply_skill_self_buff() -> void:
    var skill: Skill = ai.current_skill
    if not skill: return
    var buff: BuffEntity = skill.params.get(&"self_buff", null)
    if not buff: return
    var bc: BuffComponent = owner_node.get_node_or_null(^"BuffComponent")
    if bc: bc.apply(buff, owner_node.global_position)
```

Skill 配置示例：

```
# bk_defend_buff.tres
state = "generic_attack"
params = {
    "animation": "buff_cast",
    "self_buff": ExtResource("res://Core/Buffs/library/bk_defense_x05_3s.tres")
}
```

---

## 7. 完整伤害链路

### 7.1 主路径

```
[攻击者侧] HitBox.update_attack()
    ├─ damage.randomize_damage()                          ← 暴击 roll
    ├─ damage.amount *= attacker.buff.get_modifier(OUTGOING_DAMAGE)  ← 攻击/虚弱
    └─ ✓
[碰撞] HitBox.area_entered → HurtBox.take_damage(damage, attacker_pos)
[受击者侧] HealthComponent.take_damage(damage, attacker_pos, trigger_hit_reaction=true):
    1. is_alive 检查 → 早退（防尸体二次伤害）
    2. is_invincible 检查 → 早退（防 0×0.5 浪费倍率）
    3. raw = damage.amount
    4. mult = buff.get_modifier(INCOMING_DAMAGE, 1.0)     ← 防御/易伤
    5. final = raw * mult
    6. health = clamp(health - final, 0, max_health)
    7. emit health_changed(health, max_health)            ← 血条同步
    8. if trigger_hit_reaction:
       └─ emit damaged(damage, attacker_pos)              ← 触发 HitState
    9. health <= 0 → die() → emit died → BuffComponent.clear_all
[8 触发后] AgentAIBase._on_agent_damaged:
    ├─ buff_comp.apply(damage.effects[*])                 ← buff 入栈
    └─ ai.dispatch(EV_DAMAGED) → HitState.enter
[表现] HitState.enter:
    ├─ buff_comp.get_top_hit_buff() → 选动画
    └─ timer(hit_lock_duration or default)
```

### 7.2 HealthComponent.take_damage 改动

```gdscript
func take_damage(damage: Damage, attacker_pos: Vector2 = Vector2.ZERO,
                 trigger_hit_reaction: bool = true) -> void:
    if not is_alive or is_invincible: return
    var mult: float = _incoming_mult()
    var final_amount: float = damage.amount * mult
    health = clamp(health - final_amount, 0, max_health)
    display_damage_number(damage)
    health_changed.emit(health, max_health)

    if trigger_hit_reaction:
        # 应用 damage 携带的 buff（玩家 / AI / 敌人统一入口）
        var bc: BuffComponent = owner_body.get_node_or_null(^"BuffComponent")
        if bc and damage.effects:
            for buff in damage.effects:
                if buff: bc.apply(buff, attacker_pos)
        damaged.emit(damage, attacker_pos)

    if health <= 0: die()

func _incoming_mult() -> float:
    var bc: BuffComponent = owner_body.get_node_or_null(^"BuffComponent")
    return bc.get_modifier(StatIds.INCOMING_DAMAGE, 1.0) if bc else 1.0
```

**关键**：buff 应用与 `damaged` 信号都在 `trigger_hit_reaction=true` 分支内。DoT 内部调 `take_damage(..., false)` 跳过此分支，避免链式触发。

### 7.3 HitBoxComponent.update_attack 改动

```gdscript
func update_attack() -> void:
    if not damage: return
    damage.randomize_damage()
    # 套 outgoing buff 倍率（攻击者侧）
    var attacker: Node = get_owner()  # HitBox 的 scene owner = CharacterBody2D
    if attacker:
        var bc: BuffComponent = attacker.get_node_or_null(^"BuffComponent")
        if bc:
            damage.amount *= bc.get_modifier(StatIds.OUTGOING_DAMAGE, 1.0)
```

**约定**：HitBox 的 scene owner 必须是 CharacterBody2D（角色根节点）。所有现有 .tscn 已符合此约定（HitBox 是角色子树成员）。Bullet/Projectile 的 HitBox 没有"攻击者 buff"概念，`get_owner()` 返回子弹自身→无 BuffComponent→静默跳过 outgoing 倍率（正确行为）。

---

## 8. 治疗链路

```
[治疗源] BK skill / heal pickup / HoT tick
    ↓
HealthComponent.heal(amount):
    1. is_alive 检查
    2. mult = buff.get_modifier(HEAL_RECEIVED, 1.0)       ← 重伤减疗
    3. health = min(health + amount * mult, max_health)
    4. emit health_changed(health, max_health)            ← 血条同步
    （不发 damaged 信号，不触发任何状态机）
```

```gdscript
func heal(amount: float) -> void:
    if not is_alive: return
    var mult: float = _heal_mult()
    health = min(health + amount * mult, max_health)
    health_changed.emit(health, max_health)

func _heal_mult() -> float:
    var bc: BuffComponent = owner_body.get_node_or_null(^"BuffComponent")
    return bc.get_modifier(StatIds.HEAL_RECEIVED, 1.0) if bc else 1.0
```

`HealOverTimeBuff.on_tick` 调 `hc.heal(heal_per_tick)`，倍率自动套用。

---

## 9. DoT / HoT 详设

### 9.1 DamageOverTimeBuff（中毒/灼烧）

```gdscript
# Core/Buffs/DamageOverTimeBuff.gd
extends BuffEntity
class_name DamageOverTimeBuff

@export var damage_per_tick: float = 5.0
@export var tick_interval: float = 0.5
@export var damage_template: Damage = null   # 可空；非空时携带元素/特效

func on_tick(target: Node, inst: BuffInstance, dt: float) -> void:
    inst.tick_accum += dt
    if inst.tick_accum < tick_interval: return
    inst.tick_accum -= tick_interval

    var hc: HealthComponent = target.get_node_or_null(^"HealthComponent")
    if not hc: return

    var dmg: Damage = damage_template.duplicate() if damage_template else Damage.new()
    dmg.amount = damage_per_tick
    hc.take_damage(dmg, inst.source_pos, false)  # ← 关键：不触发 HitState
```

**关键点**：
- 复用 `take_damage` 自动享受 INCOMING_DAMAGE 倍率（防御 buff 也减免中毒，符合直觉）
- 第三参数 `false` 跳过 `damaged` 信号 → 不锁状态机进 HitState 死循环
- 必须 `duplicate()` 或 `new()` —— 直接修改 `damage_template.amount` 会污染共享 resource（多个角色共用同 .tres 时）。每 tick 一个临时 Damage 对象，GC 成本可忽略

### 9.2 HealOverTimeBuff（同构）

```gdscript
extends BuffEntity
class_name HealOverTimeBuff

@export var heal_per_tick: float = 5.0
@export var tick_interval: float = 0.5

func on_tick(target: Node, inst: BuffInstance, dt: float) -> void:
    inst.tick_accum += dt
    if inst.tick_accum < tick_interval: return
    inst.tick_accum -= tick_interval
    var hc: HealthComponent = target.get_node_or_null(^"HealthComponent")
    if hc: hc.heal(heal_per_tick)
```

即时治疗用 `duration=0` + `tick_interval=0`：第一次 _physics_process 即触发 tick 然后过期。

---

## 10. Stacking 三策略详定

| 策略 | 同 id 已存在时 | on_apply | on_expire | 适用 |
|---|---|---|---|---|
| `REFRESH` | 仅刷新 remaining；保留旧实例 | **不重入** | 仅在 expire 时调一次 | 大多数 debuff（中毒、虚弱） |
| `STACK` | 新增独立 instance；多个并存独立 tick | 每次新增都调 | 每个 instance 各自 expire | 叠层 DoT、堆叠护盾 |
| `REPLACE` | 旧实例先 expire；新实例 apply | 新增时调 | 旧实例先 expire | 不同强度同类（弱毒→强毒） |

**保证**：on_apply 与 on_expire 配对调用次数一致，不重入、不漏 cleanup。

---

## 11. 多攻击者并行正确性

### 11.1 Godot 单线程同步模型

`area_entered` 信号在物理 step 后**依次同步派发**——不存在真并发，问题转化为"依次处理时最终态正确"。

### 11.2 5 个保证点

| # | 风险 | 解决方案 |
|---|---|---|
| 1 | 共享 .tres state 污染 | runtime state 全在 **BuffInstance**，BuffEntity 永远 immutable |
| 2 | KnockBack 后 Stun 覆盖 velocity | velocity "后来者覆盖" 是物理预期；hit 动画用 hit_priority 选最强 |
| 3 | REFRESH 时 on_apply 重入致染色叠加 | REFRESH 仅刷 remaining，不重入 on_apply |
| 4 | 死亡后 DoT 还在 tick | BuffComponent 监听 `died` → `clear_all`；take_damage 也有 is_alive 早退 |
| 5 | 同帧多 emit health_changed | OK：HealthBar 取最后值；过程值同帧不可见 |

### 11.3 验算：3 个攻击者同帧 + 后续 DoT

```
T=0.0 Frame N:
  玩家A 击退攻击 (Damage{20, [KnockBack]}):
    HC.take_damage → 100→80 → emit(80,100) → emit damaged
    AAB._on_agent_damaged → buff.apply(KnockBack) → dispatch EV_DAMAGED
    AI: Chase → HitState.enter（reentrant）→ 播 "hit" 0.3s

  玩家B 中毒攻击 (Damage{15, [PoisonDoT_5/0.5s_8s]}):
    HC.take_damage → 80→65 → emit(65,100) → emit damaged
    AAB._on_agent_damaged → buff.apply(Poison) → dispatch EV_DAMAGED
    AI: HitState.exit → HitState.enter（重入）→ timer 重置

  玩家C 击飞攻击 (Damage{10, [KnockUp(prio=2)]}):
    HC.take_damage → 65→55 → emit(55,100)
    AAB._on_agent_damaged → buff.apply(KnockUp) → dispatch
    AI: HitState.enter → 重新查 top_hit_buff → KnockUp(prio=2) 胜出 → 播 "hit_air"

Frame N 末: health=55, buffs=[KnockBack, Poison, KnockUp], 状态=HitState
HealthBar: 55%（最终 emit 的值）

T=0.5: Poison.on_tick → take_damage(5, ..., trigger=false) → 50 → emit(50,100)
T=1.0: Poison tick → 45
... 每 0.5s 减 5，HealthBar 平滑下降
T=8.5: Poison expire → on_expire → buffs_changed
```

**最终态正确**，每次 emit 一次 health_changed，血条精确反映真实 HP。

### 11.4 不同 buff 共存数学

```
Boss buffs = [Defense_x0.5, Weakness_x1.5_incoming, Poison]
玩家攻击 raw 40:
  outgoing 倍率 = 1.0 (玩家无 debuff)        → 40
  incoming 倍率 = 0.5 × 1.5 = 0.75            → 30
  HP -30

玩家虚弱期间反击：
  outgoing 倍率 = 0.5 (虚弱)                   → 20
  incoming 倍率 = 0.75                          → 15
```

完全可叠加且数学可预测。

---

## 12. HealthBar 实时性保证

| 场景 | 信号触发 | 时序 |
|---|---|---|
| 受击伤害 | `take_damage` 第 7 步 | 同帧即时 |
| DoT tick | `on_tick → take_damage(... false)` 第 7 步 | 最多滞后 tick_interval |
| Heal / HoT | `heal` 末尾 emit | 同帧即时 |
| Buff apply/expire | **不**触发 health_changed（HP 不变） | 正确 |
| 死亡 | die() 前最后一次 emit(0, max) → emit died | 血条归零再触发死亡逻辑 |

**HealthBar 端**（既有代码无需改）：

```gdscript
health_comp.health_changed.connect(func(cur, max_v):
    progress_bar.max_value = max_v
    progress_bar.value = cur)
```

---

## 13. 边界情况与错误处理

| 情形 | 行为 |
|---|---|
| BuffComponent 节点缺失 | get_modifier 返回默认值；buff 应用静默失败 |
| Damage.effects 含 null | apply 时 `if buff:` 跳过 |
| BuffEntity.id 为空 | REFRESH/REPLACE 退化为 STACK 行为（_find_by_id 返回 null） |
| Duration < 0 | 按 0 处理（永久），需要 manual remove |
| on_tick 调 take_damage 在 die 期间 | is_alive 早退，无副作用 |
| BuffComponent 被 free 时仍有 active | _exit_tree 时遍历 on_expire（防资源泄漏） |
| 同一 buff .tres 同时给玩家+Boss | 各自独立 BuffInstance，零干扰 |
| max_health 改变（未来 buff 类型） | 同时 emit health_changed(health, new_max)，HealthBar 自动适配 |

---

## 14. 改动清单

### 14.1 新增（Core/Buffs/）

| 文件 | 估行数 |
|---|---|
| `BuffEntity.gd` | ~30 |
| `BuffInstance.gd` | ~15 |
| `BuffComponent.gd` | ~120 |
| `StatIds.gd` | ~10 |
| `StatModifierBuff.gd` | ~10 |
| `KnockBackBuff.gd` | ~25 |
| `KnockUpBuff.gd` | ~25 |
| `GatherBuff.gd` | ~20 |
| `DamageOverTimeBuff.gd` | ~30 |
| `HealOverTimeBuff.gd` | ~25 |
| `library/*.tres` | ~10 个预设 |

`StunBuff` / `ForceStunBuff` 不需要 .gd（仅 .tres）。

### 14.2 改写

| 文件 | 改动 |
|---|---|
| [AgentAIBase.gd](../../../Core/AI/AgentAIBase.gd) | **不改**（buff 应用在 HealthComponent，AgentAIBase 仅 dispatch） |
| [Stock/HitState.gd](../../../Core/AI/Stock/HitState.gd) | 重写为查询型（删 effect apply） |
| [CommonStates/HitState.gd](../../../Core/StateMachine/CommonStates/HitState.gd) | 同步重写（玩家用） |
| [HealthComponent.gd](../../../Core/Components/HealthComponent.gd) | take_damage 加 mult 查询 + trigger_hit_reaction 参数；heal 加 mult |
| [HitBoxComponent.gd](../../../Core/Components/HitBoxComponent.gd) | update_attack 加 outgoing mult（含 owner 反查） |
| [Damage.gd](../../../Core/Resources/Damage.gd) | `effects: Array[BuffEntity]`；删 `apply_effects`（管线已上移） |
| [GenericAttackState.gd](../../../Core/AI/Stock/GenericAttackState.gd) | 加 `apply_skill_self_buff`（skill.params.self_buff） |

### 14.3 全删（不兼容存量）

- `Core/Resources/AttackEffect.gd`
- `Core/Resources/StunEffect.gd`
- `Core/Resources/ForceStunEffect.gd`
- `Core/Resources/KnockBackEffect.gd`
- `Core/Resources/KnockUpEffect.gd`
- `Core/Resources/GatherEffect.gd`
- `test/unit/test_attack_effects.gd`

### 14.4 .tscn 挂载

8-10 个角色场景（Player + 4 Boss + Enemy 模板）加 `BuffComponent` 子节点。

### 14.5 .tres 数据迁移

9 个 Damage .tres 重连线（Godot 编辑器手动重指 buff 资源）：
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
| `test_buff_component.gd` | apply/tick/expire；REFRESH/STACK/REPLACE 三策略；on_apply/on_expire 调用次数；BuffInstance 隔离 |
| `test_buff_modifier_aggregation.gd` | get_modifier 多 buff 乘法；空 active 返回默认；不同 stat_id 不串扰 |
| `test_damage_over_time.gd` | tick_interval 精度；trigger_hit_reaction=false 不发 damaged 信号；INCOMING_DAMAGE 套用 |
| `test_health_component_buff_integration.gd` | take_damage 套防御；heal 套疗效；连续 emit health_changed 顺序 |
| `test_hit_state_buff_query.gd` | get_top_hit_buff 优先级；hit_animations 映射 fallback；timer 时长 |
| `test_buff_lifecycle_on_death.gd` | died → clear_all → on_expire 全调用 + 锁清理 |

### 15.2 手动场景测试

1. **BK 防御 buff**：连续受击观察伤害减半（`bk_defense_x05_3s.tres`）
2. **多攻击者同帧**：模拟 3 个 attacker 同帧攻击 → 验最终 HP + buff 列表
3. **DoT 边界**：中毒到死，不进 HitState 死亡循环
4. **Stacking**：同 id REFRESH 多次只有 1 个 instance；STACK 多次累计 tick
5. **死亡清理**：DoT 致死后 BuffComponent.active 为空
6. **行为锁聚合**：StunBuff + 自定义 lock buff 同时存在，过期时 stunned 字段正确清

---

## 16. BK 迁移衔接

### 16.1 取代 spec §6.1 占位方案

| BK 迁移 §6.1 旧设计 | 新设计 |
|---|---|
| BK.gd `apply_defense_buff(duration)` 占位方法 | 删除；改用 `bk_defense_x05_3s.tres` (StatModifierBuff) |
| BK.gd `heal_self(amount)` 占位方法 | 删除；改用 `bk_heal_self.tres` (HealOverTimeBuff, 单次 tick) |
| `GenericAttackState.call_skill_method` | 取消；改用 `apply_skill_self_buff` (skill.params.self_buff) |
| `_defense_multiplier` 字段 | 取消；BuffComponent + INCOMING_DAMAGE 替代 |
| spec §6.3 Phase 3 迁移路径 | 一步到位，无 Phase 3 |

### 16.2 时序：BuffEntity 先做，BK 迁移后做

BK 迁移 spec 标注的 `apply_defense_buff` / `heal_self` 占位方法 **完全不实现**——BK 重写时直接用 BuffEntity 终态，无技术债。

---

## 17. 范围外（YAGNI 边界）

| 项 | 推迟原因 |
|---|---|
| Max HP 修改型 buff | 涉及"过期是否同步降 HP"策略选择，需求来时再设计 |
| 加法型 modifier（"+5 防御点"） | 当前需求全是百分比，乘法够用 |
| 元素抗性（火/冰/物理） | 项目暂无元素系统 |
| Buff icon UI / `buffs_changed` 接 HUD | 信号已铺好，HUD 下迭代 |
| Buff 来源追踪（被谁施加的 actor） | source_pos 已存，source_actor 暂不需要 |
| Buff 互斥/优先抢占（如"狂暴免疫眩晕"） | 当前需求未出现 |

---

## 18. 工作量估算

| 阶段 | 工时 |
|---|---|
| 框架核心（BuffEntity + BuffComponent + StatModifier + StatIds） | 0.5 天 |
| Buff 子类（KnockBack/Up/Gather/DoT/HoT） | 0.5 天 |
| HitState + AgentAIBase + HealthComponent + HitBox 集成 | 0.5 天 |
| Damage.tres 数据迁移 + 角色 .tscn 挂载 | 0.5 天 |
| 单测 6 套 + 手动验证 | 1 天 |
| **合计** | **3 天** |

---

## 19. 验收标准

- 所有单测通过
- BK 战斗：防御 buff 生效（伤害减半）、自疗生效（HP 上涨可见）
- 多攻击者并行：3 个测试 attacker 同帧攻击 boss → 最终 HP 与 buff 列表与预期一致
- DoT：中毒可击杀，不死循环 HitState
- HealthBar：每次 HP 改变（受击/DoT/heal）即时反映，无延迟
- 死亡时 BuffComponent.active 自动清空
- 删除文件清单清空，git status 干净（仅含本次 spec 与实现）
- 与新 AgentAI 框架（[AgentAIBase.gd](../../../Core/AI/AgentAIBase.gd)）零回归
