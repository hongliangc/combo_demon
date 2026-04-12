# AI Controller — State Machine 与 Decision 分离架构设计

- **日期**: 2026-04-11
- **范围**:
  - 新建 Scene 模板 `EnemyAIBase.tscn` / `BossAIBase.tscn`，新敌人/Boss 通过继承模板零配置即可运行
  - 新建 Core/AI 子系统：Blackboard + DecisionTable + AIController + 纯执行器 State 层
  - 试点 Boss DemonSlime（并行目录 `DemonSlime2/`，继承 BossAIBase 模板）
  - 出 stock 决策表 + stock guard 库 + 脚本模板
- **设计目标**: 把决策逻辑从状态内剥离到声明式 Decision Table；状态机退化成纯执行层；简化架构、降低新敌人创作成本（目标 < 10 分钟从零到能跑）
- **非目标**: StatusEffectComponent / DoT 系统（独立 spec）、现有 `DemonSlime/` 目录的兼容性、旧模板的敌人迁移

---

## 1. 背景与动机

### 当前痛点

1. **决策逻辑散落在 4 个位置**（以 DemonSlime 为例）：
   - `DSChase.physics_process_state` 内的距离判断 + pick_attack 调用
   - `BossBaseState.evaluate_combat_transition` 的共享距离表
   - `DSCleave / DSSlam` 末尾的 `evaluate_combat_transition()` 调用
   - `DSStateMachine._get_phase_route` 的阶段硬路由

2. **反应层走"信号中断 + StatePriority"**：功能上够用，但 `BossStateMachine._on_owner_damaged` 里的 poise / evasion / hit 分派是硬编码 if-else，可读性差、难以扩展。

3. **公共状态基类臃肿**：`BaseState` 暴露了 `try_attack / try_chase / decide_next_state / evaluate_transition / on_damaged` 等一堆决策辅助方法，每个继承它的状态都承担认知负担。

4. **新敌人接入成本**：复制 CommonStates 子节点后，要同时改状态里的决策代码 + BehaviorConfig + 特殊 override，修改点分散。

### 参考

- **LimboAI**（`E:/workspace/4.godot/OpenSource/limboai`）：HSM 采用声明式转换表 `add_transition(from, to, event, guard)` + `dispatch(event)`，反应类事件通过 ANYSTATE 通配转换处理（`limbo_hsm.cpp:143`）。Hit 反应在 demo 里是"挂起 HSM + 播动画 + 恢复"，不做成 State。
- **BehaviourToolkit**：显式 `FSMTransition` 节点 + 条件轮询，节点式但每帧评估。

**启发**：
- 声明式转换表 > 命令式 `force_transition`
- 事件驱动 > 每帧轮询（辅以 safety tick 处理条件式）
- LimboAI 最复杂的 demo 仅使用 `BTProbabilitySelector` + `BTCooldown`，无动态 Utility 打分 —— 说明"加权池 + 冷却 + guard"足够表达复杂 AI，不需要 Utility Scoring 系统

---

## 2. 架构概览

```
Enemy / Boss Node (CharacterBody2D)
├── AIController (Node)                      ← AI 总入口
│    ├── Blackboard (Resource)               数据源
│    ├── DecisionTable (Resource)            声明式转换表
│    └── StateMachine (Node)                 状态容器
│         ├── IdleState        ┐
│         ├── ChaseState       │  纯执行器
│         ├── CleaveState      │  只做行为，不做决策
│         ├── SlamState        │
│         ├── HitState         │
│         ├── StunState        │
│         └── DeathState       ┘
├── HealthComponent                          不变
├── HurtBoxComponent                         不变（连接点调整）
└── AnimationTree / Sprite 等                不变
```

三层职责：

| 层 | 组件 | 单一职责 |
|---|---|---|
| **数据层** | `Blackboard` | 持有 AI 决策的全部输入（感知、冷却、记忆） |
| **决策层** | `DecisionTable` + `AIController` | 声明转换规则，在事件到来或 safety tick 时查表选下一状态 |
| **执行层** | `State` 子类 | 只执行行为（移动、播动画、生成攻击判定），通过 `state_event` 信号向外通知生命周期 |

**禁止反向调用**：执行层不得直接切换状态；所有切换必须走 `AIController.dispatch(event)`。

---

## 3. 核心类设计

### 3.1 `Blackboard` (Resource)

路径：`Core/AI/Blackboard.gd`

```gdscript
class_name Blackboard extends Resource

# ---- 感知（AIController 每次 dispatch/tick 前 pull 刷新）----
@export_group("Perception")
var distance_to_target: float = INF
var target_alive: bool = false
var target_position: Vector2 = Vector2.ZERO
var has_line_of_sight: bool = false   # 预留

# ---- 自身状态（镜像 HealthComponent / Owner）----
@export_group("Self")
var self_hp_ratio: float = 1.0
var self_hp: float = 0.0
var current_phase: int = 0

# ---- 冷却 ----
@export_group("Cooldowns")
var attack_cooldown: float = 0.0
var global_cooldown: float = 0.0       # 全局 GCD，受击后硬性延迟

# ---- 行为记忆 ----
@export_group("Memory")
var last_action: StringName = &""
var time_since_last_attack: float = 0.0
var recently_hit: bool = false

# ---- 反应标记（由 damage 回调写入）----
@export_group("Reaction Flags")
var last_damage: Damage = null
var last_attacker_position: Vector2 = Vector2.ZERO
var poise_broken: bool = false      # Boss 特有，普通 Enemy 始终 false
var evasion_rolled: bool = false    # Boss 特有

# ---- 自定义扩展槽（子类 AI 可自由使用）----
@export_group("Custom")
var custom: Dictionary = {}
```

