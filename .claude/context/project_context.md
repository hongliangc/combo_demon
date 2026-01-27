# Combo Demon - 项目上下文

> **2D 动作游戏** | Godot 4.4.1 | 连招战斗系统 | 81个脚本 | 21个场景

## 🎯 项目概述

**核心玩法**: 流畅连招战斗 + 状态机AI + 多阶段Boss战 + 攻击特效系统

**技术栈**: Godot 4.4.1 (Mobile Renderer) | GDScript | Git | MCP

---

## 🆕 最近更新

### 2026-01-19: Player自治组件架构重构 ✅
**类型**: 重大架构优化 + Bug修复

**重构成果**:
- ✨ **全新架构**: 将Player从单体278行重构为5个自治组件（119行主类 + 5组件）
- 🔧 **代码简化**: 主类 `-57%`（278行 → 119行）
- 🗑️ **清理冗余**: 删除 `movement_hander.gd` 和 `animation_hander.gd`
- 🎯 **职责分离**: 每个组件单一职责，完全自治运行
- 🔌 **信号解耦**: 组件间通过信号通信，零耦合
- 🐛 **Bug修复**: 修复特殊攻击后无法移动的严重Bug

**5大自治组件**:
```
Player (hahashin.gd) - 119行
├── HealthComponent    - 生命值管理
├── MovementComponent  - 自动处理输入和移动（_process + _physics_process）
├── AnimationComponent - 自动管理AnimationTree
├── CombatComponent    - 自动处理技能输入
└── SkillManager       - 自动执行特殊攻击完整流程
```

**参考文档**:
- 📄 [player_autonomous_components_implementation_2026-01-19.md](../../dev_log/player_autonomous_components_implementation_2026-01-19.md)
- 📄 [autonomous_component_architecture_2026-01-18.md](../../dev_log/autonomous_component_architecture_2026-01-18.md)
- 📋 [optimization_work_plan.md](../../dev_log/optimization_work_plan.md)

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
├── 状态机 (StateMachine)
│   ├── BaseState          - 统一接口
│   └── CommonStates/      - 5个通用模板（80%复用）
│       ├── idle_state     - 12@export，玩家检测
│       ├── chase_state    - 10@export，动态范围
│       ├── attack_state   - 11@export，组件集成
│       ├── wander_state   - 13@export，随机/固定
│       └── stun_state     - 10@export，击飞物理模拟
│
├── 伤害系统 (Damage/AttackEffect)
│   ├── Damage (Resource)  - 伤害值 + 特效数组
│   ├── Hitbox/Hurtbox    - 碰撞检测
│   └── Effects/          - KnockUp/KnockBack/Gather/ForceStun
│
├── Boss战
│   ├── Boss基类          - 多阶段（3阶段）、8方位移动
│   ├── 状态机（9状态）   - idle/patrol/chase/circle/attack/retreat/special/enrage/stun
│   ├── 攻击管理器        - 统一攻击模式
│   └── 连招系统          - combo_attack
│
└── Player (自治组件架构 ✨ 2026-01-19)
    ├── HealthComponent    - 生命值、受伤、死亡、血条UI
    ├── MovementComponent  - 自动处理输入、移动、加速、翻转
    ├── AnimationComponent - 自动管理AnimationTree、动画播放
    ├── CombatComponent    - 自动处理技能输入、伤害类型切换
    └── SkillManager       - 自动执行特殊攻击完整流程
        └── 扇形检测 → 移动 → 动画 → 聚集敌人
```

---

## 🧩 关键模块

### 状态机 ⭐⭐⭐⭐⭐

**特点**:
- **零代码配置** - 编辑器直接设置@export参数
- **高复用率** - Enemy/Boss共用通用状态模板
- **继承扩展** - 继承 + super() 实现自定义

**示例**:
```gdscript
# 方式1: 零代码（在场景中添加状态节点，设置参数）

# 方式2: 继承扩展
extends "res://Util/StateMachine/CommonStates/chase_state.gd"
func physics_process_state(delta):
    super.physics_process_state(delta)
    # 自定义逻辑
