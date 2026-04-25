# BladeKeeper 迁移到 AgentAIBase + SkillSet — 设计文档

**日期**：2026-04-18
**前置依赖**：[Skill 系统设计](2026-04-16-skill-system-design.md) 已实现并通过 CR
**迁移范围**：仅 BladeKeeper；BossBase 保留供 Cyclops 使用

---

## 1. 背景与目标

### 1.1 现状
BladeKeeper 当前基于 BossBase + BKAttackManager + BKAttack 的 step-machine 架构：
- `BKAttack.gd`（327 行）使用内部 Step enum 编排 ATK/SP_ATK/DODGE/JUMP/AIR_ATK
- `BKAttackManager.gd` 通过 3 套 `BossPhaseConfig` + 硬编码权重选择行为
- 防御/回避散落在独立状态（BKDefend / BKRoll）

### 1.2 问题
- 行为编排被代码硬编码，调参需改 .gd 文件
- step machine 难以测试（test_bk_attack.gd 435 行 mock 重）
- 阶段差异（如 P1 sp_atk=10%、P3=60%）藏在常量字典中，难以预览
- 与新 Skill 系统的概念重叠（Skill / ComboSkill / SkillSet 已能覆盖）

### 1.3 目标
- 拆解 BKAttack step machine → 多个 Skill / ComboSkill 资源
- BK 改继承 `AgentAIBase`（CharacterBody2D），通过 SkillSet 选技
- 解决"BK 永远追不上 player"——新增 `ApproachState` 共享突进执行器
- 受击触发防御/回避——通过 `damage_recent` precondition 路由
- 为后续 BuffEntity 框架预留接口（method-call 过渡）

---

## 2. 迁移范围与文件清单

### 2.1 删除

| 文件 | 原因 |
|---|---|
| `Scenes/Characters/Bosses/BladeKeeper/BKAttackManager.gd` | 被 SkillSet 取代 |
| `Scenes/Characters/Bosses/BladeKeeper/States/BKAttack.gd` | step machine 拆为多个 Skill |
| `Scenes/Characters/Bosses/BladeKeeper/States/BKChase.gd` | 用 `Core/AI/Stock/ChaseState` |
| `Scenes/Characters/Bosses/BladeKeeper/States/BKDefend.gd` | 改为 defensive Skill |
| `Scenes/Characters/Bosses/BladeKeeper/States/BKRoll.gd` | 改为 evasive Skill |
| `Scenes/Characters/Bosses/BladeKeeper/States/BKProjectile.gd` | 改用 GenericAttackState + spawn_projectile |
| `Scenes/Characters/Bosses/BladeKeeper/States/BKTrap.gd` | 改用 GenericAttackState + spawn_entity |
| `Scenes/Characters/Bosses/BladeKeeper/States/BKStateMachine.gd` | AgentAIBase 自带转换表 |
| `test/unit/test_bk_attack.gd` | step machine 删除后失效 |

### 2.2 新增/重写

| 文件 | 说明 |
|---|---|
| `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd` | 重写，extends `AgentAIBase` |
| `Scenes/Characters/Bosses/BladeKeeper/skills/*.tres` | ~12 个 Skill / ComboSkill 资源 |
| `Core/AI/Stock/ApproachState.gd` | **新增共享**，突进追击执行器 |
| `Core/AI/Stock/GenericAttackState.gd` | **扩展**，支持动画 method call |
| `test/unit/test_approach_state.gd` | 新增 |
| `test/unit/test_generic_attack_method_call.gd` | 新增 |

### 2.3 BossBase 处理
**保留**。Cyclops 仍依赖 BossBase + BossPhaseConfig + 旧 evasion/poise 字段。本次迁移**不动 BossBase**，只把 BK 从 BossBase 子树中摘出。

---

## 3. 共享基础设施改造

### 3.1 新增 `Core/AI/Stock/ApproachState.gd`

**用途**：突进追击执行器。BK 因 player 移动速度高，普通 ChaseState 永远追不上，需要一个高速冲刺技能。该状态通用，未来其他 boss 也可复用。

```gdscript
# Core/AI/Stock/ApproachState.gd
extends BaseAttackState

## 突进执行器：高速接近目标，到达 stop_distance 或动画结束即退出

func enter() -> void:
    var skill: Skill = ai.current_skill
    if not skill:
        _finish()
        return
    var anim_name = skill.params.get(&"animation", &"")
    if anim_name and "anim_player" in owner_node and owner_node.anim_player:
        owner_node.anim_player.play(anim_name)
        owner_node.anim_player.animation_finished.connect(_on_anim_done, CONNECT_ONE_SHOT)

func physics_update(_delta: float) -> void:
    var skill: Skill = ai.current_skill
    if not skill or not (owner_node is CharacterBody2D):
        return
    var spd: float = skill.params.get(&"speed", 0.0)
    var dir_key: StringName = skill.params.get(&"direction", &"toward_target")
    (owner_node as CharacterBody2D).velocity.x = _resolve_direction(dir_key) * spd
    var stop_dist: float = skill.params.get(&"stop_distance", 0.0)
    if stop_dist > 0 and bb.get_var(&"distance", INF) <= stop_dist:
        _finish()

func exit() -> void:
    if "anim_player" in owner_node and owner_node.anim_player:
        if owner_node.anim_player.animation_finished.is_connected(_on_anim_done):
            owner_node.anim_player.animation_finished.disconnect(_on_anim_done)

func _on_anim_done(_anim_name: StringName) -> void:
    _finish()
```

