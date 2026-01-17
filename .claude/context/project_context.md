# Combo Demon - 项目上下文

> **2D 动作游戏** | Godot 4.4.1 | 连招战斗系统

## 🎯 项目概述

**核心玩法**: 流畅的连招战斗 + 状态机AI + 多种攻击特效

**技术栈**: Godot 4.4.1 (Mobile Renderer) | GDScript | Git | MCP

---

## 📦 核心架构

### 系统层级图

```
AutoLoad 单例层
├── UIManager          # UI层级管理（6层：Background/Game/Menu/Popup/Tooltip/Loading）
├── GameManager        # 游戏流程（角色选择、场景切换）
├── SoundManager       # 音效管理
├── DamageNumbers      # 伤害数字显示
└── DebugConfig        # 调试日志系统（4级别、分类标签、路径配置）

游戏系统
├── 角色系统           # Scenes/charaters/hahashin.gd
│   ├── 移动处理       # movement_hander.gd
│   ├── 动画管理       # animation_hander.gd
│   └── 攻击判定       # hitbox.gd
├── 敌人系统           # Scenes/enemies/
│   ├── 普通敌人       # dinosaur/ (状态机: idle/wander/chase/attack/stun)
│   └── Boss          # boss/ (9状态: idle/patrol/chase/circle/attack/retreat/special/enrage/stun)
├── 战斗系统           # Util/Components/
│   ├── Health        # 生命值管理
│   ├── Hitbox        # 攻击判定（支持@export配置和Damage资源）
│   ├── Hurtbox       # 受击判定
│   └── AttackEffect  # 特效基类（KnockUp/KnockBack）
└── 武器系统           # Weapons/
    ├── 近战           # slash/claw/
    └── 远程           # bullet/fire, bubble
```

---

## 🧩 关键模块说明

### 1️⃣ 状态机框架 (Util/StateMachine/)

**通用状态模板**（80%复用率）:
- `idle_state.gd` - 待机（12个@export参数，支持玩家检测）
- `wander_state.gd` - 巡游（13参数，随机/固定方向）
- `chase_state.gd` - 追击（10参数，动态攻击范围）
- `attack_state.gd` - 攻击（11参数，AttackComponent集成）
- `stun_state.gd` - 眩晕（10参数，自定义恢复逻辑）

**使用方式**:
```gdscript
# 方式1: 纯配置（0代码）
# 在场景中添加状态节点，设置@export参数

# 方式2: 继承+重载
extends "res://Util/StateMachine/CommonStates/chase_state.gd"
func physics_process_state(delta: float) -> void:
    super.physics_process_state(delta)
    # 自定义逻辑
```

### 2️⃣ 伤害系统 (Util/Classes/)

**核心类**:
```gdscript
# Damage.gd - 伤害数据（Resource）
@export var min_amount: float
@export var max_amount: float
@export_enum("Physical", "KnockUp", "KnockBack") var type: String
@export var effects: Array[AttackEffect]  # 特效数组

func randomize_damage() -> void  # 静态RNG，所有实例共享
func apply_effects(target: Node) -> void
```

**Hitbox配置方式**:
1. **简单配置**: Inspector设置 `min_damage`/`max_damage`
2. **高级配置**: 拖入 `.tres` Damage资源（支持复杂特效）

**攻击特效**:
- `KnockUpEffect` - 击飞（抛物线运动，适配8方向俯视地图）
- `KnockBackEffect` - 击退

### 3️⃣ UI系统 (Util/UI/)

**UIManager API**:
```gdscript
# Toast提示（4种类型：info/success/warning/error）
UIManager.show_toast("操作成功！", 2.0, "success")

# 确认对话框
UIManager.show_confirm_dialog("标题", "消息", on_confirm, on_cancel)

# 打开面板（自动管理层级和堆栈）
UIManager.open_panel(panel_scene, UIManager.UILayer.POPUP)

# 场景转场（淡入淡出）
UIManager.transition_to_scene("res://Scenes/main.tscn")
```

**组件规范**:
- 继承 `Control`（非CanvasLayer）
- 实现 `play_open_animation()` / `play_close_animation()`
- 使用 `class_name` 便于引用

