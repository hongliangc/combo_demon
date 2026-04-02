# Boss 系统重构 + BladeKeeper & DemonSlime 设计

> 日期: 2026-03-28
> 状态: 已批准
> 替代: 2026-03-27-two-new-bosses-design.md（旧方案废弃）

## 概述

基于现有架构模板（BossBase、AnimationTree BlendTree、BossPhaseConfig）重新实现 BladeKeeper 和 DemonSlime 两个新 Boss。同时重构 Boss 基础设施为通用基类，将现有 Cyclops Boss 迁移到统一目录。

### 关键决策

| 决策 | 选择 |
|------|------|
| 动画系统 | AnimationTree + BlendTree（与 Cyclops 统一） |
| 目录结构 | 统一 `Scenes/Characters/Bosses/`，含 Shared/ |
| DemonSlime slam 动画 | 复用 cleave 动画，VFX 区分 |
| DemonSlime 小怪分裂 | 不实现 |
| AttackManager | 抽取通用基类 |
| StateMachine | 抽取通用基类 |

---

## 1. 目录结构

```
Scenes/Characters/Bosses/
├── Shared/
│   ├── BossBaseState.gd          # 所有 Boss 状态基类
│   ├── BossStateMachine.gd       # 通用 Boss 状态机基类
│   ├── BossAttackManager.gd      # 通用攻击管理器基类
│   ├── BossPhaseConfig.gd        # 阶段配置 Resource
│   └── BossComboAttack.gd        # 组合技 Resource
├── Cyclops/                       # 原 boss/ 迁移
│   ├── Cyclops.gd
│   ├── Cyclops.tscn
│   ├── CyclopsAttackManager.gd
│   ├── CyclopsStateMachine.gd
│   ├── States/                    # 7 个状态
│   └── Attacks/                   # Projectile/Laser/AOE
├── BladeKeeper/
│   ├── BladeKeeper.gd
│   ├── BladeKeeper.tscn
│   ├── BKAttackManager.gd
│   ├── BKStateMachine.gd
│   ├── States/                    # 8 个状态
│   └── Attacks/                   # SwordProjectile/Trap
└── DemonSlime/
    ├── DemonSlime.gd
    ├── DemonSlime.tscn
    ├── DSAttackManager.gd
    ├── DSStateMachine.gd
    ├── States/                    # 5 个状态
    └── Attacks/                   # Shockwave
```

---

## 2. 基类重构

### BossAttackManager（通用基类）

```
通用逻辑（基类实现）：
  pick_attack_state(distance: float) → String     加权攻击池选择
  get_cooldown() → float                           阶段冷却
  get_player() → Node2D                            懒缓存
  _weighted_pick(pool: Array) → Dictionary         加权随机

子类钩子：
  _execute_attack(entry: Dictionary, target_pos: Vector2) → void
```

### BossStateMachine（通用基类）

```
通用逻辑（基类实现）：
  is_transitioning_phase: bool
  _setup_signals()           连接 phase_changed
  _on_owner_damaged()        阶段转换期间阻止状态切换
  _on_phase_changed(phase)   保护标志 + 调用钩子 + 0.3s 延迟清除

子类钩子：
  _get_phase_route(phase: int) → String
```

### BossPhaseConfig 扩展

向后兼容加权选择：有 `weight` 字段走加权随机，无 `weight` 走 `pick_random()`。

```gdscript
# Cyclops 兼容格式
attacks: [{ "mode": "fan_spread", "count": 3 }]

# 新 Boss 加权格式
attacks: [{ "mode": "attack", "weight": 50 }, { "mode": "combo_剑刃风暴", "weight": 30 }]
```

---

## 3. BladeKeeper Boss

### 定位
快速技巧型剑士。3 段连击、防御反击、闪避翻滚、剑气投射、地面陷阱。

### AnimationTree BlendTree

```
AnimationNodeBlendTree (root)
├── locomotion (BlendSpace2D: idle↔run)
│   → loco_timescale → control_blend[0]
├── control_sm (StateMachine)
│   ├── atk_1 → atk_2 → atk_3
│   ├── sp_atk
│   ├── defend
│   ├── roll
│   ├── projectile_cast
│   ├── trap_cast
│   ├── take_hit
│   ├── stun (复用 take_hit 循环)
│   └── death
│   → ctrl_timescale → control_blend[1]
└── control_blend (Blend2) → output
```

### 状态机（8 状态）

| 状态 | 优先级 | 动画 | 行为 |
|------|--------|------|------|
| BKIdle | BEHAVIOR | locomotion(0,0) | 检测距离，超时→chase |
| BKChase | BEHAVIOR | locomotion(dir, speed) | 向目标移动，进入范围→attack |
| BKAttack | BEHAVIOR | control_sm: atk_1→2→3 或 sp_atk | 连击/特殊，animation_finished 推进 |
| BKDefend | BEHAVIOR | control_sm: defend | 格挡 1.5s，受击反击 x1.5 |
| BKRoll | BEHAVIOR | control_sm: roll | 侧向闪避，can_be_interrupted=false |
| BKProjectile | BEHAVIOR | control_sm: projectile_cast | 释放剑气投射物 |
| BKTrap | BEHAVIOR | control_sm: trap_cast | 放置陷阱（最多 3 个） |
| BKStun | CONTROL | control_sm: stun | 眩晕 1.5s |

### 组合技（3 套）

| 名称 | 解锁 | 动作序列 | 意图 |
|------|------|---------|------|
| 剑刃风暴 | Phase 1+ | atk_1 → atk_2 → atk_3 → projectile_cast | 连击收尾接剑气 |
| 影步突袭 | Phase 2+ | roll → atk_1 → atk_2 → defend | 突进→二连→防御姿态 |
| 绝剑连环 | Phase 3 | roll → trap_cast → atk_1 → atk_2 → atk_3 → sp_atk | 全套最高威胁 |

