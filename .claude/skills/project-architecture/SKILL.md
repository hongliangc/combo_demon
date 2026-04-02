---
name: project-architecture
description: "Combo Demon project architecture overview. Use when understanding codebase structure, navigating layers, tracing data flow, or locating modules. Triggers on: architecture, layer, data flow, signal chain, module, navigate, locate, codebase."
---

# 项目架构总览

Combo Demon 2D 动作游戏的架构导航 skill。提供分层架构、数据流、模块速查，供开发和排查共用。

## 四层架构

| 层 | 职责 | 关键目录 | 入口文件 |
|---|---|---|---|
| **Framework** | 与业务无关的通用能力：状态机框架、组件基类、Resource 基类、Effect 系统 | `Core/StateMachine/`, `Core/Components/`, `Core/Resources/`, `Core/Effects/` | `BaseState.gd`, `BaseStateMachine.gd`, `HealthComponent.gd`, `Damage.gd` |
| **Services** | 跨场景的全局单例服务：游戏流程、UI管理、音频、调试日志、对象池 | `Core/Autoloads/` | `GameManager.gd`, `UIManager.gd`, `DebugConfig.gd`, `LevelManager.gd` |
| **Business** | 具体角色实现：敌人 AI、Boss 阶段逻辑、玩家技能、关卡目标脚本 | `Scenes/Characters/`, `Scenes/Levels/*.gd` | `EnemyBase.gd`, `BossBase.gd`, `PlayerBase.gd` |
| **Presentation** | 场景组合（.tscn）、UI 界面、美术/音频资源 | `Scenes/**/*.tscn`, `Scenes/UI/`, `Assets/` | 各 .tscn 文件 |

### 依赖方向

```
Presentation → Business → Framework
                 ↓
              Services（全局可访问，但不反向依赖 Business）
```

- **允许**：上层调用下层的公共 API，Services 被任意层通过 Autoload 访问
- **禁止**：Framework 引用 Business 代码，Services 直接操作特定角色逻辑

## 三条核心数据流

### 1. 伤害链路
```
玩家输入(atk_1/2/3)
  → PlayerState 触发攻击动画
  → HitBoxComponent.area_entered(enemy_hurtbox)
  → HurtBoxComponent.take_damage(damage, attacker_pos)
  → HealthComponent:
      ├─ health -= damage.amount
      ├─ display_damage_number()
      ├─ apply_attack_effects() → KnockBack/Stun/KnockUp
      ├─ health_changed.emit() → UI 血条更新
      └─ damaged.emit() → BaseCharacter.damaged.emit()
  → BaseStateMachine._on_owner_damaged()
  → current_state.on_damaged(damage, attacker_pos)
  → 状态切换: StunEffect→"stun", KnockBack→"knockback", else→"hit"
```

### 2. 状态机切换链路
```
触发源（timer/距离检测/伤害）
  → current_state.transitioned.emit(self, "new_state_name")
  → BaseStateMachine._on_state_transition(from_state, new_state_name)
      ├─ 验证 from_state == current_state（防止过期请求）
      ├─ states.get(new_state_name.to_lower())（查找目标状态）
      └─ current_state.can_transition_to(new_state)（优先级检查）
          ├─ 高优先级 > 低优先级 → 允许
          ├─ 同优先级 → 检查 can_be_interrupted
          └─ 当前状态主动转低优先级 → 允许（自愿结束）
  → _execute_transition: exit() → enter() → current_state = new_state
```

### 3. 关卡流程
```
Main.tscn 加载
  → GameManager: MENU → CHARACTER_SELECT → PLAYING
  → LevelManager.start_level(index)
      → 加载 LEVEL_SCENES[index]
      → level_started.emit(index)
  → Level 脚本:
      ├─ 注册目标（treasures/keys/boss）
      ├─ 监听完成条件
      └─ LevelManager.complete_level() → 加载下一关
```

## 分层定位法（排查用）

> 详细排查流程 → 触发 `troubleshooting` skill

遇到问题时，先判断现象属于哪一层，然后从该层入口文件开始排查。日志通道: `animation`, `combat`, `state_machine`, `movement`。

## 按需加载详细资料

根据需要读取 references/ 下的详细文件：

| 需要了解 | 读取文件 |
|---------|---------|
| 四层架构的详细说明（文件清单、职责边界、通信规则） | `references/layer-map.md` |
| 完整信号链路图、时序图、Autoload 信号列表 | `references/data-flow.md` |
| 核心类速查（类名→路径→职责→API→依赖） | `references/module-registry.md` |
| 场景模板、类图、AnimationTree 分层动画、状态流转图 | `references/scene-templates.md` |

### 独立架构文档（docs/）

| 需要了解 | 文档 |
|---------|------|
| 总索引 + 新人路线 + 所有文档/skill 导航 | `docs/ARCHITECTURE.md` |
| mermaid 类图（角色/状态机/组件/Resource/Autoload） | `docs/class-diagrams.md` |
| mermaid 架构图（分层/伤害时序/状态流转/Boss 阶段/AnimationTree） | `docs/architecture-diagrams.md` |