**关键参数**：
- `speed` — 冲刺速度（建议 350+）
- `stop_distance` — 距目标 ≤ 此值时提前终止
- `direction` — `toward_target`

### 3.2 扩展 `GenericAttackState.gd` — 支持动画 method call

新增方法 `call_skill_method`，供动画 Call Method Track 触发，统一调用 boss 自身方法（buff / heal / debuff 等占位机制，BuffEntity 框架到位前的过渡方案）。

```gdscript
## 动画 method call track 调用：调用 owner_node 上的方法
## 用于 BuffEntity 框架到位前的过渡方案，等 BuffEntity 落地后通过 spawn_scene 替代
func call_skill_method() -> void:
    var skill: Skill = ai.current_skill
    if not skill:
        return
    var method_name: StringName = skill.params.get(&"method", &"")
    if method_name == &"" or not owner_node.has_method(method_name):
        return
    var arg = skill.params.get(&"method_arg", null)
    if arg == null:
        owner_node.call(method_name)
    else:
        owner_node.call(method_name, arg)
```

**Skill 配置示例**：
```
params = {
  "animation": "buff_cast",
  "method": "apply_defense_buff",
  "method_arg": 3.0
}
```

BK 实现 `func apply_defense_buff(duration: float)`，动画播到关键帧时通过 Call Method Track 调用 `call_skill_method`。

---

## 4. Skill 资源清单

文件位置：`Scenes/Characters/Bosses/BladeKeeper/skills/`

### 4.1 单技能（Skill.tres）

| id | state | min_phase | weight | cooldown | min/max_dist | tags | params 关键字段 |
|---|---|---|---|---|---|---|---|
| `bk_atk_basic` | generic_attack | 1 | 10 | 0.8 | 0/180 | offensive,melee | animation=attack_1 |
| `bk_atk_heavy` | generic_attack | 2 | 6 | 1.5 | 0/200 | offensive,melee | animation=attack_2, speed=80 |
| `bk_dash_approach` | approach | 1 | 4 | 5.0 | 200/600 | offensive,gap_close | animation=dash, speed=350, stop_distance=180 |
| `bk_throw_sword` | generic_attack | 1 | 3 | 4.0 | 200/800 | offensive,projectile | animation=throw_sword, projectile_scene=（沿用 BKProjectile 当前引用） |
| `bk_place_trap` | generic_attack | 2 | 2 | 6.0 | 0/300 | offensive,trap | animation=place_trap, spawn_scene=（沿用 BKTrap 当前引用） |
| `bk_dodge_back` | generic_attack | 1 | — | 3.0 | 0/200 | evasive | animation=dodge_back, speed=300, direction=away_target |
| `bk_defend_buff` | generic_attack | 1 | — | 8.0 | 0/INF | defensive,buff | animation=buff_cast, method=apply_defense_buff, method_arg=3.0 |
| `bk_heal_self` | generic_attack | 2 | — | 12.0 | 0/INF | defensive,buff | animation=buff_cast, method=heal_self, method_arg=20.0 |

`weight = —` 表示防御类技能不参与攻击池随机抽取，由 `_guard_under_pressure` 触发的独立 pick context 选取。

### 4.2 组合技（ComboSkill.tres）

| id | state | min/max_phase | weight | sequence | gap |
|---|---|---|---|---|---|
| `bk_combo_basic` | combo | P1+ | 5 | atk_1 → atk_2 → atk_3 | 0.1 |
| `bk_combo_finisher_p2` | combo | P2 only | 3 | atk_1 → atk_2 → atk_3 → sp_atk | 0.1 |
| `bk_combo_finisher_p3` | combo | P3+ | 6 | atk_1 → atk_2 → atk_3 → sp_atk | 0.1 |
| `bk_combo_dodge_seq` | combo | P1+ | — | dodge_back+trap → air_throw → land | 0.0 |

**Q1 落地说明**：通过 3 个 combo .tres + min/max_phase 实现"P1 sp 概率=0、P2≈30%、P3≈60%"的效果。**不扩展 SkillSet 字段**，复用既有 phase filter + weighted_pick。

### 4.3 防御/回避技能的 precondition

