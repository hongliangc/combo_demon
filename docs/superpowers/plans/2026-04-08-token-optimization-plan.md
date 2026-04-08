# Token 消耗优化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Claude Code 对话 token 消耗从 ~50-80K 降低到 ~15-25K，通过 MCP 裁剪、按需加载 skill 架构、docs 重组和 memory 清理。

**Architecture:** 核心变更是将 skill 从"全量加载"改为"路由表+按需 Read"模式。SKILL.md 瘦身为触发条件+流程+路由表（~1.5-2KB），references 只在需要时被 Read。配合移除冗余 MCP servers、清理 settings、精简 CLAUDE.md。

**Tech Stack:** Claude Code skills (Markdown), MCP config (JSON), Git

---

### Task 1: MCP Server 裁剪

**Files:**
- Modify: `.mcp.json`

- [ ] **Step 1: 编辑 .mcp.json，删除 filesystem 和 github server**

将 `.mcp.json` 改为只保留 godot server：

```json
{
  "mcpServers": {
    "godot": {
      "command": "node",
      "args": [
        "C:\\Users\\ivan\\AppData\\Roaming\\npm\\node_modules\\godot-mcp\\build\\index.js"
      ],
      "env": {
        "GODOT_PATH": "D:\\devtool\\godot\\Godot_v4.6-stable_win64.exe\\Godot_v4.6-stable_win64.exe"
      },
      "disabled": false,
      "autoApprove": [
        "launch_editor",
        "run_project",
        "get_debug_output",
        "stop_project",
        "get_godot_version",
        "list_projects",
        "get_project_info",
        "create_scene",
        "add_node",
        "load_sprite",
        "export_mesh_library",
        "save_scene",
        "get_uid",
        "update_project_uids"
      ]
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add .mcp.json
git commit -m "chore: remove filesystem and github MCP servers to reduce token usage"
```

---

### Task 2: Settings 清理

**Files:**
- Modify: `.claude/settings.local.json`

- [ ] **Step 1: 精简 settings.local.json**

