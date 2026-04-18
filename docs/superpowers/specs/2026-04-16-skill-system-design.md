# Skill System — 数据驱动技能选择与执行架构

- **日期**: 2026-04-16
- **范围**:
  - 新建 Skill / ComboSkill Resource、SkillSet 选择器
  - 新建 AttackDispatcher / GenericAttackState / ComboState 通用状态
  - 扩展 AIController（current_skill、goto、打断检查）
  - 扩展 AgentAIBase（skill_set、sensor、damage_recent）
  - 更新 AgentAIBase.tscn 模板场景
  - 试点迁移 DemonSlime2，删除 DS2Cleave / DS2Slam
- **设计目标**: 用 Resource 声明技能元数据，SkillSet 统一过滤+加权选择+冷却管理，Guard 即场景定义，通用 State 覆盖 80% 执行需求
- **非目标**: BladeKeeper 迁移（独立 spec）、Utility AI 评分系统、HSM 嵌套

---

## 1. 背景与动机

### 当前痛点

1. **`last_action` 机制缺陷**：DS2 用 `bb.set_var(&"last_action", &"cleave")` + guard 检查防连续重复。但 phase 0 只有 cleave 一种攻击时，`last_action == "cleave"` 永远成立，boss 打一次就再也不攻击。

2. **每招一条规则 + 一个 guard**：转换表里 `chase→cleave` 和 `chase→slam` 各写一条规则、各写一个 guard 方法。新增招式需改转换表 + 写 guard + 写 State，修改点分散。

3. **缺乏情境适配**：没有机制表达「远距离优先远程攻击」「被打重了触发闪避」等战术行为。旧版 BladeKeeper 通过 BossPhaseConfig 的 chase_attacks/retreat_attacks/counter 子池半手工实现，和新 AI 架构不兼容。

4. **combo 实现不统一**：BladeKeeper 的 BKAttack（327 行）内部硬编码多段攻击逻辑，无法复用。

5. **攻击冷却冗余**：`attack_cooldown` 和 `global_cooldown` 语义重叠，per-attack 冷却需求被 `last_action` hack 代替。

### 设计原则

- **数据驱动**：技能参数用 Resource .tres 文件声明，Inspector 可编辑
- **通用优先**：GenericAttackState + ComboState 覆盖多数场景，自定义 State 只在通用方案不够时使用
- **Guard 即场景**：「远程优先」「防御反应」等情境通过 guard 方法 + pick_tagged 表达，转换表 priority 决定优先级
- **不引入新概念**：复用现有 Blackboard、转换表、事件机制，只扩展不重构

---

## 2. 架构概览

```
Boss 主脚本
 ├─ _setup_skill_set()     → SkillSet.setup([.tres, .tres, ...])
 ├─ _setup_transitions()   → 转换表（guard 调 SkillSet.pick/pick_tagged）
 └─ guard / precondition 方法

          ┌─────────────┐
  事件/轮询 → │ 转换表 guard │ → pick/pick_tagged → pending_skill
          └──────┬──────┘
                 ↓
         ┌──────────────┐
         │ Dispatcher   │ → 读 pending_skill → start_cooldown → goto(state)
         └──────┬───────┘
                ↓
    ┌───────────┴───────────┐
    │                       │
GenericAttackState      ComboState
    │                       │
 播动画                  按序播 N 段动画
 (AnimationPlayer        (sequence[i].params)
  method call track       ↓
  触发 HurtBox/Spawn)    每步结束 → 下一步
    │                       │
    └───────┬───────────────┘
            ↓
   EV_ATTACK_FINISHED → current_skill=null → 回 chase/idle
```

三层职责不变，新增 SkillSet 作为决策层辅助：

| 层 | 组件 | 职责 |
|---|---|---|
| **数据层** | Blackboard + Skill Resource | 战斗状态 + 技能声明 |
| **决策层** | AIController + SkillSet | 转换表匹配 + 技能过滤/选择/冷却 |
| **执行层** | GenericAttackState / ComboState | 播动画、生成投射物/实体 |

---

## 3. 核心类设计

### 3.1 Skill Resource

**文件**：`Core/AI/Skill.gd`

```gdscript
class_name Skill extends Resource

# ==== 选择层（SkillSet 读取）====
@export var id: StringName = &""
@export var state_name: StringName = &""
@export var cooldown: float = 1.5
@export var weight: int = 1
@export var min_phase: int = 0
@export var max_phase: int = -1     # -1 = 不限
@export var min_range: float = 0.0  # 0 = 不限
@export var max_range: float = 0.0  # 0 = 不限
@export var tags: Array[StringName] = []
@export var precondition_method: StringName = &""

# ==== 控制层（AIController 读取）====
## false = 执行期间只有 EV_DIED 可打断
@export var interruptible: bool = true

# ==== 执行层（State 读取）====
## 状态专属参数字典
## 常见 key：
##   animation: StringName    动画名
##   speed: float             移动速度
##   direction: StringName    "forward"|"backward"|"toward_target"|"away_from_target"
##   projectile_scene: PackedScene   投射物场景
##   spawn_scene: PackedScene        生成物场景（陷阱、特效）
##   spawn_offset: Vector2           生成偏移
##   global_cooldown: float          攻击结束后写入的全局后摇
@export var params: Dictionary = {}
```