**原则**：Blackboard 只读数据不写逻辑；所有字段都由 AIController 或 HitState 等"授权写入者"更新。

### 3.2 `TransitionRule` (Resource)

路径：`Core/AI/TransitionRule.gd`

```gdscript
class_name TransitionRule extends Resource

## 单条决策规则。guard 为空 = 无条件触发。
## event 为空 = 条件式规则（每 safety tick 评估）。
## event 非空 = 事件式规则（dispatch 时评估）。

@export var from_state: StringName = &""   # "*" 表示 ANYSTATE
@export var to_state: StringName = &""
@export var event: StringName = &""         # 空 = 条件式规则（safety tick 评估）
@export var guard_script: GDScript          # 可空；非空时运行时调 guard_script.check(bb)
@export var priority: int = 0               # 同事件多条命中时取高优先级
@export var debug_label: String = ""

func evaluate(bb: Blackboard) -> bool:
    if guard_script == null:
        return true
    return guard_script.check(bb)
```

**Guard 约定**：每条带 guard 的规则关联一个独立 `.gd` 文件，该文件里必须定义 `static func check(bb: Blackboard) -> bool`。文件不继承任何 Node（`extends RefCounted`），因为只被当纯函数容器用。初版**不支持**字符串表达式；后续若有需要再加。

### 3.3 `DecisionTable` (Resource)

路径：`Core/AI/DecisionTable.gd`

```gdscript
class_name DecisionTable extends Resource

@export var rules: Array[TransitionRule] = []

## 查找匹配事件式规则
func find_event_rules(current_state: StringName, event: StringName) -> Array[TransitionRule]:
    var matched: Array[TransitionRule] = []
    for r in rules:
        if r.event != event:
            continue
        if r.from_state != current_state and r.from_state != &"*":
            continue
        matched.append(r)
    matched.sort_custom(func(a, b): return a.priority > b.priority)
    return matched

## 查找匹配条件式规则（event 为空）
func find_conditional_rules(current_state: StringName) -> Array[TransitionRule]:
    var matched: Array[TransitionRule] = []
    for r in rules:
        if r.event != &"":
            continue
        if r.from_state != current_state and r.from_state != &"*":
            continue
        matched.append(r)
    matched.sort_custom(func(a, b): return a.priority > b.priority)
    return matched
```

**.tres 编辑方式**：在 Godot 编辑器里新建 `DemonSlime2DecisionTable.tres`，添加 `TransitionRule` 子资源，每条填好 `from / to / event / guard_script`。

### 3.4 `State` (Node, 纯执行器)

路径：`Core/AI/State.gd`

```gdscript
class_name State extends Node

## 状态向外发事件，由 AIController 捕获并查决策表
signal state_event(event_name: StringName)

## 由 AIController 注入
var ai: AIController
var bb: Blackboard
var owner_node: Node

# ---- 生命周期（子类重写）----
func enter() -> void: pass
func exit() -> void: pass
func update(_delta: float) -> void: pass            # _process
func physics_update(_delta: float) -> void: pass    # _physics_process

# ---- 工具方法（最小集）----
func get_distance_to_target() -> float:
    if owner_node is Node2D and bb.target_position != Vector2.ZERO:
        return (owner_node as Node2D).global_position.distance_to(bb.target_position)
    return INF

func emit_event(event_name: StringName) -> void:
    state_event.emit(event_name)
```

**禁用**：`transition_to / force_transition / try_attack / try_chase / decide_next_state / evaluate_transition / on_damaged` 全部不存在。状态不调 state_machine 的切换 API。

**事件发出惯例**：
- 攻击状态动画完成 → `emit_event(&"attack_finished")`
- 追击进入攻击范围 → `emit_event(&"in_attack_range")`（只发一次，去抖动靠 AIController 的 dispatch 幂等）
- 失去目标 → `emit_event(&"target_lost")`

### 3.5 `AIController` (Node)

路径：`Core/AI/AIController.gd`

