---
name: context-updater
description: "项目架构文档与 Skills 更新器。仅在开发完毕 + 测试通过 + Code Review 无问题后触发，更新架构文档和 skill references 保持最新。由 feature-development Step 6 调用，不在中间步骤触发。触发词：更新文档, 更新架构, 同步skills, 完成实现."
---
# 项目上下文与架构文档更新器

当项目发生变更时，按本 skill 检查并更新所有相关文档和 skills。

## 触发时机

**前置条件：开发完毕 + 测试通过 + Code Review 无问题。**

本 skill 只在全流程走完后触发，不在中间步骤触发：

```
实现 → 测试(testing) → CR(code-review) → CR 通过 → ✅ 触发 context-updater
```

具体触发场景：

- `feature-development` skill 的 Step 6（通用开发流程，CR 通过后）
- `feature-development` skill 的 Step 6（重构/优化流程，CR 通过后）
- 手动触发（确认变更已经稳定、不会再改时）

## 更新检查矩阵

根据变更类型，逐项检查是否需要更新：

| 变更类型                          | 检查项                                                                   |
| --------------------------------- | ------------------------------------------------------------------------ |
| **新增/删除类**             | `docs/class-diagrams.md` 继承图、`module-registry.md` 类速查表       |
| **修改继承关系**            | `docs/class-diagrams.md` 对应继承图                                    |
| **新增/修改信号链路**       | `docs/architecture-diagrams.md` 信号通信图、`data-flow.md`           |
| **新增/修改状态**           | `docs/architecture-diagrams.md` 状态流转图、`scene-templates.md`     |
| **新增 Autoload**           | `docs/class-diagrams.md` Autoload 依赖图、`CLAUDE.md` Autoloads 列表 |
| **新增 Resource 类**        | `docs/class-diagrams.md` Resource 体系图                               |
| **修改 Boss 阶段**          | `docs/architecture-diagrams.md` Boss 阶段图                            |
| **新增角色类型**            | `docs/class-diagrams.md` 角色继承图、对应 enemy/boss guide             |
| **修改物理层/输入**         | `CLAUDE.md` Physics Layers / Input 章节                                |
| **新增组件**                | `docs/class-diagrams.md` 组件图、`component-guide.md`                |
| **修改 AnimationTree 结构** | `docs/architecture-diagrams.md` BlendTree 图、`scene-templates.md`   |
| **新增开发模式/约定**       | `godot-coding-standards` skill                                         |
| **新增常见问题**            | `troubleshooting/references/common-issues.md`                          |
| **修改项目统计**            | `CLAUDE.md` 概览、`docs/ARCHITECTURE.md` 概览表                      |

## 更新流程

### Step 1: 变更分类

判断本次变更涉及的层级：

```
□ Framework 层 (Core/) — 基类/组件/Resource 变更
□ Services 层 (Autoloads/) — 全局服务变更
□ Business 层 (Scenes/Characters/) — 角色/关卡实现变更
□ Presentation 层 (.tscn/UI/Assets) — 场景/UI 变更
```

### Step 2: 文档更新

按更新检查矩阵，逐项判断并更新：

**架构文档 (docs/):**

1. `docs/ARCHITECTURE.md` — 总索引是否需要新增条目
2. `docs/class-diagrams.md` — 类图中是否需要新增/修改类
3. `docs/architecture-diagrams.md` — 数据流/状态图是否需要更新

**入口文件:**
4. `CLAUDE.md` — 概览信息是否过时（脚本数/场景数/角色数等）

### Step 3: Skill Reference 更新

**判断标准**: 如果变更引入了新的开发模式、最佳实践或踩坑经验，需要更新对应 skill reference。

| 变更涉及         | 可能需要更新的 Reference                                |
| ---------------- | ------------------------------------------------------- |
| 新敌人开发模式   | `feature-development/references/enemy-guide.md`       |
| 新 Boss 开发模式 | `feature-development/references/boss-guide.md`        |
| 新攻击效果模式   | `feature-development/references/effect-guide.md`      |
| 新组件模式       | `feature-development/references/component-guide.md`   |
| 新重构经验       | `feature-development/references/refactoring-guide.md` |
| 新踩坑/排查经验  | `troubleshooting/references/common-issues.md`         |
| 新核心类         | `project-architecture/references/module-registry.md`  |
| 新场景模板       | `project-architecture/references/scene-templates.md`  |
| 新数据流         | `project-architecture/references/data-flow.md`        |
| 新架构层文件     | `project-architecture/references/layer-map.md`        |

### Step 4: 验证一致性

- 确保 `docs/class-diagrams.md` 中的类名与实际代码一致
- 确保 `docs/architecture-diagrams.md` 中的状态名与 `StateNames.gd` 一致
- 确保 `CLAUDE.md` 中的统计数字反映当前实际

## 更新原则

1. **最小改动** — 只更新受影响的部分，不重写整个文件
2. **代码驱动** — 所有更新内容从实际代码中提取，不虚构
3. **保持简洁** — 图表中只包含关键类和关系，不事无巨细
4. **同步更新** — 不留"待更新"标记，当场完成

## 不需要更新的场景

- Bug 修复（不涉及架构变更）
- 参数微调（@export 值调整）
- UI 样式调整
- 注释/文档格式修改
- 测试代码增删
