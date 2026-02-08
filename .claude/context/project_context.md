# Combo Demon - 项目上下文

> **2D 动作游戏** | Godot 4.4.1 | 连招战斗系统 | 81个脚本 | 21个场景

## 🎯 项目概述

**核心玩法**: 流畅连招战斗 + 状态机AI + 多阶段Boss战 + 攻击特效系统

**技术栈**: Godot 4.4.1 (Mobile Renderer) | GDScript | Git | MCP

---

## 🆕 最近更新

### 2026-02-08: AI 状态机 + AnimationTree 架构优化 ✅
**类型**: 状态机框架升级 + 动画系统重构

**核心成果**:
- **三层优先级状态机**: BEHAVIOR(0) < REACTION(1) < CONTROL(2)，高优先级自动打断低优先级
- **BaseState 内置 AnimationTree 控制**: set_locomotion / fire_attack / enter_control_state
- **分层动画混合**: locomotion(BlendSpace2D) + attack_oneshot(OneShot) + control_sm(StateMachine)
- **StunEffect 攻击特效**: X攻击附带眩晕，触发 stun 状态和动画
- **ForestEnemyState 体系**: 地面敌人通用基类（边缘/墙壁检测）

### 2026-01-19: Player自治组件架构重构 ✅
**类型**: 重大架构优化

**成果**: Player 从单体278行重构为5个自治组件（119行主类 + 5组件）

---

## 📦 核心架构

### 系统层级

```
AutoLoad 单例
├── GameManager      - 游戏流程、角色选择、场景切换
├── UIManager        - UI层级管理（6层）、Toast、对话框
├── SoundManager     - 音效管理
├── DamageNumbers    - 伤害数字显示
└── DebugConfig      - 4级日志（debug/info/warn/error）+ 分类标签

核心系统
├── 状态机框架 (Core/StateMachine/)
│   ├── BaseStateMachine     - 通用框架，AnimationMode: NONE/ANIM_TREE/SIGNAL
│   ├── EnemyStateMachine    - Preset: BASIC/RANGED/BOSS 自动创建状态
│   ├── BaseState            - 三层优先级 + AnimationTree 控制方法
│   ├── CommonStates/        - 7个通用状态（高复用）
│   │   ├── IdleState        - 玩家检测，定时转wander
│   │   ├── ChaseState       - 追踪目标，blend_y=speed/max_speed
│   │   ├── WanderState      - 随机巡逻，blend_y限0.5(walk)
│   │   ├── AttackState      - fire_attack() OneShot触发
│   │   ├── HitState         - enter_control_state("hit"), REACTION优先级
│   │   ├── StunState        - enter_control_state("stunned"), CONTROL优先级
│   │   └── KnockbackState   - 击退物理减速, REACTION优先级
│   └── ForestEnemyStates/   - 地面敌人基类（边缘/墙壁检测, AnimatedSprite2D）
│
├── 伤害系统 (Core/Resources/)
│   ├── Damage (Resource)    - 伤害值 + effects: Array[AttackEffect]
│   ├── Hitbox/Hurtbox       - 碰撞检测
│   └── AttackEffect子类     - StunEffect/KnockUp/KnockBack/Gather/ForceStun
│
├── Boss战
│   ├── Boss基类             - 多阶段（3阶段）、8方位移动
│   └── 状态机（9状态）      - idle/patrol/chase/circle/attack/retreat/special/enrage/stun
│
└── Player (自治组件架构)
    ├── HealthComponent      - 生命值、受伤、死亡
    ├── MovementComponent    - 自动处理输入和移动
    ├── AnimationComponent   - AnimationTree管理
    ├── CombatComponent      - 技能输入、伤害类型切换（Physical/KnockUp/Special）
    └── SkillManager         - 特殊攻击: 扇形检测 → 移动 → 动画 → 聚集
```

---

## 🧩 关键模块

### 状态机 + AnimationTree 架构 ⭐⭐⭐⭐⭐

**三层优先级系统**:
```
CONTROL  (2) - 最高：stun, frozen（不可被同级打断）
REACTION (1) - 中级：hit, knockback
BEHAVIOR (0) - 基础：idle, wander, chase, attack
```

**BaseState AnimationTree 控制方法**:
```gdscript
set_locomotion(blend: Vector2)       # 设置 BlendSpace2D 混合位置
fire_attack() / abort_attack()       # 触发/中止 OneShot 攻击动画
enter_control_state(state_name)      # 进入控制状态（hit/stunned/death）+ blend_amount=1.0
exit_control_state()                 # 退出控制状态，blend_amount=0.0
```

**AnimationNodeBlendTree 分层结构** (dinosaur为例):
```
BlendTree (root)
├── locomotion (BlendSpace2D)     ← 行为层: idle/walk/run
│   ├── (0, 0)     idle
│   ├── (±1, 0.5)  left/right_walk
│   └── (±1, 1.0)  left/right_run
├── attack_oneshot (OneShot)      ← 攻击层: 一次性覆盖
├── control_sm (StateMachine)     ← 控制层: hit → stunned → death
│   ├── hit      (REACTION)
│   ├── stunned  (CONTROL)
│   └── death    (终态)
└── output (Blend2)               ← blend_amount 混合 locomotion 与 control_sm
```