```gdscript
class_name AIController extends Node

@export var blackboard: Blackboard
@export var decision_table: DecisionTable
@export var initial_state_name: StringName = &"idle"
@export var safety_tick_interval: float = 0.2   # 条件式规则评估节奏
@export var target_group: StringName = &"player"

var owner_node: Node
var target_node: Node
var states: Dictionary = {}       # name -> State
var current_state: State
var _tick_accum: float = 0.0

func _ready() -> void:
    owner_node = get_owner()
    _collect_states()
    call_deferred("_find_target")
    call_deferred("_enter_initial_state")

func _collect_states() -> void:
    # 约定：StateMachine 节点作为 AIController 的兄弟或子节点
    var state_container := get_node_or_null(^"StateMachine")
    if not state_container:
        return
    for child in state_container.get_children():
        if child is State:
            var s := child as State
            s.ai = self
            s.bb = blackboard
            s.owner_node = owner_node
            s.state_event.connect(_on_state_event)
            states[StringName(s.name.to_lower())] = s

func _find_target() -> void:
    target_node = get_tree().get_first_node_in_group(target_group)

func _enter_initial_state() -> void:
    _change_state(initial_state_name)

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

# ---- Blackboard 更新（Pull 模式）----
func _update_blackboard(delta: float) -> void:
    if blackboard == null:
        return
    # 目标感知
    if is_instance_valid(target_node):
        blackboard.target_alive = target_node.get("alive") if "alive" in target_node else true
        blackboard.target_position = (target_node as Node2D).global_position
        if owner_node is Node2D:
            blackboard.distance_to_target = (owner_node as Node2D).global_position.distance_to(blackboard.target_position)
    else:
        blackboard.target_alive = false
        blackboard.distance_to_target = INF
    # HP 镜像
    var hc := owner_node.get_node_or_null(^"HealthComponent")
    if hc:
        blackboard.self_hp = hc.health
        blackboard.self_hp_ratio = hc.health / maxf(hc.max_health, 1.0)
    # Phase 镜像
    if owner_node is BossBase:
        blackboard.current_phase = (owner_node as BossBase).current_phase
    # 冷却倒计时
    blackboard.attack_cooldown = maxf(0.0, blackboard.attack_cooldown - delta)
    blackboard.global_cooldown = maxf(0.0, blackboard.global_cooldown - delta)
    blackboard.time_since_last_attack += delta

# ---- 事件分派 ----
func dispatch(event: StringName) -> void:
    if current_state == null:
        return
    var rules := decision_table.find_event_rules(StringName(current_state.name.to_lower()), event)
    for rule in rules:
        if rule.evaluate(blackboard):
            _change_state(rule.to_state)
            return

# ---- 条件式转换评估 ----
func _evaluate_conditional_transitions() -> void:
    if current_state == null:
        return
    var rules := decision_table.find_conditional_rules(StringName(current_state.name.to_lower()))
    for rule in rules:
        if rule.evaluate(blackboard):
            _change_state(rule.to_state)
            return

# ---- 状态切换 ----
func _change_state(new_state_name: StringName) -> void:
    var new_state: State = states.get(new_state_name)
    if new_state == null:
        push_warning("[AIController] 状态 '%s' 不存在" % new_state_name)
        return
    if current_state:
        current_state.exit()
    current_state = new_state
    current_state.enter()
    DebugConfig.debug("[AIController] → %s" % new_state_name, "", "state_machine")

# ---- 状态事件回调 ----
func _on_state_event(event_name: StringName) -> void:
    dispatch(event_name)

# ---- 外部接口 ----
func get_current_state_name() -> StringName:
    return StringName(current_state.name.to_lower()) if current_state else &""
```

---

## 4. 反应层 / 伤害流程（新）

旧的"信号中断 + StatePriority + force_transition"全部删除，改为：

```
HurtBox.damaged 信号
    → HealthComponent.take_damage(damage)                  ← 保留现有连接
        ├─ 扣血
        ├─ if health <= 0: emit died
        └─ else: emit damaged(damage, attacker_pos)
                                    │
DemonSlime2._on_damaged (监听 HealthComponent.damaged) ←──┘
    ├─ bb.last_damage = damage
    ├─ bb.last_attacker_position = pos
    ├─ bb.recently_hit = true
    ├─ bb.poise_broken = _check_poise(damage)
    ├─ bb.evasion_rolled = _check_evasion()
    └─ ai_controller.dispatch(&"damaged")
           → DecisionTable 查 (current_state, damaged) + (*, damaged)
           → 按 priority 降序评估 guard，第一条命中的被选
           → 未命中任何规则 → 静默丢弃（实现"执行中免疫"）
           → 命中 → _change_state(target)
                 例：hit → HitState.enter 读 bb.last_damage，
                     应用 effects、播动画、设 timer
                 → timer 超时 → emit_event(&"hit_recovered")
                 → 命中规则 11/12 → 回到 chase/idle

DemonSlime2._on_died (监听 HealthComponent.died)
    → ai_controller.dispatch(&"died")
    → 命中规则 13 → DeathState
```

**关键点**：
- 反应优先级不由 `StatePriority` 实现，由决策表里规则的 `priority` 字段实现 —— 多条 `from=*, event=damaged` 规则按 priority 排序，第一个 guard 命中的被选
- `HitState` / `StunState` / `CounterState` / `DefendState` / `RollState` 都是普通 State，没有特殊待遇
- "不可打断"的表达 = 决策表里**不注册**对应的事件式转换（如 CounterState 执行期间不注册 `from=counter, event=damaged` 规则，自动免疫新伤害）

---

## 5. DemonSlime2 试点实现

### 5.1 目录结构（继承 AgentAIBase 模板）

```
Scenes/Characters/Bosses/DemonSlime2/
├── DemonSlime2.gd              extends BossBase, 使用 enemy_ai_root 脚本模板
├── DemonSlime2.tscn            ← inherited scene from AgentAIBase.tscn
│                                  根节点 script 覆盖为 BossBase.gd → DemonSlime2.gd
│                                  新增 BossAttackManager / StunState 等子节点
├── AI/
│   ├── DS2DecisionTable.tres   base_table = StandardBossDecision.tres
│   └── Guards/
│       ├── can_cleave.gd       (DS2 特有, 非 stock)
│       ├── can_slam.gd
│       ├── poise_broken.gd
│       ├── evasion_rolled_defend.gd
│       └── evasion_rolled_roll.gd
├── States/                     (DS2 特有状态, 放入 StateMachine 作为 inherited scene 新增子节点)
│   ├── DS2Cleave.gd            播动画 + 生成扇形冲击波 + emit attack_finished
│   ├── DS2Slam.gd              播动画 + 生成 slam 伤害区 + emit attack_finished
│   ├── DS2Counter.gd           反击动作 + emit reaction_finished
│   ├── DS2Defend.gd            格挡动作 + emit reaction_finished
│   └── DS2Roll.gd              翻滚回避 + emit reaction_finished
└── Attacks/                    (效果场景)
    ├── FanShockwave.tscn
    └── SlamImpact.tscn
```

