# 状态机与 AnimationTree BlendTree 架构

> **文档类型**: 核心架构 - 状态机 + 动画混合系统
> **更新日期**: 2026-03-16
> **Godot版本**: 4.x
> **架构模式**: 优先级状态机 + 双层 BlendTree 动画混合
> **涵盖范围**: Player / Enemy / Boss / ForestEnemy 全部状态机实现

---

## 目录

1. [架构概述](#1-架构概述)
2. [状态机核心框架](#2-状态机核心框架)
3. [AnimationTree BlendTree 架构](#3-animationtree-blendtree-架构)
4. [Player 状态机](#4-player-状态机)
5. [Enemy 状态机](#5-enemy-状态机)
6. [Boss 状态机](#6-boss-状态机)
7. [ForestEnemy 状态机](#7-forestenemy-状态机)
8. [状态间通信与组件集成](#8-状态间通信与组件集成)
9. [架构优缺点分析](#9-架构优缺点分析)
10. [待提升项与改进建议](#10-待提升项与改进建议)

---

## 1. 架构概述

### 1.1 核心思想

项目采用 **统一的 BaseState/BaseStateMachine 框架**，所有角色类型（Player、Enemy、Boss、ForestEnemy）共享同一套状态机基础设施。动画控制通过 **双层 BlendTree**（locomotion + control）实现，状态脚本通过 BaseState 提供的 helper 方法操控 AnimationTree 参数，实现逻辑层与动画层的解耦。

```
状态机（逻辑层）  ←→  AnimationTree（动画层）
     │                      │
     │  set_locomotion()           →  locomotion 层: BlendSpace2D 或 SM
     │  enter_control_state("hit") →  control_sm 层: 播放 hit
     │  exit_control_state()       →  control_blend=0, 回到 locomotion
     │                      │
     └── BaseState helper 统一接口 ──┘
```

### 1.2 四套状态机对比

| 特性 | Player | Enemy (通用) | Boss | ForestEnemy |
|------|--------|-------------|------|-------------|
| 状态机类 | BaseStateMachine | EnemyStateMachine | BossStateMachine | BaseStateMachine |
| 状态数量 | 5+1 (Ground, Air, Combat, Roll, Hit, SpecialAttack) | 7 (Idle ~ Knockback) | 7 + HSM (Idle, Patrol, Chase, Circle, Attack[Normal/Special/Enrage], Retreat, Stun) | 自定义 (继承 ForestEnemyState) |
| locomotion 类型 | StateMachine (idle/run) | BlendSpace2D (方向+速度) | AnimationPlayer 直接 | AnimatedSprite2D 直接 |
| 攻击动画方式 | enter_control_state("atk_x") | fire_attack() (OneShot) | AnimationPlayer 直接 | AnimatedSprite2D.play() |
| 动画系统 | AnimationTree (BlendTree) | AnimationTree (BlendTree) | AnimationPlayer | AnimatedSprite2D |
| 优先级系统 | BEHAVIOR/REACTION/CONTROL | BEHAVIOR/REACTION/CONTROL | BEHAVIOR (内部阶段逻辑) | BEHAVIOR (简单) |

---

## 2. 状态机核心框架

### 2.1 类继承体系

```
┌─────────────────────────────────────────┐
│              BaseState                   │
│─────────────────────────────────────────│
│ + priority: StatePriority               │
│ + can_be_interrupted: bool              │
│ + owner_node / target_node / state_machine │
│─────────────────────────────────────────│
│ + enter() / exit()                      │
│ + process_state(delta)                  │
│ + physics_process_state(delta)          │
│ + on_damaged(damage, pos)              │
│─────────────────────────────────────────│
│ 动画 Helper:                            │
│ + set_locomotion(blend: Vector2)        │  ← Enemy 用 (BlendSpace2D)
│ + set_locomotion_state(name: String)    │  ← Player 用 (SM locomotion)
│ + enter_control_state(name: String)     │
│ + exit_control_state()                  │
│ + fire_attack() / abort_attack()        │
│ + set_locomotion_time_scale(scale)      │
│ + set_control_time_scale(scale)         │
│ + start_timer() / stop_timer()          │
└──────────────────┬──────────────────────┘
                   │ extends
    ┌──────────────┼──────────────────────────┐
    │              │                          │
PlayerBaseState  CommonStates/*         ForestEnemyState
    │              │                          │
  Ground         IdleState                ForestChaseState
  Air            ChaseState               ...
  Combat         AttackState
  Roll           HitState
  Hit            StunState
  SpecialAttack  KnockbackState
                 WanderState
```

**文件**: `Core/StateMachine/BaseState.gd` (444行)
**文件**: `Core/StateMachine/BaseStateMachine.gd` (226行)

### 2.2 优先级系统

```gdscript
enum StatePriority {
    BEHAVIOR = 0,    # idle, wander, chase, attack — 日常行为
    REACTION = 1,    # hit, knockback, combat, roll — 响应动作
    CONTROL = 2      # stun, frozen — 控制效果
}
```

**转换规则** (BaseState.can_transition_to):
- 高优先级 **总是** 可以打断低优先级
- 同优先级看 `can_be_interrupted` 标志
- 当前状态可以自愿退出到任意状态

**优先级矩阵** (以 Player 为例):

```
请求的新状态 →   Ground(0)  Air(0)  Combat(1)  Roll(1)  Hit(2)
当前状态 ↓
─────────────────────────────────────────────────────────────
Ground(0)          Y        Y       Y         Y       Y
Air(0)             Y        Y       Y         Y       Y
Combat(1)          Y*       Y*      N         N       Y
Roll(1)            Y*       Y*      N         N       Y
Hit(2)             Y*       Y*      Y*        Y*      N

Y  = 允许转换
N  = 拒绝（优先级不足 + can_be_interrupted=false）
Y* = 仅允许自愿退出（由当前状态主动 emit transitioned）
```

### 2.3 状态转换机制

**信号驱动转换**:
```gdscript
# 状态请求转换
signal transitioned(from_state: BaseState, new_state_name: String)

# BaseStateMachine._on_state_transition() 执行:
# 1. 验证是否为当前状态发起
# 2. 检查优先级 (can_transition_to)
# 3. 查找目标状态
# 4. 执行 exit() → enter() 生命周期
```

**强制转换**:
```gdscript
# force_transition() 跳过优先级检查
# 用于外部系统（如 HealthComponent）强制切换到 hit/stun 状态
state_machine.force_transition("stun")
```

### 2.4 Timer 管理

每个状态内置懒创建复用的 Timer:
```gdscript
func _ensure_timer() -> void:
    if not _state_timer:
        _state_timer = Timer.new()
        _state_timer.one_shot = true
        add_child(_state_timer)

func start_timer(duration, callback, one_shot=true) -> Timer:
    _ensure_timer()
    _disconnect_timer_callback()  # 断开旧回调
    _state_timer.wait_time = duration
    _state_timer.one_shot = one_shot
    _timer_callback = callback if callback.is_valid() else _on_timer_timeout
    _state_timer.timeout.connect(_timer_callback)
    _state_timer.start()
    return _state_timer

func stop_timer():
    if _state_timer:
        _state_timer.stop()
        _disconnect_timer_callback()
```

---

## 3. AnimationTree BlendTree 架构

### 3.1 双层 BlendTree 结构

所有使用 AnimationTree 的角色共享相同的 BlendTree 拓扑结构:

```
AnimationNodeBlendTree (root)
│
├── locomotion (BlendSpace2D 或 StateMachine)
│   └── 移动/待机动画
│
├── loco_timescale (TimeScale)
│   └── locomotion 动画速度控制
│
├── control_sm (AnimationNodeStateMachine)
│   └── hit, stunned, death, atk_*, roll 等动作动画
│
├── ctrl_timescale (TimeScale)
│   └── control 动画速度控制
│
├── control_blend (Blend2)
│   ├── input[0]: loco_timescale (locomotion)
│   └── input[1]: ctrl_timescale (control)
│   └── blend_amount: 0.0=locomotion, 1.0=control
│
├── attack_oneshot (OneShot) ← Enemy 专用
│   └── 攻击动画覆盖
│
└── output
```

### 3.2 关键参数路径

| 参数路径 | 类型 | 用途 | 控制方法 |
|---------|------|------|---------|
| `parameters/control_blend/blend_amount` | float | 切换 locomotion(0) / control(1) | `enter/exit_control_state()` |
| `parameters/locomotion/blend_position` | Vector2 | 移动方向+速度 (Enemy) | `set_locomotion(Vector2)` |
| `parameters/locomotion/playback` | Playback | 移动状态切换 (Player) | `set_locomotion_state()` |
| `parameters/control_sm/playback` | Playback | 动作状态控制 | `enter_control_state()` |
| `parameters/loco_timescale/scale` | float | locomotion 速度倍率 | `set_locomotion_time_scale()` |
| `parameters/ctrl_timescale/scale` | float | control 速度倍率 | `set_control_time_scale()` |
| `parameters/attack_oneshot/request` | int | OneShot 触发 (Enemy) | `fire_attack()` |

### 3.3 数据流

```
               ┌──────────────┐
               │  locomotion  │ idle / run / walk / 方向混合
               └──────┬───────┘
                      │
               ┌──────┴───────┐
               │ loco_timescale│ x1.0 (可调速)
               └──────┬───────┘
                      │ input[0]
               ┌──────┴───────┐
               │ control_blend │ blend_amount
               │  (Blend2)    │ 0.0 = locomotion
               │              │ 1.0 = control
               └──────┬───────┘
                      │ input[1]
               ┌──────┴───────┐
               │ ctrl_timescale│ x1.0~2.0
               └──────┬───────┘
                      │
               ┌──────┴───────┐
               │  control_sm  │ hit / stun / death / atk_*
               └──────┬───────┘
                      │
               ┌──────┴───────┐
               │    output    │ → AnimationPlayer
               └──────────────┘
```

### 3.4 Player vs Enemy locomotion 差异

| 方面 | Player | Enemy (BlendTree) |
|------|--------|-------------------|
| 节点类型 | AnimationNodeStateMachine | BlendSpace2D |
| 控制方法 | `set_locomotion_state("idle"/"run")` | `set_locomotion(Vector2(dir, speed))` |
| 动画数量 | 2 (idle, run) | 5+ (idle, left_walk, right_walk, left_run, right_run) |
| 混合方式 | 离散切换 | 连续混合 (blend_position) |
| 适用场景 | 二元状态 (静止/移动) | 多方向+多速度等级 |

**Enemy BlendSpace2D 坐标**:
```
          speed_ratio (y)
              1.0
              │
   left_run ──┼── right_run
    (-1,1)    │    (1,1)
              0.5
              │
  left_walk ──┼── right_walk
   (-1,0.5)  │   (1,0.5)
              │
     idle ────┤ (0,0)
            -1    0    1   direction (x)
```

### 3.5 Player control_sm 状态机

```
control_sm 内部:
  Start → j_up → j_down (travel)
  atk_1 → End (at_end, auto)
  atk_2 → End (at_end, auto)
  atk_3 → End (at_end, auto)
  atk_sp → End (at_end, auto)
  atk_air → End (at_end, auto)
  roll → End (at_end, auto)
  take_hit → End (at_end, auto)

动画完成检测:
  control_sm 中的动画到达 End 节点时
  AnimationTree 发出 animation_finished 信号
  当前状态监听该信号，决定下一步转换
```

### 3.6 Enemy control_sm 状态机

```
control_sm 内部:
  hit → stunned (hit_to_stunned)
  hit → death (hit_to_death)
  stunned → death (stunned_to_death)
```

---

## 4. Player 状态机

### 4.1 状态图

```
                    ┌─────────────────────────────────────────┐
                    │        BEHAVIOR 层 (priority=0)          │
                    │                                          │
                    │   Ground ←──────→ Air                    │
                    │   (idle/run)    (!on_floor / on_floor)   │
                    └────┬───────────────────┬─────────────────┘
                         │                   │
              ┌──────────┴──────────┐        │
              │                     │        │
    ┌─────────┴──────────┐  ┌──────┴─────┐  │
    │ REACTION (p=1)     │  │ REACTION   │  │
    │                    │  │            │  │
    │ Combat             │  │ Roll       │  │
    │ (atk_1/2/3/sp/air) │  │            │  │
    └────────────────────┘  └────────────┘  │
              │                     │        │
              │   damaged           │        │ damaged
              ▼                     ▼        ▼
    ┌──────────────────────────────────────────┐
    │        CONTROL 层 (priority=2)            │
    │                                           │
    │   Hit (take_hit)                          │
    │   → 动画结束后 return_to_locomotion()       │
    └───────────────────────────────────────────┘
```

### 4.2 各状态详解

**文件索引**:
- `Core/StateMachine/PlayerStates/PlayerBaseState.gd` — 玩家状态基类
- `Core/StateMachine/PlayerStates/PlayerGroundState.gd` — 地面状态
- `Core/StateMachine/PlayerStates/PlayerAirState.gd` — 空中状态
- `Core/StateMachine/PlayerStates/PlayerCombatState.gd` — 战斗状态
- `Core/StateMachine/PlayerStates/PlayerRollState.gd` — 翻滚状态
- `Core/StateMachine/PlayerStates/PlayerSpecialAttackState.gd` — 特殊攻击状态

#### Ground (BEHAVIOR=0, interruptible)

```
enter():
  exit_control_state()          → blend 回到 locomotion
  set_locomotion_state("idle")  → 初始 idle
  movement.can_move = true

physics_process_state():
  !is_on_floor()        → emit "air"
  atk_input             → pending_combat_skill = "atk_x", emit "combat"
  V_skill_input         → emit "special_attack"
  roll_input            → emit "roll"
  |velocity.x| > 1.0   → set_locomotion_state("run")
  else                  → set_locomotion_state("idle")
```

#### Air (BEHAVIOR=0, interruptible)

```
enter():
  velocity.y < 0 → enter_control_state("j_up")   → 上升动画
  else           → enter_control_state("j_down")  → 下落动画
  movement.can_move = true

physics_process_state():
  is_on_floor()        → emit "ground"
  atk_input            → pending_combat_skill = "atk_air", emit "combat"
  V_skill_input        → emit "special_attack"
  velocity.y > 0       → playback.travel("j_down")
```

#### Combat (REACTION=1, not interruptible)

```
enter():
  current_skill = owner.pending_combat_skill   → 读取技能名
  enter_control_state(current_skill)           → 播放攻击动画
  set_control_time_scale(2.0)                  → 2倍速
  movement.can_move = false
  connect animation_finished

exit():
  set_control_time_scale(1.0)                  → 恢复正常速度
  movement.can_move = true
  disconnect animation_finished

_on_animation_finished(anim_name):
  if anim_name == current_skill → return_to_locomotion()
```

#### Roll (REACTION=1, not interruptible)

```
enter():
  enter_control_state("roll")
  set_control_time_scale(2.0)
  movement.apply_dash_speed(roll_speed)        → 冲刺位移
  connect animation_finished

exit():
  set_control_time_scale(1.0)
  exit_control_state()
  movement.can_move = true
  disconnect animation_finished
```

#### Hit (CONTROL=2, not interruptible)

```
enter():
  enter_control_state("take_hit")
  movement.can_move = false
  connect animation_finished

exit():
  exit_control_state()
  movement.can_move = true
  disconnect animation_finished

on_damaged():  → 在 Hit 状态中再次受击
  enter_control_state("take_hit")              → 重新播放受击动画
```

#### SpecialAttack (REACTION=1, not interruptible)

```
6 阶段执行流程:
  1. create_effects()    → 残影扩散 + 心跳 + 漩涡特效
  2. detect_enemies()    → 锥形检测敌人 (半径300, 角度45度)
  3. gather_enemies()    → 相机移动 + 子弹时间 + 眩晕敌人
  4. dash_to_target()    → 残影冲刺到漩涡位置
  5. enter_control_state("atk_sp") → 播放攻击动画
  6. cleanup()           → 解除眩晕、隐藏漩涡

特殊处理:
  - 禁用 HurtBox (无敌)
  - can_move = false
  - 与 SkillManager 组件深度耦合
```

### 4.3 攻击时序 (Ground atk_1 完整流程)

```
Input: atk_1 pressed
  │
  ▼
GroundState.physics_process_state()
  │ pending_combat_skill = "atk_1"
  │ transitioned.emit(self, "combat")
  ▼
BaseStateMachine._on_state_transition()
  │ can_transition_to? REACTION(1) > BEHAVIOR(0) → YES
  │
  ├─→ GroundState.exit()
  │
  └─→ CombatState.enter()
       │ enter_control_state("atk_1")
       │   → control_blend = 1.0
       │   → control_sm.start("atk_1")
       │ set_control_time_scale(2.0)
       │ movement.can_move = false
       │
       │ ... 攻击动画播放 ...
       │
       │ AnimationTree.animation_finished("atk_1")
       │
       ▼
  CombatState._on_animation_finished("atk_1")
       │ return_to_locomotion()
       │   → is_on_floor() ? emit "ground" : emit "air"
       │
       ├─→ CombatState.exit()
       │     ctrl_timescale = 1.0
       │     movement.can_move = true
       │
       └─→ GroundState.enter()
             exit_control_state()   → control_blend = 0.0
             set_locomotion_state("idle")
```

---

## 5. Enemy 状态机

### 5.1 EnemyStateMachine

**文件**: `Core/StateMachine/EnemyStateMachine.gd` (155行)

继承 BaseStateMachine，增加:
- **Preset 系统**: BASIC / RANGED / BOSS 三种预设状态组合
- **auto_create_states**: 自动创建状态节点（模板中设为 false）
- **便捷方法**: `force_stun()`, `force_hit()`, `force_knockback()`, `is_controlled()`, `can_act()`

### 5.2 7 个通用状态

**文件目录**: `Core/StateMachine/CommonStates/`

| 状态 | 优先级 | 可打断 | 动画控制 | 核心逻辑 |
|------|--------|--------|---------|---------|
| Idle | BEHAVIOR | Y | `set_locomotion(0,0)` | Timer 等待 → wander, 检测玩家 → chase |
| Wander | BEHAVIOR | Y | `set_locomotion(dir, 0.5)` | 随机方向移动，Timer 结束 → idle |
| Chase | BEHAVIOR | Y | `set_locomotion(dir, speed_ratio)` | 追踪目标，进入攻击范围 → attack |
| Attack | BEHAVIOR | Y | `fire_attack()` (OneShot) | AttackComponent 生成攻击实体 |
| Hit | REACTION | Y | `enter_control_state("hit")` | 固定受击时间，可重置 |
| Stun | CONTROL | N | `enter_control_state("stunned")` | 支持击退速度，Timer 自动恢复 |
| Knockback | REACTION | Y | — | 摩擦力减速，速度低于阈值 → 恢复 |

### 5.3 状态转换图

```
               ┌────── Idle ──────┐
               │  (timer)         │ (检测到玩家)
               ▼                  ▼
            Wander ←───────── Chase
               │                  │ (进入攻击范围)
               │                  ▼
               │              Attack
               │                  │ (攻击完毕)
               │                  │
               └──────────────────┘

任意 BEHAVIOR 状态:
  ├── damaged (无 stun 效果) → Hit → decide_next_state()
  ├── damaged (有 stun 效果) → Stun → decide_next_state()
  └── damaged (有 knockback) → Knockback → decide_next_state()
```

### 5.4 locomotion BlendSpace2D 混合逻辑

```gdscript
# ChaseState 中的 blend 计算:
var speed = body.velocity.length()
var max_speed = chase_speed
var direction = body.velocity.normalized()

var blend_x = sign(direction.x) if abs(direction.x) > 0.1 else 0.0
var blend_y = minf(speed / max_speed, 1.0)  # chase: 0.0~1.0

set_locomotion(Vector2(blend_x, blend_y))

# WanderState 中:
var blend_y = clampf(speed / max_speed, 0.0, 0.5)  # wander: 0.0~0.5 (walk)
```

---

## 6. Boss 状态机

### 6.1 BossStateMachine

**文件**: `Scenes/Characters/Enemies/Boss/Scripts/States/BossStateMachine.gd`

继承 BaseStateMachine，添加:
- **phase_changed 信号监听**: Boss 阶段变化时自动切换状态
- **阶段转换保护**: `is_transitioning_phase` 标志防止转换期间被打断
- Phase 3 自动进入 Enrage 模式（设置 `pending_mode` + `force_transition`）

### 6.2 7 个 Boss 状态 + HSM 攻击子状态机

**状态文件目录**: `Scenes/Characters/Enemies/Boss/Scripts/States/`
**子状态文件目录**: `Scenes/Characters/Enemies/Boss/Scripts/Handlers/`

| 状态 | 优先级 | 核心逻辑 |
|------|--------|---------|
| Idle | BEHAVIOR | 等待检测到玩家 |
| Patrol | BEHAVIOR | 沿巡逻点移动 |
| Chase | BEHAVIOR | 追踪玩家 |
| Circle | BEHAVIOR | 围绕玩家绕行 |
| **Attack (HSM)** | BEHAVIOR | **子状态机** — 管理 Normal / Special / Enrage |
| Retreat | BEHAVIOR | 拉开距离，边退边打 |
| Stun | CONTROL | 眩晕（Phase 3 免疫） |

### 6.3 Attack 层级状态机 (HSM)

Attack 节点是一个**子状态机**，内部管理 3 个攻击子状态。外部状态机只看到一个 "Attack" 状态，子状态对其透明。

```
StateMachine/ (BossStateMachine)
  ├── Idle, Patrol, Chase, Circle, Retreat, Stun  ← 普通 BossState
  └── Attack (BossAttack.gd, extends BossState)    ← 子状态机
        ├── Normal  (BossNormalAttack.gd,  extends BossAttackSubState)
        ├── Special (BossSpecialAttack.gd, extends BossAttackSubState)
        └── Enrage  (BossEnrageAttack.gd,  extends BossAttackSubState)
```

**BossAttackSubState** (模板基类, extends Node):
- 内置 Timer + 中点攻击 + 冷却 + 退出的 **Template Method** 模板
- 子类通过重写 hook 方法自定义行为
- 继承 Node（非 BaseState），不会被父 StateMachine 注册

| Hook 方法 | 默认行为 | Normal | Special | Enrage |
|-----------|---------|--------|---------|--------|
| `_on_enter()` | 停止移动 | 继承 | 继承 | 空（不停移动） |
| `_perform_attack()` | execute + play_anim | 继承 | 仅 execute | N/A |
| `_set_cooldown()` | pass | attack_cooldown | special_cooldown | N/A |
| `_on_attack_finished()` | pass | 距离判断→retreat/chase/circle | Phase3→enrage, else→circle | N/A |
| `on_process()` | timer 模板 | 继承 | 继承 | 重写（空） |
| `on_physics()` | 减速 | 继承 | 继承 | 重写（追击+快速攻击） |
| `get_can_be_interrupted()` | true | 继承 | 继承 | false |
| `_on_damaged()` | Phase1-2→stun | 继承 | 继承 | 空（免疫） |

**子状态切换机制**:
- **外部 → Attack**: 通过 `pending_mode` 属性 + `transitioned.emit("attack")` 或 `force_transition("attack")`
  - Phase 3 自动检测: `enter()` 中如果 `pending_mode == "normal"` 且 Phase 3，自动选择 "enrage"
- **内部切换**: `_switch_mode("special")` → `mode_transition` signal → 父节点 `_on_mode_transition()`
- **子状态退出**: `_transition_to("retreat")` → `force_transition()` 绕过优先级检查（子状态退出总是自愿的）

### 6.4 Boss 数据驱动攻击

每个子状态独立配置一份 `BossAttackData` 资源（`.tres`），通过 Resource 层级结构实现零代码攻击配置:

```
BossSkillDef (.tres)    ← 原子技能定义（模式、弹幕数、角度）
    ↓
BossAttackEntry         ← 引用技能 + 权重
    ↓
BossPhasePattern        ← 单阶段攻击池（entries + cooldown + 加权随机）
    ↓
BossAttackData          ← 顶层容器，patterns[阶段枚举值] 自动映射
```

详见 [Boss 数据驱动攻击系统](10_boss_data_driven_attack.md)。

### 6.5 Boss 状态转换图

```
                ┌────── Idle ──────┐
                │  (检测到玩家)       │
                ▼                   │
             Patrol ──────────── Chase
                                  │ (进入攻击范围)
                                  ▼
            Circle ←─────── Attack (HSM)
              │   (距离合适)  │ ├─ Normal  → retreat/chase/circle
              │              │ ├─ Special → circle / _switch_mode("enrage")
              └──→ Attack ──┘ └─ Enrage  → retreat/patrol / _switch_mode("special")
                                  │
                                  ▼
                              Retreat
                                  │ (拉开距离后)
                                  └──→ Attack / Circle

任意 BEHAVIOR 状态 (Phase 1-2):
  └── damaged → Stun → decide_next_state()

Phase 3 阶段切换:
  └── BossStateMachine._on_phase_changed()
      → states["attack"].pending_mode = "enrage"
      → force_transition("attack")
```

---

## 7. ForestEnemy 状态机

### 7.1 独立的状态基类

**文件**: `Core/StateMachine/ForestEnemyStates/ForestEnemyState.gd` (112行)

ForestEnemy（ForestBoar, ForestSnail）使用 AnimatedSprite2D 而非 AnimationTree，因此有自己的状态基类:

```gdscript
# ForestEnemyState 核心功能:
- RayCast2D 边缘检测 (ground_ray, wall_ray)
- 方向管理 (1=右, -1=左)
- 障碍物检测自动翻转
- AnimatedSprite2D.play() 直接控制动画
```

### 7.2 与主状态机框架的差异

| 方面 | 主框架 (BaseState) | ForestEnemyState |
|------|-------------------|------------------|
| 动画控制 | AnimationTree helper | AnimatedSprite2D.play() |
| 移动方式 | 通过 velocity | 直接 velocity + RayCast 检测 |
| 方向管理 | set_locomotion blend_x | direction 变量 (-1/1) |
| 平台检测 | 无 | ground_ray + wall_ray |
| 精灵翻转 | 通过 EnemyBase._update_sprite_facing() | 直接设置 flip_h |

---

## 8. 状态间通信与组件集成

### 8.1 组件交互图

```
┌─────────────────────────────────────────────────────────┐
│                     状态机层                              │
│                                                          │
│  State ───transitioned──→ StateMachine ──→ State.enter() │
│                                                          │
│  State ←──on_damaged───── StateMachine ←── damaged signal│
│                                                          │
└─────────────────────┬───────────────────────────────────┘
                      │ 交互
┌─────────────────────┴───────────────────────────────────┐
│                     组件层                                │
│                                                          │
│  MovementComponent:                                      │
│    can_move ← State.enter()/exit()                      │
│    apply_dash_speed() ← RollState                       │
│    last_face_direction → AttackComponent                │
│                                                          │
│  AttackComponent:                                        │
│    perform_attack() ← AttackState                       │
│                                                          │
│  CombatComponent:                                        │
│    switch_to_damage_type() ← Animation Method Track     │
│    current_damage → HitBoxComponent                     │
│                                                          │
│  SkillManager:                                           │
│    detect/gather/dash/cleanup ← SpecialAttackState      │
│                                                          │
│  HealthComponent:                                        │
│    damaged signal → StateMachine.on_damaged()            │
│    died signal → BaseCharacter._on_died()               │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### 8.2 Player 技能传递模式

```
GroundState/AirState:
  owner_node.pending_combat_skill = "atk_1"  ← 设置
  transitioned.emit(self, "combat")

CombatState.enter():
  current_skill = owner_node.pending_combat_skill  ← 读取
  enter_control_state(current_skill)
```

这种通过 `owner_node` 属性传递的模式是一种简单但脆弱的状态间通信方式。

---

## 9. 架构优缺点分析

### 9.1 优点

**统一框架**
- Player/Enemy/Boss 共用 BaseState/BaseStateMachine 基础设施
- 新角色只需扩展 BaseState，无需重新实现状态管理逻辑
- 代码复用率高，修改基础设施惠及所有角色

**优先级系统**
- 三层优先级 (BEHAVIOR < REACTION < CONTROL) 解决了"受击打断攻击"、"眩晕打断一切"等游戏逻辑
- `can_be_interrupted` 提供精细控制
- `force_transition()` 为外部系统（如 AttackEffect）提供强制入口

**AnimationTree Helper 抽象**
- 状态脚本无需直接操作 AnimationTree 参数路径
- `enter_control_state()` / `exit_control_state()` / `set_locomotion()` 提供清晰的语义接口
- 动画层变更不影响状态逻辑

**信号驱动转换**
- 状态间无直接引用，通过信号解耦
- 状态机验证所有转换请求，防止非法切换
- 支持外部系统（HealthComponent）触发状态变更

**模板内置状态**
- 7/9 个状态预置在模板场景中
- 子场景仅需覆盖差异化的状态脚本
- 零代码即可创建功能完整的敌人

### 9.2 缺点

**动画系统不统一**
- Player 使用 AnimationTree (StateMachine locomotion)
- Enemy (通用) 使用 AnimationTree (BlendSpace2D locomotion)
- Boss 使用 AnimationPlayer 直接控制（完全绕过 AnimationTree）
- ForestEnemy 使用 AnimatedSprite2D 直接控制
- 四种不同的动画控制方式增加了维护复杂度

**SpecialAttackState 过度复杂**
- 133 行的状态脚本，包含 6 个执行阶段
- 与 SkillManager 组件深度耦合（直接调用多个方法）
- 包含相机控制、子弹时间、特效管理等非状态机职责
- 违反了"单一职责"原则

**pending_combat_skill 传递方式脆弱**
- 通过 `owner_node.pending_combat_skill` 属性传递技能名
- 缺乏类型安全（纯字符串）
- 时序依赖：必须在 emit transitioned 之前设置
- 如果多个状态同时设置会产生竞态

**force_transition 绕过优先级**
- `force_transition()` 跳过所有优先级检查
- 任何外部系统都可以强制切换状态，可能导致意外行为
- 例如：眩晕恢复时 force_transition("wander") 可能打断玩家的有效攻击

**状态堆栈未实现**
- 早期文档提到了 push_state/pop_state 堆栈模式
- 当前代码中没有实现状态堆栈
- Stun 恢复后通过 `decide_next_state()` 简单选择下一状态，而非恢复被中断的状态

---

## 10. 待提升项与改进建议

### 10.1 短期改进（低风险、高收益）

#### A. ~~数据驱动的 Boss 攻击模式~~ (已完成)

已通过 HSM 子状态机 + BossSkillDef/BossAttackEntry/BossPhasePattern/BossAttackData 资源层级实现。
详见 [Boss 数据驱动攻击系统](10_boss_data_driven_attack.md)。

#### B. 技能传递改用 Dictionary
```
当前: owner_node.pending_combat_skill = "atk_1"
建议: 使用 Dictionary 或专用数据类，支持传递额外参数

# 改进方案
var pending_skill_data: Dictionary = {
    "skill_name": "atk_1",
    "combo_count": 1,
    "air_attack": false
}
```

#### C. ~~Timer 池化~~ (已完成)

BaseState 已使用懒创建复用 Timer (`_ensure_timer()` + `_disconnect_timer_callback()`)。

### 10.2 中期改进（中等风险、中等收益）

#### D. 为 Boss 添加 AnimationTree 支持
```
当前: Boss 直接使用 AnimationPlayer，绕过 AnimationTree 系统
建议: BossBase.tscn 添加 AnimationTree 节点，使用与 EnemyBase 相同的 BlendTree 结构

收益:
- Boss 可以使用 enter_control_state() 等统一 helper
- 动画混合更平滑
- 阶段转换可以利用 blend 过渡

成本:
- 需要为 Boss 配置完整的 BlendTree
- BossBaseState 需要适配 AnimationTree 调用
```

#### E. SpecialAttackState 责任拆分
```
当前: SpecialAttackState 同时管理特效、相机、子弹时间、冲刺、动画
建议: 将 6 阶段拆分为 SkillManager 的协程/状态机

# SkillManager 内部实现阶段推进
func execute_special_attack():
    await phase_create_effects()
    await phase_detect_enemies()
    await phase_gather_enemies()
    await phase_dash_to_target()
    await phase_play_attack()
    phase_cleanup()

# SpecialAttackState 只负责:
func enter():
    movement.can_move = false
    skill_manager.execute_special_attack()
    await skill_manager.special_attack_completed
    return_to_locomotion()
```

#### F. ForestEnemy 统一到 AnimationTree 框架
```
当前: ForestEnemy 完全绕过 AnimationTree，使用 AnimatedSprite2D 直接控制
建议: 为 AnimatedSprite2D 类型的敌人创建轻量级 AnimationTree 适配器

或者: 接受 AnimatedSprite2D 作为合法的简单动画方案，
     但在 BaseState 中增加 AnimatedSprite2D helper 方法:

func play_sprite_animation(anim_name: String):
    var sprite = owner_node.get_node("AnimatedSprite2D")
    if sprite:
        sprite.play(anim_name)
```

### 10.3 长期改进（需架构变更）

#### G. 状态堆栈实现
```
用途: Stun 恢复后恢复被中断的状态
     Boss 阶段转换时保存当前行为状态

# BaseStateMachine 中:
var state_stack: Array[BaseState] = []

func push_state(state_name: String):
    state_stack.push_back(current_state)
    current_state.pause()  # 新增 pause() 生命周期
    _execute_transition(states[state_name])

func pop_state():
    current_state.exit()
    current_state = state_stack.pop_back()
    current_state.resume()  # 新增 resume() 生命周期
```

#### H. 并行状态机 (Parallel State Machine)
```
用途: 将 locomotion 和 combat 分离为独立的并行状态机

┌────────────┐  ┌────────────┐
│ Movement SM │  │ Combat SM  │
│             │  │            │
│ Idle ↔ Run  │  │ Idle       │
│ ↕           │  │ ↕          │
│ Air         │  │ Attack     │
│             │  │ ↕          │
│             │  │ Roll       │
│             │  │ ↕          │
│             │  │ SpecialAtk │
└────────────┘  └────────────┘

收益: 移动和战斗状态独立管理，减少状态组合爆炸
代价: 需要处理两个状态机之间的协调
```

### 10.4 改进优先级

| 优先级 | 改进项 | 状态 |
|--------|--------|------|
| ~~P0~~ | ~~C. Timer 池化~~ | **已完成** — 懒创建复用 Timer |
| ~~P1~~ | ~~A. Boss 攻击数据驱动~~ | **已完成** — HSM + Resource 数据驱动 |
| P1 | B. 技能传递改进 | 待实施 |
| P2 | E. SpecialAttack 拆分 | 待实施 |
| P2 | D. Boss AnimationTree | 待实施 |
| P3 | F. ForestEnemy 统一 | 待实施 |
| P3 | G. 状态堆栈 | 待评估 |
| P4 | H. 并行状态机 | 待评估 |

---

## 文件索引

**核心框架**:
- `Core/StateMachine/BaseState.gd` — 通用状态基类 (444行)
- `Core/StateMachine/BaseStateMachine.gd` — 通用状态机 (226行)
- `Core/StateMachine/EnemyStateMachine.gd` — 敌人状态机扩展 (155行)

**Player 状态**:
- `Core/StateMachine/PlayerStates/PlayerBaseState.gd`
- `Core/StateMachine/PlayerStates/PlayerGroundState.gd`
- `Core/StateMachine/PlayerStates/PlayerAirState.gd`
- `Core/StateMachine/PlayerStates/PlayerCombatState.gd`
- `Core/StateMachine/PlayerStates/PlayerRollState.gd`
- `Core/StateMachine/PlayerStates/PlayerSpecialAttackState.gd`

**Enemy 通用状态**:
- `Core/StateMachine/CommonStates/IdleState.gd`
- `Core/StateMachine/CommonStates/ChaseState.gd`
- `Core/StateMachine/CommonStates/AttackState.gd`
- `Core/StateMachine/CommonStates/HitState.gd`
- `Core/StateMachine/CommonStates/StunState.gd`
- `Core/StateMachine/CommonStates/KnockbackState.gd`
- `Core/StateMachine/CommonStates/WanderState.gd`

**Boss 状态**:
- `Scenes/Characters/Enemies/Boss/Scripts/States/BossBaseState.gd` — Boss 状态基类
- `Scenes/Characters/Enemies/Boss/Scripts/States/BossAttack.gd` — Attack 子状态机
- `Scenes/Characters/Enemies/Boss/Scripts/States/BossStateMachine.gd` — Boss 状态机
- `Scenes/Characters/Enemies/Boss/Scripts/States/BossRetreat.gd` — 撤退状态

**Boss 攻击子状态 (HSM)**:
- `Scenes/Characters/Enemies/Boss/Scripts/Handlers/BossAttackSubState.gd` — 模板基类
- `Scenes/Characters/Enemies/Boss/Scripts/Handlers/BossNormalAttack.gd` — Normal 子状态
- `Scenes/Characters/Enemies/Boss/Scripts/Handlers/BossSpecialAttack.gd` — Special 子状态
- `Scenes/Characters/Enemies/Boss/Scripts/Handlers/BossEnrageAttack.gd` — Enrage 子状态

**ForestEnemy 状态**:
- `Core/StateMachine/ForestEnemyStates/ForestEnemyState.gd`
- `Core/StateMachine/ForestEnemyStates/ForestChaseState.gd`

**组件**:
- `Core/Components/MovementComponent.gd`
- `Core/Components/AttackComponent.gd`
- `Core/Components/SkillManager.gd`
- `Core/Components/CombatComponent.gd`

---

> **相关文档**:
> - [角色模板系统](07_character_template_architecture.md) — 模板场景设计
> - [战斗系统架构](02_combat_system_architecture.md) — 战斗系统
> - [组件系统架构](03_component_system_architecture.md) — 组件系统
> - [信号驱动架构](04_signal_driven_architecture.md) — 信号通信
>
> **更新历史**:
> - 2026-01-20: 创建文档，基础状态机架构
> - 2026-02-27: 新增 Player 状态机 + AnimationTree 详解
> - 2026-03-15: 全面重写，整合 Player/Enemy/Boss/ForestEnemy 四套状态机，深度分析优缺点和改进建议
> - 2026-03-16: Boss 攻击 HSM 重构 — Attack/SpecialAttack/Enrage 合并为 Attack 子状态机，数据驱动攻击系统，Timer 池化标记完成