保留核心权限，删除所有一次性 Bash 权限、filesystem/github MCP 权限。新内容：

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "permissions": {
    "allow": [
      "Read",
      "Edit",
      "Write",
      "Glob",
      "Grep",
      "Bash",
      "WebSearch",
      "WebFetch(domain:godotshaders.com)",
      "WebFetch(domain:anokolisa.itch.io)",
      "WebFetch(domain:www.youtube.com)",
      "WebFetch(domain:github.com)",
      "WebFetch(domain:forum.gamemaker.io)",
      "WebFetch(domain:forum.godotengine.org)",
      "WebFetch(domain:iknowabit.com)",
      "WebFetch(domain:critpoints.net)",
      "mcp__godot__run_project",
      "mcp__godot__get_debug_output",
      "mcp__godot__get_uid",
      "mcp__godot__update_project_uids",
      "mcp__godot__launch_editor",
      "mcp__godot__get_godot_version",
      "mcp__godot__get_project_info",
      "mcp__godot__stop_project",
      "mcp__godot__create_scene",
      "mcp__godot__add_node",
      "mcp__godot__save_scene",
      "Agent",
      "Bash(\"D:/devtool/godot/Godot_v4.6-stable_win64.exe/Godot_v4.6-stable_win64_console.exe\" --headless --import)",
      "Bash(\"D:/devtool/godot/Godot_v4.6-stable_win64.exe/Godot_v4.6-stable_win64_console.exe\" --headless --script addons/gut/gut_cmdln.gd *)"
    ],
    "deny": [
      "Bash(git rm:*)",
      "Bash(git clean:*)",
      "Bash(git reset --hard:*)"
    ],
    "ask": []
  },
  "enableAllProjectMcpServers": true,
  "enabledMcpjsonServers": [
    "godot"
  ]
}
```

- [ ] **Step 2: Commit**

```bash
git add .claude/settings.local.json
git commit -m "chore: clean up settings - remove stale bash permissions and MCP refs"
```

---

### Task 3: Memory 清理

**Files:**
- Delete: `C:/Users/ivan/.claude/projects/E--workspace-4-godot-combo-demon/memory/project_statemachine_refactor.md`
- Delete: `C:/Users/ivan/.claude/projects/E--workspace-4-godot-combo-demon/memory/reference_vscode_conpty_fix.md`
- Delete: `C:/Users/ivan/.claude/projects/E--workspace-4-godot-combo-demon/memory/reference_atlas_annotation_workflow.md`
- Delete: `C:/Users/ivan/.claude/projects/E--workspace-4-godot-combo-demon/memory/reference_tilemap_binary_format.md`
- Delete: `C:/Users/ivan/.claude/projects/E--workspace-4-godot-combo-demon/memory/reference_level3_atlas_coords.md`
- Modify: `C:/Users/ivan/.claude/projects/E--workspace-4-godot-combo-demon/memory/MEMORY.md`
- Check/migrate: feedback files from old `E--workspace-4-godot-combo_demon` path

- [ ] **Step 1: 检查旧目录下的 feedback 文件**

检查 `C:/Users/ivan/.claude/projects/E--workspace-4-godot-combo_demon/memory/` 目录是否存在，如果存在且包含 `feedback_refactoring_is_development.md` 和 `feedback_doc_update_timing.md`，将它们复制到正确的 `E--workspace-4-godot-combo-demon/memory/` 目录下。

- [ ] **Step 2: 删除过期 memory 文件**

删除以下 5 个文件：
```bash
rm "C:/Users/ivan/.claude/projects/E--workspace-4-godot-combo-demon/memory/project_statemachine_refactor.md"
rm "C:/Users/ivan/.claude/projects/E--workspace-4-godot-combo-demon/memory/reference_vscode_conpty_fix.md"
rm "C:/Users/ivan/.claude/projects/E--workspace-4-godot-combo-demon/memory/reference_atlas_annotation_workflow.md"
rm "C:/Users/ivan/.claude/projects/E--workspace-4-godot-combo-demon/memory/reference_tilemap_binary_format.md"
rm "C:/Users/ivan/.claude/projects/E--workspace-4-godot-combo-demon/memory/reference_level3_atlas_coords.md"
```

- [ ] **Step 3: 更新 MEMORY.md 索引**

新内容：

```markdown
# Combo Demon - Project Memory

## Feedback
- [Refactoring is development](feedback_refactoring_is_development.md) — refactoring/optimization must trigger feature-development skill
- [Doc updates after CR](feedback_doc_update_timing.md) — architecture docs/skills only updated after dev+test+CR all pass
- [Commit after CR](feedback_commit_after_cr.md) — don't commit incrementally; wait until all changes complete + CR passes
```

---

### Task 4: Specs/Plans 归档 + 删除 doc-organizer

**Files:**
- Create dir: `docs/superpowers/archive/`
- Move: `docs/superpowers/specs/` 和 `docs/superpowers/plans/` 下除最近的文件外，全部移到 archive
- Delete: `.claude/skills/doc-organizer.md`

- [ ] **Step 1: 创建 archive 目录并移动历史文件**

```bash
mkdir -p docs/superpowers/archive