**说明**：
- **Idle / Chase / Hit / Death 从 AgentAIBase 模板继承**，StunState 作为 Boss 额外子节点添加，不在 DS2 目录里重写
- DS2 特有状态（Cleave/Slam/Counter/Defend/Roll）作为 inherited scene 的新增子节点，加入 `StateMachine` 容器
- `DS2DecisionTable.base_table = StandardBossDecision.tres`，只写 16 条增量规则（§14.4）
- **明确放弃**：不在旧 `DemonSlime/` 上修改；不引用旧 DS 状态；如需复用攻击效果 Scene，直接 preload

### 5.2 DS2 决策表规则全表

**规则类型标记**：`event` 列为空 = 条件式规则（AIController safety tick 评估），非空 = 事件式规则（仅在对应 `dispatch` 时评估）。

| # | from | event | to | guard | priority | 说明 |
|---|---|---|---|---|---|---|
| 1 | idle | — | chase | `bb.target_alive and bb.distance_to_target < 600` | 0 | 玩家进入感知范围 |
| 2 | chase | — | idle | `not bb.target_alive or bb.distance_to_target > 700` | 0 | 脱战 |
| 3 | chase | — | cleave | `GuardCanCleave.check(bb)` | 10 | 近战主攻，见 §5.5 |
| 4 | chase | — | slam | `GuardCanSlam.check(bb)` | 20 | Phase 2+ slam 优先级更高 |
| 5 | cleave | attack_finished | chase | — | 0 | 攻击完回追击 |
| 6 | slam | attack_finished | chase | — | 0 | 同上 |
| 7 | * | damaged | counter | `bb.poise_broken` | 30 | Poise 破防反击 |
| 8 | * | damaged | defend | `GuardDefend.check(bb)` | 20 | 闪避命中走 defend |
| 9 | * | damaged | roll | `GuardRoll.check(bb)` | 19 | 闪避命中走 roll |
| 10 | * | damaged | hit | — | 10 | 普通受击兜底 |
| 11 | hit | hit_recovered | chase | `bb.target_alive` | 10 | |
| 12 | hit | hit_recovered | idle | — | 0 | 目标死亡回 idle |
| 13 | * | died | death | — | 100 | 死亡压倒一切 |
| 14 | * | phase_changed | chase | `bb.target_alive` | 50 | Phase 切换重置战斗 |

**Phase 切换**：`BossBase.phase_changed` 信号由 `DemonSlime2._on_phase_changed` 接收 → 调 `ai_controller.dispatch(&"phase_changed")` → 命中规则 14。不再需要 `_get_phase_route`。

**Counter / Defend / Roll 状态的免疫**：这三个状态执行期间，决策表里**没有**任何 `from=counter / from=defend / from=roll` 的 `event=damaged` 规则，因此 dispatch("damaged") 在这些状态下无匹配、静默丢弃 —— 实现"执行中免疫新伤害"的效果。恢复时由各自状态 `emit_event(&"reaction_finished")` 驱动（规则需补：`from=counter/defend/roll, event=reaction_finished, to=chase`，对称三条）。

### 5.3 DS2 State 示例 —— `DS2Chase.gd`

```gdscript
extends State

@export var move_speed: float = 80.0

var _entered_range: bool = false

func enter() -> void:
    _entered_range = false
    if owner_node and "anim_tree" in owner_node:
        owner_node.anim_tree.set("parameters/locomotion/blend_position", Vector2(1, 1))

func physics_update(_delta: float) -> void:
    if not (owner_node is CharacterBody2D):
        return
    var body := owner_node as CharacterBody2D
    var dir: Vector2 = (bb.target_position - body.global_position).normalized()
    body.velocity = dir * move_speed
    body.move_and_slide()
    # 更新面向由 owner 处理

func exit() -> void:
    if owner_node is CharacterBody2D:
        (owner_node as CharacterBody2D).velocity = Vector2.ZERO
```

**注意**：没有任何转换代码。距离、冷却判断**全在 DecisionTable 的 guard 脚本里**。

### 5.4 DS2 Cleave 示例 —— `DS2Cleave.gd`

```gdscript
extends State

@export var cleave_damage: Damage
@export var cleave_cooldown: float = 2.5

var _anim_tree: AnimationTree

func enter() -> void:
    bb.attack_cooldown = cleave_cooldown
    bb.global_cooldown = 0.3
    bb.last_action = &"cleave"
    bb.time_since_last_attack = 0.0
    _anim_tree = owner_node.get_node(^"AnimationTree") if owner_node else null
    if _anim_tree:
        _anim_tree.animation_finished.connect(_on_anim_finished, CONNECT_ONE_SHOT)
        # 触发 cleave 动画
        var pb = _anim_tree.get("parameters/control_sm/playback")
        if pb: pb.start(&"cleave")

func _on_anim_finished(_name: StringName) -> void:
    # 生成扇形冲击波（从 Attacks 目录 preload 场景并实例化）
    # ...
    emit_event(&"attack_finished")

func exit() -> void:
    pass
```

### 5.5 Guard 脚本示例 —— `Guards/can_cleave.gd`

```gdscript
extends RefCounted
class_name GuardCanCleave

static func check(bb: Blackboard) -> bool:
    if bb.attack_cooldown > 0: return false
    if bb.global_cooldown > 0: return false
    if bb.distance_to_target > 250: return false
    if bb.last_action == &"cleave" and bb.time_since_last_attack < 3.0:
        return false
    return true
```