**设计要点**：

- **纯数据**：Skill 不含执行逻辑，只描述选择条件 + 执行参数
- **state_name 字符串解耦**：通过名称查找 AIState 节点，便于 .tres 序列化
- **距离双向**：`max_range > 0` 表示太远不打，`min_range > 0` 表示太近不打
- **precondition 用方法名**：Boss 脚本里定义 `_precond_xxx` 方法，不引入表达式 DSL
- **tags 开放**：Array[StringName]，不做 enum，项目演进时自由新增
- **无 hit_frame**：伤害触发由 AnimationPlayer 的 method call track 驱动，不在 Skill 里定义帧数
- **无 lock_flags**：状态切换后原状态（如 chase）不再执行，无需锁定移动/朝向。`interruptible` 单一字段足够

### 3.2 ComboSkill

**文件**：`Core/AI/ComboSkill.gd`

```gdscript
class_name ComboSkill extends Skill

## 组合技步骤：每步是一个 Skill Resource
## ComboState 读取 sequence[i].params 按序播放，不调用子 Skill 的 State
@export var sequence: Array[Skill] = []

## 每步之间的间隔（秒）
@export var gap: float = 0.1

func _init() -> void:
    interruptible = false
    state_name = &"combo"
```

**combo 执行模型**：ComboState 读取 sequence 的 params（animation、speed 等）按序播放。子 Skill 的 `state_name` 在 combo 内被忽略——它仅在子 Skill 被单独使用时生效。这避免了嵌套状态机的复杂度（spec 已明确排除 HSM 嵌套）。

**子 Skill 引用方式**：支持混用——引用独立 .tres 文件（复用）或 inline 匿名 sub-resource（combo 专用步骤）。Godot Resource 天然支持两种。

**子 Skill 选择层字段全部失效**：combo 是否能释放只看顶层 ComboSkill 自身的 cooldown / phase / range / precondition。子 Skill 仅作为"动画+位移参数容器"，其选择层字段在 combo 执行时全部被忽略：

| Skill 字段 | 在 combo 子步骤中是否生效 |
|---|---|
| `id` | 仅作为标识，不参与 cooldown 跟踪 |
| `cooldown` | ❌ 忽略 |
| `weight` | ❌ 忽略 |
| `min_phase` / `max_phase` | ❌ 忽略 |
| `min_range` / `max_range` | ❌ 忽略 |
| `precondition_method` | ❌ 忽略 |
| `interruptible` | ❌ 忽略（用 ComboSkill 自己的） |
| `state_name` | ❌ 忽略（被 ComboState 接管） |
| `params.*` | ✅ 全部生效（animation / speed / direction / projectile_scene 等）|

**机制原因**：`SkillSet._cooldowns` 只在 `setup()` 中为顶层注册技能创建条目，子 Skill 不在内；`AttackDispatcher` 仅对它选中的顶层技能调 `start_cooldown(skill.id)`；`ComboState._play_step()` 只读子 Skill 的 params，不调 `start_cooldown`、不走 `_filter`。所以即便子 Skill 复用了某个顶层 .tres（共享 id），combo 执行也不会触发该顶层技能的冷却。

**实务含义**：

- 想让一段动画"既能单刷又能进 combo"，**直接复用 .tres 安全**——单刷时正常计 cd，combo 内不影响顶层 cd。
- 想让 combo 在"某个子步骤的资源刚被单刷过"时仍可释放——**默认就是这样**，不需要额外处理。
- 不要试图给子步骤设独立 cooldown 来限制重复——**不会生效**；要做这种约束，把 combo 拆成多个独立顶层 Skill，用转换表/guard 串联。

### 3.3 SkillSet

**文件**：`Core/AI/SkillSet.gd`

```gdscript
class_name SkillSet extends RefCounted

## 技能池管理器：过滤 → 加权选择 → 冷却管理

var _skills: Array[Skill] = []
var _cooldowns: Dictionary = {}   # { skill.id: float }
```

#### 核心 API

```gdscript
## 初始化技能池
func setup(skills: Array[Skill]) -> void:
    _skills = skills
    for s in skills:
        _cooldowns[s.id] = 0.0

## 从可用技能中加权随机选一个
func pick(boss_ref: Node, bb: Blackboard) -> Skill:
    var pool := _filter(boss_ref, bb, false)
    if pool.is_empty():
        return null
    return _weighted_pick(pool)

## 按 tag 过滤后选（用于情境触发）
func pick_tagged(tag: StringName, boss_ref: Node, bb: Blackboard) -> Skill:
    var pool := _filter(boss_ref, bb, true).filter(
        func(s): return tag in s.tags
    )
    if pool.is_empty():
        return null
    return _weighted_pick(pool)

## 查询是否有任何技能可用
func has_available(boss_ref: Node, bb: Blackboard) -> bool:
    return not _filter(boss_ref, bb, false).is_empty()

## 触发冷却
func start_cooldown(skill_id: StringName) -> void:
    var s := _find_skill(skill_id)
    if s:
        _cooldowns[s.id] = s.cooldown

## 每帧扣减冷却
func tick(delta: float) -> void:
    for id in _cooldowns:
        if _cooldowns[id] > 0:
            _cooldowns[id] = maxf(_cooldowns[id] - delta, 0.0)
```

