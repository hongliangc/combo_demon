# AI Controller — State Machine 与 Decision 分离架构设计

- **日期**: 2026-04-12（v2 — 基于 LimboAI 源码审核后修正）
- **范围**:
  - 新建 Core/AI 子系统：Blackboard（动态字典）+ AIController（代码注册转换表）+ 纯执行器 State 层
  - 新建 Scene 模板 `AgentAIBase.tscn`，新敌人通过继承模板零配置即可运行
  - 试点 Boss DemonSlime（并行目录 `DemonSlime2/`，继承 AgentAIBase 模板）
  - 出 stock 状态库 + 脚本模板
- **设计目标**: 把决策逻辑从状态内剥离到代码集中声明的转换表；状态机退化成纯执行层；简化架构、降低新敌人创作成本
- **非目标**: StatusEffectComponent / DoT 系统（独立 spec）、现有 `DemonSlime/` 目录的兼容性、旧模板的敌人迁移

---

## 1. 背景与动机

### 当前痛点

1. **决策逻辑散落在 4 个位置**（以 DemonSlime 为例）：
   - `DSChase.physics_process_state` 内的距离判断 + pick_attack 调用
   - `BossBaseState.evaluate_combat_transition` 的共享距离表
   - `DSCleave / DSSlam` 末尾的 `evaluate_combat_transition()` 调用
   - `DSStateMachine._get_phase_route` 的阶段硬路由

2. **反应层走"信号中断 + StatePriority"**：`BossStateMachine._on_owner_damaged` 里的 poise / evasion / hit 分派是硬编码 if-else，可读性差、难以扩展。

3. **公共状态基类臃肿**：`BaseState` 暴露了 `try_attack / try_chase / decide_next_state / evaluate_transition / on_damaged` 等决策辅助方法。

4. **新敌人接入成本**：复制 CommonStates + 改决策代码 + BehaviorConfig + 特殊 override，修改点分散。

### 参考：LimboAI 源码审核

审读了 `limbo_hsm.cpp`、`limbo_state.cpp`、`blackboard.cpp` 完整源码 + demo 代码，提取以下关键设计决策：

| LimboAI 做法 | 说明 |
|---|---|
| **Blackboard = 动态字典** | `HashMap<StringName, BBVariable>`，`get_var/set_var`，支持 `bind_var_to_property` 自动镜像节点属性 |
| **转换表在代码注册** | `hsm.add_transition(from, to, event, guard)`，不用 Resource 文件 |
| **Guard = Callable** | `state.set_guard(callable)` 或 `add_transition(..., guard_callable)`，不是独立 .gd |
| **Blackboard 有 parent scope** | 子 Blackboard 读不到本地变量时向 parent 查询（层级作用域） |
| **LimboHSM extends LimboState** | HSM 本身可嵌套（本 spec 不做） |
| **无 Utility AI** | 最复杂 demo 仅 `BTProbabilitySelector` + `BTCooldown`，无动态评分 |
| **Hit 不是 State** | demo 里 hit 反应 = 挂起 HSM + 播动画 + 恢复（本 spec 保留 HitState 作为正式状态，因为 Boss 反应逻辑更复杂） |

---

## 2. 架构概览

```
Enemy / Boss Node (CharacterBody2D)
├── AIController (Node)                      ← AI 总入口
│    ├── Blackboard (RefCounted, 动态字典)    数据源
│    └── StateMachine (Node)                 状态容器
│         ├── IdleState        ┐
│         ├── ChaseState       │  纯执行器
│         ├── CleaveState      │  只做行为，不做决策
│         ├── SlamState        │
│         ├── HitState         │
│         ├── StunState        │
│         └── DeathState       ┘
├── HealthComponent                          不变
├── HurtBoxComponent                         不变
└── AnimationTree / Sprite 等                不变
```

三层职责：

