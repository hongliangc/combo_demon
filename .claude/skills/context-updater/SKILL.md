---
name: context-updater
description: "项目架构文档与 Skills 更新器。仅在开发完毕 + 测试通过 + Code Review 无问题后触发。由 feature-development 最后一步调用。触发词：更新文档, 更新架构, 同步skills, 完成实现."
---

# 上下文与架构文档更新器

**前置**: 开发完毕 + 测试通过 + CR 通过后才触发。

## 更新矩阵

| 变更类型 | 检查项 |
|---------|--------|
| 新增/删除类 | `docs/class-diagrams.md`, `module-registry.md` |
| 修改继承关系 | `docs/class-diagrams.md` |
| 新增/修改信号链路 | `docs/architecture-diagrams.md`, `data-flow.md` |
| 新增/修改状态 | `docs/architecture-diagrams.md`, `scene-templates.md` |
| 新增 Autoload | `docs/class-diagrams.md`, `CLAUDE.md` |
| 新增 Resource | `docs/class-diagrams.md` |
| 修改 Boss 阶段 | `docs/architecture-diagrams.md` |
| 新增角色类型 | `docs/class-diagrams.md`, enemy/boss guide |
| 修改物理层/输入 | `CLAUDE.md` |
| 新增组件 | `docs/class-diagrams.md`, `component-guide.md` |
| 修改 AnimationTree | `docs/architecture-diagrams.md`, `scene-templates.md` |
| 新开发模式/约定 | `godot-coding-standards` skill |
| 新踩坑经验 | `common-issues.md` |
| 修改统计 | `CLAUDE.md`, `docs/ARCHITECTURE.md` |

## 原则

- 最小改动，只更新受影响部分
- 代码驱动，不虚构
- 同步更新，不留"待更新"
- Bug 修复/参数微调/UI 样式调整 → 不需要更新