**状态 → 动画映射**:

| 状态 | 优先级 | 动画调用 | 效果 |
|------|--------|----------|------|
| Idle | BEHAVIOR | set_locomotion(0,0) | idle动画 |
| Wander | BEHAVIOR | set_locomotion(dir, 0.5) | walk动画 |
| Chase | BEHAVIOR | set_locomotion(dir, 1.0) | run动画 |
| Attack | BEHAVIOR | fire_attack() | OneShot攻击 |
| Hit | REACTION | enter_control_state("hit") | hit动画 |
| Stun | CONTROL | enter_control_state("stunned") | stunned动画 |

**伤害 → 状态转换链**:
```
Damage.apply_effects(enemy) → StunEffect._find_state_machine() → transition("stun")
                             → BaseState.on_damaged() 检查 has_effect("StunEffect") → emit stun
```

### 伤害系统 ⭐⭐⭐⭐

**Damage Resource**: `amount` + `effects: Array[AttackEffect]`

**特效类型**:
- `StunEffect` - 眩晕（触发stun状态，1.5秒）
- `ForceStunEffect` - 强制眩晕（禁用移动，用于特殊技能）
- `KnockUpEffect` - 击飞（抛物线，重力模拟）
- `KnockBackEffect` - 击退
- `GatherEffect` - 聚集敌人

**配置示例** (Physical.tres): `effects = [StunEffect(1.5s)]`

### Boss战 ⭐⭐⭐⭐⭐

**三阶段**: 100%-66%(基础) → 66%-33%(1.3x加速) → 33%-0%(1.5x狂暴)

**8方位系统**: 预计算DIRECTIONS_8，平滑旋转

---

## 🎮 配置

### 输入映射

| 操作 | 按键 | 功能 |
|------|------|------|
| move_* | 方向键 | 8方向移动 |
| primary_fire | 鼠标左键 | 主攻击 |
| atk_sp | V | 特殊攻击 |
| atk_1/2/3 | X/W/E | 技能1/2/3 |
| dash/roll | 空格/R | 冲刺/翻滚 |

### 物理层

| Layer | 名称 | 碰撞规则 |
|-------|------|---------|
| 2 | Player | ✅ World, Walls, Enemy, Enemy Projectile |
| 3 | Player Projectile | ✅ Enemy, Walls |
| 4 | Enemy | ✅ World, Walls, Player, Player Projectile |
| 5 | Enemy Projectile | ✅ Player, Walls |
| 8 | Walls | ✅ All |

---

## 📁 目录结构

```
Core/
├── Autoloads/       - 全局单例
├── StateMachine/    - 状态机框架
│   ├── BaseState.gd / BaseStateMachine.gd
│   ├── EnemyStateMachine.gd
│   ├── CommonStates/    - 7个通用状态
│   └── ForestEnemyStates/ - 地面敌人状态
├── Resources/       - Damage, AttackEffect, StunEffect 等
├── Components/      - Health, Hitbox, Hurtbox, Combat, Movement, Animation, SkillManager
├── Data/SkillBook/  - .tres 资源文件（Physical, KnockUp, SpecialAttack）
└── Effects/         - 视觉特效（AfterImage, Highlight, Vortex）

Scenes/
├── Characters/
│   ├── Player/      - Hahashin（自治组件架构）
│   └── Enemies/     - dinosaur/ (AnimationTree) + boss/ + Forest系列
├── Levels/          - 关卡场景
└── UI/              - 所有UI组件
```

---

## 📚 设计原则

1. **通用性** - `@export` 配置化，场景复用
2. **模块化** - 单一职责，组件模式，信号解耦
3. **可复用性** - Resource存储数据，清晰接口
4. **简洁实用** - 避免过度设计，代码自解释

### 命名规范

```gdscript
class_name PlayerHealth      # PascalCase
var max_health: float        # snake_case
const MAX_SPEED = 200.0      # UPPER_SNAKE_CASE
signal health_changed()      # snake_case
func take_damage() -> void   # snake_case + 类型注解
```

### AnimatedSprite2D 配置 (Forest敌人)

**SpriteFrames 切图**: 面板 → "Add frames from Sprite Sheet" → 设置帧尺寸 → 选帧

| 敌人 | 帧尺寸 | 动画 |
|------|--------|------|
| ForestBee | 64x64 | fly, attack, hit |
| ForestBoar | 48x32 | idle, run, walk, hit |
| ForestSnail | 48x32 | walk, hide, dead |

---

**最后更新**: 2026-02-08
**Token消耗**: ~2800 tokens
**项目状态**: ✅ 可运行，架构清晰，AI状态机+AnimationTree完善
