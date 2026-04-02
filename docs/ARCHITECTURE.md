# Combo Demon — 架构总索引

> 项目概览 → 分层架构 → 核心数据流 → 文档与 Skill 导航 → 新人路线

## 项目概览

**Combo Demon** — Godot 4.4.1 2D 动作游戏，核心玩法：流畅连招战斗、状态机 AI、多阶段 Boss 战、攻击特效系统。

| 指标 | 值 |
|------|-----|
| 引擎 | Godot 4.4.1 (Mobile Renderer) |
| 脚本 | ~190 GDScript |
| 场景 | ~74 .tscn |
| 敌人类型 | 14+ |
| Boss | 3 (BladeKeeper, Cyclops, DemonSlime) |
| 物理层 | 8 (World/Player/PlayerProj/Enemy/EnemyProj/Object/Walls) |

---

## 四层架构

```
┌─────────────────────────────────────────────────┐
│  Presentation 层  — .tscn 场景文件, UI, Assets  │
├─────────────────────────────────────────────────┤
│  Business 层      — 角色实现, 关卡逻辑          │
├─────────────────────────────────────────────────┤
│  Framework 层     — 状态机, 组件, Resource, 特效 │
├─────────────────────────────────────────────────┤
│  Services 层      — Autoload 全局单例服务       │
└─────────────────────────────────────────────────┘
  依赖方向: Presentation → Business → Framework
            Services 被任意层访问，不反向依赖 Business
```

| 层 | 目录 | 入口文件 |
|---|---|---|
| Framework | `Core/StateMachine/`, `Core/Components/`, `Core/Resources/`, `Core/Effects/` | BaseState.gd, BaseStateMachine.gd, HealthComponent.gd, Damage.gd |
| Services | `Core/Autoloads/` | GameManager.gd, UIManager.gd, DebugConfig.gd, LevelManager.gd |
| Business | `Scenes/Characters/`, `Scenes/Levels/*.gd` | EnemyBase.gd, BossBase.gd, PlayerBase.gd |
| Presentation | `Scenes/**/*.tscn`, `Scenes/UI/`, `Assets/` | 各 .tscn 文件 |

---

## 核心数据流（速览）

### 伤害链路
```
输入(atk) → PlayerState → HitBox.area_entered → HurtBox.take_damage
  → HealthComponent: 扣血 + 伤害数字 + apply_effects(Stun/KnockBack/...)
  → damaged.emit → StateMachine → 状态切换(stun/knockback/hit)
```

### 状态机优先级
```
CONTROL(2) > REACTION(1) > BEHAVIOR(0)
高优先级打断低优先级，同优先级检查 can_be_interrupted
```

### Boss 阶段
```
Phase 1 (100%~67%) → Phase 2 (67%~33%) → Phase 3 (33%~0%)
每阶段: 速度倍率↑, 冷却↓, Phase 3 免疫眩晕
```

---

## 文档导航

### 架构文档 (docs/)

| 文档 | 内容 | 适合场景 |
|------|------|---------|
| [class-diagrams.md](class-diagrams.md) | mermaid 类图: 角色继承、状态机层次、组件关系、Resource 继承 | 理解类关系 |
| [architecture-diagrams.md](architecture-diagrams.md) | mermaid 架构图: 四层分层、伤害时序、状态流转、Boss 阶段 | 理解数据流 |
| [onboarding-guide.md](onboarding-guide.md) | 新人30分钟上手指南 + 推荐阅读路径 | 首次接触项目 |
| [resource-management.md](resource-management.md) | 配置管理现状、.tres/Resource 迁移路线图 | 理解配置体系 |
| [ai-friendliness.md](ai-friendliness.md) | AI 辅助开发友好性分析 + 改进建议 | AI 编码障碍 |
| [risk-and-tech-debt.md](risk-and-tech-debt.md) | 技术债 P0/P1/P2 分级 + 修复优先级 | 风险评估 |

### Skills 导航 (.claude/skills/)

| Skill | 触发场景 | 说明 |
|-------|---------|------|
| `project-architecture` | 理解架构、定位模块、追踪数据流 | 四层架构 + 三条数据流 + 分层定位法 |
| `godot-coding-standards` | 编写/审查代码 | 组件模式、信号通信、编辑器优先、AnimationTree 规范 |
| `feature-development` | 新功能、新敌人/Boss/效果、重构、优化 | 需求分类 → 加载指南 → 实现 → 验证 → 更新 |
| `testing` | 验证功能 | 三层验证: Debug 日志 → GUT 单测 → MCP 运行时 |
| `troubleshooting` | 排查 bug | 分层定位 → 日志追踪 → 数据流验证 |
| `code-review` | 代码审查 | 多维审查清单 + P0/P1/P2 严重度 |
| `godot-level-design` | 设计/生成关卡 | 两种模式: 从零设计 / 截图还原 |
| `context-updater` | 架构变更后 | 保持 project_context.md 最新 |

### Skill Reference 详细资料

| 需要了解 | Reference 文件 |
|---------|---------------|
| 四层详细说明 + 文件清单 | `project-architecture/references/layer-map.md` |
| 完整信号链路 + 时序图 | `project-architecture/references/data-flow.md` |
| 核心类速查(类名→API→依赖) | `project-architecture/references/module-registry.md` |
| 场景模板 + mermaid 类图/状态图 | `project-architecture/references/scene-templates.md` |
| 敌人开发指南 | `feature-development/references/enemy-guide.md` |
| Boss 开发指南 | `feature-development/references/boss-guide.md` |
| 攻击效果开发指南 | `feature-development/references/effect-guide.md` |
| 组件开发指南 | `feature-development/references/component-guide.md` |
| 陷阱开发指南 | `feature-development/references/trap-guide.md` |
| 常见问题速查表 | `troubleshooting/references/common-issues.md` |
| GUT 测试模式 | `testing/references/gut-patterns.md` |
| 重构指南 | `feature-development/references/refactoring-guide.md` |

---

## 新人阅读路线（30 分钟）

### Phase 1: 框架骨架（10 分钟）
1. `Core/StateMachine/BaseState.gd` — 状态基类 + 优先级系统
2. `Core/StateMachine/BaseStateMachine.gd` — 状态机引擎
3. `Core/Resources/Damage.gd` — 伤害数据 + 效果链

### Phase 2: 角色体系（10 分钟）
4. `Core/Characters/BaseCharacter.gd` — 角色通用逻辑
5. `Core/Characters/EnemyBase.gd` — 敌人 AI 参数
6. `Core/Characters/BossBase.gd` — Boss 阶段系统

### Phase 3: 完整实例（10 分钟）
7. `Scenes/Characters/Enemies/Slime/` — 最简单的敌人，端到端走通
8. `Core/StateMachine/CommonStates/` — 7 个通用状态

### 然后
- 要开发新功能 → 触发 `feature-development` skill
- 要排查问题 → 触发 `troubleshooting` skill
- 要理解某个模块 → 触发 `project-architecture` skill

---

## 调试入口

```gdscript
DebugConfig.debug("消息", "", "channel")
# 通道: state_machine, animation, combat, movement
```

配置文件: `Core/Autoloads/debug_config.json`

MCP 工具:
- `mcp__godot__run_project` — 运行
- `mcp__godot__get_debug_output` — 读日志
- `mcp__godot__stop_project` — 停止
