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
