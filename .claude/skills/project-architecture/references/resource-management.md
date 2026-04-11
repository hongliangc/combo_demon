# 配置与资源管理分析

> 分析当前项目的配置来源、Resource 使用模式、硬编码问题，并给出优化建议。

## 当前配置来源分布

| 配置方式 | 使用位置 | 比例 |
|---------|---------|------|
| `@export` 变量 | EnemyBase AI 参数、BossBase 检测参数、攻击场景参数 | ~60% |
| `.tres` Resource 文件 | CharacterData (3个)、SkillBook 伤害数据 (4个) | ~15% |
| GDScript 硬编码 | Boss 阶段攻击池、相位转换特效参数、状态阈值 | ~20% |
| JSON 配置 | DebugConfig 日志配置 | ~5% |

## Resource 文件使用现状

### 已有 Resource 类型

| Resource 类 | 文件路径 | 用途 |
|------------|---------|------|
| `CharacterData` | `Core/Data/Characters/*.tres` | 角色元数据 (name, scene_path, stats) |
| `Damage` | `Core/Data/SkillBook/*.tres` | 伤害数据 (amount + effects 数组) |
| `AttackEffect` (5 子类) | `Core/Resources/` | 攻击效果 (Stun/KnockBack/KnockUp/Gather/ForceStun) |
| `EnemyData` | `Core/Resources/EnemyData.gd` | 敌人 AI 参数（数据驱动模式） |
| `BossPhaseConfig` | `Boss/Scripts/BossPhaseConfig.gd` | Boss 阶段配置 |

### Resource 使用良好的部分

1. **Damage 组合模式** — `Damage` Resource 含 `effects: Array[AttackEffect]`，支持效果自由组合，设计简洁且可扩展
2. **EnemyData 数据驱动** — EnemyBase 支持 `@export var enemy_data: EnemyData`，可从 .tres 文件驱动所有 AI 参数
3. **BossPhaseConfig** — 每个阶段独立 Resource，含攻击池、冷却、行为模式，设计合理

---

## 问题分析

### 问题 1: Boss 攻击池硬编码在代码中

**位置**: `Scenes/Characters/Enemies/boss/Scripts/States/BossAttack.gd:31-95`

**现状**: 三个阶段的攻击池直接写在 GDScript 中作为 `var` 字典数组：

```gdscript
# Phase 1 — 硬编码在 BossAttack.gd
var phase1_attacks = [
    { "mode": "fan_spread", "count": 3, "spread": deg_to_rad(30) },
    { "mode": "rapid_fire", "count": 3 },
    { "mode": "combo", "factory": "create_triple_shot" },
]
```

**问题**:
- 虽然有 `BossPhaseConfig` Resource 类，但实际 Boss 的攻击池并未使用它，而是硬编码在状态脚本中
- 修改攻击配置需要改代码，不能通过编辑器 Inspector 调整
- 添加新 Boss 时需要复制大量硬编码配置

**建议**: 将 `BossAttack.gd` 中的攻击池迁移到 `BossPhaseConfig.tres` 文件，通过 Inspector 配置。

---

### 问题 2: 相位转换特效参数内嵌

**位置**: `Core/Characters/BossBase.gd:131-132`

```gdscript
var knockback_radius := 200.0  # 击退范围
var knockback_force := 500.0   # 击退力度
```

**问题**: 相位转换的击退效果参数是方法内局部变量，无法从外部配置。不同 Boss 如果需要不同的转换特效强度，必须重写方法。

**建议**: 提取为 `@export` 变量或加入 `BossPhaseConfig`。

---

### 问题 3: EnemyData 使用率低

**现状**: `EnemyData` Resource 设计完善，但检查现有敌人：

| 敌人 | 使用 EnemyData .tres | 使用方式 |
|------|---------------------|---------|
| Slime | 否 | 直接用 @export 默认值 |
| BlueBat | 否 | 直接用 @export 默认值 |
| Bear | 否 | 直接用 @export 默认值 |
| Dragon | 否 | 直接用 @export 默认值 |

**问题**: 没有敌人实际使用 `enemy_data: EnemyData` 属性。所有敌人直接在 Inspector 中配置 `@export` 值，导致：
- 相同类型敌人在不同关卡中无法共享配置
- 批量调整某类敌人的参数需要逐个场景修改

**建议**: 为每种敌人创建 .tres 配置文件，统一通过 `enemy_data` 驱动。

---

### 问题 4: 攻击场景参数混合策略

Boss 攻击场景（BossProjectile、BossLaser、BossAoe）使用了较好的 `@export` 模式：

```gdscript
# BossProjectile.gd — 良好的 @export 模式
@export var speed := 300.0
@export var lifetime := 5.0
@export var frame_speed := 10.0

# BossLaser.gd — 同样良好
@export var charge_time := 2.5
@export var fire_duration := 1.5
@export var rotation_speed := 1.0
@export var laser_length := 500.0

# BossAoe.gd — 同样良好
@export var expand_time := 0.8
@export var hold_time := 0.5
@export var max_radius := 200.0
```