# 移动所有非当前优化相关的 specs 和 plans 到 archive
mv docs/superpowers/specs/2026-03-23-enemy-special-skills-design.md docs/superpowers/archive/
mv docs/superpowers/specs/2026-03-25-trap-system-design.md docs/superpowers/archive/
mv docs/superpowers/specs/2026-03-25-trap-system-plan.md docs/superpowers/archive/
mv docs/superpowers/specs/2026-03-27-two-new-bosses-design.md docs/superpowers/archive/
mv docs/superpowers/plans/2026-03-27-two-new-bosses-plan.md docs/superpowers/archive/
mv docs/superpowers/specs/2026-03-28-skill-system-design.md docs/superpowers/archive/
mv docs/superpowers/plans/2026-03-28-skill-system-plan.md docs/superpowers/archive/
mv docs/superpowers/specs/2026-03-28-boss-redesign.md docs/superpowers/archive/
mv docs/superpowers/plans/2026-03-28-boss-redesign-plan.md docs/superpowers/archive/
mv docs/superpowers/specs/2026-03-29-boss-sprite-unified-design.md docs/superpowers/archive/
mv docs/superpowers/specs/2026-03-29-enemy-boss-unification-design.md docs/superpowers/archive/
mv docs/superpowers/plans/2026-03-29-enemy-boss-unification-plan.md docs/superpowers/archive/
mv docs/superpowers/specs/2026-04-02-statemachine-refactor-design.md docs/superpowers/archive/
mv docs/superpowers/plans/2026-04-02-statemachine-refactor-plan.md docs/superpowers/archive/
mv docs/superpowers/specs/2026-04-05-statemachine-bugfix-design.md docs/superpowers/archive/
mv docs/superpowers/plans/2026-04-05-statemachine-bugfix-plan.md docs/superpowers/archive/
mv docs/superpowers/specs/2026-04-05-bladekeeper-combat-redesign.md docs/superpowers/archive/
mv docs/superpowers/plans/2026-04-05-bladekeeper-combat-redesign-plan.md docs/superpowers/archive/
mv docs/superpowers/specs/2026-04-06-melee-boss-distance-and-poise-counter.md docs/superpowers/archive/
mv docs/superpowers/plans/2026-04-06-melee-boss-distance-and-poise-counter-plan.md docs/superpowers/archive/
mv docs/superpowers/specs/2026-04-06-bk-combat-decision-redesign.md docs/superpowers/archive/
mv docs/superpowers/plans/2026-04-06-bk-combat-decision-redesign-plan.md docs/superpowers/archive/
mv docs/superpowers/specs/2026-04-06-hit-state-damage-flow-design.md docs/superpowers/archive/
mv docs/superpowers/plans/2026-04-07-hit-state-damage-flow-plan.md docs/superpowers/archive/
```

保留在原位：
- `docs/superpowers/specs/2026-04-08-token-optimization-design.md`（当前）
- `docs/superpowers/plans/2026-04-08-token-optimization-plan.md`（当前）

- [ ] **Step 2: 删除 doc-organizer skill**

```bash
rm .claude/skills/doc-organizer.md
```

- [ ] **Step 3: Commit**

```bash
git add -A docs/superpowers/ .claude/skills/doc-organizer.md
git commit -m "chore: archive old specs/plans, remove doc-organizer skill"
```

---

### Task 5: CLAUDE.md 精简

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: 精简 CLAUDE.md**

替换 Architecture (Quick Reference) 段的详细内容为指针，新的完整文件内容：

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Combo Demon** — 2D action game in Godot 4.4.1 (Mobile Renderer). Core gameplay: fluid combo combat, state machine AI, multi-phase boss fights, and attack effect system.

## Development Commands

**MCP Tools** (preferred over Bash for Godot operations):
- `mcp__godot__run_project` — launch game
- `mcp__godot__get_debug_output` — read engine logs
- `mcp__godot__create_scene` / `mcp__godot__add_node` / `mcp__godot__save_scene`
- `mcp__godot__get_uid` — resolve res:// UIDs for .tscn files

**Debugging**: `DebugConfig.debug("message", "", "channel")` — channels: `state_machine`, `animation`, `combat`, `movement`

## Architecture

> 触发 `project-architecture` skill 或阅读 `docs/ARCHITECTURE.md`
> 类图 → `docs/class-diagrams.md` | 架构图 → `docs/architecture-diagrams.md`
> 编码规范 → 触发 `godot-coding-standards` skill
> 重构/优化 → 触发 `feature-development` skill

## Key Directories

| Layer | Path |
|---|---|
| Framework | `Core/StateMachine/`, `Core/Components/`, `Core/Resources/`, `Core/Effects/` |
| Services | `Core/Autoloads/` |
| Business | `Scenes/Characters/`, `Scenes/Levels/` |
| Presentation | `Assets/`, `Scenes/UI/` |

## Coding Conventions

`class_name PascalCase`, `var snake_case: Type`, `const UPPER_SNAKE`, `func snake_case() -> Type`。`@export` 配置化，懒缓存 `get_tree()` 查询。详见 `godot-coding-standards` skill。
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "chore: slim down CLAUDE.md - replace inline architecture with skill pointers"
```