**使用方式**：在 `DS2DecisionTable.tres` 里创建一条 `TransitionRule` 子资源，将其 `guard_script` 字段拖入 `can_cleave.gd`。运行时 `TransitionRule.evaluate(bb)` 会调 `guard_script.check(bb)`。

**注意**：Godot 的 `@export var guard_script: GDScript` 在 Inspector 中允许直接拖放 .gd 文件，被加载为 `GDScript` 资源。静态方法通过 `guard_script.call("check", bb)` 或直接 `guard_script.check(bb)`（GDScript 支持后者）访问。若运行时发现该写法不可用，退路是让 guard_script 持 `class_name` 然后用 `ClassDB.instantiate()`，或改为实例方法（`guard_script.new().check(bb)`）。试点时先按静态调用写，跑起来验证，不行就切换。

### 5.6 DemonSlime2 根脚本

```gdscript
class_name DemonSlime2 extends BossBase

@onready var ai_controller: AIController = $AIController
@onready var health_component: HealthComponent = $HealthComponent

func _ready() -> void:
    super._ready()
    if health_component:
        health_component.damaged.connect(_on_damaged)
        health_component.died.connect(_on_died)
    phase_changed.connect(_on_phase_changed)

func _on_damaged(damage: Damage, attacker_pos: Vector2) -> void:
    var bb := ai_controller.blackboard
    if bb == null: return
    bb.last_damage = damage
    bb.last_attacker_position = attacker_pos
    bb.recently_hit = true
    # Poise / evasion 判定写入 Blackboard 顶层字段
    bb.poise_broken = _check_poise(damage)
    bb.evasion_rolled = _check_evasion()
    ai_controller.dispatch(&"damaged")

func _on_died() -> void:
    ai_controller.dispatch(&"died")

func _on_phase_changed(_new_phase: int) -> void:
    ai_controller.dispatch(&"phase_changed")
```

---

## 6. 删除清单（新代码完成后）

以下内容**在 DS2 试点期间不删**（旧 DemonSlime 还在用），验收通过并全面推广时再清理：

- `Core/StateMachine/BaseState.gd` 中：
  - `enum StatePriority`
  - `can_be_interrupted` 导出字段
  - `try_attack / try_chase / decide_next_state / evaluate_transition / _resolve_eval_state`
  - `on_damaged` 默认实现
  - `can_transition_to` 优先级检查
- `Core/StateMachine/BaseStateMachine.gd` 中：
  - `force_transition`
  - `recover_from_stun`
  - `_on_state_transition` 的优先级检查
  - `last_damage / last_attacker_position` 字段（迁移到 Blackboard）
- `Core/StateMachine/CommonStates/` 全部（ChaseState / AttackState / IdleState / WanderState / HitState / SpecialSkillState）
- `Scenes/Characters/Bosses/Shared/BossBaseState.gd`：`evaluate_combat_transition`
- `Scenes/Characters/Bosses/Shared/BossStateMachine.gd`：`_on_owner_damaged` 的 poise/evasion 分派
- 所有现存 DS / BK / Cyclops / 普通 Enemy 的状态文件

**迁移顺序**：
1. DS2 试点（本 spec）
2. 验证通过 → 推广到 Cyclops、BladeKeeper（独立 spec）
3. 推广到普通 Enemy（CommonStates 废弃）
4. 旧 CommonStates 代码删除

---

## 7. 测试策略（DS2 试点）

### 7.1 单元测试（GUT）

- `test_blackboard.gd`：验证 Pull 更新、字段镜像正确
- `test_decision_table.gd`：
  - 事件式规则查找、priority 排序
  - 条件式规则查找
  - ANYSTATE 通配匹配
- `test_transition_rule.gd`：guard 脚本加载 + 调用
- `test_ai_controller.gd`（mock owner + states）：
  - 初始状态进入
  - dispatch 触发状态切换
  - 条件式规则在 safety tick 时触发
  - guard 阻挡不该切的转换

### 7.2 集成测试

- `test_ds2_integration.gd`：
  - Spawn DemonSlime2 + Player mock
  - 验证 Idle → Chase（玩家进入 detection）
  - 验证 Chase → Cleave（进入距离 + 冷却 OK）
  - 验证 Cleave → Chase（attack_finished 事件）
  - 验证伤害 → Hit → Chase
  - 验证 HP → 0 → Death
  - 验证 Phase 切换后攻击池/guard 变化

### 7.3 运行时验证

- `mcp__godot__run_project` 启动游戏
- `mcp__godot__get_debug_output` 检查 `[AIController] → xxx` 日志链
- 手动打几拳验证 Hit 反应、CD、Phase 切换

---

## 8. 风险与已知局限

1. **Guard 用 GDScript 脚本**：比字符串表达式麻烦（要建 .gd 文件），但可调试、类型安全、支持断点。可接受。
2. **条件式规则 safety tick 节奏 0.2s**：对快节奏战斗够用；如果出现"玩家瞬移进攻击范围但 DS 没反应"类问题，可考虑在 `_on_player_moved` 之类信号里强制 `dispatch(&"reeval")`。
3. **DecisionTable 编辑体验**：初版靠 Godot Inspector 编辑 `.tres`，列数多时不好看。后续可做自定义 Inspector 插件（独立 spec）。
4. **事件命名约定缺失**：本 spec 使用 `attack_finished / hit_recovered / damaged / died / phase_changed / in_attack_range / target_lost`。需写到 `Core/AI/AIEvents.gd` 作为 const 常量集中管理，防拼写错。