| 层 | 组件 | 单一职责 |
|---|---|---|
| **数据层** | `Blackboard` | 动态字典，持有 AI 决策的全部输入；支持 bind 自动同步节点属性 |
| **决策层** | `AIController` | 内存转换表（代码注册）；事件 dispatch 或 safety tick 时查表选下一状态 |
| **执行层** | `State` 子类 | 只执行行为，通过 `dispatch` 向外通知生命周期事件 |

**禁止反向调用**：执行层不得直接切换状态；所有切换必须走 `AIController.dispatch(event)` 或由 safety tick 条件规则驱动。

---

## 3. 核心类设计

### 3.1 `Blackboard` (RefCounted, 动态字典)

路径：`Core/AI/Blackboard.gd`

学 LimboAI 的 `blackboard.cpp`。核心是一个 `Dictionary<StringName, Variant>` + parent scope + bind_var_to_property。

```gdscript
class_name Blackboard extends RefCounted

var _data: Dictionary = {}             # StringName → Variant
var _bindings: Dictionary = {}         # StringName → { object: Object, property: StringName }
var parent: Blackboard = null          # parent scope（读不到本地时向上查）

## 读变量（先查 binding 同步值，再查本地，再查 parent）
func get_var(var_name: StringName, default: Variant = null) -> Variant:
    if _bindings.has(var_name):
        var b: Dictionary = _bindings[var_name]
        if is_instance_valid(b.object):
            return b.object.get(b.property)
    if _data.has(var_name):
        return _data[var_name]
    if parent:
        return parent.get_var(var_name, default)
    return default

## 写变量（同步到 binding 如果有）
func set_var(var_name: StringName, value: Variant) -> void:
    _data[var_name] = value
    if _bindings.has(var_name):
        var b: Dictionary = _bindings[var_name]
        if is_instance_valid(b.object):
            b.object.set(b.property, value)

func has_var(var_name: StringName) -> bool:
    return _data.has(var_name) or (parent and parent.has_var(var_name))

## 绑定变量到节点属性（读写自动同步）
func bind_var(var_name: StringName, object: Object, property: StringName) -> void:
    _bindings[var_name] = { "object": object, "property": property }
    # 初始化本地值
    _data[var_name] = object.get(property)

func unbind_var(var_name: StringName) -> void:
    _bindings.erase(var_name)
```

**用法示例**（DemonSlime2._ready 里）：
```gdscript
var bb := ai_controller.blackboard
bb.bind_var(&"health", health_component, &"health")
bb.bind_var(&"max_health", health_component, &"max_health")
bb.bind_var(&"current_phase", self, &"current_phase")
bb.set_var(&"detection_radius", 600.0)
bb.set_var(&"attack_range", 250.0)
```

Guard 方法里用 `bb.get_var(&"health")` 直接读到 HealthComponent.health 的**实时值**，不需要 AIController 手动 pull。

**对比旧 spec**：删除了 `distance_to_target / target_alive / self_hp_ratio` 等全部硬编码字段；删除了 `custom: Dictionary` 扩展槽。一切通过 `get_var / set_var` 动态存取。

### 3.2 `State` (Node, 纯执行器)

路径：`Core/AI/State.gd`

```gdscript
class_name State extends Node

## 由 AIController 注入
var ai: AIController
var bb: Blackboard
var owner_node: Node

# ---- 生命周期（子类重写）----
func enter() -> void: pass
func exit() -> void: pass
func update(_delta: float) -> void: pass            # _process
func physics_update(_delta: float) -> void: pass    # _physics_process

# ---- 向 AIController dispatch 事件 ----
func dispatch(event: StringName) -> void:
    if ai:
        ai.dispatch(event)
```

**禁用**：`transition_to / force_transition / try_attack / try_chase / decide_next_state / evaluate_transition / on_damaged` 全部不存在。

**事件发出惯例**：
- 攻击动画完成 → `dispatch(AIEvents.EV_ATTACK_FINISHED)`
- 受击恢复 → `dispatch(AIEvents.EV_HIT_RECOVERED)`

### 3.3 `AIController` (Node)

路径：`Core/AI/AIController.gd`

**核心改动**：转换表从 Resource 改为**代码注册**（学 LimboAI `add_transition`），Guard 从 GDScript 文件改为 **Callable**。

