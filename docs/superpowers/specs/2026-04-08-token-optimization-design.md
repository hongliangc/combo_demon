# Token 消耗优化设计

**日期**: 2026-04-08
**方案**: 方案 B — 按需加载架构（中风险，高收益）

## 目标

全面优化 Claude Code 对话中的 token 消耗，覆盖 MCP servers、settings、skills、docs、memory 等所有维度。典型开发对话 context 从 ~50-80K tokens 降低到 ~15-25K tokens。

## 1. MCP Server 裁剪 + Settings 清理

### 1.1 移除 filesystem + github MCP

- **`.mcp.json`**: 删除 `filesystem` 和 `github` server 定义，只保留 `godot`
- **`settings.local.json`**: 删除所有 `mcp__filesystem__*` 和 `mcp__github__*` allow 条目，以及 `enabledMcpjsonServers` 中对应项
- **节省**: ~3-5K tokens/对话（~40 个工具定义）

### 1.2 清理一次性 Bash 权限

**保留**:
- `Bash("D:/devtool/godot/Godot_v4.6-stable_win64.exe/Godot_v4.6-stable_win64_console.exe" --headless --import)`
- `Bash("D:/devtool/godot/Godot_v4.6-stable_win64.exe/Godot_v4.6-stable_win64_console.exe" --headless --script addons/gut/gut_cmdln.gd *)`

**删除**: 其余 curl/unzip/cp/cygpath/mv/旧 Godot 4.4.1 路径等全部清理。

### 1.3 移除 doc-organizer skill

删除 `.claude/skills/doc-organizer.md`。

## 2. Skill 按需加载架构（核心优化）

### 2.1 加载模式变更

**当前**: 触发 skill → SKILL.md + 所有 references 全量加载（如 feature-development 一次加载 ~42.9KB）

**优化后**: 触发 skill → 精简 SKILL.md (~1.5-2KB) + 根据任务类型只 Read 对应 reference（单次 ~5-8KB）

### 2.2 SKILL.md 瘦身结构

每个 SKILL.md 重构为三段：

1. **触发条件 + 角色定义**（~200-500 bytes）
2. **核心流程/检查清单**（~500-1000 bytes）
3. **Reference 路由表** — 根据任务类型指示 Read 对应 reference 文件

路由表示例：
```markdown
## Reference 按需加载
根据任务内容，Read 对应的 reference 文件：
| 任务类型 | 文件 |
|---|---|
| Boss 开发/修改 | references/boss-guide.md |
| Enemy 开发/修改 | references/enemy-guide.md |
| 组件/信号 | references/component-guide.md |
```

### 2.3 各 Skill 优化目标

| Skill | 当前总量 | 目标 SKILL.md | 策略 |
|---|---|---|---|
| `feature-development` | 42.9KB | ~2KB | refs 按需 |
| `project-architecture` | 66.9KB | ~1.5KB | refs 按需 |
| `testing` | 16.4KB | ~1.5KB | ref 按需 |
| `troubleshooting` | 11.2KB | ~1.5KB | ref 按需 |
| `godot-level-design` | 74.7KB | ~2KB | refs 按需 |
| `godot-coding-standards` | 8.9KB | ~3-4KB | 压缩去重 |
| `code-review` | 3.5KB | ~2.5KB | 微调 |
| `context-updater` | 5.5KB | ~2-3KB | 压缩 |

### 2.4 Reference 大文件压缩

目标：每个 reference 控制在 5-8KB 以内。重点压缩：
- `module-registry.md` (22.5KB) → 索引+指针
- `scene-templates.md` (21.1KB) → 关键模式+路径索引
- `screenshot-to-level.md` (19.1KB) → 精简流程
- `gut-patterns.md` (12.7KB) → 常用模式速查

## 3. CLAUDE.md 极简化

### 3.1 精简 Architecture 段

当前 ~1.2KB 架构摘要与 `project-architecture` skill 和 `docs/ARCHITECTURE.md` 重复。替换为指针：

```markdown
## Architecture
> 触发 `project-architecture` skill 或阅读 `docs/ARCHITECTURE.md`
> 类图 → `docs/class-diagrams.md` | 架构图 → `docs/architecture-diagrams.md`
```

**目标**: 2.9KB → ~1.5KB

## 4. Docs 重组

### 4.1 保留在 docs/ 下

- `ARCHITECTURE.md` (6.8KB) — 架构入口
- `class-diagrams.md` (7.0KB) — 被 CLAUDE.md 引用
- `architecture-diagrams.md` (8.2KB) — 被 CLAUDE.md 引用

### 4.2 移到 .claude/skills/ 作为 reference

- `ai-friendliness.md` (8.2KB)
- `onboarding-guide.md` (7.2KB)
- `resource-management.md` (8.5KB)
- `risk-and-tech-debt.md` (14.0KB)

### 4.3 移到 .claude/ 下

- `生成项目 AI Skills 与架构文档.md` — 元提示文件
- `META-PROMPT-GENERATE-SKILLS-AND-DOCS.md` — 元提示文件

## 5. Memory 清理

### 5.1 保留

- `feedback_commit_after_cr.md` — 活跃工作流指导
- `feedback_refactoring_is_development.md` — 活跃工作流指导（需从旧路径迁移）
- `feedback_doc_update_timing.md` — 活跃工作流指导（需从旧路径迁移）

### 5.2 删除

- `project_statemachine_refactor.md` (3.5KB) — 已完成
- `reference_vscode_conpty_fix.md` — 环境问题，与开发无关
- `reference_atlas_annotation_workflow.md` — 不再需要
- `reference_tilemap_binary_format.md` — 不再需要
- `reference_level3_atlas_coords.md` — 特定数据，已在代码中体现

### 5.3 MEMORY.md 索引

更新索引，只保留 3 个 feedback 条目。迁移旧路径下的文件到正确目录。

## 6. Specs/Plans 归档

将 `docs/superpowers/` 下已完成的 spec/plan 文件移到 `docs/superpowers/archive/` 子目录。只保留最近未完成的在原位。

## 7. 实施顺序

1. MCP 裁剪 + Settings 清理（零风险）
2. Memory 清理 + 旧文件迁移
3. Specs/Plans 归档
4. 删除 doc-organizer
5. CLAUDE.md 精简
6. Docs 重组
7. Skill SKILL.md 瘦身重构（核心工作）
8. Reference 大文件压缩

## 8. 验证方式

- 启动新对话，观察初始 token 用量
- 触发对应 skill，确认功能正常、按需加载生效
- 执行一次完整小 feature 开发流程，对比优化前后消耗

## 9. 预期效果

| 优化项 | 预估节省 |
|---|---|
| 移除 filesystem + github MCP | ~3-5K tokens/对话 |
| Settings 清理 | ~0.5K tokens |
| Memory 清理 | ~1K tokens |
| CLAUDE.md 精简 | ~0.5K tokens/对话 |
| Skill 按需加载 | ~15-25K tokens/次触发 |
| Reference 压缩 | ~5-10K tokens |
| Docs 重组 | 减少探索性误读 |