---

## 9. 交付物

### 9.1 核心类 (Core/AI/)
1. `Blackboard.gd` + .uid
2. `TransitionRule.gd` + .uid
3. `DecisionTable.gd` + .uid（含 §14 继承机制）
4. `State.gd` + .uid
5. `AIController.gd` + .uid
6. `AIEvents.gd`（事件常量）

### 9.2 Stock 状态库 (Core/AI/Stock/)
7. `IdleState.gd` / `ChaseState.gd` / `WanderState.gd` / `HitState.gd` / `StunState.gd` / `DeathState.gd`

### 9.3 Stock Guard 库 (Core/AI/Guards/)
8. `guard_target_alive.gd` / `guard_target_lost.gd` / `guard_in_detection_range.gd` / `guard_in_attack_range.gd` / `guard_in_melee_range.gd` / `guard_attack_cooldown_ready.gd` / `guard_global_cooldown_ready.gd` / `guard_hp_below_threshold.gd` / `guard_stun_applied.gd`

### 9.4 Stock 决策表 (Core/AI/Templates/)
9. `StandardEnemyDecision.tres`
10. `PatrolEnemyDecision.tres`
11. `StandardBossDecision.tres`

### 9.5 场景模板 (Scenes/Characters/Templates/)
12. `AgentAIBase.tscn`（单一模板，预装 AIController + StateMachine + 4 stock 状态；Boss 通过继承后覆盖 script + 加子节点实现）

### 9.6 Godot 脚本模板 (script_templates/)
14. `Node/ai_state.gd`
15. `RefCounted/ai_guard.gd`
16. `CharacterBody2D/enemy_ai_root.gd`

### 9.7 DemonSlime2 试点 (Scenes/Characters/Bosses/DemonSlime2/)
17. 完整目录，详见 §5.1

### 9.8 测试 (Tests/AI/)
18. `test_blackboard.gd` / `test_decision_table.gd`（含继承） / `test_transition_rule.gd` / `test_ai_controller.gd` / `test_stock_states.gd` / `test_ds2_integration.gd`

### 9.9 文档
19. 本 spec 实现完成后由 `context-updater` skill 更新 `CLAUDE.md` Architecture 章节、`docs/class-diagrams.md`、`docs/architecture-diagrams.md`

---

## 10. 未来扩展接口（本 spec 不做）

- StatusEffectComponent（DoT / Buff / Debuff）—— 独立 spec，会用到 Blackboard.custom 传递
- DecisionTable 的自定义 Inspector 插件
- Blackboard 的信号式变化通知（目前是 Pull，未来可加 `bb_changed` 信号让 AIController 立即重评估而非等 safety tick）
- 嵌套 AIController（LimboAI 式 HSM 嵌套），用于表达多层"战斗模式"

---

## 11. 场景模板架构（Template Inheritance）

参考 LimboAI 的 `agent_base.tscn` 模式：新敌人通过继承共享模板，继承所有基础设施 + 预装 AI 管线，只需调整贴图/数值/添加特有攻击状态即可运行。

### 11.1 单一模板 `AgentAIBase.tscn`

新架构下 AI 层通过 AIController 完全统一，Boss 和 Enemy 差异仅在根脚本和可选组件，**不需要两套模板**：

| Boss 与 Enemy 的差异 | 怎么处理 |
|---|---|
| 根脚本（BossBase vs EnemyBase） | 继承场景里**覆盖根节点 script** |
| BossAttackManager | 需要时**手动加子节点** |
| Phase 系统 | BossBase 的信号，根脚本里 `dispatch("phase_changed")` |
| Poise / Evasion | 根脚本 `_on_damaged` 里按需实现 |
| StunState | 需要时加到 StateMachine（任何 enemy 也可以有 stun） |
| AnimatedSprite2D | 模板默认 Sprite2D；需要 AnimatedSprite2D 时隐藏 Sprite2D 并新增 |

### 11.2 AgentAIBase.tscn 节点结构

```
AgentAIBase (CharacterBody2D, script=Core/Characters/EnemyBase.gd, groups=["enemy"])
├── Sprite2D                          空 texture, 待子场景覆盖
├── AnimationPlayer
├── AnimationTree
│     参数路径约定:
│       parameters/locomotion/blend_position  (Vector2, 移动混合)
│       parameters/control_sm/playback        (StateMachine, hit/stun/attack 动画)
│       parameters/control_blend/blend_amount (float, locomotion ↔ control_sm)
│       parameters/attack_oneshot/request     (OneShot, 攻击动画触发)
├── CollisionShape2D                  空 shape, 待子场景覆盖
├── FloorCollision                    CollisionShape2D
├── HurtBoxComponent (Area2D)
│   └── CollisionShape2D
├── HitBoxComponent (Area2D)
│   └── CollisionShape2D
├── HealthComponent                   max_health=100 默认
├── HealthBar (ProgressBar)
├── DamageNumbersAnchor (Node2D)
└── AIController (Node)
     @export decision_table = Core/AI/Templates/StandardEnemyDecision.tres  (默认)
     @export initial_state_name = &"idle"
     └── StateMachine (Node)          纯容器，不带脚本
          ├── IdleState   (script=Core/AI/Stock/IdleState.gd)
          ├── ChaseState  (script=Core/AI/Stock/ChaseState.gd)
          ├── HitState    (script=Core/AI/Stock/HitState.gd)
          └── DeathState  (script=Core/AI/Stock/DeathState.gd)
```

