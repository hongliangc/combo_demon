# 生成项目 AI Skills 与架构文档

## 一句话

```
请阅读 META-PROMPT-GENERATE-SKILLS-AND-DOCS.md，分析当前项目，生成完整的 Skills 和架构文档。
```

## 目标

1. 分析项目架构，按功能域归类为 Skills，方便 AI 助手按需加载
2. 生成架构文档体系，让新人快速理解项目结构、编码规范和开发流程
3. 补充架构图、类图、数据流图，结合关键路径代码描述，可直接指导开发
4. 底层框架与业务逻辑分层，各层有独立的 Skill 和文档

## 产出结构

```
{project}/
├── CLAUDE.md                          # AI 助手入口（~300行概览）
├── .claude/skills/                    # Skills（可执行指令层）
│   ├── {project}-feature-development/ # 端到端开发工作流
│   ├── {project}-framework-core/      # 框架核心机制
│   ├── {project}-business-logic/      # 业务逻辑层
│   ├── {project}-adaptor-layer/       # 外部适配层（按需）
│   └── {project}-troubleshooting/     # 日志排查（按需）
└── docs/                              # 架构文档（详细层）
    ├── ARCHITECTURE.md                # 总索引 + 新人路径
    ├── 01-architecture-overview.md    # 分层架构 + 启动流程
    ├── 02-data-pipeline.md            # 数据/请求全链路
    ├── 03-class-diagrams.md           # 类/接口继承层次
    ├── development-guide.md           # 开发指南（最重要）
    └── ...                            # 按需：配置/模块/数据流等
```

## 核心原则

1. **代码驱动** — 所有示例和约定从代码中提取，不虚构
2. **按需生成** — 文档和 Skill 数量跟着架构走，不强凑
3. **三层递进** — CLAUDE.md 概览 → docs 详细 → skills 可执行
4. **面向实战** — Common Mistakes 来自真实代码观察
5. **语言无关** — 适用于 C++/Go/Java/Python/Rust/TypeScript 等任何语言

## 详细规范

见 `META-PROMPT-GENERATE-SKILLS-AND-DOCS.md`
