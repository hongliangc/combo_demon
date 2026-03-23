# Boss 数据驱动攻击系统

> **类型**: 架构文档 + 配置教程
> **日期**: 2026-03-16
> **Godot 版本**: 4.6
> **设计模式**: Resource 数据驱动 + 加权随机 + 阶段索引 + HSM 子状态机
> **范围**: Boss 攻击子状态机（Attack 节点内 Normal / Special / Enrage 子状态）

---

## 目录

1. [系统概述](#1-系统概述)
2. [Resource 层级结构](#2-resource-层级结构)
3. [攻击模式枚举](#3-攻击模式枚举)
4. [配置教程：编辑器操作](#4-配置教程编辑器操作)
5. [配置教程：.tres 文件](#5-配置教程tres-文件)
6. [现有配置参考](#6-现有配置参考)
7. [扩展指南：添加更多阶段](#7-扩展指南添加更多阶段)
8. [扩展指南：添加新攻击模式](#8-扩展指南添加新攻击模式)
9. [运行时执行流程](#9-运行时执行流程)
10. [关键文件索引](#10-关键文件索引)

---

## 1. 系统概述

Boss 攻击系统使用 **层级状态机 (HSM)** + **数据驱动** 架构。主状态机中只有一个 `Attack` 状态节点，内部管理 3 个攻击子状态（Normal / Special / Enrage），每个子状态独立配置一份 `BossAttackData` 资源。

```
StateMachine/ (BaseStateMachine)
  ├── Idle, Patrol, Chase, Circle, Retreat, Stun
  └── Attack (BossAttackState, extends BossState)  ← 子状态机
        ├── Normal  (BossNormalAttack,  attack_data = NormalAttackData.tres)
        ├── Special (BossSpecialAttack, attack_data = SpecialAttackData.tres)
        └── Enrage  (BossEnrageAttack,  attack_data = EnrageAttackData.tres)
```

**核心优势**:
- 零代码增删攻击招式，编辑器中拖拽配置
- 阶段数量不限，数组索引自动映射
- 权重系统控制招式出现概率
- 子状态间通过 `_switch_mode()` 内部切换，对外部状态机透明
- 子状态继承 `BossAttackSubState`（Template Method 模式），共享 timer + 中点攻击模板

---

## 2. Resource 层级结构

```
BossSkillDef (.tres)              ← 原子技能定义（模式、参数），独立文件可复用
    ↓
BossAttackEntry                   ← 引用技能 + 权重
    ↓
BossPhasePattern                  ← 单阶段攻击池（entries + cooldown + 加权随机）
    ↓
BossAttackData                    ← 顶层容器，绑定到子状态节点
├── patterns: Array[BossPhasePattern]
│   ├── [0] Phase 1 Pattern       ← 对应 PHASE_1（枚举值 0）
│   │   ├── cooldown: 1.5
│   │   └── entries: Array[BossAttackEntry]
│   │       ├── Entry A  (skill=FanSpread3.tres, weight=2.0)
│   │       ├── Entry B  (skill=RapidFire3.tres, weight=1.0)
│   │       └── Entry C  (skill=ComboTripleShot.tres, weight=1.0)
│   ├── [1] Phase 2 Pattern
│   └── [N] Phase N+1 Pattern     ← 可无限扩展
```

**映射规则**: `patterns[阶段枚举值]`，超出范围自动 clamp 到最后一个。

---

## 3. 攻击模式枚举

`BossSkillDef.AttackMode`:

| 枚举值 | 名称 | BossSkillDef 参数 | 说明 |
|--------|------|-------------------|------|
| 0 | `FAN_SPREAD` | projectile_count, spread_angle | 扇形弹幕 |
| 1 | `SPIRAL` | projectile_count | 螺旋弹幕 |
| 2 | `LASER` | — | 激光（需 target_node） |
| 3 | `AOE` | — | 冲击波（需 aoe_scene） |
| 4 | `COMBO` | combo_factory | 预定义连击序列 |
| 5 | `RAPID_FIRE` | projectile_count | 快速追踪射击（需 target_node） |

**可用 combo_factory**:
- `"create_triple_shot"` — 三连射
- `"create_fan_spiral"` — 扇形 + 螺旋
- `"create_laser_shockwave"` — 激光 + 冲击波
- `"create_ultimate_combo"` — 终极连击（螺旋 + 扇形 + AOE + 激光）
- `"create_double_spiral"` — 双重螺旋

---

## 4. 配置教程：编辑器操作

### 4.1 查看现有配置

1. 打开 `Scenes/Characters/Templates/BossBase.tscn`
2. 在场景树中展开 `StateMachine → Attack`
3. 选择 `Normal` / `Special` / `Enrage` 子节点
4. Inspector 面板 → `attack_data` 属性

### 4.2 修改攻击招式

1. 点击 `attack_data` 展开 `BossAttackData`
2. 展开 `patterns` 数组
3. 选择阶段索引（如 `[0]` = Phase 1）
4. 展开 `entries` 数组
5. 修改具体 Entry 的 `skill`（拖拽 Skills/*.tres 文件）和 `weight`

### 4.3 添加新攻击招式

1. 创建新的 `BossSkillDef` .tres 文件（配置 mode、projectile_count 等）
2. 在目标阶段的 `entries` 数组中点击 `+` 按钮
3. 新 Entry 中选择刚创建的 skill，调整 `weight`

### 4.4 添加新阶段

1. 在 `patterns` 数组中点击 `+` 按钮
2. 新元素自动映射到下一个阶段索引
3. 配置 `cooldown` 和 `entries`

---

## 5. 配置教程：.tres 文件

### BossSkillDef (.tres) — 技能定义

```ini
[gd_resource type="Resource" script_class="BossSkillDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://Core/Resources/BossSkillDef.gd" id="1"]

[resource]
script = ExtResource("1")
skill_name = "fan_spread_5"
mode = 0                    ; 0=FAN_SPREAD, 1=SPIRAL, 2=LASER, 3=AOE, 4=COMBO, 5=RAPID_FIRE
projectile_count = 5
spread_angle = 0.7854       ; PI/4 ≈ 45°
combo_factory = ""          ; COMBO 模式填工厂方法名
```

### BossAttackEntry — 引用技能 + 权重

```ini
[sub_resource type="Resource" id="my_entry"]
script = ExtResource("3_entry")
skill = ExtResource("my_skill_def")  ; 引用 BossSkillDef .tres
weight = 1.0
```

**常用角度值**:
- `PI / 6` ≈ `0.5236`（30°）
- `PI / 4` ≈ `0.7854`（45°）
- `PI / 3` ≈ `1.0472`（60°）

---

## 6. 现有配置参考

### BossNormalAttackData（Normal 子状态）

| 阶段 | 冷却 | 攻击池 |
|------|------|--------|
| Phase 1 | 1.5s | FanSpread3 / RapidFire3 / ComboTripleShot |
| Phase 2 | 1.0s | FanSpread5 / Spiral16 / Laser / ComboFanSpiral / ComboLaserShockwave |
| Phase 3 | 0.7s | FanSpread8 / Spiral16 / Laser / Aoe / ComboUltimate / ComboDoubleSpiral |

### BossSpecialAttackData（Special 子状态）

| 阶段 | 冷却 | 攻击池 |
|------|------|--------|
| Phase 1 | 5.0s | Laser |
| Phase 2 | 4.0s | Spiral16 |
| Phase 3 | 2.0s | ComboUltimate / ComboDoubleSpiral |

### BossEnrageAttackData（Enrage 子状态）

| 阶段 | 冷却 | 攻击池 |
|------|------|--------|
| Phase 1 | 0.5s | FanSpread3 |
| Phase 2 | 0.5s | FanSpread5 |
| Phase 3 | 0.5s | FanSpread6 / RapidFire3 / Spiral12 / Laser |

---

## 7. 扩展指南：添加更多阶段

需要修改 **3 处**：

### 7.1 添加 Phase 枚举值

**文件**: `Core/Characters/BossBase.gd`

```gdscript
enum Phase {
    PHASE_1,
    PHASE_2,
    PHASE_3,
    PHASE_4,  # ← 新增
}
```

### 7.2 添加阶段触发条件

**文件**: `Core/Characters/BossBase.gd` → `check_phase_transition()`

```gdscript
@export var phase_4_health_percent := 0.15  # 15% 血量触发
```

### 7.3 在 .tres 中追加 Pattern

在 `patterns` 数组末尾添加新的 `BossPhasePattern`（编辑器中点 `+`，或编辑 .tres 文件）。

**无需修改代码** — `BossAttackData.get_pattern()` 使用数组索引 + clamp，自动支持任意数量阶段。

---

## 8. 扩展指南：添加新攻击模式

需要修改 **2 处**：

### 8.1 添加枚举值

**文件**: `Core/Resources/BossSkillDef.gd`

```gdscript
enum AttackMode {
    FAN_SPREAD,
    SPIRAL,
    LASER,
    AOE,
    COMBO,
    RAPID_FIRE,
    HOMING_MISSILE,  # ← 新增
}
```

### 8.2 添加分派逻辑

**文件**: `Scenes/Characters/Enemies/Boss/Scripts/States/BossBaseState.gd` → `_dispatch_attack()`

```gdscript
func _dispatch_attack(attack_manager: BossAttackManager, entry: BossAttackEntry) -> void:
    var skill := entry.skill
    match skill.mode:
        # ... 现有模式 ...
        BossSkillDef.AttackMode.HOMING_MISSILE:
            attack_manager.fire_homing_missile(skill.projectile_count)
```

然后创建新的 `BossSkillDef` .tres 文件配置新模式，在编辑器中拖拽到 `BossAttackEntry.skill` 即可。

---

## 9. 运行时执行流程

```
外部状态 → transitioned.emit("attack")
  └─ BossAttackState.enter()
       ├─ 读取 pending_mode（默认 "normal"）
       ├─ Phase 3 自动检测: mode=="normal" && Phase3 → mode="enrage"
       ├─ _activate_sub(mode)
       │     ├─ attack_data = sub_state.attack_data
       │     ├─ can_be_interrupted = sub_state.get_can_be_interrupted()
       │     └─ sub_state.on_enter()
       └─ 子状态 on_process(delta)
            ├─ timer 倒计时
            ├─ 中点触发: _perform_attack()
            │     └─ BossState.execute_data_driven_attack()
            │          ├─ attack_data.get_pattern(phase)  → BossPhasePattern
            │          ├─ pattern.pick_random()            → BossAttackEntry (加权随机)
            │          └─ _dispatch_attack(manager, entry) → match skill.mode → fire_*
            └─ 结束: _set_cooldown() + _on_attack_finished()
                  └─ 距离判断 → retreat/chase/circle 或 _switch_mode()
```

### 转换机制

**外部 → Attack 子状态**:
- 默认: `transitioned.emit("attack")` → `pending_mode="normal"` → Phase 1-2 进入 Normal, Phase 3 自动进入 Enrage
- 显式: `states["attack"].pending_mode = "enrage"` + `force_transition("attack")` → 进入指定子状态

**子状态 → 外部状态**:
- `_transition_to("retreat")` → `force_transition()` 绕过优先级检查
- 子状态退出总是自愿的，不受 `can_be_interrupted` 限制

**内部模式切换**: `_switch_mode("special")` → `mode_transition` signal → `BossAttackState._on_mode_transition()` → exit 当前 + activate 新子状态

**加权随机示例**: 3 个 Entry 权重分别为 2.0, 1.0, 1.0
- Entry A: 2/4 = 50% 概率
- Entry B: 1/4 = 25% 概率
- Entry C: 1/4 = 25% 概率

---

## 10. 关键文件索引

| 文件 | 作用 |
|------|------|
| `Core/Resources/BossSkillDef.gd` | 原子技能定义（模式、弹幕数、角度、连击工厂） |
| `Core/Resources/BossAttackEntry.gd` | 技能引用 + 选择权重 |
| `Core/Resources/BossPhasePattern.gd` | 单阶段攻击池（entries + cooldown + 加权随机） |
| `Core/Resources/BossAttackData.gd` | 顶层容器（patterns 数组，按阶段索引） |
| `Boss/Scripts/States/BossBaseState.gd` | 执行引擎（execute / dispatch / combo） |
| `Boss/Scripts/States/BossAttack.gd` | 攻击子状态机（管理 Normal/Special/Enrage） |
| `Boss/Scripts/Handlers/BossAttackSubState.gd` | 子状态模板基类（Timer + Hook 方法） |
| `Boss/Scripts/Handlers/BossNormalAttack.gd` | Normal 子状态 |
| `Boss/Scripts/Handlers/BossSpecialAttack.gd` | Special 子状态 |
| `Boss/Scripts/Handlers/BossEnrageAttack.gd` | Enrage 子状态 |
| `Boss/Resources/BossNormalAttackData.tres` | Normal 子状态配置 |
| `Boss/Resources/BossSpecialAttackData.tres` | Special 子状态配置 |
| `Boss/Resources/BossEnrageAttackData.tres` | Enrage 子状态配置 |
| `Boss/Resources/Skills/*.tres` | 共享技能定义（14 个） |
| `Templates/BossBase.tscn` | 场景模板（状态节点绑定） |