**Boss 场景在继承模板后额外操作**：
1. 根节点 script 覆盖为 `BossBase.gd`
2. 添加 `BossAttackManager` 子节点（如需攻击池）
3. 添加 `StunState` 到 StateMachine（如需眩晕）
4. `AIController.decision_table` 改指向 `StandardBossDecision.tres` 或自定义表
5. HealthBar 尺寸/样式按需覆盖

### 11.3 模板里的 Resource 绑定约定

Godot 的 `@export var decision_table: DecisionTable` 字段在模板 `.tscn` 里通过 `ExtResource` 绑定到具体 .tres。**注意**：继承模板的子场景如果想换一张决策表，必须在子场景里显式覆盖该字段，不能靠"清空"—— 清空会变成 null 而不是"回到默认"。这是 Godot inherited scene 的固有行为，spec 不做特殊处理，工作流文档里会提示。

### 11.4 旧模板处理

`Scenes/Characters/Templates/EnemyBase.tscn` / `BossBase.tscn` **保留不动**（现有敌人还在用），在模板顶部的 `_comment` 节点或 README 里标注 `@deprecated — 新敌人请使用 EnemyAIBase.tscn`。未来全面迁移完成后再删。

---

## 12. Core/AI 目录结构（新）

```
Core/AI/
├── Blackboard.gd                     §3.1
├── TransitionRule.gd                 §3.2
├── DecisionTable.gd                  §3.3  + §14 继承机制
├── State.gd                          §3.4
├── AIController.gd                   §3.5
├── AIEvents.gd                       事件常量集中
│
├── Stock/                            预装的通用状态（模板内被引用）
│   ├── IdleState.gd
│   ├── ChaseState.gd
│   ├── WanderState.gd               (PatrolEnemy 用)
│   ├── HitState.gd
│   ├── StunState.gd                  (Boss 用)
│   └── DeathState.gd
│
├── Guards/                           通用 guard 函数库，规则可直接引用
│   ├── guard_target_alive.gd
│   ├── guard_target_lost.gd
│   ├── guard_in_detection_range.gd
│   ├── guard_in_attack_range.gd
│   ├── guard_in_melee_range.gd
│   ├── guard_attack_cooldown_ready.gd
│   ├── guard_global_cooldown_ready.gd
│   └── guard_hp_below_threshold.gd   (带参数版本，见 §14)
│
└── Templates/                        stock 决策表
    ├── StandardEnemyDecision.tres    idle/chase/hit/death 基础
    ├── PatrolEnemyDecision.tres      + wander/patrol
    └── StandardBossDecision.tres     + stun, phase_changed
```

### 12.1 AIEvents.gd

```gdscript
class_name AIEvents

# 生命周期事件
const EV_DAMAGED        := &"damaged"
const EV_DIED           := &"died"
const EV_PHASE_CHANGED  := &"phase_changed"

# 状态完成事件
const EV_ATTACK_FINISHED := &"attack_finished"
const EV_HIT_RECOVERED   := &"hit_recovered"
const EV_STUN_RECOVERED  := &"stun_recovered"
const EV_REACTION_DONE   := &"reaction_finished"

# 感知事件（可选，由外部系统 dispatch）
const EV_TARGET_LOST     := &"target_lost"
const EV_TARGET_SPOTTED  := &"target_spotted"
```

状态和决策表规则都用常量，防拼写错。

### 12.2 StandardEnemyDecision.tres 规则表

| # | from | event | to | guard | priority |
|---|---|---|---|---|---|
| 1 | idle | — | chase | `GuardTargetInDetectionRange` | 0 |
| 2 | chase | — | idle | `GuardTargetLost` | 0 |
| 3 | * | damaged | hit | — | 10 |
| 4 | hit | hit_recovered | chase | `GuardTargetAlive` | 10 |
| 5 | hit | hit_recovered | idle | — | 0 |
| 6 | * | died | death | — | 100 |

新敌人继承此表后，通过"扩展"（§14）添加攻击规则（例：`chase → my_attack, guard=GuardInMeleeRange`）。

### 12.3 StandardBossDecision.tres 规则表

在 StandardEnemyDecision 基础上 +：

| # | from | event | to | guard | priority |
|---|---|---|---|---|---|
| 7 | * | phase_changed | chase | `GuardTargetAlive` | 50 |
| 8 | * | damaged | stun | `GuardStunApplied` | 15 |
| 9 | stun | stun_recovered | chase | `GuardTargetAlive` | 10 |

---

## 13. 新敌人创作工作流

目标：< 10 分钟从零到可运行。

### 13.1 普通敌人（无攻击）

1. Godot 编辑器：右键 `Scenes/Characters/Enemies/` → **New Inherited Scene** → 选 `AgentAIBase.tscn`
2. 根节点重命名 `NewEnemy`
3. 设置 `Sprite2D.texture` = 贴图
4. 调整 `HealthComponent.max_health`
5. 调整 `CollisionShape2D` / `HurtBoxComponent/CollisionShape2D` / `HitBoxComponent/CollisionShape2D` 尺寸
6. 保存为 `Scenes/Characters/Enemies/NewEnemy/NewEnemy.tscn`

此时敌人已经可以跑：待机 → 玩家进入 detection → 追击 → 受击 → 死亡。**零代码。**

### 13.2 带特殊攻击的敌人

在 13.1 基础上继续：