#### 过滤逻辑

```gdscript
func _filter(boss_ref: Node, bb: Blackboard, include_zero_weight: bool) -> Array[Skill]:
    var phase: int = bb.get_var(&"current_phase", 0)
    var dist: float = bb.get_var(&"distance", INF)
    var result: Array[Skill] = []
    for s in _skills:
        if _cooldowns.get(s.id, 0.0) > 0:
            continue
        if phase < s.min_phase:
            continue
        if s.max_phase >= 0 and phase > s.max_phase:
            continue
        if s.max_range > 0 and dist > s.max_range:
            continue
        if s.min_range > 0 and dist < s.min_range:
            continue
        if not include_zero_weight and s.weight <= 0:
            continue
        if s.precondition_method != &"" and boss_ref.has_method(s.precondition_method):
            if not boss_ref.call(s.precondition_method):
                continue
        result.append(s)
    return result
```

#### 加权随机

```gdscript
func _weighted_pick(pool: Array[Skill]) -> Skill:
    var total := 0
    for s in pool:
        total += maxi(s.weight, 1)
    var roll := randi() % total
    var acc := 0
    for s in pool:
        acc += maxi(s.weight, 1)
        if roll < acc:
            return s
    return pool.back()

func _find_skill(id: StringName) -> Skill:
    for s in _skills:
        if s.id == id:
            return s
    return null
```

##### 算法原理（CDF 反演抽样）

把每个技能的 weight 想象成数轴 `[0, total)` 上一段长度等于 weight 的区间，`randi() % total` 在数轴上均匀掷点，落入哪一段就选哪个：

```
weights:   cleave=5  combo=2     total=7
区间:    [0────────────5)[5──6)
roll:     0 1 2 3 4    5 6
选中:     cleave×5     combo×2
```

每个技能被选中的概率 = 自己的 weight / total。

##### 概率示例（cleave + combo_2hit）

| 技能 | weight | 区间 | 概率 |
|---|---|---|---|
| cleave | 5 | [0,5) | 5/7 ≈ **71.4%** |
| combo_2hit | 2 | [5,7) | 2/7 ≈ **28.6%** |

##### 关键性质

1. **顺序无关**：池的遍历顺序只影响"哪个 roll 值映射到哪个技能"，不影响每个技能的子区间长度，所以边际概率不变。把高 weight 技能排前可以少几次循环迭代，但仅是性能微优化。
2. **weight=0 兜底为 1**：`maxi(s.weight, 1)` 保证 `pick_tagged` 路径下 weight=0 的技能（如 retreat）也能被选中，概率等同 weight=1。普通 `pick()` 路径已先在 `_filter` 中剔除 weight≤0，不受兜底影响。
3. **均匀整数掷点**：`randi() % total` 是均匀离散分布，无浮点累积误差，可重现。
4. **过滤先于加权**：进入 `_weighted_pick` 的池已被 `_filter` 按冷却/phase/距离/precondition 过滤，权重只决定"可选项之间的相对偏好"。

#### 与 global_cooldown 的关系

`global_cooldown` 保留在 Blackboard 上，由 AgentAIBase 统一 tick。SkillSet 不管它。Guard 先检查 `global_cooldown <= 0`，再查 `skill_set.has_available()`。两层门控：全局后摇 → per-skill 冷却。

---

## 4. 通用 State

### 4.1 AttackDispatcher（路由状态）

**文件**：`Core/AI/States/AttackDispatcher.gd`

```gdscript
class_name AttackDispatcher extends AIState

## 纯路由：读 pending_skill → 设 current_skill → 跳转目标状态

func _enter(_msg := {}) -> void:
    var skill: Skill = ai.blackboard.get_var(&"pending_skill")
    if not skill:
        ai.dispatch(AIEvents.EV_ATTACK_FINISHED)
        return
    ai.current_skill = skill
    owner.skill_set.start_cooldown(skill.id)
    ai.goto(skill.state_name)
```

### 4.2 GenericAttackState（通用攻击执行器）

**文件**：`Core/AI/States/GenericAttackState.gd`

覆盖场景：普通近战、退后闪避、远程投射等——只要「播动画 + 可选位移 + 可选生成物 + 动画结束退出」。