### BossPhaseConfig

| Phase | 攻击池 | 冷却 | 速度倍率 |
|-------|-------|------|---------|
| Phase 1 | attack(50), defend(20), combo_剑刃风暴(30) | 1.5s | 1.0x |
| Phase 2 | attack(30), defend(15), combo_剑刃风暴(20), combo_影步突袭(20), roll→projectile(15) | 1.2s | 1.3x |
| Phase 3 | attack(15), defend(10), combo_剑刃风暴(15), combo_影步突袭(20), combo_绝剑连环(20), roll→trap(20) | 1.0s | 1.5x |

### 攻击实体

- **BKSwordProjectile**: Area2D, speed=400, lifetime=4s, 命中消失
- **BKTrap**: Area2D, alpha=0.3, 触发→爆炸+0.5s ForceStun, lifetime=8s, 最多 3 个

### 数值

move_speed=180, detection=800, attack_range=200, min_distance=100

---

## 4. DemonSlime Boss

### 定位
慢速重击型。高伤害大范围冲击波施压，阶段越高攻击种类越多、范围越大。

### AnimationTree BlendTree

```
AnimationNodeBlendTree (root)
├── locomotion (BlendSpace2D: idle↔walk)
│   → loco_timescale → control_blend[0]
├── control_sm (StateMachine)
│   ├── cleave
│   ├── take_hit
│   ├── stun (复用 take_hit 循环)
│   └── death
│   → ctrl_timescale → control_blend[1]
└── control_blend (Blend2) → output
```

### 状态机（5 状态）

| 状态 | 优先级 | 动画 | 行为 |
|------|--------|------|------|
| DSIdle | BEHAVIOR | locomotion(0,0) | 检测距离，超时→chase |
| DSChase | BEHAVIOR | locomotion(dir, speed) | 向目标移动，进入范围→attack |
| DSCleave | BEHAVIOR | control_sm: cleave | 播放 cleave，生成 120° 扇形冲击波 |
| DSSlam | BEHAVIOR | control_sm: cleave | 共用 cleave 动画，生成 360° 圆形冲击波 |
| DSStun | CONTROL | control_sm: stun | 眩晕 1.5s，Phase 3 免疫 |

### 组合技（3 套）

| 名称 | 解锁 | 动作序列 | 意图 |
|------|------|---------|------|
| 大地震颤 | Phase 1+ | cleave(fan) → 0.3s → cleave(fan, 反方向) | 左右扇形覆盖 |
| 毁灭重压 | Phase 2+ | slam(ring) → 0.5s → cleave(fan, 加大范围) | 击退→追击 |
| 灭世连击 | Phase 3 | cleave(fan) → 0.2s → cleave(fan) → 0.2s → slam(ring, 加大范围) | 快速压制→终结 |

### BossPhaseConfig

| Phase | 攻击池 | 冷却 | 速度倍率 |
|-------|-------|------|---------|
| Phase 1 | cleave(60), combo_大地震颤(40) | 2.5s | 1.0x (80) |
| Phase 2 | cleave(30), slam(20), combo_大地震颤(25), combo_毁灭重压(25) | 2.0s | 1.3x (104) |
| Phase 3 | cleave(15), slam(15), combo_大地震颤(20), combo_毁灭重压(25), combo_灭世连击(25) | 1.5s | 1.5x (120) |

### 攻击实体

- **DSShockwave** (Area2D, 通用冲击波):
  - `fan` 模式: 120° 扇形, radius=200 (Phase 3: 260)
  - `ring` 模式: 360° 圆形, radius=250
  - 0.5s 存活, Damage + KnockBackEffect

### 数值

base_move_speed=80, detection=600, attack_range=250, min_distance=80, health=1.5x 默认

---

## 5. 迁移策略

### 删除

```
Scenes/Characters/Enemies/BladeKeeper/   ← 整个删除
Scenes/Characters/Enemies/DemonSlime/    ← 整个删除
```

### Cyclops 迁移

| 原路径 | 新路径 | 改动 |
|-------|-------|------|
| boss/Boss.gd | Cyclops/Cyclops.gd | class_name → Cyclops |
| boss/Boss.tscn | Cyclops/Cyclops.tscn | 更新脚本引用 |
| boss/Scripts/BossAttackManager.gd | Cyclops/CyclopsAttackManager.gd | 提取通用→基类 |
| boss/Scripts/States/BossStateMachine.gd | Cyclops/CyclopsStateMachine.gd | 提取通用→基类 |
| boss/Scripts/States/BossBaseState.gd | Shared/BossBaseState.gd | 通用 |
| boss/Scripts/States/Boss*.gd (7状态) | Cyclops/States/ | 加 Cyclops 前缀 |
| boss/Scripts/BossPhaseConfig.gd | Shared/BossPhaseConfig.gd | 扩展加权 |
| boss/Scripts/BossComboAttack.gd | Shared/BossComboAttack.gd | 不变 |
| boss/Attacks/ | Cyclops/Attacks/ | 不变 |

### 外部引用更新

- Level3.gd / Level3.tscn — Boss 场景路径
- Core/Characters/BossBase.gd — 保持原位（Framework 层）

### 实现顺序

1. 基类重构（Shared/ + BossPhaseConfig 扩展）
2. Cyclops 迁移（验证现有 Boss 正常）
3. BladeKeeper 新建
4. DemonSlime 新建
5. 关卡关联