7. 右键 `Scenes/Characters/Enemies/NewEnemy/` → New Script → 选脚本模板 **"AI State"** → 命名 `NewEnemyAttack.gd`
8. 实现 `enter() / physics_update() / exit()`，在动画结束时 `emit_event(AIEvents.EV_ATTACK_FINISHED)`
9. 把 `NewEnemyAttack` 作为 `StateMachine` 的子节点添加（名字 = `"attack"`）
10. 右键 `Core/AI/Templates/StandardEnemyDecision.tres` → Duplicate → `NewEnemyDecision.tres`
11. 打开 `NewEnemyDecision.tres`，添加一条 `TransitionRule`:
    - `from = chase`, `to = attack`, `guard_script = GuardInMeleeRange`
12. 可选：添加 `from = attack, event = attack_finished, to = chase`（若不用 stock 规则 5 的回退路径）
13. 把 `AIController.decision_table` 改指向 `NewEnemyDecision.tres`

运行验证。**加一个攻击约 5-10 分钟。**

### 13.3 Boss

流程同 13.2，但：
- Step 1 选 `AgentAIBase.tscn`，根节点 script 覆盖为 `BossBase.gd`
- 添加 `BossAttackManager` / `StunState` 等 Boss 特有子节点
- Step 10 duplicate `StandardBossDecision.tres`
- 配置 `BossAttackManager.phase_configs`（多阶段攻击池，复用现有机制）
- Boss 根脚本继承 `BossBase`，监听 `phase_changed` → `ai_controller.dispatch(AIEvents.EV_PHASE_CHANGED)`

---

## 14. DecisionTable 继承机制

### 14.1 动机

- DS2 决策表 90% 规则和 StandardBossDecision 一样（idle/chase/hit/stun/death/phase_changed）
- 不希望复制粘贴，否则 stock 规则更新时所有 Boss 都要手动同步

### 14.2 实现

`DecisionTable.gd` 新增：

```gdscript
@export var base_table: DecisionTable = null   # 可选基表
@export var rules: Array[TransitionRule] = []

var _cached_rules: Array[TransitionRule] = []
var _is_cached: bool = false

## 返回合并后的完整规则（递归合并 base）
func get_effective_rules() -> Array[TransitionRule]:
    if _is_cached:
        return _cached_rules
    var merged: Array[TransitionRule] = []
    if base_table:
        merged.append_array(base_table.get_effective_rules())
    merged.append_array(rules)
    # 注：不做去重，让子表规则有机会"影子覆盖"同 from+event 的父规则
    # AIController 查询时按 priority 排序后取第一条命中的
    _cached_rules = merged
    _is_cached = true
    return _cached_rules
```

`AIController` 调用 `decision_table.get_effective_rules()` 而非 `rules` 直接读。

### 14.3 子表如何覆盖父表规则

子表加一条 `from=chase, event="", to=cleave, priority=20`；父表如果有 `from=chase, event="", to=attack, priority=10` —— 合并后两条都在，AIController 按 priority 降序评估，子表优先。**不主动删除父规则**（避免隐式破坏）。

如需**完全屏蔽**父规则：子表加一条同 `from + event` 但 `to` 指向 noop、priority 更高的规则，或者 spec 后续引入 `@export var disabled_events: Array[StringName]` 显式禁用（本版本不做）。

### 14.4 DS2DecisionTable.tres 示例

```
base_table: StandardBossDecision.tres

rules (本表新增):
├─ chase → cleave  (cond, GuardCanCleave, priority=10)
├─ chase → slam    (cond, GuardCanSlam,   priority=20)
├─ cleave → chase  (event=attack_finished, priority=0)
├─ slam → chase    (event=attack_finished, priority=0)
├─ * → counter     (event=damaged, guard=GuardPoiseBroken, priority=30)
├─ * → defend      (event=damaged, guard=GuardEvasionRolledDefend, priority=20)
├─ * → roll        (event=damaged, guard=GuardEvasionRolledRoll, priority=19)
├─ counter → chase (event=reaction_finished, priority=0)
├─ defend → chase  (event=reaction_finished, priority=0)
└─ roll → chase    (event=reaction_finished, priority=0)
```

Stock 的 `hit / death / idle ↔ chase / phase_changed` 规则全部从父表继承，DS2 只写 16 条增量。

---

## 15. 脚本模板（script_templates/）

Godot 的 `script_templates/` 目录允许用户在"新建脚本"对话框里选预定义骨架。新增 3 个：

### 15.1 `script_templates/Node/ai_state.gd`

```gdscript
# meta-description: AI State (pure executor, emits events)
extends State

func enter() -> void:
    pass

func physics_update(_delta: float) -> void:
    pass

func exit() -> void:
    pass
```

### 15.2 `script_templates/RefCounted/ai_guard.gd`

```gdscript
# meta-description: AI Guard (static check function for DecisionTable rules)
extends RefCounted

static func check(bb: Blackboard) -> bool:
    return true
```

### 15.3 `script_templates/CharacterBody2D/enemy_ai_root.gd`

```gdscript
# meta-description: Enemy/Boss root script with AI wiring
extends EnemyBase  # or BossBase

@onready var ai_controller: AIController = $AIController
@onready var health_component: HealthComponent = $HealthComponent

func _ready() -> void:
    super._ready()
    if health_component:
        health_component.damaged.connect(_on_damaged)
        health_component.died.connect(_on_died)

func _on_damaged(damage: Damage, attacker_pos: Vector2) -> void:
    var bb := ai_controller.blackboard
    if bb == null: return
    bb.last_damage = damage
    bb.last_attacker_position = attacker_pos
    bb.recently_hit = true
    ai_controller.dispatch(AIEvents.EV_DAMAGED)

func _on_died() -> void:
    ai_controller.dispatch(AIEvents.EV_DIED)
```