```gdscript
class_name AIController extends Node

@export var initial_state_name: StringName = &"idle"
@export var safety_tick_interval: float = 0.2
@export var target_group: StringName = &"player"

var blackboard: Blackboard
var owner_node: Node
var target_node: Node
var states: Dictionary = {}       # StringName → State
var current_state: State
var ANYSTATE: State = null        # 哨兵值，代表通配

var _transitions: Array = []     # Array[_Transition]
var _tick_accum: float = 0.0

# ---- 内部转换结构 ----
class _Transition:
    var from_state: State         # null = ANYSTATE
    var to_state: State
    var event: StringName         # 空 = 条件式
    var guard: Callable           # 空 Callable = 无条件
    var priority: int

# ---- 注册转换（在 enemy 的 _setup_transitions 里调用）----
func add_transition(from: State, to: State, event: StringName = &"",
        guard: Callable = Callable(), priority: int = 0) -> void:
    var t := _Transition.new()
    t.from_state = from
    t.to_state = to
    t.event = event
    t.guard = guard
    t.priority = priority
    _transitions.append(t)
    # 保持按 priority 降序，dispatch 时遇到第一个命中即停
    _transitions.sort_custom(func(a, b): return a.priority > b.priority)

# ---- 初始化 ----
func _ready() -> void:
    owner_node = get_owner()
    blackboard = Blackboard.new()
    _collect_states()
    call_deferred("_find_target")
    call_deferred("_enter_initial_state")

func _collect_states() -> void:
    var container := get_node_or_null(^"StateMachine")
    if not container:
        return
    for child in container.get_children():
        if child is State:
            var s := child as State
            s.ai = self
            s.bb = blackboard
            s.owner_node = owner_node
            states[StringName(s.name.to_lower())] = s

func _find_target() -> void:
    target_node = get_tree().get_first_node_in_group(target_group)

func _enter_initial_state() -> void:
    var s: State = states.get(initial_state_name)
    if s:
        current_state = s
        current_state.enter()

# ---- 主循环 ----
func _physics_process(delta: float) -> void:
    _update_blackboard(delta)
    if current_state:
        current_state.physics_update(delta)
    _tick_accum += delta
    if _tick_accum >= safety_tick_interval:
        _tick_accum = 0.0
        _evaluate_conditional_transitions()

func _process(delta: float) -> void:
    if current_state:
        current_state.update(delta)

# ---- Blackboard 更新（极简 — 仅算 distance，其余靠 bind）----
func _update_blackboard(delta: float) -> void:
    # distance 是计算值，不是属性，无法 bind，手动更新
    if is_instance_valid(target_node) and owner_node is Node2D:
        var dist: float = (owner_node as Node2D).global_position.distance_to(
            (target_node as Node2D).global_position)
        blackboard.set_var(&"distance", dist)
        blackboard.set_var(&"target_position", (target_node as Node2D).global_position)
        blackboard.set_var(&"target_alive",
            target_node.get("alive") if "alive" in target_node else true)
    else:
        blackboard.set_var(&"distance", INF)
        blackboard.set_var(&"target_alive", false)
    # 冷却倒计时
    var atk_cd: float = blackboard.get_var(&"attack_cooldown", 0.0)
    if atk_cd > 0:
        blackboard.set_var(&"attack_cooldown", maxf(0.0, atk_cd - delta))
    var gcd: float = blackboard.get_var(&"global_cooldown", 0.0)
    if gcd > 0:
        blackboard.set_var(&"global_cooldown", maxf(0.0, gcd - delta))

# ---- 事件分派 ----
func dispatch(event: StringName) -> void:
    if current_state == null or event == &"":
        return
    for t in _transitions:
        if t.event != event:
            continue
        if t.from_state != null and t.from_state != current_state:
            continue
        if t.guard.is_valid() and not t.guard.call():
            continue
        _change_state(t.to_state)
        return

# ---- 条件式转换评估（event 为空的规则）----
func _evaluate_conditional_transitions() -> void:
    if current_state == null:
        return
    for t in _transitions:
        if t.event != &"":
            continue
        if t.from_state != null and t.from_state != current_state:
            continue
        if t.guard.is_valid() and not t.guard.call():
            continue
        _change_state(t.to_state)
        return

# ---- 状态切换 ----
func _change_state(new_state: State) -> void:
    if new_state == null:
        return
    if current_state:
        current_state.exit()
    current_state = new_state
    current_state.enter()
    DebugConfig.debug("[AI] → %s" % new_state.name, "", "state_machine")

# ---- 外部接口 ----
func get_current_state_name() -> StringName:
    return StringName(current_state.name.to_lower()) if current_state else &""

func get_state(state_name: StringName) -> State:
    return states.get(state_name)
```