**但存在内嵌魔法数字**:
- `BossAoe.gd:51` — `max_radius / 50.0` 假设原始大小为 100x100
- `BossLaser.gd:66` — `sin(timer * 10.0) * 0.5 + 0.3` 闪烁效果参数

**建议**: 将视觉效果参数也提取为 `@export` 或 `const`。

---

### 问题 5: 阶段速度倍率在 3 个 Boss 文件中重复

**位置**: `Scenes/Characters/Enemies/boss/Scripts/boss.gd:22-24`, `BladeKeeper/BladeKeeperBoss.gd:12-15`, `DemonSlime/DemonSlimeBoss.gd:11-15`

**现状**: 三个 Boss 文件各自硬编码了相同的速度倍率（1.0/1.3/1.5），用不同格式：

```gdscript
# boss.gd — const 常量
const PHASE_1_SPEED_MULT = 1.0
const PHASE_2_SPEED_MULT = 1.3
const PHASE_3_SPEED_MULT = 1.5

# BladeKeeperBoss.gd / DemonSlimeBoss.gd — Dictionary
const PHASE_SPEED := { Phase.PHASE_1: 1.0, Phase.PHASE_2: 1.3, Phase.PHASE_3: 1.5 }
```

**问题**: 值重复且格式不一致。`BossPhaseConfig` 已有 `speed_multiplier` 字段但仅用于 chase 模式。

**建议**: 将速度倍率统一到 `BossPhaseConfig.speed_multiplier`，各 Boss 从阶段配置 Resource 读取。

---

### 问题 6: DebugConfig JSON 配置路径硬编码

**位置**: `Core/Autoloads/DebugConfig.gd:59`

```gdscript
var config_path := "res://Core/Autoloads/debug_config.json"
```

**问题**: 配置文件路径硬编码，且使用 `res://` 前缀意味着导出后不可修改。

**建议**: 改为 `user://debug_config.json`，支持运行时修改。

---

## 推荐配置架构

### 三级配置策略

```
┌──────────────────────────────────────────────┐
│ Level 1: Resource (.tres)                     │
│ 适用: 可在编辑器中可视化调整的游戏数据         │
│ 例: EnemyData, BossPhaseConfig, Damage, etc.  │
├──────────────────────────────────────────────┤
│ Level 2: @export 变量                         │
│ 适用: 场景特定的覆写值（覆盖 Resource 默认值） │
│ 例: 特定场景中某个 Slime 的独特参数            │
├──────────────────────────────────────────────┤
│ Level 3: const / 内联值                        │
│ 适用: 真正不变的物理常量或系统参数             │
│ 例: 重力方向、最小浮点阈值                    │
└──────────────────────────────────────────────┘
```

### 推荐迁移步骤

| 优先级 | 任务 | 收益 |
|--------|------|------|
| P0 | Boss 攻击池从 BossAttack.gd 迁移到 BossPhaseConfig .tres | 解耦配置与代码，新 Boss 只需新建 .tres |
| P1 | 为每种敌人创建 EnemyData .tres | 统一配置管理，支持批量调参 |
| P1 | BossBase 相位转换参数提取为 @export | 不同 Boss 可差异化相位表现 |
| P2 | 攻击场景视觉参数提取 | 策划可通过编辑器微调视觉效果 |
| P2 | DebugConfig 路径改为 user:// | 支持运行时修改日志配置 |

### 示例: EnemyData .tres 配置

```tres
# Core/Data/Enemies/SlimeData.tres
[gd_resource type="Resource" script_class="EnemyData" load_steps=2 format=3]

[ext_resource type="Script" path="res://Core/Resources/EnemyData.gd" id="1"]

[resource]
script = ExtResource("1")
max_health = 50
health = 50
min_wander_time = 2.0
max_wander_time = 8.0
wander_speed = 30.0
detection_radius = 120.0
chase_radius = 250.0
follow_radius = 30.0
chase_speed = 60
has_gravity = false
```

### 示例: BossPhaseConfig .tres 使用

```tres
# Scenes/Characters/Enemies/boss/Data/Phase1Config.tres
[gd_resource type="Resource" script_class="BossPhaseConfig" load_steps=2 format=3]

[ext_resource type="Script" path="res://Scenes/Characters/Enemies/boss/Scripts/BossPhaseConfig.gd" id="1"]

[resource]
script = ExtResource("1")
attacks = [
    { "mode": "fan_spread", "count": 3, "spread": 0.523 },
    { "mode": "rapid_fire", "count": 3 },
    { "mode": "combo", "factory": "create_triple_shot" }
]
cooldown = 2.0
attack_duration = 1.0
behavior = "timer"
speed_multiplier = 1.0
immune = false
```
