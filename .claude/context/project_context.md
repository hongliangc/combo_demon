# Combo Demon - 项目上下文

> **快速参考**: 项目架构、系统设计和技术选型

---

## 🎮 项目概述

**Combo Demon** 是一个 2D 动作游戏，核心玩法是连招战斗系统。

### 核心特性
- ⚔️ 流畅的连招战斗系统
- 🤖 基于状态机的敌人AI
- 🎯 多种技能和伤害类型
- 🎨 像素艺术风格
- 🎵 动态音效系统

### 技术栈
- **引擎**: Godot 4.4.1-stable
- **渲染**: Mobile Renderer
- **脚本**: GDScript
- **版本控制**: Git
- **开发工具**: VSCode + Claude Code + MCP

---

## 🏗️ 系统架构

### 核心系统设计图

```
┌─────────────────────────────────────────────────┐
│              Game Manager (AutoLoad)             │
│  ┌──────────────┐  ┌──────────────────────────┐ │
│  │SoundManager  │  │DamageNumbers             │ │
│  └──────────────┘  └──────────────────────────┘ │
└─────────────────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
┌──────────────┐ ┌─────────────┐ ┌──────────────┐
│ Player       │ │ Enemy       │ │ Weapons      │
│ System       │ │ System      │ │ System       │
│              │ │             │ │              │
│ - Movement   │ │ - AI State  │ │ - Melee      │
│ - Animation  │ │ - Machine   │ │ - Ranged     │
│ - Skills     │ │ - Patrol    │ │ - Projectile │
│ - Combat     │ │ - Combat    │ │              │
└──────┬───────┘ └──────┬──────┘ └──────┬───────┘
       │                │                │
       └────────────────┼────────────────┘
                        ▼
              ┌──────────────────┐
              │  Component Layer │
              ├──────────────────┤
              │ - Health         │
              │ - Hitbox         │
              │ - Hurtbox        │
              │ - Attack         │
              └──────────────────┘
```

---

## 📦 模块详解

### 1. 角色系统 (`Scenes/charaters/`)

**主要文件**:
- `hahashin.gd` - 主角控制器
- `movement_hander.gd` - 移动处理
- `animation_hander.gd` - 动画管理
- `hitbox.gd` - 攻击判定

**职责**:
- 处理玩家输入
- 角色移动和物理
- 技能释放
- 动画状态管理

**关键变量**:
```gdscript
var max_speed: float = 100
var damage_types: Array[Damage]
var current_damage: Damage
var alive: bool = true
```

---

### 2. 敌人AI系统 (`Scenes/enemies/dinosaur/`)

**状态机架构**:
```
enemy_state_machine.gd
├── enemy_idle.gd         # 闲置状态
├── enemy_wander.gd       # 巡逻状态
├── enemy_chase.gd        # 追击状态
├── enemy_attack.gd       # 攻击状态
└── enemy_stun.gd         # 眩晕状态
```

**状态转换逻辑**:
```
Idle ──发现玩家──> Chase ──到达攻击范围──> Attack
  │                  │                      │
  └──超时──> Wander  │                      │
              │      └──失去目标──> Idle <──┘
              │                             │
              └──发现玩家───────────────────┘
```

**关键组件**:
- `enemy.gd` - 敌人主控制器
- `enemy_health.gd` - 生命值管理
- `enemy_health_bar.gd` - UI显示

---

### 3. 战斗系统 (`Util/Components/`)

**伤害计算流程**:
```
攻击方                              受击方
───────                              ───────
Hitbox (attack_componet.gd)
  │
  ├─ 创建 Attack 对象
  │   ├─ damage: float
  │   ├─ knockback: float
  │   └─ type: String
  │
  └─ 碰撞检测 ──> Hurtbox (hurtbox.gd)
                     │
                     └─> Health Component
                           │
                           ├─ 计算最终伤害
                           ├─ 应用击退效果
                           └─ 触发受伤事件
```

**组件说明**:

| 组件 | 文件 | 职责 |
|------|------|------|
| Health | `health.gd` | 生命值管理、死亡判定 |
| Hitbox | `hitbox.gd` | 攻击判定区域 |
| Hurtbox | `hurtbox.gd` | 受击判定区域 |
| Attack Component | `attack_componet.gd` | 攻击逻辑处理 |

---

### 4. 武器系统 (`Weapons/`)

**武器类型**:

```
Weapons/
├── slash/              # 近战武器
│   └── claw/          # 爪击
│       ├── slash_attack.gd
│       └── slash_attack.tscn
└── bullet/            # 远程武器
    ├── fire/          # 火焰弹
    │   ├── fire_bullet.gd
    │   └── fire_bullet.tscn
    └── bubble/        # 泡泡弹
        ├── bubble_bullet.gd
        ├── bubble_bullet_splash.gd
        └── *.tscn
```