---

### Task 6: Docs 重组

**Files:**
- Move: `docs/ai-friendliness.md` → `.claude/skills/project-architecture/references/ai-friendliness.md`
- Move: `docs/onboarding-guide.md` → `.claude/skills/project-architecture/references/onboarding-guide.md`
- Move: `docs/resource-management.md` → `.claude/skills/project-architecture/references/resource-management.md`
- Move: `docs/risk-and-tech-debt.md` → `.claude/skills/project-architecture/references/risk-and-tech-debt.md`
- Move: `docs/生成项目 AI Skills 与架构文档.md` → `.claude/meta-prompts/generate-skills-and-docs.md`
- Move: `docs/META-PROMPT-GENERATE-SKILLS-AND-DOCS.md` → `.claude/meta-prompts/META-PROMPT-GENERATE-SKILLS-AND-DOCS.md`

- [ ] **Step 1: 移动 AI 辅助文档到 skill references**

```bash
mv docs/ai-friendliness.md .claude/skills/project-architecture/references/ai-friendliness.md
mv docs/onboarding-guide.md .claude/skills/project-architecture/references/onboarding-guide.md
mv docs/resource-management.md .claude/skills/project-architecture/references/resource-management.md
mv docs/risk-and-tech-debt.md .claude/skills/project-architecture/references/risk-and-tech-debt.md
```