**对比旧 spec**：
- 删除了 `@export var decision_table: DecisionTable`（不再需要 Resource）
- 删除了 `@export var blackboard: Blackboard`（AIController 自动创建）
- `_update_blackboard` 从 ~20 行缩减到 ~10 行（HP/phase 靠 bind，不用 pull）
- `dispatch` 直接遍历内存 `_transitions` 数组，不查 Resource
- 新增 `add_transition()` API

### 3.4 `AIEvents` (事件常量)

路径：`Core/AI/AIEvents.gd`

```gdscript
class_name AIEvents

const EV_DAMAGED         := &"damaged"
const EV_DIED            := &"died"
const EV_PHASE_CHANGED   := &"phase_changed"
const EV_ATTACK_FINISHED := &"attack_finished"
const EV_HIT_RECOVERED   := &"hit_recovered"
const EV_STUN_RECOVERED  := &"stun_recovered"
const EV_REACTION_DONE   := &"reaction_finished"
```

---

## 4. 反应层 / 伤害流程

```
HurtBox.damaged 信号
    → HealthComponent.take_damage(damage)              ← 保留现有连接
        ├─ 扣血
        ├─ if health <= 0: emit died
        └─ else: emit damaged(damage, attacker_pos)

DemonSlime2._on_damaged (监听 HealthComponent.damaged)
    ├─ bb.set_var(&"last_damage", damage)
    ├─ bb.set_var(&"last_attacker_pos", pos)
    ├─ bb.set_var(&"recently_hit", true)
    ├─ bb.set_var(&"poise_broken", _check_poise(damage))
    ├─ bb.set_var(&"evasion_rolled", _check_evasion())
    └─ ai_controller.dispatch(AIEvents.EV_DAMAGED)
         → 遍历 _transitions，匹配 event="damaged"
         → ANYSTATE 规则按 priority 降序评估 guard
         → 第一个命中 → _change_state
         → 未命中 → 静默丢弃（"执行中免疫"）

DemonSlime2._on_died (监听 HealthComponent.died)
    → ai_controller.dispatch(AIEvents.EV_DIED)
```

"不可打断" = 不注册 `from=该状态` 的 `event=damaged` 转换规则，dispatch 自然无匹配。

---

## 5. DemonSlime2 试点实现

### 5.1 目录结构

```
Scenes/Characters/Bosses/DemonSlime2/
├── DemonSlime2.gd              extends BossBase
├── DemonSlime2.tscn            ← inherited scene from AgentAIBase.tscn
│                                  根节点 script 覆盖为 DemonSlime2.gd
│                                  新增 BossAttackManager / StunState 等子节点
├── States/
│   ├── DS2Cleave.gd            播动画 + 生成扇形冲击波 + dispatch attack_finished
│   ├── DS2Slam.gd              播动画 + 生成 slam 伤害区 + dispatch attack_finished
│   ├── DS2Counter.gd           反击动作 + dispatch reaction_finished
│   ├── DS2Defend.gd            格挡动作 + dispatch reaction_finished
│   └── DS2Roll.gd              翻滚回避 + dispatch reaction_finished
└── Attacks/
    ├── FanShockwave.tscn
    └── SlamImpact.tscn
```