`bk_defend_buff` / `bk_heal_self` / `bk_dodge_back` 的 `precondition_method` 字段（按 Skill 系统现有 API，是方法名 StringName，不是 Callable）：

```
precondition_method = &"_precond_under_pressure"
```

BK.gd：
```gdscript
func _precond_under_pressure() -> bool:
    return blackboard.get_var(&"damage_recent", 0.0) > 35.0
```

`damage_recent` 由 `AgentAIBase._update_damage_recent` 维护（已存在，参见 `Core/AI/AgentAIBase.gd:110`），按时间窗口累加并衰减。

### 4.4 共用 tag — `reactive`

`bk_defend_buff` / `bk_heal_self` / `bk_dodge_back` 共用 `tags = [&"reactive"]`（替代 §4.1 表中暂列的 `defensive` / `evasive` 单独标签）。原因：现有 `SkillSet.pick_tagged` 仅支持**单 tag** 过滤；用统一标签可一次抽取，避免双查后合并的复杂度。`defensive` / `evasive` 可作为附加语义标签共存（不影响过滤）。

---

## 5. BladeKeeper.gd 转换表与 Guard

### 5.1 状态节点（场景树）

`BladeKeeper.tscn` 下 `AIController/StateMachine` 子节点：
- `Idle` — IdleState
- `Chase` — ChaseState（追击 + 距离判断）
- `Dispatcher` — AttackDispatcher（路由状态，pick skill → goto state_name）
- `GenericAttack` — GenericAttackState
- `Combo` — ComboState
- `Approach` — ApproachState（新增）
- `Dead` — DeadState

### 5.2 _setup_transitions

```gdscript
func _setup_transitions() -> void:
    var idle = ai.get_state(&"idle")
    var chase = ai.get_state(&"chase")
    var dispatcher = ai.get_state(&"dispatcher")
    var dead = ai.get_state(&"dead")

    # 全局：死亡（最高优先级）
    ai.add_transition(ai.ANYSTATE, dead, AIEvents.EV_DIED, Callable(), 100)

    # Idle → Chase（有目标且活着）
    ai.add_transition(idle, chase, &"", _guard_target_alive, 10)

    # Chase → Dispatcher（进入攻击范围 + 有可用技能）
    ai.add_transition(chase, dispatcher, &"", _guard_can_attack, 20)

    # 攻击结束 → Chase（重新评估）
    ai.add_transition(ai.ANYSTATE, chase, AIEvents.EV_ATTACK_FINISHED, Callable(), 5)

    # 受压条件触发：Chase 中可被打断进入 Dispatcher（释放 defensive/evasive）
    ai.add_transition(chase, dispatcher, &"", _guard_under_pressure, 30)
```

**说明**：BK 的转换规则收敛到 5 条。技能选择全部交给 `Dispatcher`（AttackDispatcher 在 enter() 调 `skill_set.pick(ctx)` → `ai.goto(skill.state_name)`）。

### 5.3 Guard 方法

按 SkillSet 现有 API：`pick(boss_ref, bb)` / `pick_tagged(tag, boss_ref, bb)`。`current_phase` 与 `distance` 由 SkillSet 内部从 blackboard 读取，无需在 guard 里组装上下文。

```gdscript
func _guard_target_alive() -> bool:
    return blackboard.get_var(&"target_alive", false)

func _guard_can_attack() -> bool:
    if not blackboard.get_var(&"target_alive", false):
        return false
    var skill: Skill = skill_set.pick(self, blackboard)
    if skill == null:
        return false
    blackboard.set_var(&"pending_skill", skill)
    return true

func _guard_under_pressure() -> bool:
    if blackboard.get_var(&"damage_recent", 0.0) <= 35.0:
        return false
    var skill: Skill = skill_set.pick_tagged(&"reactive", self, blackboard)
    if skill == null:
        return false
    blackboard.set_var(&"pending_skill", skill)
    return true
```

**前置要求**：BK 必须把 `current_phase` 写入 blackboard（`blackboard.set_var(&"current_phase", n)`）于 phase change 钩子中。具体接入点见 §8 风险表。

### 5.4 Boss 占位方法（method-call 过渡方案）

```gdscript
# BladeKeeper.gd
var _defense_multiplier: float = 1.0

func apply_defense_buff(duration: float) -> void:
    _defense_multiplier = 0.5
    get_tree().create_timer(duration).timeout.connect(
        func(): _defense_multiplier = 1.0)

func heal_self(amount: float) -> void:
    hp = min(hp + amount, max_hp)
```

`_defense_multiplier` 在 `take_damage` 路径中乘到入伤上（具体接入点视 AgentAIBase 当前 hp 接口而定，实现期再决定）。

---

## 6. BuffEntity 引入路线图

