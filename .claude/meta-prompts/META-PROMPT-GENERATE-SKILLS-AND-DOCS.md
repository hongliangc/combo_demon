# 为任意工程生成 AI Skills 与架构文档

> 将此文件放到项目根目录，让 AI 助手执行即可。
> 适用于任何语言、任何框架、任何规模的工程。

---

## 使用方法

```
请阅读 META-PROMPT-GENERATE-SKILLS-AND-DOCS.md，分析当前项目，生成完整的 Skills 和架构文档。
```

---

## 执行步骤

### Phase 1: 项目分析（先分析，不写文件）

**1.1 扫描项目结构**

读取以下内容，形成项目画像：
- 构建文件（package.json / CMakeLists.txt / go.mod / Cargo.toml / pom.xml / Makefile 等）
- 入口文件（main.* / index.* / app.* / cmd/ 等）
- 目录结构（`find . -type f | head -300`，排除 node_modules/.git/vendor/target 等）
- 配置文件（*.cfg / *.yaml / *.toml / .env* 等）
- 已有文档（README / docs/ / CLAUDE.md 等）

**1.2 识别架构层次**

从代码中识别实际存在的层次（不要套模板，按项目实际情况分）：

```
常见分层模式（仅供参考，以项目实际代码为准）：

Web 服务类:  Controller → Service → Repository → Database
数据管道类:  Source → Transform → Sink
CLI 工具类:  Command → Handler → Core Logic
Agent 类:    Adaptor → Process → Deliver
SDK/Library: Public API → Internal → Primitives
微服务类:    Gateway → Service → Client → External
```

**1.3 提取编码约定**

从代码中观察（不是推测）：
- 命名风格、文件组织模式、错误处理方式
- 日志/监控模式、测试模式
- 特有的宏/装饰器/注解/trait 使用惯例

**1.4 向用户确认**

将项目画像和架构分层结果展示给用户，确认无误后再进入 Phase 2。

---

### Phase 2: 生成架构文档

在 `docs/` 下生成文档。**文档数量和主题根据项目实际需要决定**，不必固定 8 篇。

#### 必须生成的文档

| 文档 | 内容要求 |
|------|---------|
| `ARCHITECTURE.md` | 总索引 + 新人阅读路径 + 目录结构（标注重要度） |
| `01-architecture-overview.md` | 分层架构图(ASCII) + 技术栈表 + 启动/初始化流程 + 线程/进程模型 |
| `02-data-pipeline.md` | 数据/请求从入口到出口的完整链路，含序列图，标注每个环节的关键函数 |
| `03-class-diagrams.md` | 核心类/接口/trait 的继承层次图(ASCII)，关键数据结构定义 |
| `development-guide.md` | **最重要** — 见下方详细要求 |

#### 按需生成的文档

根据项目复杂度选择性生成：
- `data-flow.md` — 与外部服务的交互（适用于有多个外部依赖的项目）
- `module-index.md` — 模块分域导航（适用于多模块/多环境项目）
- `configuration.md` — 配置管理指南（适用于配置复杂的项目）
- `module-loading.md` — 模块发现与加载机制（适用于插件式架构）

#### development-guide.md 详细要求

这是最重要的文档，必须做到**拿来就能指导开发**：

```markdown
# 新功能开发指南

## 开发流程
1. 需求分析 → 2. 方案设计 → 3. 编码实现 → 4. 测试验证 → 5. 提交审查

## 代码模板（从项目中提取真实模式，不是虚构的）
### 新增 [核心功能单元] 模板
{实际代码骨架，含 import/include、类定义、关键方法、注册/配置}

### 标准业务流程模板
{读操作 / 写操作 / 异步操作 的真实代码模式}

## 构建与测试命令
{每个命令可直接复制执行}

## 常见错误（10+ 项，来自代码中观察到的实际模式）
| 错误 | 正确做法 |

## 开发自查清单
- [ ] ...
```

#### 文档质量红线

- **代码示例必须来自项目真实代码**，不允许虚构
- **ASCII 流程图**优先（终端兼容），不用 Mermaid
- 每个文档标注**对应的关键源文件路径**，方便跳转

---

### Phase 3: 生成 Skills

在 `.claude/skills/` 下生成 Skill 文件。

#### Skill 分类原则

按项目架构层次拆分 Skill，每个 Skill 对应一个关注域。典型拆法：