**说明**：
- **Idle / Chase / Hit / Death 从 AgentAIBase 模板继承**，不在 DS2 目录里重写
- StunState 作为 Boss 额外子节点添加到 StateMachine
- **不再有** `AI/Guards/` 目录和 `DS2DecisionTable.tres` — 所有规则在 `DemonSlime2.gd` 里代码注册
- 不引用旧 DS 状态；如需复用攻击效果 Scene，直接 preload

### 5.2 DemonSlime2 根脚本（核心 — 转换表集中声明）

```gdscript
class_name DemonSlime2 extends BossBase

@onready var ai: AIController = $AIController
@onready var health_comp: HealthComponent = $HealthComponent

func _ready() -> void:
    super._ready()
    _setup_blackboard()
    _setup_transitions()
    _setup_signals()

# ---- Blackboard 初始化（bind 自动同步 + 手动初始值）----
func _setup_blackboard() -> void:
    var bb := ai.blackboard
    bb.bind_var(&"health", health_comp, &"health")
    bb.bind_var(&"max_health", health_comp, &"max_health")
    bb.bind_var(&"current_phase", self, &"current_phase")
    bb.set_var(&"detection_radius", detection_radius)
    bb.set_var(&"attack_range", attack_range)
    bb.set_var(&"attack_cooldown", 0.0)
    bb.set_var(&"global_cooldown", 0.0)
    bb.set_var(&"last_action", &"")
    bb.set_var(&"recently_hit", false)

# ---- 转换表集中声明（一个方法看完所有规则）----
func _setup_transitions() -> void:
    var sm := ai.states
    var idle: State  = sm.idle
    var chase: State = sm.chase
    var cleave: State = sm.cleave
    var slam: State   = sm.slam
    var hit: State    = sm.hit
    var stun: State   = sm.stun
    var death: State  = sm.death
    var counter: State = sm.counter
    var defend: State  = sm.defend
    var roll: State    = sm.roll

    # 行为层（条件式 — safety tick 评估）
    ai.add_transition(idle, chase, &"", _guard_detected)
    ai.add_transition(chase, idle, &"", _guard_target_lost)
    ai.add_transition(chase, slam, &"", _guard_can_slam, 20)    # slam 优先级高于 cleave
    ai.add_transition(chase, cleave, &"", _guard_can_cleave, 10)

    # 攻击完成（事件式）
    ai.add_transition(cleave, chase, AIEvents.EV_ATTACK_FINISHED)
    ai.add_transition(slam, chase, AIEvents.EV_ATTACK_FINISHED)

    # 反应层（ANYSTATE 事件式，按 priority 降序）
    ai.add_transition(ai.ANYSTATE, death, AIEvents.EV_DIED, Callable(), 100)
    ai.add_transition(ai.ANYSTATE, chase, AIEvents.EV_PHASE_CHANGED, _guard_target_alive, 50)
    ai.add_transition(ai.ANYSTATE, counter, AIEvents.EV_DAMAGED, _guard_poise_broken, 30)
    ai.add_transition(ai.ANYSTATE, defend, AIEvents.EV_DAMAGED, _guard_evasion_defend, 20)
    ai.add_transition(ai.ANYSTATE, roll, AIEvents.EV_DAMAGED, _guard_evasion_roll, 19)
    ai.add_transition(ai.ANYSTATE, hit, AIEvents.EV_DAMAGED, Callable(), 10)

    # 恢复
    ai.add_transition(hit, chase, AIEvents.EV_HIT_RECOVERED, _guard_target_alive, 10)
    ai.add_transition(hit, idle, AIEvents.EV_HIT_RECOVERED, Callable(), 0)
    ai.add_transition(stun, chase, AIEvents.EV_STUN_RECOVERED, _guard_target_alive, 10)
    ai.add_transition(stun, idle, AIEvents.EV_STUN_RECOVERED, Callable(), 0)
    ai.add_transition(counter, chase, AIEvents.EV_REACTION_DONE)
    ai.add_transition(defend, chase, AIEvents.EV_REACTION_DONE)
    ai.add_transition(roll, chase, AIEvents.EV_REACTION_DONE)

# ---- Guard 方法（Callable，就是普通方法）----
func _guard_detected() -> bool:
    var bb := ai.blackboard
    return bb.get_var(&"target_alive", false) and bb.get_var(&"distance", INF) < bb.get_var(&"detection_radius", 600.0)

func _guard_target_lost() -> bool:
    var bb := ai.blackboard
    return not bb.get_var(&"target_alive", false) or bb.get_var(&"distance", INF) > 700.0

func _guard_target_alive() -> bool:
    return ai.blackboard.get_var(&"target_alive", false)

func _guard_can_cleave() -> bool:
    var bb := ai.blackboard
    if bb.get_var(&"attack_cooldown", 1.0) > 0: return false
    if bb.get_var(&"global_cooldown", 1.0) > 0: return false
    if bb.get_var(&"distance", INF) > bb.get_var(&"attack_range", 250.0): return false
    if bb.get_var(&"last_action") == &"cleave":
        return false  # 不连续出 cleave
    return true

func _guard_can_slam() -> bool:
    var bb := ai.blackboard
    if bb.get_var(&"attack_cooldown", 1.0) > 0: return false
    if bb.get_var(&"global_cooldown", 1.0) > 0: return false
    if bb.get_var(&"distance", INF) > 180.0: return false
    if bb.get_var(&"current_phase", 0) < 1: return false  # Phase 2+ 才有 slam
    return true

func _guard_poise_broken() -> bool:
    return ai.blackboard.get_var(&"poise_broken", false)

func _guard_evasion_defend() -> bool:
    return ai.blackboard.get_var(&"evasion_rolled", false) and randf() < 0.5

func _guard_evasion_roll() -> bool:
    return ai.blackboard.get_var(&"evasion_rolled", false)

# ---- 信号连接 ----
func _setup_signals() -> void:
    if health_comp:
        health_comp.damaged.connect(_on_damaged)
        health_comp.died.connect(_on_died)
    phase_changed.connect(_on_phase_changed)

func _on_damaged(damage: Damage, attacker_pos: Vector2) -> void:
    var bb := ai.blackboard
    bb.set_var(&"last_damage", damage)
    bb.set_var(&"last_attacker_pos", attacker_pos)
    bb.set_var(&"recently_hit", true)
    bb.set_var(&"poise_broken", _check_poise(damage))
    bb.set_var(&"evasion_rolled", _check_evasion())
    ai.dispatch(AIEvents.EV_DAMAGED)

func _on_died() -> void:
    ai.dispatch(AIEvents.EV_DIED)

func _on_phase_changed(_new_phase: int) -> void:
    ai.dispatch(AIEvents.EV_PHASE_CHANGED)
```

