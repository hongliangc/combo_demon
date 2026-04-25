# AgentAIBase 角色开发指南 (agent-ai-guide.md)

适用于所有继承 [AgentAIBase](../../../../Core/AI/AgentAIBase.gd) 的角色（Boss / 敌人），
基于 AIController + SkillSet 架构。新 Boss/Enemy 默认走本指南；
**旧 BossBase/EnemyBase 路径不再新增**，仅维护现有 Cyclops/DemonSlime1 等历史角色。

参考实现：[DemonSlime2.gd](../../../../Scenes/Characters/Bosses/DemonSlime2/DemonSlime2.gd) +
[BladeKeeper.gd](../../../../Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd)。

---

## 1. 场景结构

所有 AgentAIBase 角色**必须**从 [Templates/AgentAIBase.tscn](../../../../Scenes/Characters/Templates/AgentAIBase.tscn) 继承。模板已含：

```
AgentAIBase [CharacterBody2D]  layer=8(Enemy), mask=128(Walls)
├── HurtBoxComponent [Area2D]  layer=8, mask=0
├── HitBoxComponent  [Area2D]  layer=8, mask=2(Player)
├── HealthComponent
├── HealthBar
├── DamageNumbersAnchor
├── FloorCastL/R + WallCastL/R (平台位移边缘检测)
└── AIController
    └── StateMachine (由子类场景添加 state 节点)
```

**不要**在子类场景里改 HurtBox/HitBox 的 `collision_layer` 为 0 —— 这会让伤害检测失效。
DS2 当前还有此遗留问题（layer=0），修复时恢复为模板默认即可。

---

## 2. 转换表：`_register_rules` 数据驱动

**禁止**命令式 `ai.add_transition()` 调用。一律用 `_register_rules` 数组：

```gdscript
func _setup_transitions() -> void:
    _register_rules([
        # from,    to,           event,                       guard,                    priority
        # 探测 / 追击
        ["idle",    "chase",      "",                          "_guard_detected",        10],
        ["chase",   "idle",       "",                          "_guard_target_lost",      0],
        # 攻击调度
        ["chase",   "dispatcher", "",                          "_guard_can_attack",      20],
        # 受压反击（可选，reactive 技能）
        ["chase",   "dispatcher", "",                          "_guard_under_pressure",  30],
        # 攻击完成 → 回追击
        ["*",       "chase",      AIEvents.EV_ATTACK_FINISHED, "_guard_target_alive",     5],
        ["*",       "idle",       AIEvents.EV_ATTACK_FINISHED, "",                        0],
        # 受击 / 死亡（每个角色都需要）
        ["*",       "death",      AIEvents.EV_DIED,            "",                      100],
        ["*",       "hit",        AIEvents.EV_DAMAGED,         "_guard_can_interrupt",   10],
        ["hit",     "chase",      AIEvents.EV_HIT_RECOVERED,   "_guard_target_alive",    10],
        ["hit",     "idle",       AIEvents.EV_HIT_RECOVERED,   "",                        0],
    ])
```

规则：`from="*"` 表示 ANYSTATE；`event=""` 表示条件式评估；`guard=""` 表示无条件；
priority 越高越先匹配（死亡 100 最高）。不存在的目标状态会自动跳过，不用手动 if 判空。

---

## 3. 必备 Guards

每个 AgentAIBase 角色至少实现以下 guard（参考 DS2/BK 实现）：

| Guard | 职责 | 典型实现 |
|---|---|---|
| `_guard_detected` | 玩家进入检测范围 | `target_alive && distance < detection_radius` |
| `_guard_target_lost` | 玩家脱离 | `!target_alive || distance > detection_radius * 1.2` |
| `_guard_target_alive` | 玩家存活 | `bb.get_var(&"target_alive", false)` |
| `_guard_can_attack` | 冷却完成 + 能挑到技能 | 调 `skill_set.pick(...)`，命中则写入 `pending_skill` |
| `_guard_can_interrupt` | 当前技能可打断 | `ai.current_skill == null or ai.current_skill.interruptible` |
| `_guard_under_pressure` | （可选）短期内受伤超阈值 | `damage_recent > pressure_threshold`，调 `skill_set.pick_tagged(&"reactive", ...)` |

**关键**：`_guard_can_attack` / `_guard_under_pressure` 在返回 true 前**必须**把选中的 Skill
写入 `bb.pending_skill`，AttackDispatcher 靠这个字段路由到具体攻击状态。

---

## 4. Skill `.tres` 配置铁律

### `state_name` 必须匹配 StateMachine 子节点名的**小写去下划线**形式