```gdscript
class_name GenericAttackState extends AIState

func _enter(_msg := {}) -> void:
    var skill := ai.current_skill
    # 播放动画
    var anim = skill.params.get(&"animation", &"")
    if anim and owner.anim_player:
        owner.anim_player.play(anim)
        owner.anim_player.animation_finished.connect(_on_done, CONNECT_ONE_SHOT)
    # 可选位移
    var spd = skill.params.get(&"speed", 0.0)
    if spd > 0:
        var dir_key = skill.params.get(&"direction", &"forward")
        owner.velocity.x = _resolve_direction(dir_key) * spd

func _on_done(_anim_name: StringName) -> void:
    # 写入全局后摇
    var gcd = ai.current_skill.params.get(&"global_cooldown", 0.3)
    ai.blackboard.set_var(&"global_cooldown", gcd)
    ai.current_skill = null
    ai.dispatch(AIEvents.EV_ATTACK_FINISHED)

## 动画 method call track 调用：生成投射物
func spawn_projectile() -> void:
    var skill := ai.current_skill
    var scene: PackedScene = skill.params.get(&"projectile_scene")
    if not scene:
        return
    var proj := scene.instantiate()
    owner.get_tree().root.add_child(proj)
    proj.global_position = owner.global_position + skill.params.get(&"spawn_offset", Vector2.ZERO)
    var target_pos = ai.blackboard.get_var(&"target_position", owner.global_position)
    if proj.has_method(&"set_direction"):
        proj.set_direction((target_pos - proj.global_position).normalized())

## 动画 method call track 调用：生成实体（陷阱、特效等）
func spawn_entity() -> void:
    var skill := ai.current_skill
    var scene: PackedScene = skill.params.get(&"spawn_scene")
    if not scene:
        return
    var entity := scene.instantiate()
    owner.get_tree().root.add_child(entity)
    entity.global_position = owner.global_position + skill.params.get(&"spawn_offset", Vector2.ZERO)

func _resolve_direction(dir_key: StringName) -> float:
    match dir_key:
        &"forward":
            return 1.0 if not owner.sprite.flip_h else -1.0
        &"backward":
            return -1.0 if not owner.sprite.flip_h else 1.0
        &"toward_target":
            var tp = ai.blackboard.get_var(&"target_position", owner.global_position)
            return sign(tp.x - owner.global_position.x)
        &"away_from_target":
            var tp = ai.blackboard.get_var(&"target_position", owner.global_position)
            return -sign(tp.x - owner.global_position.x)
    return 0.0
```

**params key 约定**：

| Key | 类型 | 默认 | 行为 |
|---|---|---|---|
| `animation` | StringName | 必填 | AnimationPlayer 动画名 |
| `speed` | float | 0 | >0 时设 velocity.x |
| `direction` | StringName | "forward" | 方向解析 |
| `projectile_scene` | PackedScene | null | 由动画 method call 触发 spawn_projectile() |
| `spawn_scene` | PackedScene | null | 由动画 method call 触发 spawn_entity() |
| `spawn_offset` | Vector2 | (0,0) | 生成偏移 |
| `global_cooldown` | float | 0.3 | 攻击结束写入全局后摇 |

### 4.3 ComboState（组合技执行器）

**文件**：`Core/AI/States/ComboState.gd`

```gdscript
class_name ComboState extends AIState

var _combo: ComboSkill
var _step: int = 0
var _waiting_gap: bool = false
var _gap_timer: float = 0.0

func _enter(_msg := {}) -> void:
    _combo = ai.current_skill as ComboSkill
    if not _combo or _combo.sequence.is_empty():
        _finish()
        return
    _step = 0
    _play_step()

func _physics_process_state(delta: float) -> void:
    if _waiting_gap:
        _gap_timer -= delta
        if _gap_timer <= 0:
            _waiting_gap = false
            _play_step()

func _play_step() -> void:
    var sub_skill: Skill = _combo.sequence[_step]
    var anim_name = sub_skill.params.get(&"animation", &"")
    if anim_name and owner.anim_player:
        owner.anim_player.play(anim_name)
        if not owner.anim_player.animation_finished.is_connected(_on_sub_anim_done):
            owner.anim_player.animation_finished.connect(_on_sub_anim_done)
    var spd = sub_skill.params.get(&"speed", 0.0)
    if spd > 0:
        var dir_key = sub_skill.params.get(&"direction", &"forward")
        owner.velocity.x = _resolve_direction(dir_key) * spd

func _on_sub_anim_done(_anim_name: StringName) -> void:
    _step += 1
    if _step >= _combo.sequence.size():
        _finish()
        return
    if _combo.gap > 0:
        _waiting_gap = true
        _gap_timer = _combo.gap
    else:
        _play_step()

func _finish() -> void:
    if owner.anim_player.animation_finished.is_connected(_on_sub_anim_done):
        owner.anim_player.animation_finished.disconnect(_on_sub_anim_done)
    var gcd = ai.current_skill.params.get(&"global_cooldown", 0.3)
    ai.blackboard.set_var(&"global_cooldown", gcd)
    ai.current_skill = null
    ai.dispatch(AIEvents.EV_ATTACK_FINISHED)

func _exit() -> void:
    if owner.anim_player and owner.anim_player.animation_finished.is_connected(_on_sub_anim_done):
        owner.anim_player.animation_finished.disconnect(_on_sub_anim_done)

func _resolve_direction(dir_key: StringName) -> float:
    match dir_key:
        &"forward":
            return 1.0 if not owner.sprite.flip_h else -1.0
        &"backward":
            return -1.0 if not owner.sprite.flip_h else 1.0
        &"toward_target":
            var tp = ai.blackboard.get_var(&"target_position", owner.global_position)
            return sign(tp.x - owner.global_position.x)
        &"away_from_target":
            var tp = ai.blackboard.get_var(&"target_position", owner.global_position)
            return -sign(tp.x - owner.global_position.x)
    return 0.0
```

