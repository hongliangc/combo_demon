# Claude Code 工作流

> Claude Code 在本项目中的配置加载、工作流程与工具链

---

## 1. 配置加载

```mermaid
sequenceDiagram
    participant CC as Claude Code
    participant S as settings.json
    participant SL as settings.local.json
    participant CTX as context/project_context.md
    participant SK as skills/*.md
    participant MCP as MCP Servers

    CC->>S: 加载基础权限
    CC->>SL: 合并本地权限（Bash/MCP/WebFetch）
    CC->>CTX: 注入项目上下文
    CC->>SK: 注册 Skills（按触发词匹配）
    CC->>MCP: 连接 MCP Servers（Godot/GitHub/FS）
    Note over CC: 就绪
```

### .claude/ 目录

```
.claude/
├── settings.json              # 团队共享权限
├── settings.local.json        # 本地扩展权限
├── context/
│   └── project_context.md     # 项目上下文（自动注入，<4000 tokens）
└── skills/
    ├── godot-coding-standards/SKILL.md
    ├── context-updater/SKILL.md
    └── doc-organizer.md
```

### 权限配置

| 文件 | 作用 | 内容 |
|------|------|------|
| settings.json | 团队基线 | 仅允许 `mcp__godot__stop_project` |
| settings.local.json | 本地扩展 | Bash (git/godot/python)、MCP (run_project/get_debug_output/get_uid)、WebFetch 域名白名单 |

---

## 2. 工作流程

### 2.1 会话生命周期

```mermaid
stateDiagram-v2
    [*] --> Init: 新会话

    state Init {
        [*] --> LoadConfig: settings + context + skills
        LoadConfig --> ReadGit: 读取 git status
        ReadGit --> [*]
    }

    Init --> Work: 接收任务

    state Work {
        [*] --> Plan
        Plan --> Todo: TodoWrite 建任务
        Todo --> Execute: in_progress
        Execute --> Done: completed
        Done --> Plan: 下一任务
        Done --> [*]: 全部完成
    }

    Work --> End

    state End {
        [*] --> SkillTrigger: Skills 自动触发
        SkillTrigger --> [*]
    }

    End --> [*]
```

### 2.2 任务处理流程

```mermaid
flowchart TD
    A([接收任务]) --> B{复杂度?}
    B -->|多步/架构级| C[EnterPlanMode]
    C --> D{用户批准}
    D -->|否| C
    D -->|是| E
    B -->|简单| E[TodoWrite 创建清单]
    E --> F[[逐项执行]]
    F --> G[标记 in_progress]
    G --> H[Read → Edit/Write]
    H --> I[标记 completed]
    I --> J{还有任务?}
    J -->|是| F
    J -->|否| K{触发 Skills?}
    K -->|context-updater| L[更新 project_context.md]
    K -->|否| M([完成])
    L --> M
```

---

## 3. Skills 系统

```mermaid
flowchart LR
    Input[用户消息] --> Match{包含触发词?}
    Match -->|godot/组件/信号/架构| S1[godot-coding-standards]
    Match -->|新功能/重构/架构变更| S2[context-updater]
    Match -->|文档整理| S3[doc-organizer]
    Match -->|无匹配| Pass[不触发]

    S1 -->|约束| Code[代码编写]
    S2 -->|写入| CTX[project_context.md]
    S3 -->|整理| Doc[DevLog/]
```

| Skill | 触发词 | 作用 | 约束 |
|-------|--------|------|------|
| godot-coding-standards | godot, 组件, 信号, 架构, 设计 | 编码规范约束 | 组件模式、信号通信、Resource 设计、BlendTree 标准 |
| context-updater | 新功能, 重构, 架构变更, 新模块 | 更新项目上下文 | 总量 < 4000 tokens，每模块 ≤ 3 行 |
| doc-organizer | 文档整理, 优化文档 | 拆分/归档文档 | 每文档 ≤ 1500 tokens，无跨文档重复 |

---

## 4. MCP 工具链

```mermaid
flowchart TB
    CC[Claude Code]
    CC -->|场景/运行/调试| G["Godot MCP\nrun_project, create_scene,\nadd_node, get_debug_output, get_uid"]
    CC -->|PR/Issue/搜索| GH["GitHub MCP\ncreate_pull_request,\nsearch_code, list_issues"]
    CC -->|文件读写| FS["Filesystem MCP"]
    CC -->|Shell 命令| Bash["Bash\ngit, godot --headless, python"]
```

---

## 5. 数据流总览

```mermaid
flowchart LR
    subgraph 输入
        U[用户指令]
        G[Git 状态]
        C[现有代码]
    end

    subgraph Claude_Code
        CTX[Context 上下文]
        SK[Skills 约束]
        TOOL[Tools/MCP]
    end

    subgraph 输出
        CODE[代码变更]
        DOC[文档更新]
        CTXU[上下文更新]
        GIT[Git 提交]
    end

    U & G & C --> Claude_Code
    CTX & SK --> Claude_Code
    Claude_Code --> CODE & DOC & CTXU & GIT
    CTXU -.->|反馈| CTX
```

---

*v2.1 | 2026-03-15*