**一个文件看完所有 AI 行为**：规则表、Guard、信号连接、Blackboard 初始化。可断点、可 print、可 call stack。

### 5.3 DS2 State 示例 —— `DS2Cleave.gd`

```gdscript
extends State

@export var cleave_damage: Damage
@export var cleave_cooldown: float = 2.5

var _anim_tree: AnimationTree

func enter() -> void:
    bb.set_var(&"attack_cooldown", cleave_cooldown)
    bb.set_var(&"global_cooldown", 0.3)
    bb.set_var(&"last_action", &"cleave")

    _anim_tree = owner_node.get_node_or_null(^"AnimationTree")
    if _anim_tree:
        _anim_tree.animation_finished.connect(_on_anim_finished, CONNECT_ONE_SHOT)
        var pb = _anim_tree.get("parameters/control_sm/playback")
        if pb: pb.start(&"cleave")

func _on_anim_finished(_name: StringName) -> void:
    # 生成扇形冲击波
    # ...
    dispatch(AIEvents.EV_ATTACK_FINISHED)

func exit() -> void:
    pass
```

### 5.4 DS2Chase —— 从 Stock 继承，不用写

Stock `ChaseState.gd` 已经处理移动+动画。DemonSlime2 直接用模板里预装的 ChaseState。

---

