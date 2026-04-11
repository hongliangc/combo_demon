# 两个新 Boss 设计文档

## 概述

基于 `res://Assets/Art/BLADE_KEEPER/` 和 `res://Assets/Art/BOSS_SLIME/` 资源，创建两个新 Boss：BladeKeeper（技巧型剑士）和 DemonSlime（力量型史莱姆），各自配备独立关卡（Level4、Level5）。

## 架构决策

- **继承 BossBase**，不新增中间层，不改动现有 Boss
- **各自独立 AttackManager**，不扩展现有 BossAttackManager
- **AnimatedSprite2D + SpriteFrames**（PNG 序列帧），非 AnimationTree
- 复用 BossStateMachine 的阶段转换逻辑

```
BossBase (不动)
├── Boss (现有 Eye Boss，不动)
├── BladeKeeperBoss (新) → BladeKeeperStateMachine + BladeKeeperAttackManager
└── DemonSlimeBoss (新) → DemonSlimeStateMachine + DemonSlimeAttackManager
```

## 文件结构

```
Scenes/Characters/Enemies/
├── boss/                    (现有，不动)
├── BladeKeeper/
│   ├── BladeKeeperBoss.tscn
│   ├── BladeKeeperBoss.gd
│   ├── BladeKeeperAttackManager.gd
│   ├── BladeKeeperStateMachine.gd
│   ├── States/
│   │   ├── BKBaseState.gd
│   │   ├── BKIdle.gd
│   │   ├── BKChase.gd
│   │   ├── BKAttack.gd
│   │   ├── BKDefend.gd
│   │   ├── BKRoll.gd
│   │   ├── BKProjectile.gd
│   │   ├── BKTrap.gd
│   │   ├── BKSpecial.gd
│   │   └── BKStun.gd
│   ├── Attacks/
│   │   ├── BKSwordProjectile.tscn
│   │   ├── BKSwordProjectile.gd
│   │   ├── BKTrap.tscn
│   │   └── BKTrap.gd
│   └── Resources/
│       ├── phase1_config.tres
│       ├── phase2_config.tres
│       └── phase3_config.tres
├── DemonSlime/
│   ├── DemonSlimeBoss.tscn
│   ├── DemonSlimeBoss.gd
│   ├── DemonSlimeAttackManager.gd
│   ├── DemonSlimeStateMachine.gd
│   ├── States/
│   │   ├── DSBaseState.gd
│   │   ├── DSIdle.gd
│   │   ├── DSChase.gd
│   │   ├── DSCleave.gd
│   │   ├── DSSlam.gd
│   │   └── DSStun.gd
│   ├── Attacks/
│   │   ├── DSShockwave.tscn
│   │   └── DSShockwave.gd
│   ├── MiniSlime/
│   │   ├── MiniSlime.tscn
│   │   └── MiniSlime.gd
│   └── Resources/
│       ├── phase1_config.tres
│       ├── phase2_config.tres
│       └── phase3_config.tres
Scenes/Levels/
├── Level4_BladeKeeper/
│   ├── Level4.tscn
│   └── Level4.gd
└── Level5_DemonSlime/
    ├── Level5.tscn
    └── Level5.gd
```

---

## Boss 1: BladeKeeper（技巧型剑士）

### 角色定位

快节奏近战剑士Boss。招式多变：3段连击、防御反击、翻滚闪避、飞剑投射、陷阱布置。难度来源于节奏快和招式多样性。

### 动画映射（AnimatedSprite2D）

| 动画名 | 资源目录 | 帧数 |
|---|---|---|
| idle | 01_idle | - |
| run | 02_run | - |
| atk_1 | 07_1_atk | 6 |
| atk_2 | 08_2_atk | - |
| atk_3 | 09_3_atk | - |
| sp_atk | 10_sp_atk | 11 |
| air_atk | air_atk | - |
| defend | 11_defend | - |
| roll | 04_roll | - |
| projectile_cast | 05_projectile_cast | 7 |
| trap_cast | 06_trap_cast | - |
| take_hit | 12_take_hit | - |
| death | 13_death | - |

### 状态机（9个状态）

| 状态 | 优先级 | 行为描述 |
|---|---|---|
| BKIdle | BEHAVIOR(0) | 原地待机，检测到玩家→Chase |
| BKChase | BEHAVIOR(0) | 追向玩家，进入攻击范围后由 AttackManager 选择攻击 |
| BKAttack | BEHAVIOR(0) | 3段近战连击(atk_1→atk_2→atk_3)，每段之间可被打断 |
| BKDefend | BEHAVIOR(0) | 举盾防御1-2秒，期间受击伤害减半，防御结束→反击(sp_atk) |
| BKRoll | BEHAVIOR(0) | 向玩家侧方翻滚闪避，拉开距离后→Projectile 或 Trap |
| BKProjectile | BEHAVIOR(0) | 播放 projectile_cast，发射飞剑投射物 |
| BKTrap | BEHAVIOR(0) | 播放 trap_cast，在地面放置陷阱 |
| BKSpecial | BEHAVIOR(0) | Phase 3 专属，播放 sp_atk，大范围剑气攻击 |
| BKStun | CONTROL(2) | 眩晕，复用 StunState 逻辑 |

### 攻击选择逻辑（BladeKeeperAttackManager）

