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

> **正文在 wiki 中, 本地 `docs/` 仅指针 stub。**
> 项目架构 → wiki `[[architecture]]` (`E:\workspace\knowledge-wiki\wiki\projects\combo-demon\architecture.md`)
> 类图 → wiki `wiki/sources/combo-demon-class-diagrams.md`
> 架构图 / 数据流 → wiki `[[damage-flow]]`、`wiki/projects/combo-demon/`
> 触发 `project-architecture` skill 或读 `docs/ARCHITECTURE.md` 拿到 wiki 跳转
> 编码规范 → 触发 `godot-coding-standards` skill
> 重构/优化 → 触发 `feature-development` skill

## Key Directories

| Layer | Path |
|---|---|
| Framework | `Core/AI/`, `Core/Damage/`, `Core/Buffs/`, `Core/Animation/`, `Core/Components/`, `Core/Resources/`, `Core/Effects/` |
| Services | `Core/Autoloads/` |
| Business | `Scenes/Characters/`, `Scenes/Levels/` |
| Presentation | `Assets/`, `Scenes/UI/` |

## Coding Conventions

`class_name PascalCase`, `var snake_case: Type`, `const UPPER_SNAKE`, `func snake_case() -> Type`。`@export` 配置化，懒缓存 `get_tree()` 查询。详见 `godot-coding-standards` skill。

## Wiki Knowledge Base

Path: `E:\workspace\knowledge-wiki\` (git repo: `knowledge-wiki`)

### 写作规则 (2026-05-02 起)

**写新方案 / 架构图 / 数据流程图 / 设计文档时, 直接写入 wiki**, 不再先写本地 `docs/` 再同步。
- 项目专属 → `wiki/projects/combo-demon/<topic>.md`
- 通用 Godot / 设计模式 → `wiki/domains/<domain>/<concept>.md`
- 双向 wikilink 关联两侧
- 本地 `docs/` 仅保留 1-3 行 pointer stub (标题 + wikilink)
- 例外: `Todo.md`、`CLAUDE.md`、`.claude/`、运行时配置仍在本地

### 阅读规则

需要项目以外的通用知识（Godot / 游戏设计 / 通用编程模式）时, 按顺序读取:
1. `wiki/hot.md` (最近上下文, ~500 字)
2. `wiki/index.md` (主目录, 若 hot.md 不够)
3. `wiki/domains/<domain>/_index.md` (领域分类)
4. 具体页面 (最后再读)

需要项目内架构 / 流程信息时, 直接读 `wiki/projects/combo-demon/`。本地 `docs/*.md` 是指针, 看到指针后跳到 wiki 读正文。

**不要**为以下情况查 wiki:
- 通用编程语法 / 语言问题
- 已经在本项目文件或对话上下文里的内容
- 与 Godot / 游戏设计 / 工具链无关的任务