| Skill | 对应层次 | 何时触发 |
|-------|---------|---------|
| `{project}-feature-development` | 全链路 | 新功能/Bug修复/协议变更 |
| `{project}-framework-core` | 入口+框架+公共层 | 理解启动流程/线程模型/核心机制 |
| `{project}-business-logic` | 业务层 | 修改业务规则/数据处理/聚合逻辑 |
| `{project}-adaptor-layer` | 适配层 | 新增数据源/外部服务集成/协议对接 |
| `{project}-troubleshooting` | 运维/调试 | 线上问题/日志分析/性能排查 |

**注意**：以上只是参考。如果项目只有 3 层，就只生成 3-4 个 Skill。不要强凑数量。

#### SKILL.md 标准格式

```markdown
---
name: {skill-name}
description: >
  {一段话：定位 + 触发场景 + 关键词列表}
  写得"宽泛"一些，多列触发词，避免漏触发。
---

# {Skill 名称}

## Overview
{一段话定位}

## When to Use
- 场景 1
- 场景 2
**不适用：** ...

## Architecture Reference
→ docs/{对应文档}

## Key Files
| 模块 | 文件 | 职责 |
|------|------|------|

## Core Workflow / Mechanism
{选择合适的方式：}
- 分阶段工作流（Phase 1 → N）  ← feature-development 类
- Key Files + Code Patterns     ← framework/business 类
- 分步操作指南（Step 1 → N）   ← troubleshooting 类

## Common Code Patterns
{3-5 个从项目中提取的真实代码模式}

## Debugging Tips
{5+ 个常见问题排查方向}

## Common Mistakes
| 错误 | 正确做法 |
|------|---------|
{10+ 项，来自代码中观察到的真实模式}

## Related Skills
| Skill | 何时切换 |
|-------|---------|
```

#### `feature-development` Skill 必须包含

```
Phase 1: 需求分析
  - 改动清单拆解（按架构层次）
  - 调用链/继承关系影响分析
  - 风险识别（兼容性、并发、性能）

Phase 2: 方案设计
  - 参数/接口设计
  - 异常处理设计
  - 设计评审检查点 ← 编码前必须确认

Phase 3: 编码实现
  - 编码顺序（底层 → 上层 → 配置 → 测试）
  - 编码规范检查项（从项目约定中提取）

Phase 4: 测试验证
  - 构建/测试/lint 命令
  - 测试工具使用说明

Phase 5: 提交审查
  - 自查清单
  - Commit message / PR 描述模板
```

---

### Phase 4: 生成/更新 CLAUDE.md

CLAUDE.md 是 AI 助手的入口，保持精简（200-300 行），包含：

```markdown
# {project}

> {一句话描述}

## Project Overview
{项目描述 + 技术栈 + 核心能力}

## Common Commands
{构建、测试、lint、运行 — 每条可直接执行}

## Architecture
{分层架构简图 + 数据流简图}

## Key Components
{10 个核心组件一句话描述}

## Configuration
{配置文件说明}

## Testing
{测试框架和运行方式}

## Conventions
{10-15 条编码约定，从代码中观察得出}

## Documentation
{docs/ 文档列表}

## Skills
| Skill | 触发场景 |
|-------|---------|
```

---

### Phase 5: 质量验证

生成完成后逐项检查：

**硬性要求**（不通过则必须修复）：
- [ ] 代码示例来自项目真实代码
- [ ] 所有命令可直接执行
- [ ] 文件路径引用正确
- [ ] 术语全局一致

**软性要求**（建议优化）：
- [ ] CLAUDE.md ≤ 300 行
- [ ] 每个 SKILL.md ≤ 500 行
- [ ] Related Skills 形成完整导航网络
- [ ] 新人阅读路径合理

---

## 设计原则

1. **三层递进**: CLAUDE.md（概览 ~300行）→ docs/（详细 ~200行/篇）→ skills/（可执行 ~300行/篇）
2. **代码驱动**: 所有示例、约定、模式必须从代码中提取，不允许虚构
3. **触发优先**: Skill description 多列触发词，宁可误触发也不要漏触发
4. **按需生成**: 文档和 Skill 数量跟着架构走，不强凑固定数量
5. **面向实战**: Common Mistakes 来自真实代码观察，不是理论推导
