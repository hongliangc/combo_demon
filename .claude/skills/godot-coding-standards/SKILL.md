---
name: godot-coding-standards
description: "Godot 4.x 核心架构原则。当设计、审查 Godot 组件和系统时使用。关注：组件模式、信号通信、Resource设计、系统架构。触发词：godot, 组件, 信号, 架构, 设计, coding standards."
---

# Godot 4.x 核心架构原则

## 设计原则

1. **通用性** — `@export` 配置化，组件跨场景复用，不依赖特定父节点
2. **模块化** — 单一职责，组件组合复杂行为，信号松耦合
3. **可复用** — Resource 存储配置（Damage, SkillData），清晰接口，private `_` 前缀
4. **简洁** — 不过度设计，不为未来需求预设，代码自解释
5. **继承+钩子** — 通用逻辑在基类，提供可重写钩子，子类只重写必要方法

## 编辑器配置优先

- Node 派生对象在编辑器创建配置，代码只控制运行时参数
- 动态生成: `preload("*.tscn").instantiate()`，不 `new()` + `add_child()`
- 编辑器负责: 节点层级、属性默认值、信号连接、AnimationTree 节点
- 代码负责: `set()` 参数驱动、`travel()` 状态切换、条件判断

## 场景模板（Scene Template）原则 — 骨架 vs 内容

**核心原则**：**模板只做骨架，不做内容**。被多个实例继承的 .tscn（如 `AgentAIBase.tscn`、`PlayerBase.tscn`）必须只包含"所有继承者都需要的结构"，不预设任何实例特有的视觉、数值、shape、动画数据。

### 骨架（属于模板） vs 内容（属于实例）

| 类别 | 骨架（模板提供） | 内容（实例自加） |
|---|---|---|
| 节点结构 | `CharacterBody2D` 根、`HurtBox/HitBox/HealthComponent/HealthBar/AnimationPlayer/AIController/StateMachine` 等公共组件节点 | `AnimatedSprite2D` / `Sprite2D` 等视觉节点（每个 boss 自己选） |
| 状态机 | Stock states：`Idle/Chase/Hit/Death/Dispatcher/GenericAttack/Combo`（无 boss 配置、所有 boss 都用） | Boss 特殊 states（如 BK 的 `Approach`、DS2 的 `Counter/Defend/Roll/Stun`） |
| Shape | `CollisionShape2D` **节点存在但 shape 留空** | shape 大小、形状由 boss 自填 |
| 动画 | `AnimationPlayer` 节点存在、`libraries/` 留空 | `AnimationLibrary` 资源、track 内容 |
| 数值 | 字段定义、`@export` 默认值 = 0/null | `max_health`、`base_move_speed` 等具体数值 override |

### Leakage 反 pattern（必须避免）

模板里**任何一处指向具体子节点或假设具体内容**，都会污染所有继承者：

1. **占位视觉节点**（如模板放 `Sprite2D`，但 boss 用 `AnimatedSprite2D`）
   - 后果：实例被迫"忽略继承的节点 + 加 sibling 替代节点"。继承场景**无法删除**继承来的节点，只能 override 字段。
   - 修法：模板**不**预放视觉节点，由 boss 实例自己 add。
2. **默认 shape**（如 `RectangleShape2D` size=`Vector2(81, 80)`）
   - 后果：boss 忘记 override 时仍能编译，但 hitbox 大小荒谬。
   - 修法：shape 节点存在但 `shape = null`，boss 必须显式 assign。
3. **RESET 动画引用具体子节点**（如 `Sprite2D:modulate` track）
   - 后果：boss 改了视觉节点名/类型，模板的 RESET 失效。
   - 修法：模板的 AnimationLibrary 留空，让 boss 在自己的库里定义 RESET。
4. **boss-specific 状态进入模板**（如把 `Counter` 加进 AgentAIBase）
   - 后果：所有不需要 Counter 的 boss 都背着 dead code。
   - 修法：保持模板纯净 —— 加节点前问"**所有**继承者都需要吗？"否则放实例。

### 实操规则

- 添加节点入模板前自问：**"所有继承者都需要它吗？"** 否则放实例。
- shape / animation library / sprite frames 等数据资源**不预填**，留空。
- 节点必须存在（structural）但内容必须空（data-empty）—— 例：`CollisionShape2D` 节点在，`shape` 字段空。
- 模板升级（加新事件、新组件字段）时所有继承者**自动**同步；这是接受继承复杂度的根本回报。
- 实例需要的特殊功能（boss-specific buff、特殊状态、特效节点）**永远在实例内**，不上推到模板。

## 状态机 + AnimationTree 规范

**统一 BlendTree**:
```
locomotion → loco_timescale → control_blend[0]
control_sm → ctrl_timescale → control_blend[1]
control_blend → output
```

- 状态继承 BaseState，用 helper: `set_locomotion()`, `enter_control_state()`, `exit_control_state()`
- 优先级三层: `BEHAVIOR(0) < REACTION(1) < CONTROL(2)`
- `exit()` 必须断开 `animation_finished` 信号 + 停止 Timer
- locomotion 两模式: BlendSpace2D (`set_locomotion(Vector2)`) / StateMachine (`set_locomotion_state()`)

## 架构检查要点

- `@export` 配置化？跨场景复用？
- 单一职责？信号解耦？
- 清晰接口？Resource 正确使用？
- 基类钩子？子类最小化重写？
- 编辑器配置节点？不在代码中 `new()` Node？
- 状态继承 BaseState？用 helper 不直接操作 AnimationTree？
- exit() 断开信号+停止 Timer？
- **场景模板纯骨架？** 模板里有无占位视觉节点 / 默认 shape / boss-specific state / 引用具体子节点的 RESET 动画？（任一项即 leakage，必须迁回实例）