[AIController._collect_states](../../../../Core/AI/AIController.gd#L68) 用
`states[StringName(s.name.to_lower())] = s` 做 key。这会把 `GenericAttack` 节点变成 `&"genericattack"`，
而 `&"generic_attack"` 永远查不到 —— `ai.goto()` 静默失败，AI 卡在 Dispatcher 不出状态。

| 节点名 | 合法 `state_name` |
|---|---|
| `GenericAttack` | `&"genericattack"` |
| `Combo` | `&"combo"` |
| `Approach` | `&"approach"` |
| `Chase` | `&"chase"` |

不要写驼峰、下划线或大写。新增技能 `.tres` 前先看 [DS2/Skills/](../../../../Scenes/Characters/Bosses/DemonSlime2/Skills/) 里的约定。

### Animation Call Method Tracks 要打在具体状态节点上

`spawn_projectile` / `spawn_entity` / `call_skill_method` 的轨道 path 固定为
`NodePath("AIController/StateMachine/GenericAttack")`（或对应子状态）。
迁移时容易漏加方法轨 —— 动画播完但没触发子弹 / 特效 = 多半是轨道缺失。

---

## 5. Phase 系统：用 `health_changed` 信号，不要重写 `_on_agent_damaged`

**正确**（DS2/BK 模式）：

```gdscript
func _ready() -> void:
    super._ready()
    if health_comp:
        health_comp.health_changed.connect(_on_health_changed)

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

**禁止**：重写 `_on_agent_damaged(damage, pos)` 去做 phase 判断 —— 会打破 AgentAIBase
的 `damage_recent` 统计 + EV_DAMAGED 派发链，副作用难调试。

---

## 6. Blackboard 绑定：优先 `bind_var`

角色字段需要被 AI 状态/技能读取时，用 `bb.bind_var(key, self, prop)` 自动同步：

```gdscript
func _setup_blackboard() -> void:
    super._setup_blackboard()
    var bb := ai.blackboard
    bb.bind_var(&"current_phase", self, &"current_phase")     # 字段变化自动同步
    bb.set_var(&"detection_radius", detection_radius)          # 一次性常量用 set_var
    bb.set_var(&"chase_speed", move_speed)                     # Phase 变化时记得在信号里重新 set
```

规则：
- 字段 + 属性 → `bind_var`（双向同步，无需手动 set）
- 导出常量 → `set_var`（一次）
- Phase 变化驱动的值（如 `chase_speed`）→ 在 `_on_health_changed` 里重新 `set_var`

---

## 7. 伤害链路（已由 AgentAIBase 自动接线）

```
HitBox(player) ↔ HurtBox(agent) overlap
  → HurtBox.take_damage(damage, pos)
  → HurtBox.damaged signal
  → HealthComponent.take_damage          【AgentAIBase._setup_signals 自动连】
  → HP 扣除 + HealthComponent.damaged signal
  → AgentAIBase._on_agent_damaged        【AgentAIBase._setup_signals 自动连】
  → bb.last_damage / last_attacker_pos 写入
  → ai.dispatch(EV_DAMAGED)
  → 匹配转换表 → Hit 状态                 【需在 _register_rules 里声明】
  → Stock/HitState.enter() 遍历 damage.effects 调 apply_effect
  → KnockBackEffect / KnockUpEffect / StunEffect 生效
```

**子类不用手动接 HurtBox → HealthComponent 信号**（[AgentAIBase.gd](../../../../Core/AI/AgentAIBase.gd) `_setup_signals` 已做）。
但**必须**在 `_register_rules` 里写 `EV_DAMAGED → hit` 和 `EV_HIT_RECOVERED → chase/idle` 两组规则，否则掉血没反应。

---

## 8. 朝向翻转

AgentAIBase._update_facing() 同时处理 sprite 和 hitbox：

```gdscript
# 导出参数：美术原图默认朝向
@export var sprite_faces_right: bool = false   # 多数素材默认朝左，设 false
```

`_update_facing` 根据 `velocity.x` 符号和 `sprite_faces_right` 翻转 sprite 的 `flip_h`，
并把 HitBoxComponent 的 `scale.x` 镜像到 ±1。**子类不要重写这个方法**，除非有特殊需求（如多方向精灵）。

---

## 9. 迁移/新增时的常见坑

**下列每一项都曾在生产代码里翻过车，新角色务必逐条核对：**

1. **死节点残留**：从旧架构迁移时，`.tscn` 里会残留旧的 StateMachine 子节点（Counter/Defend/Roll/Stun 等），
   grep `parent="AIController/StateMachine"` 比对 `_register_rules` + 技能 `.tres` 引用，未引用的全删。
   详见 [feedback_dead_state_node_audit](../../../../../../.claude/projects/...)。

2. **孤儿 `.uid`**：`.gd.uid` 文件在 `.gitignore` 里，删除 `.gd` 后对应 `.uid` 不会出现在 git status，用 `ls` 手动核对。

3. **skill `state_name` 写错**：generic_attack vs genericattack —— 静默失败无报错，
   表现是 AI 进 Dispatcher 就卡住。

4. **HurtBox collision_layer 被改成 0**：角色永远无法被攻击。DS2 目前有此问题待修。

5. **漏写 EV_DAMAGED 规则**：掉血但不进 Hit 状态 —— 没有击退/硬直/受击动画，看起来像"无敌"。

6. **Phase 判断放错地方**：`_on_agent_damaged` 重写 → 破坏 AgentAIBase 的标准链路。用 `health_changed` 信号。

7. **忘记 bind `chase_speed`**：Phase 加速不生效，玩家看不出阶段差异。

---

## 10. 验收清单

新 AgentAIBase 角色提交前，跑一遍：

- [ ] 场景继承 `AgentAIBase.tscn`，HurtBox/HitBox 未被改成 layer=0
- [ ] `_register_rules` 包含 EV_DIED / EV_DAMAGED / EV_HIT_RECOVERED 三组标准规则
- [ ] 六个 guard 全部实现（`_guard_detected` / `_target_lost` / `_target_alive` / `_can_attack` / `_can_interrupt`，可选 `_under_pressure`）
- [ ] 每个技能 `.tres` 的 `state_name` 是小写去下划线（`genericattack` / `combo` / `approach`）
- [ ] 技能动画里该有的方法轨（`spawn_projectile` / `spawn_entity` / `call_skill_method`）都在
- [ ] Phase 逻辑用 `health_changed` 信号，不重写 `_on_agent_damaged`
- [ ] 用 MCP `run_project` 跑一遍 Level 场景，日志里能看到 Idle → Chase → Dispatcher → 攻击状态 → Hit → Chase 循环
- [ ] `.tscn` 无残留的旧 State 子节点；删除旧 `.gd` 时 `.uid` 也清