### 6.1 Phase 1（本次迁移，立即落地）
- BK.gd 直接实现 `apply_defense_buff` / `heal_self`
- GenericAttackState 通过 `call_skill_method` 在动画关键帧调用
- **优点**：无需新框架即可让 BK 跑通
- **缺点**：buff 逻辑耦合在 BK 内，难复用

### 6.2 Phase 2（独立 spec/plan，时间另定）
- 新建 `Core/Buffs/BuffEntity.gd`：Resource，字段 `id / duration / stat_modifiers / on_apply / on_tick / on_expire`
- 新建 `Core/Buffs/BuffComponent.gd`：Node，挂在角色身上管理活跃 buff 列表
- 设计要点：
  - 叠加策略（refresh / stack / replace）
  - 与现有 stats 系统的接口
  - 视觉反馈（buff icon / 角色 shader 染色）

### 6.3 Phase 3（迁移 method 调用为 spawn_scene）
- `bk_defend_buff.tres` 改为：
  ```
  params = {
    "animation": "buff_cast",
    "spawn_scene": "res://Core/Buffs/DefenseBuff.tres"
  }
  ```
- 复用 `GenericAttackState.spawn_entity` 路径（已有），在 BuffComponent 上注册
- 删除 BK.gd 内的 `apply_defense_buff` / `heal_self` 占位方法

**好处**：Phase 1 不阻塞当前迁移；BuffEntity 框架日后服务于所有 boss + 玩家技能；迁移路径清晰（只改 .tres + 删占位方法，不动状态机）。

---

## 7. 测试策略

### 7.1 保留（已通过的 Skill 系统单测）
- `test/unit/test_skill.gd`
- `test/unit/test_combo_skill.gd`
- `test/unit/test_skill_set.gd`
- `test/unit/test_attack_dispatcher.gd`

### 7.2 新增单测
- `test/unit/test_approach_state.gd`：mock owner/skill，断言 `physics_update` 设置 velocity，距离 ≤ stop_distance 时 `_finish` 被调用
- `test/unit/test_generic_attack_method_call.gd`：断言 `call_skill_method` 通过 `params.method` 正确路由到 owner_node

### 7.3 手动场景测试（BK 战斗场景）
1. **P1 验证**：观察 combo 序列长度 = 3，无 sp_atk
2. **P2 phase change**：触发 phase change → combo finisher 出现 sp_atk
3. **远距离突进**：触发 `bk_dash_approach`，验证 stop_distance 提前终止
4. **受压触发防御**：连续受击 → `damage_recent > 35` → 触发 `bk_defend_buff` 或 `bk_dodge_back`，验证 `_guard_under_pressure` 路径
5. **P3 验证**：sp_atk combo 权重提升肉眼可见

---

## 8. 风险与未决项

| 风险 | 缓解 |
|---|---|
| AgentAIBase 当前 take_damage 接口可能与 `_defense_multiplier` 接入点不匹配 | 实现期检查；若必要，BK 重写 take_damage 钩子 |
| BK 现有动画名（attack_1/attack_2/attack_3/sp_atk/dodge_back/...）需与 .tres params 一一对应 | 实现首日核对 AnimationPlayer，列出实际动画名清单 |
| `bk_combo_dodge_seq` 的 trap 生成时机依赖动画 method track | 首个 sub-skill 用 GenericAttackState 已有的 spawn_entity；ComboSkill 子步骤复用此机制 |
| ComboSkill 子步骤的 method call 暂不支持 | 本次不需要（buff 都是单 Skill）；如未来需要，在 ComboState 中也加 `call_skill_method` |
| `current_phase` 字段需写入 blackboard，BK 当前 phase 系统继承自 BossBase，迁移后需找到等价钩子 | 实现期：BK._ready 里订阅自有 phase change 信号或在 take_damage 中按血量阈值更新；首次写入用 `blackboard.set_var(&"current_phase", 1)` |
| `bk_combo_dodge_seq` 涉及 dodge 动画期间生成 trap，需要 sub-skill 通过动画 method track 调用 boss 方法（GenericAttackState.spawn_entity 在 combo 子步无效，因为它读的是 ai.current_skill 即 ComboSkill 而非子 Skill） | 落地方案：boss 自身实现 `spawn_trap_at_feet()` / `spawn_air_projectile()`，由动画 method track 直接调用；或将 `bk_combo_dodge_seq` 推迟到第 2 次迭代（基础迁移完成后）|

---

## 9. 验收标准

- BK 场景可正常战斗，三个阶段行为差异符合 §4 配置
- 所有保留单测通过；新增单测覆盖 ApproachState 和 method call 路径
- BossBase / Cyclops 不受影响（Cyclops 战斗场景仍可玩）
- 删除文件清单全部清空，git status 干净
- 调试日志（`ai_diag` 频道）显示完整的 Idle → Chase → Dispatcher → 具体技能 → Chase 循环