**Phase 1** — 基础剑术：
- 近距离：80% 3段连击、20% 防御
- 远距离：追击
- 冷却：1.5s

**Phase 2** — 加入远程：
- 近距离：50% 连击、20% 防御反击、30% 翻滚→飞剑
- 远距离：投射飞剑 / 布置陷阱
- 冷却：1.2s，速度 ×1.3

**Phase 3** — 狂暴：
- 近距离：40% 连击、20% 特殊攻击、20% 防御反击、20% 翻滚
- 远距离：连续飞剑 + 陷阱组合
- 冷却：1.0s，速度 ×1.5，解锁 sp_atk

### 攻击实体

**BKSwordProjectile（飞剑投射物）**：
- 直线飞行，速度 400
- 碰到玩家/墙壁消失
- 造成中等伤害
- 物理层：Enemy Projectile (5)

**BKTrap（地面陷阱）**：
- 放置后半透明（0.3 alpha），玩家踩到后触发
- 触发效果：爆炸伤害 + 短暂减速（ForceStunEffect 0.5s）
- 持续时间：8秒后自动消失
- 场上最多3个（超出时移除最早的）
- 物理层：Enemy Projectile (5)

### 数值

| 属性 | 值 |
|---|---|
| 基础血量 | 与现有 Boss 相近 |
| 移动速度 | 180 |
| 检测范围 | 800 |
| 攻击范围 | 200 |
| 最小距离 | 100 |

---

## Boss 2: DemonSlime（力量型恶魔史莱姆）

### 角色定位

慢速重击型Boss。动作迟缓但伤害高、范围广。核心压力来自劈砍冲击波和逐渐增多的小史莱姆。

### 动画映射（AnimatedSprite2D）

| 动画名 | 资源目录 | 帧数 |
|---|---|---|
| idle | 01_demon_idle | - |
| walk | 02_demon_walk | - |
| cleave | 03_demon_cleave | 15 |
| take_hit | 04_demon_take_hit | - |
| death | 05_demon_death | - |

### 状态机（5个状态）

| 状态 | 优先级 | 行为描述 |
|---|---|---|
| DSIdle | BEHAVIOR(0) | 原地待机，检测到玩家→Chase |
| DSChase | BEHAVIOR(0) | 缓慢追向玩家，进入攻击范围→攻击选择 |
| DSCleave | BEHAVIOR(0) | 播放劈砍动画，动画中段生成前方120°扇形冲击波 |
| DSSlam | BEHAVIOR(0) | Phase 2+ 解锁。跳跃砸地，落地生成360°环形冲击波。复用 cleave 动画（加速播放） |
| DSStun | CONTROL(2) | 眩晕 |

### 攻击选择逻辑（DemonSlimeAttackManager）

**Phase 1** — 笨重猎手：
- 100% Cleave
- 冷却：2.5s，移动速度 80

**Phase 2** — 解锁跳砸 + 分裂2只小史莱姆：
- 70% Cleave、30% Slam
- 冷却：2.0s，速度 ×1.3 (104)

**Phase 3** — 狂暴 + 再分裂3只小史莱姆：
- 50% Cleave、50% Slam
- 冷却：1.5s，速度 ×1.5 (120)
- Cleave 冲击波范围增大 30%

### 攻击实体

**DSShockwave（冲击波）**：
- Area2D，快速扩散后消失（0.5秒生命周期）
- 伤害 + KnockBackEffect
- Cleave 版本：前方120°扇形，半径 200
- Slam 版本：360°环形，半径 250
- Phase 3 时 Cleave 半径 → 260
- 物理层：Enemy Projectile (5)

### 小史莱姆（MiniSlime）

- 继承 EnemyBase + EnemyStateMachine (BASIC 类型)
- 复用 DemonSlime 动画资源，缩放 0.4
- AI：IdleState → ChaseState → AttackState（近身 cleave，无冲击波）
- 血量：主Boss的15%
- 伤害：主Boss的25%
- 生成时机：阶段转换时在Boss周围随机位置生成
- 生成动画：缩放从0到1（0.3秒 tween）
- Boss 死亡时所有存活的 MiniSlime 同时消失

### 数值

| 属性 | 值 |
|---|---|
| 基础血量 | 现有 Boss 的 1.5 倍 |
| 移动速度 | 80 |
| 检测范围 | 600 |
| 攻击范围 | 250 |
| 最小距离 | 80 |

---

## 关卡设计

### Level 4 — BladeKeeper 之厅

- 封闭中型竞技场（剑道场风格）
- 4个巡逻点，矩形路径
- 地面可能被 BKTrap 覆盖，玩家需注意脚下
- Boss 击败后触发胜利流程

### Level 5 — DemonSlime 之穴

- 较大开放竞技场（需要空间躲避冲击波+小史莱姆）
- 短巡逻路径（DemonSlime 移动慢）
- 随阶段推进小史莱姆逐渐增多，场地压力增大
- Boss 击败后清除所有残留 MiniSlime，触发胜利流程

### 关卡脚本

参照 Level3.gd 结构：
- 注册 Boss `boss_defeated` 信号
- Boss 击败后触发 UIManager 胜利界面 + LevelManager 关卡切换
- Level5 额外：Boss 死亡时遍历 `mini_slime` group 调用 `queue_free()`

### LevelManager 注册

在 LevelManager 的关卡列表中新增 Level4、Level5 的场景路径。
