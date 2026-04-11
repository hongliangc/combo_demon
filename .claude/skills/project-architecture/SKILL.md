---
name: project-architecture
description: "Combo Demon project architecture overview. Use when understanding codebase structure, navigating layers, tracing data flow, or locating modules. Triggers on: architecture, layer, data flow, signal chain, module, navigate, locate, codebase."
---

# 项目架构总览

## 四层架构

| 层 | 职责 | 目录 |
|---|---|---|
| **Framework** | 状态机、组件基类、Resource、Effect | `Core/StateMachine/`, `Core/Components/`, `Core/Resources/`, `Core/Effects/` |
| **Services** | 全局单例服务 | `Core/Autoloads/` |
| **Business** | 角色实现、关卡脚本 | `Scenes/Characters/`, `Scenes/Levels/` |
| **Presentation** | .tscn、UI、美术音频 | `Scenes/**/*.tscn`, `Assets/` |

依赖方向: Presentation → Business → Framework。Services 全局可访问但不反向依赖 Business。

## 按需加载

根据需要 Read 对应 reference：

| 需要了解 | 读取文件 |
|---------|---------|
| 四层详细说明、文件清单、通信规则 | `references/layer-map.md` |
| 信号链路图、时序图、Autoload 信号 | `references/data-flow.md` |
| 核心类速查（类名→路径→职责→API） | `references/module-registry.md` |
| 场景模板、类图、动画分层、状态流转 | `references/scene-templates.md` |
| AI 友好性指南 | `references/ai-friendliness.md` |
| 新人入门路线 | `references/onboarding-guide.md` |
| Resource 管理规范 | `references/resource-management.md` |
| 风险与技术债务 | `references/risk-and-tech-debt.md` |

独立架构文档：`docs/ARCHITECTURE.md`、`docs/class-diagrams.md`、`docs/architecture-diagrams.md`