## 6. 删除清单（验收通过后全面推广时）

DS2 试点期间不删旧代码，验收后：

- `Core/StateMachine/BaseState.gd`：`StatePriority` 枚举、`try_attack / try_chase / decide_next_state / evaluate_transition / on_damaged`、`can_transition_to`
- `Core/StateMachine/BaseStateMachine.gd`：`force_transition`、`recover_from_stun`、`last_damage / last_attacker_position`
- `Core/StateMachine/CommonStates/` 全部
- `Scenes/Characters/Bosses/Shared/BossBaseState.gd`：`evaluate_combat_transition`
- `Scenes/Characters/Bosses/Shared/BossStateMachine.gd`：`_on_owner_damaged` poise/evasion 分派

---

## 7. 测试策略

### 7.1 单元测试（GUT）

- `test_blackboard.gd`：
  - `get_var / set_var` 基础读写
  - `bind_var` 自动同步（修改 object property → get_var 返回新值）
  - parent scope 向上查询
- `test_ai_controller.gd`（mock owner + states）：
  - `add_transition` 注册 + priority 排序
  - `dispatch` 触发事件式转换
  - safety tick 触发条件式转换
  - guard Callable 阻挡不该切的转换
  - ANYSTATE 通配匹配
  - 无匹配规则时静默丢弃

### 7.2 集成测试

- `test_ds2_integration.gd`：
  - Idle → Chase（距离触发）
  - Chase → Cleave（距离 + cooldown）
  - Cleave → Chase（attack_finished）
  - 受伤 → Hit → Chase
  - HP → 0 → Death
  - Phase 切换重置
  - Counter/Defend/Roll guard 条件

### 7.3 运行时验证

- `mcp__godot__run_project` + `mcp__godot__get_debug_output` 检查 `[AI] → xxx` 日志

---

## 8. 风险与已知局限

1. **`bind_var` 对已销毁节点的处理**：`get_var` 里 `is_instance_valid` 检查，节点销毁后 binding 失效、回退到 `_data` 本地值。
2. **条件式规则 0.2s safety tick**：快节奏足够。极端情况可在信号回调里手动 dispatch 补充事件触发。
3. **Callable guard 无法序列化**：转换表不能导出为 .tres。这是有意为之 — 规则就该在代码里，不给 Inspector 编辑。
4. **`_transitions` 数组全扫描**：典型 enemy 20-30 条规则，O(N) 无性能问题。100+ 条规则的 Boss 再考虑 HashMap 优化。

---

## 9. 交付物

### 9.1 核心类 (Core/AI/)
1. `Blackboard.gd`（动态字典 + bind + parent scope）
2. `State.gd`（纯执行器）
3. `AIController.gd`（代码注册转换表 + dispatch + safety tick）
4. `AIEvents.gd`（事件常量）

### 9.2 Stock 状态库 (Core/AI/Stock/)
5. `IdleState.gd` / `ChaseState.gd` / `WanderState.gd` / `HitState.gd` / `StunState.gd` / `DeathState.gd`

### 9.3 场景模板 (Scenes/Characters/Templates/)
6. `AgentAIBase.tscn`（预装 AIController + StateMachine + 4 stock 状态）

### 9.4 Godot 脚本模板 (script_templates/)
7. `Node/ai_state.gd`（State 子类骨架）
8. `CharacterBody2D/enemy_ai_root.gd`（enemy 根脚本骨架，含 _setup_transitions 空方法）

### 9.5 DemonSlime2 试点
9. `Scenes/Characters/Bosses/DemonSlime2/` 完整目录

### 9.6 测试
10. `test_blackboard.gd` / `test_ai_controller.gd` / `test_ds2_integration.gd`

### 9.7 文档
11. 实现完成后由 `context-updater` skill 更新 CLAUDE.md 等

---

## 10. 未来扩展接口（本 spec 不做）

- StatusEffectComponent（DoT / Buff / Debuff）—— 独立 spec
- 嵌套 AIController（LimboAI 式 HSM 嵌套）
- Blackboard 信号式变化通知（`var_changed` 信号）
- 可视化调试面板（显示当前状态 + Blackboard 变量值）