### 4.4 何时需要自定义 State

| 场景 | 原因 | 做法 |
|---|---|---|
| 蓄力→释放 两阶段 | GenericAttackState 只支持单段 | 写 ChargeAttackState 或拆成 ComboSkill |
| 攻击中持续追踪目标 | GenericAttackState 不每帧更新方向 | 写自定义 State 或扩展 params 加 tracking |
| 抓取、吸引等复杂交互 | 通用 params 无法描述 | 写专属 State |

原则：先尝试 params 扩展，不够用才写自定义 State。

---

## 5. AIController 扩展

### 5.1 新增字段与方法

```gdscript
# AIController 新增
var current_skill: Skill = null

## 路由状态专用：直接跳转到指定状态
func goto(state_name: StringName) -> void:
    var target := get_state(state_name)
    if target:
        _transition_to(target)
```

### 5.2 dispatch 打断检查

```gdscript
func dispatch(event: StringName) -> void:
    if current_skill and not current_skill.interruptible:
        if event != AIEvents.EV_DIED and event != AIEvents.EV_ATTACK_FINISHED:
            return
    # ...原有转换表查询
```

---

## 6. AgentAIBase 扩展

### 6.1 新增成员

```gdscript
# AgentAIBase 新增
var skill_set: SkillSet

var _damage_log: Array[Array] = []
const DAMAGE_WINDOW: float = 3.0

var _hit_clear_timer: float = 0.0
const HIT_CLEAR_DELAY: float = 0.5
```

### 6.2 生命周期

```gdscript
func _ready() -> void:
    _auto_find_sprite()
    _setup_skill_set()        # 新增
    _setup_blackboard()
    _setup_transitions()
    _setup_signals()

func _physics_process(delta: float) -> void:
    if has_gravity:
        if not is_on_floor():
            velocity.y += gravity_force * delta
        elif velocity.y > 0:
            velocity.y = 0
    move_and_slide()
    skill_set.tick(delta)         # 技能冷却
    _update_sensor()              # 目标感知
    _tick_global_cooldown(delta)   # 全局后摇
    _tick_hit_clear(delta)         # recently_hit 清除
    _update_facing()

func _setup_skill_set() -> void:
    skill_set = SkillSet.new()
    # 子类覆盖来注册技能
```

### 6.3 Sensor（目标感知）

```gdscript
func _update_sensor() -> void:
    var bb := ai.blackboard
    var target = _find_target()  # 子类覆盖，返回当前目标节点（如 Player）
    if target and is_instance_valid(target):
        bb.set_var(&"target_alive", true)
        bb.set_var(&"target_position", target.global_position)
        bb.set_var(&"distance", global_position.distance_to(target.global_position))
    else:
        bb.set_var(&"target_alive", false)
        bb.set_var(&"distance", INF)
```

### 6.4 damage_recent（滑动窗口累计伤害）

```gdscript
func _on_agent_damaged(damage: Damage, attacker_pos: Vector2) -> void:
    var bb := ai.blackboard
    bb.set_var(&"last_damage", damage)
    bb.set_var(&"last_attacker_pos", attacker_pos)
    bb.set_var(&"recently_hit", true)
    _hit_clear_timer = HIT_CLEAR_DELAY
    var now := Time.get_ticks_msec() / 1000.0
    _damage_log.append([now, damage.amount])
    _update_damage_recent()
    ai.dispatch(AIEvents.EV_DAMAGED)

func _update_damage_recent() -> void:
    var now := Time.get_ticks_msec() / 1000.0
    var cutoff := now - DAMAGE_WINDOW
    while not _damage_log.is_empty() and _damage_log[0][0] < cutoff:
        _damage_log.pop_front()
    var total := 0.0
    for entry in _damage_log:
        total += entry[1]
    ai.blackboard.set_var(&"damage_recent", total)

func _tick_hit_clear(delta: float) -> void:
    if _hit_clear_timer > 0:
        _hit_clear_timer -= delta
        if _hit_clear_timer <= 0:
            ai.blackboard.set_var(&"recently_hit", false)

func _tick_global_cooldown(delta: float) -> void:
    var gcd := ai.blackboard.get_var(&"global_cooldown", 0.0)
    if gcd > 0:
        ai.blackboard.set_var(&"global_cooldown", maxf(gcd - delta, 0.0))
```

### 6.5 Blackboard 标准字段