**武器基类**:
```gdscript
# Weapons/bullet/base_bullet.gd
extends Node2D
class_name BaseBullet

var damage: float
var speed: float
var direction: Vector2
var lifetime: float
```

---

### 5. 数据系统 (`Util/Classes/`)

**Resource 数据类**:

```gdscript
# Damage.gd - 伤害数据
class_name Damage
extends Resource

@export var amount: float = 10.0
@export_enum("Physical", "KnockUp", "KnockBack") var type: String
```

```gdscript
# Attack.gd - 攻击数据传递
class_name Attack

var damage: float = 10.0
var knockback: float = 0.0
```

**现有伤害类型资源**:
- `SkillBook/Physical.tres` - 普通物理伤害
- `SkillBook/KnockUp.tres` - 浮空伤害
- `SkillBook/KnockBack.tres` - 击退伤害

---

## 🎮 输入系统

### 操作映射 (`project.godot`)

| 操作 | 按键 | 功能 |
|------|------|------|
| `move_left/right/up/down` | 方向键 | 移动 |
| `primary_fire` | 鼠标左键 | 主要攻击 |
| `dash` | 空格 | 冲刺 |
| `atk_sp` | V | 特殊攻击 |
| `atk_1` | X | 技能1 |
| `atk_2` | W | 技能2 |
| `atk_3` | E | 技能3 |
| `roll` | R | 翻滚 |

---

## 🎨 物理层设置

| Layer | 名称 | 用途 |
|-------|------|------|
| 1 | World | 世界环境 |
| 2 | Player | 玩家角色 |
| 3 | Player Projectile | 玩家弹药 |
| 4 | Enemy | 敌人 |
| 5 | Enemy Projectile | 敌人弹药 |
| 7 | Object | 可交互对象 |
| 8 | Walls | 墙体/障碍物 |

**碰撞矩阵**:
```
Player vs:
  ✅ World, Walls, Enemy, Enemy Projectile
  ❌ Player Projectile

Enemy vs:
  ✅ World, Walls, Player, Player Projectile
  ❌ Enemy Projectile
```

---

## 🔧 AutoLoad 单例

### 已配置的单例

```gdscript
# SoundManager (Util/AutoLoad/sound_manager.gd)
- 管理全局音效播放
- 音量控制
- 音效池

# DamageNumbers (Util/AutoLoad/damage_numbers.gd)
- 显示伤害数字
- 浮动文字效果
```

### 计划中的单例
- `SkillManager` - 技能系统管理
- `EventBus` - 全局事件总线
- `GameState` - 游戏状态管理

---

## 📁 文件组织规范

### 场景文件 (.tscn)
- 路径: `Scenes/[类别]/[名称].tscn`
- 示例: `Scenes/charaters/hahashin.tscn`

### 脚本文件 (.gd)
- 路径: 与对应的 .tscn 同目录
- 示例: `Scenes/charaters/hahashin.gd`

### 资源文件 (.tres)
- 路径: `Util/Data/[类别]/[名称].tres`
- 示例: `Util/Data/SkillBook/Physical.tres`

### 组件脚本
- 路径: `Util/Components/[名称].gd`
- 示例: `Util/Components/health.gd`

---

## 🎯 性能优化策略

### 对象池
```gdscript
# Util/AutoLoad/bullet_pool.gd
- 预创建 50 个子弹对象
- 循环复用，避免频繁实例化
- visible = false 代替 queue_free()
```

### 节点优化
```gdscript
# 使用 @onready 延迟初始化
@onready var sprite: Sprite2D = $Sprite2D

# 避免在 _process 中创建对象
var _temp_vector := Vector2.ZERO  # 复用变量
```

---

## 🔌 MCP 集成

### 可用的 Godot MCP 功能

| 功能 | MCP 函数 |
|------|----------|
| 启动编辑器 | `mcp__godot__launch_editor` |
| 运行游戏 | `mcp__godot__run_project` |
| 获取调试输出 | `mcp__godot__get_debug_output` |
| 创建场景 | `mcp__godot__create_scene` |
| 添加节点 | `mcp__godot__add_node` |
| 加载精灵 | `mcp__godot__load_sprite` |

### 配置文件
- `.mcp.json` - MCP 服务器配置
- `.vscode/mcp.json` - VSCode MCP 设置

---

## 📚 常用代码模式

### 创建新组件
```gdscript
extends Node
class_name [ComponentName]

signal [signal_name]([params])

@export var property: Type = default_value

func _ready() -> void:
    pass
```

### 状态机状态
```gdscript
extends Node
class_name [StateName]

var state_machine: StateMachine

func enter() -> void:
    pass

func update(delta: float) -> void:
    pass

func exit() -> void:
    pass
```

---

## 🔗 外部资源

- [Godot 文档](https://docs.godotengine.org/en/stable/)
- [GDScript 风格指南](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- [Godot 状态机教程](https://docs.godotengine.org/en/stable/tutorials/best_practices/state_design_pattern.html)

---

**最后更新**: 2025-12-22
