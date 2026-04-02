# Combo Demon 新手上手指南

> 面向首次接触本项目的开发者，5 分钟建立全局认知，快速定位修改路径。

## 一句话理解项目

Combo Demon 是一个 Godot 4.4.1 (Mobile Renderer) 2D 动作游戏，核心玩法是连招格斗 + 状态机 AI + 多阶段 Boss 战。项目约 193 个脚本、71 个场景、11 个 Resource 文件。

## 四层架构速览

```
┌─────────────────────────────────────────────────────┐
│  Presentation — .tscn 场景文件、UI、美术/音效资源     │
├─────────────────────────────────────────────────────┤
│  Business — 具体角色AI、Boss阶段逻辑、关卡目标脚本    │
├─────────────────────────────────────────────────────┤
│  Services — 跨场景全局单例 (Autoload)                │
├─────────────────────────────────────────────────────┤
│  Framework — 状态机框架、组件基类、Resource、特效系统  │
└─────────────────────────────────────────────────────┘

依赖方向: 上层 → 下层（禁止反向）
Services 被任意层通过 Autoload 访问
```

| 层 | 目录 | 你会在这里做什么 |
|---|---|---|
| Framework | `Core/StateMachine/`, `Core/Components/`, `Core/Resources/`, `Core/Effects/` | 添加新组件、新状态基类、新攻击效果 |
| Services | `Core/Autoloads/` | 添加全局服务（音频、UI、调试） |
| Business | `Scenes/Characters/`, `Scenes/Levels/` | 添加新敌人、新 Boss、新关卡 |
| Presentation | `Assets/`, `Scenes/UI/`, `*.tscn` | 配置场景节点、UI 界面、美术资源 |

## 推荐阅读顺序（30 分钟完整理解）

### 第一步：理解框架核心（10 分钟）

1. **`Core/StateMachine/BaseState.gd`** — 所有状态的基类，理解 `enter()`/`exit()`/`process_state()` 生命周期
2. **`Core/StateMachine/BaseStateMachine.gd`** — 状态机框架，理解优先级转换机制（BEHAVIOR < REACTION < CONTROL）
3. **`Core/Resources/Damage.gd`** + **`Core/Resources/AttackEffect.gd`** — 伤害系统：Damage 含 effects 数组，组合模式

### 第二步：理解角色体系（10 分钟）

4. **`Core/Characters/BaseCharacter.gd`** — 角色基类，HurtBox ↔ HealthComponent 自动连接
5. **`Core/Characters/EnemyBase.gd`** — 敌人基类，@export AI 参数驱动
6. **`Core/Characters/BossBase.gd`** — Boss 基类，三阶段系统 + 冷却管理

### 第三步：理解一个完整敌人（10 分钟）

7. **`Scenes/Characters/Enemies/Slime/`** — 最简单的敌人实现，看 .gd + .tscn 如何组合
8. **`Core/StateMachine/CommonStates/`** — 7 个通用状态（Idle/Chase/Attack/Hit/Stun 等），大部分敌人直接复用

## 核心概念速查

### 状态机优先级

```
CONTROL  (2) — stun, frozen    不可被同级打断
REACTION (1) — hit, knockback  可被 CONTROL 打断
BEHAVIOR (0) — idle, chase     可被任意高优先级打断
```

规则：高优先级 > 低优先级 → 允许转换；同优先级 → 检查 `can_be_interrupted`；当前状态主动转低优先级 → 允许（自愿结束）。

### AnimationTree 统一结构

所有角色共用同一 BlendTree 布局：

```
locomotion (BlendSpace2D 或 StateMachine) ─┐
                                           ├─ control_blend (Blend2) → output
control_sm (StateMachine: hit/stun/death) ─┘
```

- `blend_amount = 0.0` → 播放移动动画
- `blend_amount = 1.0` → 播放受击/眩晕/死亡动画

BaseState 提供 helper：`set_locomotion()`, `enter_control_state("hit")`, `exit_control_state()`

### 伤害链路

```
玩家攻击 → HitBoxComponent.area_entered
  → HurtBoxComponent.take_damage(damage)
  → HealthComponent: 扣血 + 应用效果 + 发信号
  → StateMachine._on_owner_damaged()
  → 自动状态切换: StunEffect→"stun", KnockBack→"knockback", else→"hit"
```

### 物理层

```
1: World    2: Player    3: Player Projectile
4: Enemy    5: Enemy Projectile    7: Object    8: Walls
```

## 调试系统

项目内置结构化日志系统 `DebugConfig`（Autoload），支持 4 级日志 + 分类过滤：

```gdscript
DebugConfig.debug("消息内容", "", "combat")    # DEBUG 级别
DebugConfig.info("消息内容", "", "state_machine")
DebugConfig.warning("消息内容", "", "animation")
DebugConfig.error("消息内容", "", "movement")
```

日志通道：`state_machine`, `animation`, `combat`, `movement`

配置文件：`Core/Autoloads/debug_config.json`

## 常见修改路径

### 添加一个新敌人

1. 在 `Scenes/Characters/Enemies/` 下创建新目录
2. 创建 .gd 脚本继承 `EnemyBase`，配置 `@export` 参数
3. 创建 .tscn 场景，挂载脚本 + `EnemyStateMachine`（选择 `BASIC`/`RANGED` 预设）
4. 场景中添加 `HurtBoxComponent`、`HealthComponent`、`AnimationTree`
5. 如需自定义行为，覆写 CommonState 或创建专用状态

### 添加一个新攻击效果

1. 在 `Core/Resources/` 创建新 .gd 继承 `AttackEffect`
2. 实现 `apply_effect(target, source_pos)` 和 `get_description()`
3. 创建 .tres 文件实例化效果
4. 在 `Damage.tres` 的 effects 数组中添加

### 添加一个新关卡

1. 在 `Scenes/Levels/` 创建新目录
2. 创建关卡场景 .tscn + .gd 脚本
3. 注册目标（treasures/keys/boss）
4. 监听完成条件，调用 `LevelManager.complete_level()`
5. 在 `LevelManager.gd` 的 `LEVEL_SCENES` 数组中注册

### 修改 Boss 行为

1. **调整攻击池**：编辑 `BossPhaseConfig` Resource（每个阶段独立配置）
2. **添加新攻击**：在 `Scenes/Characters/Enemies/boss/Attacks/` 创建新场景
3. **调整阶段阈值**：修改 `BossBase.gd` 中的 `PHASE_THRESHOLDS`
4. **添加新 Boss 状态**：在 `boss/Scripts/States/` 创建，继承 `BossBaseState`

## 项目运行

```bash
# 编辑器中打开
godot --editor --path .

# 无头运行（测试用）
godot --headless --path .

# 运行单元测试（需安装 GUT 插件）
godot --headless -s addons/gut/gut_cmdline.gd -gdir=res://test/unit -gexit
```

## 进一步阅读

| 需要了解 | 文件 |
|---------|------|
| 详细架构分层 | `.claude/skills/project-architecture/references/layer-map.md` |
| 信号链路和数据流 | `.claude/skills/project-architecture/references/data-flow.md` |
| 核心类速查 | `.claude/skills/project-architecture/references/module-registry.md` |
| 场景模板和类图 | `.claude/skills/project-architecture/references/scene-templates.md` |
| 敌人开发指南 | `.claude/skills/feature-development/references/enemy-guide.md` |
| Boss 开发指南 | `.claude/skills/feature-development/references/boss-guide.md` |
| 组件开发指南 | `.claude/skills/feature-development/references/component-guide.md` |