| 字段 | 类型 | 写入者 | 用途 |
|---|---|---|---|
| `target_alive` | bool | _update_sensor | 目标存活 |
| `target_position` | Vector2 | _update_sensor | 目标坐标 |
| `distance` | float | _update_sensor | 到目标距离 |
| `current_phase` | int | Boss bind_var | 当前阶段 |
| `global_cooldown` | float | GenericAttackState/ComboState 结束时写入 | 全局后摇 |
| `recently_hit` | bool | _on_agent_damaged | 刚被打中 |
| `last_damage` | Damage | _on_agent_damaged | 最近伤害 |
| `last_attacker_pos` | Vector2 | _on_agent_damaged | 攻击者位置 |
| `damage_recent` | float | _update_damage_recent | 近 N 秒累计受伤 |
| `health` | float | bind_var | 当前血量 |
| `max_health` | float | bind_var | 最大血量 |
| `pending_skill` | Skill | guard 方法写入 | dispatcher 读取的待执行技能 |

---

## 7. 场景触发机制

### 7.1 核心思路

**Guard 即场景定义。Guard 调 pick/pick_tagged 预选技能，写入 pending_skill。转换表 priority 决定场景优先级。Dispatcher 只读取执行。**

```
事件/轮询 → 转换表匹配 guard → guard 识别场景 + 预选技能 → Dispatcher 执行
```

### 7.2 Guard 模式

```gdscript
## 防御场景：被打 + 有 defensive 技能
func _guard_defensive() -> bool:
    var skill := skill_set.pick_tagged(&"defensive", self, ai.blackboard)
    if skill:
        ai.blackboard.set_var(&"pending_skill", skill)
        return true
    return false

## 远程优先：距离远 + 有 ranged 技能
func _guard_ranged_preferred() -> bool:
    if ai.blackboard.get_var(&"distance", 0) < 300:
        return false
    var skill := skill_set.pick_tagged(&"ranged", self, ai.blackboard)
    if skill:
        ai.blackboard.set_var(&"pending_skill", skill)
        return true
    return false

## 反击场景：poise 满 + 有 counter 技能
func _guard_counter() -> bool:
    var skill := skill_set.pick_tagged(&"counter", self, ai.blackboard)
    if skill:
        ai.blackboard.set_var(&"pending_skill", skill)
        return true
    return false

## 普通攻击：兜底
func _guard_can_attack() -> bool:
    if ai.blackboard.get_var(&"global_cooldown", 0.0) > 0:
        return false
    var skill := skill_set.pick(self, ai.blackboard)
    if skill:
        ai.blackboard.set_var(&"pending_skill", skill)
        return true
    return false

## 当前技能是否可被打断
func _guard_can_interrupt() -> bool:
    return ai.current_skill == null or ai.current_skill.interruptible
```

### 7.3 转换表 priority 控制场景优先级

```gdscript
_register_rules([
    # 场景优先级从高到低
    ["*",     "dispatcher", EV_DAMAGED,         "_guard_defensive",       25],
    ["*",     "dispatcher", EV_POISE_BREAK,     "_guard_counter",         20],
    ["chase", "dispatcher", "",                 "_guard_ranged_preferred", 15],
    ["chase", "dispatcher", "",                 "_guard_can_attack",       10],
])
```

### 7.4 场景和 tag 对应约定

| 场景 Guard | 调用方式 | 触发条件 | tag |
|---|---|---|---|
| `_guard_defensive` | `pick_tagged("defensive")` | EV_DAMAGED 事件 | defensive |
| `_guard_counter` | `pick_tagged("counter")` | EV_POISE_BREAK 事件 | counter |
| `_guard_ranged_preferred` | `pick_tagged("ranged")` | 距离 > 阈值 | ranged, gap_close |
| `_guard_can_attack` | `pick()`（全池） | global_cd 到期 | 所有 weight>0 |

每个 Boss 自定义 guard + tag，不需要「场景注册系统」。

### 7.5 触发流程示例

**DS2 被连打后触发 retreat**：

```
1. 玩家连击 → health_comp.damaged 信号
2. _on_agent_damaged() → bb: recently_hit=true, damage_recent=35
3. ai.dispatch(EV_DAMAGED)
4. AIController 查转换表：
   - prio 25: ["*", "dispatcher", EV_DAMAGED, "_guard_defensive"]
     → _guard_defensive() → pick_tagged("defensive")
       → retreat 满足 _precond_heavy_damage (damage_recent > 30)
       → pending_skill = retreat → return true ✓
   - prio 10: ["*", "hit", EV_DAMAGED] → 没机会，prio 25 赢了
5. → Dispatcher → goto("generic_attack")
6. GenericAttackState: 播 back_dash + velocity.x 反向
7. 动画结束 → EV_ATTACK_FINISHED → 回 chase
```

**远距离触发突进**：

```
1. chase 每帧轮询
2. distance=500, global_cooldown=0
3. prio 15: _guard_ranged_preferred()
   → distance > 300 ✓
   → pick_tagged("ranged") → dash_attack (tags=["gap_close","ranged"])
   → pending_skill = dash_attack → return true
4. → Dispatcher → goto("generic_attack")
```

---

## 8. 模板场景

### 8.1 AgentAIBase.tscn（更新后）