---

## 11. 场景模板 `AgentAIBase.tscn`

### 11.1 节点结构

```
AgentAIBase (CharacterBody2D, script=Core/Characters/EnemyBase.gd, groups=["enemy"])
├── Sprite2D                          空 texture
├── AnimationPlayer
├── AnimationTree
│     参数路径约定:
│       parameters/locomotion/blend_position
│       parameters/control_sm/playback
│       parameters/control_blend/blend_amount
│       parameters/attack_oneshot/request
├── CollisionShape2D
├── FloorCollision (CollisionShape2D)
├── HurtBoxComponent (Area2D)
│   └── CollisionShape2D
├── HitBoxComponent (Area2D)
│   └── CollisionShape2D
├── HealthComponent                   max_health=100
├── HealthBar (ProgressBar)
├── DamageNumbersAnchor (Node2D)
└── AIController (Node)
     └── StateMachine (Node)
          ├── Idle   (script=Core/AI/Stock/IdleState.gd)
          ├── Chase  (script=Core/AI/Stock/ChaseState.gd)
          ├── Hit    (script=Core/AI/Stock/HitState.gd)
          └── Death  (script=Core/AI/Stock/DeathState.gd)
```

### 11.2 模板使用方式

**普通 Enemy**：继承模板，换贴图 + 调血量。根脚本覆盖为自定义脚本，在 `_setup_transitions()` 里注册规则。

**Boss**：继承模板后额外覆盖根脚本为 `BossBase.gd` 子类，按需加 BossAttackManager / StunState 等子节点。

### 11.3 旧模板处理

`EnemyBase.tscn` / `BossBase.tscn` 保留不动（现有敌人在用），标注 `@deprecated`。

---

## 12. 新敌人创作工作流

### 12.1 普通敌人（无攻击，零代码）

1. 继承 `AgentAIBase.tscn`
2. 设置 `Sprite2D.texture` + `HealthComponent.max_health` + 碰撞体尺寸
3. 根脚本中写 `_setup_transitions()` 调用 stock 行为的 `add_transition`（或用模板脚本里预设的 stock 规则方法 `_setup_stock_transitions()`）
4. 保存，能跑

### 12.2 带攻击的敌人

5. 新建 AttackState.gd（extends State），实现 enter/exit/physics_update
6. 加到 StateMachine 子节点
7. 在 `_setup_transitions()` 加 `ai.add_transition(chase, attack, &"", _guard_can_attack)`
8. 写 `_guard_can_attack()` 方法

### 12.3 Boss

同 12.2 + 覆盖根脚本为 BossBase 子类 + 加 BossAttackManager + _setup_signals 连 phase_changed

---

## 13. 对比修正前方案

| 维度 | v1 (修正前) | v2 (当前) |
|---|---|---|
| Blackboard | Resource, 硬编码字段, 手动 pull | RefCounted 动态字典 + bind_var 自动同步 |
| 转换表 | DecisionTable.tres (Resource 嵌套) | 代码注册 `add_transition()` |
| Guard | 独立 .gd 文件 + static func | Callable (enemy 脚本里的方法) |
| 文件数 | ~20 .gd + .tres | ~8 .gd |
| 调试 | .tres 追溯困难 | 断点 + call stack 直达 |
| 新敌人流程 | 建 .tres + 建 guard .gd + 配 Inspector | 写 `_setup_transitions()` + guard 方法 |
| 规则复用 | DecisionTable 继承 (base_table) | `super._setup_transitions()` 代码继承 |

**删除的旧 v1 概念**：
- ~~TransitionRule.gd~~
- ~~DecisionTable.gd~~
- ~~Core/AI/Guards/ 目录~~ (8 个 guard .gd)
- ~~Core/AI/Templates/*.tres~~ (3 个 stock 决策表)
- ~~DecisionTable 继承机制~~
- ~~script_templates/RefCounted/ai_guard.gd~~