- [ ] **Step 2: 移动元提示文件到 .claude/**

```bash
mkdir -p .claude/meta-prompts
mv "docs/生成项目 AI Skills 与架构文档.md" ".claude/meta-prompts/generate-skills-and-docs-zh.md"
mv docs/META-PROMPT-GENERATE-SKILLS-AND-DOCS.md .claude/meta-prompts/META-PROMPT-GENERATE-SKILLS-AND-DOCS.md
```

- [ ] **Step 3: Commit**

```bash
git add -A docs/ .claude/skills/project-architecture/references/ .claude/meta-prompts/
git commit -m "chore: reorganize docs - move AI-assist docs to skill refs, meta-prompts to .claude/"
```

---

### Task 7: Skill SKILL.md 瘦身重构

这是核心任务，逐个 skill 重构 SKILL.md 为精简版（触发条件+核心流程+路由表）。

**Files:**
- Modify: `.claude/skills/feature-development/SKILL.md`
- Modify: `.claude/skills/project-architecture/SKILL.md`
- Modify: `.claude/skills/testing/SKILL.md`
- Modify: `.claude/skills/troubleshooting/SKILL.md`
- Modify: `.claude/skills/godot-level-design/SKILL.md`
- Modify: `.claude/skills/godot-coding-standards/SKILL.md`
- Modify: `.claude/skills/code-review/SKILL.md`
- Modify: `.claude/skills/context-updater/SKILL.md`

#### 7a: feature-development (6.1KB → ~2KB)

- [ ] **Step 1: 重写 feature-development/SKILL.md**

```markdown
---
name: feature-development
description: "General-purpose development skill for Combo Demon. Use when implementing new features, refactoring, or optimizing: enemies, bosses, attack effects, components, traps, gameplay systems, architecture adjustments, code cleanup, or performance optimization. Triggers on: new enemy, new boss, new effect, new component, new trap, new feature, implement, develop, create, add, refactor, optimize, split, decouple, migrate, restructure, cleanup, 重构, 优化, 拆分, 解耦, 迁移, 架构调整, 代码清理."
---

# 通用功能开发指南

## 需求路由

根据任务类型，Read 对应 reference 后按流程执行：

| 需求类型 | 关键词 | 读取 reference |
|---------|-------|---------------|
| 敌人 | enemy, 怪物, mob | `references/enemy-guide.md` |
| Boss | boss, 首领 | `references/boss-guide.md` |
| 攻击效果 | effect, 击退, 眩晕, 伤害 | `references/effect-guide.md` |
| 组件/系统 | component, 系统 | `references/component-guide.md` |
| 陷阱 | trap, 机关, 障碍 | `references/trap-guide.md` |
| 重构/优化 | refactor, optimize, cleanup | `references/refactoring-guide.md` |
| 关卡 | level, 地图 | 触发 `godot-level-design` skill |
| 其他 | — | 触发 `project-architecture` skill 定位架构层 |

跨多类型时依次加载相关 reference。

## 开发流程

1. **架构定位** — 触发 `project-architecture` skill，确认涉及层/目录/基类
2. **加载指南** — Read 对应 reference，获取模板/信号/Resource
3. **实现** — 继承基类只重写钩子、信号解耦、@export 配置化、懒缓存
4. **验证** — 触发 `testing` skill
5. **CR** — 触发 `code-review` skill
6. **提交** — CR 通过后统一 commit（禁止边开发边提交）
7. **文档更新** — 触发 `context-updater` skill

重构流程同上，Step 1 额外做影响范围分析（grep 所有引用点）。

## 检查清单

- [ ] 文件在正确架构层目录
- [ ] 遵循 `godot-coding-standards`
- [ ] 状态继承 BaseState，exit() 断开信号+停止 Timer
- [ ] `is_instance_valid()` + 懒缓存
- [ ] 重构：所有引用点已更新，.tscn 节点引用正确
```

- [ ] **Step 2: 验证精简后文件大小 < 2KB**

```bash
wc -c .claude/skills/feature-development/SKILL.md
```

Expected: < 2048 bytes

#### 7b: project-architecture (4.6KB → ~1.5KB)

- [ ] **Step 3: 重写 project-architecture/SKILL.md**

```markdown
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
```

- [ ] **Step 4: 验证大小 < 1.5KB**

```bash
wc -c .claude/skills/project-architecture/SKILL.md
```

#### 7c: testing (3.7KB → ~1.5KB)

- [ ] **Step 5: 重写 testing/SKILL.md**

```markdown
---
name: testing
description: "Functional testing and verification for Combo Demon. Use after feature development to validate with GUT unit tests, debug logs, and MCP runtime verification. Triggers on: test, verify, validate, check, unit test, GUT, testing, verification."
---

# 功能验证指南

## 三层验证流程（按顺序）

### Layer 1: 日志断言
1. 添加 `DebugConfig.debug()` 到关键代码路径
2. `mcp__godot__run_project` → 触发场景 → `mcp__godot__get_debug_output`
3. 确认关键日志存在、无 ERROR

### Layer 2: GUT 单元测试
运行: `godot --headless -s addons/gut/gut_cmdline.gd -gdir=res://test/unit -gexit`

测试文件: `test/unit/test_模块名.gd`，方法命名: `test_功能_场景_预期结果`

### Layer 3: MCP 集成验证
`mcp__godot__run_project` → 等待加载 → `mcp__godot__get_debug_output` → 确认无运行时错误 → `mcp__godot__stop_project`

## 按需加载

需要 GUT 测试代码模板和最佳实践 → Read `references/gut-patterns.md`
```

- [ ] **Step 6: 验证大小 < 1.5KB**

#### 7d: troubleshooting (3.4KB → ~1.5KB)

- [ ] **Step 7: 重写 troubleshooting/SKILL.md**

```markdown
---
name: troubleshooting
description: "Debug and troubleshoot Combo Demon issues. Use when encountering bugs, errors, unexpected behavior, state machine freezes, damage not triggering, animation glitches, or any runtime problem. Triggers on: bug, error, fix, debug, not working, broken, stuck, crash, freeze, issue, problem, troubleshoot."
---

# 问题排查指南

## 分层定位

| 现象 | 首先检查 | 日志通道 |
|------|---------|---------|
| 动画不播放 | BaseState helper, .tscn BlendTree | `animation` |
| 伤害不触发 | HealthComponent, HitBoxComponent | `combat` |
| 状态卡死 | BaseStateMachine, BaseState | `state_machine` |
| 敌人不追踪 | EnemyBase, ChaseState | `state_machine` |
| Boss 阶段不转换 | BossBase, health_changed | `combat` |

## 排查流程

1. **开启日志** — 确认 `debug_config.json` 对应通道 enabled
2. **添加临时日志** — `DebugConfig.debug("变量: %s" % var, "", "channel")`
3. **MCP 运行** — run_project → 触发场景 → get_debug_output → 分析 → stop_project
4. **数据流验证** — 沿链路逐节点检查（碰撞层/信号连接/is_instance_valid/优先级）

## 按需加载

具体问题速查步骤 → Read `references/common-issues.md`
```

#### 7e: godot-level-design (14.3KB → ~2KB)

- [ ] **Step 8: 重写 godot-level-design/SKILL.md**

```markdown
---
name: godot-level-design
description: "Production-grade Godot 4 level design skill for 2D Platformer games. Use when designing, generating, documenting, or reviewing game levels — including tilemap layout, enemy placement, encounter design, screenshot-to-level reconstruction. Triggers on: level, tilemap, encounter, checkpoint, screenshot to level."
---

# Godot 4 — 2D Platformer Level Design

## 两种模式

- **Mode A (从零设计)**: 明确上下文 → 空间布局 → 遭遇设计 → 技术规格 → 产出
- **Mode B (截图转关卡)**: 视觉分析 → 资产清单 → 坐标映射 → 代码生成 → 验证

## 按需加载

根据任务阶段 Read 对应 reference：

| 场景 | 读取文件 |
|------|---------|
| 截图/参考图提供时（**必读**） | `references/screenshot-to-level.md` |
| 空间布局、宏观结构、高低差 | `references/spatial-design.md` |
| 敌人配置、节奏、战斗房间 | `references/encounter-design.md` |
| TileMapLayer API、地形、自动贴图 | `references/tilemap-implementation.md` |
| 场景树、节点命名、export 变量 | `references/scene-architecture.md` |
| 魂系/银河城垂直设计、快捷路线 | `references/souls-platformer-patterns.md` |

## 核心原则速查

- 先输出 level skeleton（YAML），确认后再转 tile
- 节奏组: REST → CHALLENGE → REWARD → REST（3+ CHALLENGE 后必须 REST ≥ 4 tiles）
- 场景树: Level.tscn → World → TileMapLayer_Background/Terrain/Foreground + Encounters + Hazards
- 每个 TileMapLayer 单一用途（bg/terrain/fg），物理碰撞只在 terrain 层
- 验证报告必须含实际数值，不只 pass/fail
```

#### 7f: godot-coding-standards (8.9KB → ~3.5KB)

- [ ] **Step 9: 重写 godot-coding-standards/SKILL.md**

```markdown
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
```

#### 7g: code-review (3.5KB → ~2.5KB)

- [ ] **Step 10: 重写 code-review/SKILL.md**

```markdown
---
name: code-review
description: "Code review for Combo Demon changes. Use after feature development and testing are complete, to review changed code for architecture compliance, coding standards, safety, and performance. Triggers on: code review, CR, review code, check code."
---

# 代码审查指南

## 流程

### Step 1: 收集变更
`git diff --name-only` + `git diff --stat` + `git diff`，按架构层归类（Framework > Services > Business > Presentation）。

### Step 2: 逐层审查

**架构合规**: 文件在正确层目录、无跨层直接调用、依赖方向正确

**编码规范**: 命名规范+类型注解、@export 配置化、信号通信、状态继承 BaseState 用 helper、exit() 断开信号+停 Timer
> 详细 → `godot-coding-standards` skill

**安全性**: `is_instance_valid()` 动态引用、懒缓存、await 后检查有效性、物理层/group 正确

**性能**: _process 无重复查询、preload 替代 load、对象池高频创建、热路径无临时对象

### Step 3: 输出报告

| 级别 | 含义 | 处理 |
|------|------|------|
| **P0** | bug/安全/架构违规 | 必须修，修后重新 testing |
| **P1** | 不符规范但不影响功能 | 用户决定 |
| **P2** | 可优化 | 记录 |
```

#### 7h: context-updater (5.5KB → ~2.5KB)

- [ ] **Step 11: 重写 context-updater/SKILL.md**

```markdown
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
```

- [ ] **Step 12: Commit all skill rewrites**

```bash
git add .claude/skills/*/SKILL.md
git commit -m "chore: slim all skills to lazy-load architecture - route tables + on-demand Read"
```

---

### Task 8: Reference 大文件压缩

**Files:**
- Modify: `.claude/skills/project-architecture/references/module-registry.md` (22.5KB → ~8KB)
- Modify: `.claude/skills/project-architecture/references/scene-templates.md` (21.1KB → ~8KB)
- Modify: `.claude/skills/godot-level-design/references/screenshot-to-level.md` (19.1KB → ~8KB)
- Modify: `.claude/skills/testing/references/gut-patterns.md` (12.7KB → ~6KB)

- [ ] **Step 1: 压缩 module-registry.md**

当前是完整模块注册表（22.5KB），包含每个类的详细 API 列表。压缩策略：
- 保留类名 → 路径 → 一行职责的索引表
- 删除详细的 API 方法列表（可直接读代码获得）
- 保留继承关系和关键依赖

Read 当前文件，提取索引信息，压缩后写回。目标 ≤ 8KB。

- [ ] **Step 2: 压缩 scene-templates.md**

当前包含完整场景树和节点详情（21.1KB）。压缩策略：
- 保留场景名 → 路径 → 核心节点结构（缩进树，不超过 2 层深度）
- 删除详细的节点属性说明
- 保留 AnimationTree BlendTree 统一结构说明

Read 当前文件，压缩后写回。目标 ≤ 8KB。

- [ ] **Step 3: 压缩 screenshot-to-level.md**

当前是截图转关卡完整流水线（19.1KB）。压缩策略：
- 保留 5 阶段流水线结构和每阶段核心步骤
- 删除冗长的代码示例，只保留关键 API 调用模式
- 压缩 asset mapping 表格

Read 当前文件，压缩后写回。目标 ≤ 8KB。

- [ ] **Step 4: 压缩 gut-patterns.md**

当前是详细的 GUT 测试模式（12.7KB）。压缩策略：
- 保留常用测试模式的简短代码片段
- 删除重复的解释文字
- 合并相似的模式

Read 当前文件，压缩后写回。目标 ≤ 6KB。

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/*/references/*.md
git commit -m "chore: compress large reference files for token efficiency"
```

---

### Task 9: 最终验证

- [ ] **Step 1: 验证所有 skill 文件大小**

```bash
for f in .claude/skills/*/SKILL.md; do echo "$(wc -c < "$f") $f"; done
```

Expected: 所有 SKILL.md ≤ 对应目标大小。

- [ ] **Step 2: 验证所有 reference 文件大小**

```bash
for f in .claude/skills/*/references/*.md; do echo "$(wc -c < "$f") $f"; done
```

Expected: 四个压缩目标文件 ≤ 8KB/6KB。

- [ ] **Step 3: 验证 .mcp.json 和 settings 正确**

```bash
cat .mcp.json
cat .claude/settings.local.json
```

确认只有 godot server，权限列表干净。

- [ ] **Step 4: 验证 docs/ 目录结构**

```bash
ls docs/
ls docs/superpowers/specs/
ls docs/superpowers/plans/
ls docs/superpowers/archive/ | wc -l
```

Expected: docs/ 下只有 ARCHITECTURE.md, class-diagrams.md, architecture-diagrams.md + superpowers/。archive/ 有 24 个文件。

- [ ] **Step 5: 最终 commit（如有遗漏修复）**

```bash
git status
# 如有未提交的修复，统一 commit
```