```

### 伤害系统 ⭐⭐⭐⭐

**Damage Resource**:
- `min/max_amount` - 伤害范围
- `effects: Array[AttackEffect]` - 可组合多个特效
- `静态RNG` - 性能优化，避免重复创建

**配置方式**:
1. **简单** - Hitbox设置 min_damage/max_damage
2. **高级** - 拖入 Damage.tres 资源（.tres文件）

**特效系统**:
- `KnockUpEffect` - 击飞（8方向抛物线，重力模拟）
- `KnockBackEffect` - 击退
- `GatherEffect` - 聚集敌人（特殊攻击用）
- `ForceStunEffect` - 强制眩晕（禁用移动）

### Boss战 ⭐⭐⭐⭐⭐

**多阶段**:
- 第1阶段（100%-66%血量）- 基础模式
- 第2阶段（66%-33%血量） - 1.3x速度 + 激进攻击
- 第3阶段（33%-0%血量）  - 1.5x速度 + 狂暴模式

**转阶段特效**: 短暂无敌 + 击退周围单位

**8方位系统**: 预计算DIRECTIONS_8常量，平滑旋转

### Player技能 (自治组件架构)

**伤害类型**: Physical、KnockUp、SpecialAttack

**特殊攻击流程** (SkillManager自动执行):
1. **检测** - 扇形范围检测敌人（detection_radius, detection_angle）
2. **禁用移动** - `movement_component.can_move = false`
3. **移动** - Tween移动到第一个敌人位置
4. **播放动画** - 播放特殊攻击动画并等待完成
5. **聚集敌人** - GatherEffect聚集所有检测到的敌人
6. **触发伤害** - Hitbox触发伤害和眩晕效果
7. **恢复移动** - `movement_component.can_move = true` ✅

**关键设计**: 完整的生命周期管理，确保状态正确恢复

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
Scenes/
├── charaters/       # Player（Hahashin）
├── enemies/         # Enemy (dinosaur/) + Boss (boss/)
└── UI/              # 所有UI组件

Util/
├── AutoLoad/        # 7个全局单例
├── StateMachine/    # 状态机框架 + CommonStates/
├── Classes/         # Resource类（Damage, CharacterData, AttackEffect）
├── Components/      # 可复用组件（Health, Hitbox, Hurtbox）
└── Data/            # .tres资源文件

Weapons/
├── slash/           # 近战武器
└── bullet/          # 远程武器
```

---

## 📚 设计原则

### 核心原则（godot-coding-standards skill）

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

### 性能优化

- `@onready` 延迟初始化
- 静态RNG避免重复创建
- 对象池（bullet_pool）
- 避免 `_process()` 创建对象

---

## 🔧 已知问题与优化建议

### 高优先级

1. **Hitbox重复** - `Scenes/charaters/hitbox.gd` 与 `Util/Components/hitbox.gd` 重复
2. **Player职责过重** - hahashin.gd 278行，应拆分为组件
3. **AttackEffect的await** - 可能导致内存泄漏

### 中优先级

4. **StunState过重** - 161行，包含眩晕+物理模拟+特效判断
5. **状态名称硬编码** - 使用字符串引用，应使用常量
6. **Boss调试print** - 应统一使用 DebugConfig

### 目录优化（可选）

- `charaters` → `Characters` (拼写修正)
- `Stategy` → `Strategy` (拼写修正)
- 脚本与场景分离（Scripts/ + Scenes/）

---

## 📖 相关文档

- **架构分析**: [dev_log/architecture_review_2026-01-18.md](../../dev_log/architecture_review_2026-01-18.md)
- **编码规范**: [.claude/skills/godot-coding-standards/](../skills/godot-coding-standards/)
- **状态机指南**: [Util/StateMachine/STATE_MACHINE_GUIDE.md](../../Util/StateMachine/STATE_MACHINE_GUIDE.md)
- **调试系统**: [Util/AutoLoad/DEBUG_README.md](../../Util/AutoLoad/DEBUG_README.md)

---

**最后更新**: 2026-01-18
**Token消耗**: ~2500 tokens（优化后）
**项目状态**: ✅ 可运行，架构清晰，性能良好