```
AgentAIBase (CharacterBody2D)
├── AIController (Node)
│    └── StateMachine (Node)
│         ├── IdleState
│         ├── ChaseState
│         ├── AttackDispatcher
│         ├── GenericAttackState
│         ├── ComboState
│         ├── HitState
│         └── DeathState
├── HealthComponent
├── AnimatedSprite2D
└── CollisionShape2D
```

7 个通用 State 节点覆盖绝大多数 Boss/Enemy 场景。新建角色继承此模板，只需：配 Skill .tres + 写 Boss 主脚本。

---

## 9. DS2 迁移示例

### 9.1 技能 Resource 文件

**`Scenes/Characters/Bosses/DemonSlime2/Skills/ds2_cleave.tres`**

```
Skill: id="cleave" state_name="generic_attack" cooldown=1.5 weight=5
min_phase=0 max_range=250 tags=["melee"]
params = { animation: "cleave" }
```

**`Scenes/Characters/Bosses/DemonSlime2/Skills/ds2_slam.tres`**

```
Skill: id="slam" state_name="generic_attack" cooldown=3.0 weight=3
min_phase=1 max_range=180 tags=["melee","heavy"]
params = { animation: "slam" }
```

**`Scenes/Characters/Bosses/DemonSlime2/Skills/ds2_retreat.tres`**

```
Skill: id="retreat" state_name="generic_attack" cooldown=4.0 weight=0
tags=["defensive"] precondition_method="_precond_heavy_damage"
interruptible=false
params = { animation: "back_dash", speed: 220.0, direction: "away_from_target" }
```

**`Scenes/Characters/Bosses/DemonSlime2/Skills/ds2_combo2.tres`**

```
ComboSkill: id="combo2" state_name="combo" cooldown=5.0 weight=2
min_phase=2 max_range=230 tags=["melee","combo"]
interruptible=false  gap=0.15
sequence = [
    <ds2_slash_light.tres>   params={ animation: "slash1" }
    <ds2_slash_light.tres>   params={ animation: "slash2" }
    <ds2_slam_finisher.tres> params={ animation: "slam_heavy" }
]
```

### 9.2 DemonSlime2.gd

```gdscript
class_name DemonSlime2 extends AgentAIBase

@export var base_move_speed: float = 80.0
@export var detection_radius: float = 600.0
@export var phase_2_hp_pct: float = 0.66
@export var phase_3_hp_pct: float = 0.33

var current_phase: int = 0
const PHASE_SPEED := { 0: 1.0, 1: 1.3, 2: 1.5 }
var move_speed: float:
    get: return base_move_speed * PHASE_SPEED.get(current_phase, 1.0)

func _ready() -> void:
    sprite = $AnimatedSprite2D
    super._ready()
    if health_comp:
        health_comp.health_changed.connect(_on_health_changed)

func _setup_skill_set() -> void:
    skill_set = SkillSet.new()
    skill_set.setup([
        preload("res://Scenes/Characters/Bosses/DemonSlime2/Skills/ds2_cleave.tres"),
        preload("res://Scenes/Characters/Bosses/DemonSlime2/Skills/ds2_slam.tres"),
        preload("res://Scenes/Characters/Bosses/DemonSlime2/Skills/ds2_retreat.tres"),
        preload("res://Scenes/Characters/Bosses/DemonSlime2/Skills/ds2_combo2.tres"),
    ])

func _setup_blackboard() -> void:
    super._setup_blackboard()
    var bb := ai.blackboard
    bb.bind_var(&"current_phase", self, &"current_phase")
    bb.set_var(&"detection_radius", detection_radius)
    bb.set_var(&"global_cooldown", 0.0)

func _setup_transitions() -> void:
    _register_rules([
        ["idle",   "chase",      "",                          "_guard_detected",      10],
        ["wander", "chase",      "",                          "_guard_detected",      10],
        ["chase",  "idle",       "",                          "_guard_target_lost",    0],
        ["*",      "dispatcher", AIEvents.EV_DAMAGED,         "_guard_defensive",     25],
        ["chase",  "dispatcher", "",                          "_guard_can_attack",    10],
        ["*",      "chase",      AIEvents.EV_ATTACK_FINISHED, "_guard_target_alive",   0],
        ["*",      "idle",       AIEvents.EV_ATTACK_FINISHED, "",                      0],
        ["*",      "death",      AIEvents.EV_DIED,            "",                    100],
        ["*",      "hit",        AIEvents.EV_DAMAGED,         "_guard_can_interrupt", 10],
        ["hit",    "chase",      AIEvents.EV_HIT_RECOVERED,   "_guard_target_alive",  10],
        ["hit",    "idle",       AIEvents.EV_HIT_RECOVERED,   "",                      0],
    ])

func _guard_detected() -> bool:
    var bb := ai.blackboard
    return bb.get_var(&"target_alive", false) and bb.get_var(&"distance", INF) < detection_radius

func _guard_target_lost() -> bool:
    var bb := ai.blackboard
    return not bb.get_var(&"target_alive", false) or bb.get_var(&"distance", INF) > 700.0

func _guard_target_alive() -> bool:
    return ai.blackboard.get_var(&"target_alive", false)

func _guard_defensive() -> bool:
    var skill := skill_set.pick_tagged(&"defensive", self, ai.blackboard)
    if skill:
        ai.blackboard.set_var(&"pending_skill", skill)
        return true
    return false

func _guard_can_attack() -> bool:
    if ai.blackboard.get_var(&"global_cooldown", 0.0) > 0:
        return false
    var skill := skill_set.pick(self, ai.blackboard)
    if skill:
        ai.blackboard.set_var(&"pending_skill", skill)
        return true
    return false

func _guard_can_interrupt() -> bool:
    return ai.current_skill == null or ai.current_skill.interruptible

func _precond_heavy_damage() -> bool:
    return ai.blackboard.get_var(&"damage_recent", 0.0) > 30.0

func _on_health_changed(current: float, maximum: float) -> void:
    var pct := current / maxf(maximum, 1.0)
    var new_phase := current_phase
    if pct <= phase_3_hp_pct:
        new_phase = 2
    elif pct <= phase_2_hp_pct:
        new_phase = 1
    if new_phase != current_phase:
        current_phase = new_phase
        ai.blackboard.set_var(&"chase_speed", move_speed)
        ai.dispatch(AIEvents.EV_PHASE_CHANGED)
```