### 4️⃣ 调试日志系统 (Util/AutoLoad/debug_config.gd)

**4级别日志**:
```gdscript
DebugConfig.debug("调试信息", "", "state_machine")  # 青色
DebugConfig.info("一般信息", "", "combat")           # 绿色
DebugConfig.warn("警告信息")                         # 黄色
DebugConfig.error("错误信息")                        # 红色
```

**配置驱动** (debug_config.json):
- 全局开关和最低级别
- 分类标签配置（combat/state_machine/player/ai/ui）
- 路径层级配置（最长匹配优先）

---

## 🎮 输入映射

| 操作 | 按键 | 功能 |
|------|------|------|
| move_* | 方向键 | 移动 |
| primary_fire | 鼠标左键 | 主攻击 |
| dash | 空格 | 冲刺 |
| atk_sp | V | 特殊攻击 |
| atk_1/2/3 | X/W/E | 技能1/2/3 |
| roll | R | 翻滚 |

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

**碰撞规则**:
- Player: ✅ World, Walls, Enemy, Enemy Projectile
- Enemy: ✅ World, Walls, Player, Player Projectile

---

## 📁 文件组织规范

```
Scenes/
├── charaters/           # 角色（.tscn + .gd同目录）
├── enemies/             # 敌人（普通+Boss）
└── UI/                  # UI界面

Util/
├── AutoLoad/            # 全局单例
├── Classes/             # 数据类（Damage, CharacterData, AttackEffect）
├── Components/          # 可复用组件（Health, Hitbox, Hurtbox）
├── StateMachine/        # 状态机框架
│   └── CommonStates/    # 通用状态模板
└── UI/                  # UI系统
    ├── Core/            # UIManager
    ├── Components/      # Toast, ConfirmDialog
    └── Modules/         # LoadingScreen等

Util/Data/               # 资源文件 (.tres)
├── SkillBook/           # 技能配置（Physical.tres, KnockUp.tres等）
└── Characters/          # 角色数据（hahashin.tres等）

Weapons/                 # 武器系统
├── slash/               # 近战
└── bullet/              # 远程
```

---

## 🔧 MCP集成

**已启用MCP服务**:
- `filesystem` - 文件系统操作
- `github` - GitHub集成
- `godot` - Godot编辑器集成（启动编辑器、运行项目、创建场景）

**常用MCP功能**:
```javascript
mcp__godot__launch_editor       // 启动Godot编辑器
mcp__godot__run_project         // 运行游戏
mcp__godot__get_debug_output    // 获取调试输出
```

---

## 📚 重要设计原则

### 编码规范（godot-coding-standards skill）
1. **通用性**: `@export` 配置化，避免硬编码
2. **模块化**: 单一职责，组件模式，信号松耦合
3. **可复用性**: Resource类存储数据，清晰公共接口
4. **简洁实用**: 注重实用，避免过度设计

### 命名规范
```gdscript
class_name PlayerHealth      # PascalCase
var max_health: float        # snake_case
const MAX_SPEED = 200.0      # UPPER_SNAKE_CASE
signal health_changed()      # snake_case
func take_damage() -> void   # snake_case + 类型注解
```

### 性能优化
- 使用 `@onready` 延迟初始化
- 对象池管理频繁创建的对象（bullet_pool.gd）
- 静态RNG避免重复创建
- 避免在 `_process()` 中创建对象

---

## 📖 文档资源

- **开发日志**: [dev_log/](../../dev_log/) - 按日期的会话记录
- **历史归档**: [dev_log/archive/](../../dev_log/archive/) - 完整历史记录（不自动加载）
- **编码规范**: [.claude/skills/godot-coding-standards/](../skills/godot-coding-standards/) - Skill详细文档
- **状态机指南**: [Util/StateMachine/STATE_MACHINE_GUIDE.md](../../Util/StateMachine/STATE_MACHINE_GUIDE.md)
- **调试系统**: [Util/AutoLoad/DEBUG_README.md](../../Util/AutoLoad/DEBUG_README.md)

---

**最后更新**: 2026-01-17
**预计Token消耗**: ~3000 tokens (减少80%)