### 9.3 删除文件

| 文件 | 原因 |
|---|---|
| `DS2Cleave.gd` | GenericAttackState 取代 |
| `DS2Slam.gd` | GenericAttackState 取代 |

### 9.4 对比

| 旧版 | 新版 |
|---|---|
| `last_action` + 手写 guard | per-skill cd 天然防重复 |
| `attack_cooldown` | 删除 |
| 每招一条规则 + 一个 guard | 一条 `chase→dispatcher` + `skill_set.pick()` |
| 新招改转换表 + 写 guard + 写 State | 建 .tres + preload 一行 |

---

## 10. BladeKeeper 迁移可行性

本次不实现 BK 迁移，仅验证新架构覆盖其全部能力：

| BK 能力 | 新架构对应 |
|---|---|
| 近战三连 | ComboSkill + ComboState |
| 剑气投射 | Skill + GenericAttackState (params.projectile_scene) |
| 地面陷阱 | Skill + GenericAttackState (params.spawn_scene) |
| 防御反击 | tags=["counter"] + pick_tagged |
| 闪避翻滚 | tags=["defensive"] + precondition |
| 阶段攻击池 | Skill.min_phase/max_phase |
| 追击/撤退池分离 | guard 场景区分 |
| 加权随机 | SkillSet._weighted_pick |

BK 迁移作为独立 spec + 独立 plan。

---

## 11. 测试策略

### 11.1 单元测试（GUT）

| 测试对象 | 验证内容 |
|---|---|
| SkillSet.pick() | phase/距离/cd/weight 过滤 |
| SkillSet.pick_tagged() | weight=0 通过 tag 选中、precondition 拦截 |
| SkillSet.tick() | cd 正确扣减 |
| SkillSet._weighted_pick() | 大量采样验证权重分布 |
| Skill Resource | .tres 加载字段正确 |

### 11.2 集成测试

| 场景 | 验证 |
|---|---|
| DS2 基本攻击循环 | chase → dispatcher → generic_attack → chase |
| phase 0 只有 cleave | 连续攻击不卡死 |
| phase 1 解锁 slam | pick 选出 slam |
| phase 2 解锁 combo | ComboState 3 段播完 |
| 防御触发 | damage_recent > 阈值 → retreat |
| 不可打断 | retreat 中 EV_DAMAGED 不切 hit |
| 可打断 | cleave 中 EV_DAMAGED 切 hit |

### 11.3 运行时验证

通过 MCP + DebugConfig 日志验证完整流程。

---

## 12. 文件清单

### 新增

| 文件 | 职责 |
|---|---|
| `Core/AI/Skill.gd` | 技能 Resource |
| `Core/AI/ComboSkill.gd` | 组合技 Resource |
| `Core/AI/SkillSet.gd` | 选择器 + 冷却 |
| `Core/AI/States/AttackDispatcher.gd` | 路由状态 |
| `Core/AI/States/GenericAttackState.gd` | 通用攻击执行器 |
| `Core/AI/States/ComboState.gd` | 组合技执行器 |
| `Scenes/.../DemonSlime2/Skills/*.tres` | DS2 技能文件 |

### 修改

| 文件 | 改动 |
|---|---|
| `Core/AI/AIController.gd` | current_skill、goto()、dispatch 打断 |
| `Core/AI/AgentAIBase.gd` | skill_set、sensor、damage_recent |
| `AgentAIBase.tscn` | 加入通用 State 节点 |
| `DemonSlime2.gd` | 重写为 SkillSet 驱动 |

### 删除

| 文件 | 原因 |
|---|---|
| `DS2Cleave.gd` | GenericAttackState 取代 |
| `DS2Slam.gd` | GenericAttackState 取代 |
