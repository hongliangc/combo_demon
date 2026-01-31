# Claude Code 会话启动配置详解

**更新时间**: 2026-01-18
**用途**: 说明 Claude Code 会话启动时自动加载的所有配置及其作用

---

## 一、启动流程概览

Claude Code 会话启动时按以下顺序加载配置：

```
启动命令 (claude)
    ↓ ~50-100ms
1. Settings 配置加载
    ↓ ~100-200ms
2. Memory 上下文加载
    ↓ ~200-500ms
3. Skills 技能加载
    ↓ ~500-2000ms
4. MCP 服务器初始化
    ↓
✅ 会话就绪 (总计 1-3秒)
```

---

## 二、当前已生效的配置详解

### 1. Settings 配置

**文件位置**: `.claude/settings.local.json`

#### 1.1 权限配置 (Permissions)

**作用**: 预授权常用的Bash命令，避免每次执行时都需要用户确认。

**已生效的权限**:
```json
{
  "allow": [
    "Bash(choco --version:*)",      // Chocolatey 包管理器版本检查
    "Bash(bash:*)",                  // Bash shell 命令执行（通配符）
    "Bash(cat:*)",                   // 查看文件内容
    "Bash(mkdir:*)",                 // 创建目录
    "Bash(godot --headless --script-check:*)", // Godot 脚本语法检查
    "Bash(ls:*)",                    // 列出目录内容
    "Bash(ping:*)",                  // 网络连接测试
    "Bash(timeout /t 10 /nobreak)",  // Windows 暂停命令
    "Bash(powershell:*)",            // PowerShell 命令执行
    "Bash(tree:*)"                   // 树形显示目录结构
  ]
}
```

**优点**:
- 加快常用命令执行速度
- 减少用户交互次数
- 安全范围内的命令无需确认

#### 1.2 MCP 服务器启用配置

**作用**: 启用项目级别的 MCP (Model Context Protocol) 服务器，扩展 Claude 的工具能力。

**已生效配置**:
```json
{
  "enableAllProjectMcpServers": true,  // 自动启用所有项目 MCP 服务器
  "enabledMcpjsonServers": [           // 白名单明确启用的服务器
    "filesystem",
    "github",
    "godot"
  ]
}
```

---

### 2. Memory 上下文配置

**文件位置**: `.claude/context/project_context.md`

**作用**: 自动加载项目架构和核心信息，让 Claude 在会话开始时就了解项目背景。

**文件大小**: 7.8 KB / 242 行 (~3000 tokens，已优化)

**包含内容**:

#### 2.1 项目概述
- 项目名称: Combo Demon
- 类型: 2D 动作游戏
- 引擎版本: Godot 4.4.1
- 核心玩法: 连招系统 + Boss战

#### 2.2 架构信息
- **AutoLoad 自动加载系统**
  - DebugConfig: 调试配置管理
  - EventManager: 全局事件总线
  - GameManager: 游戏状态管理

- **核心模块**
  - 状态机系统 (StateMachine)
  - 伤害系统 (Damage)
  - 技能书系统 (SkillBook)
  - UI 系统
  - 输入系统

#### 2.3 关键配置
- 输入映射 (Input Map)
- 物理层设置 (Physics Layers)
- 文件组织规范

#### 2.4 设计原则
- 通用性、模块化、可复用性、简洁实用
- 组件化思维
- 信号解耦

**优化历史**:
- 原始大小: ~15000 tokens
- 优化后: ~3000 tokens
- 减少: 80%
- 方法: 移除冗余内容，使用结构化格式

---

### 3. Skills 技能配置

#### 3.1 Godot 编码规范 (godot-coding-standards)

**文件位置**: `.claude/skills/godot-coding-standards/`

**作用**: 为 Claude 提供 Godot 开发的核心架构原则和最佳实践。

**触发条件**: 当对话中出现以下关键词时自动激活
- godot
- 组件
- 信号
- 架构
- 设计

**Skill 内容** (已简化):

##### 核心设计原则
1. **通用性优先** - `@export` 配置化，避免硬编码
2. **模块化设计** - 单一职责，组件模式，信号解耦
3. **可复用性** - Resource 类，清晰接口，独立性
4. **简洁实用** - 避免过度设计，代码自解释

##### 组件模式示例
- 基础组件模板（Health 组件）
- Resource 数据类（Damage）

##### 架构检查要点
- 通用性、模块化、可复用性、简洁性检查

**文件大小**: ~800 tokens（简化后，减少 60%）

**简化历史**:
- **2026-01-18 简化**: 删除详细编码规范，只保留核心架构原则
- 删除文件: REFERENCE.md, CHECKLIST.md
- 保留文件: SKILL.md

#### 3.2 项目上下文更新器 (context-updater)

**文件位置**: `.claude/skills/context-updater/`

**作用**: 当新增功能、重构代码、修改架构时，自动提醒更新 `project_context.md`，确保项目文档与代码保持同步。

**触发条件**: 当对话中出现以下关键词或场景时自动激活
- 新功能、重构、架构变更、新模块、新系统、完成实现

**核心功能**:
- 触发判断（区分需要/不需要更新的场景）
- 更新原则（简洁、结构化、架构级别、< 4000 tokens）
- 更新示例（AutoLoad、核心系统）
- 自动检查清单（5项关键检查点）
- 提醒机制（检测文件变更和关键词）

**文件大小**: ~550 tokens（优化后，减少 60%）

**创建时间**: 2026-01-18
**最后优化**: 2026-01-18 - 精简示例和流程说明，从 1400 → 550 tokens

---

### 4. MCP 服务器配置

**文件位置**: `.mcp.json`

**作用**: 配置 MCP 服务器，为 Claude 提供增强的工具能力。

#### 4.1 Filesystem 服务器

**功能**: 文件系统操作工具

**配置**:
```json
{
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-filesystem"],
  "允许访问的目录": [
    "Art/",      // 美术资源
    "Scenes/",   // 场景文件
    "Util/"      // 工具类和组件
  ]
}
```

**提供的工具**:
- `mcp__filesystem__read_text_file` - 读取文本文件
- `mcp__filesystem__write_file` - 写入文件
- `mcp__filesystem__edit_file` - 编辑文件
- `mcp__filesystem__create_directory` - 创建目录
- `mcp__filesystem__list_directory` - 列出目录
- `mcp__filesystem__search_files` - 搜索文件
- `mcp__filesystem__get_file_info` - 获取文件信息
- 更多...

**安全机制**: 只能访问指定的 3 个目录

#### 4.2 GitHub 服务器

**功能**: GitHub API 集成工具

**配置**:
```json
{
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-github"],
  "env": {
    "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
  }
}
```

**提供的工具**:
- `mcp__github__create_or_update_file` - 创建/更新文件
- `mcp__github__create_issue` - 创建 Issue
- `mcp__github__create_pull_request` - 创建 PR
- `mcp__github__get_file_contents` - 获取文件内容
- `mcp__github__search_repositories` - 搜索仓库
- `mcp__github__list_commits` - 列出提交
- 更多...

**认证**: 使用环境变量 `GITHUB_TOKEN`

#### 4.3 Godot 服务器

**功能**: Godot 编辑器集成工具

**配置**:
```json
{
  "command": "node",
  "args": ["C:\\Users\\ivan\\AppData\\Roaming\\npm\\node_modules\\godot-mcp\\build\\index.js"],
  "env": {
    "GODOT_PATH": "D:\\devtool\\godot\\Godot_v4.4.1-stable_win64.exe\\Godot_v4.4.1-stable_win64.exe"
  },
  "disabled": false
}
```

**提供的工具** (全部已自动授权):
- `mcp__godot__launch_editor` - 启动 Godot 编辑器
- `mcp__godot__run_project` - 运行项目
- `mcp__godot__get_debug_output` - 获取调试输出
- `mcp__godot__stop_project` - 停止项目
- `mcp__godot__get_godot_version` - 获取版本信息
- `mcp__godot__list_projects` - 列出项目
- `mcp__godot__get_project_info` - 获取项目信息
- `mcp__godot__create_scene` - 创建场景
- `mcp__godot__add_node` - 添加节点
- `mcp__godot__load_sprite` - 加载精灵
- `mcp__godot__export_mesh_library` - 导出网格库
- `mcp__godot__save_scene` - 保存场景
- `mcp__godot__get_uid` - 获取 UID
- `mcp__godot__update_project_uids` - 更新 UID

**自动授权**: 所有 Godot 工具都在 `autoApprove` 列表中，无需确认

**Godot 路径**: `D:\devtool\godot\Godot_v4.4.1-stable_win64.exe`

---

### 5. Git 状态自动加载

**作用**: 会话启动时自动加载当前 Git 仓库状态

**加载内容**:
- 当前分支: `main`
- 主分支: (空，通常 PR 会用到)
- 文件改动状态 (M=修改, A=新增, ??=未跟踪)
- 最近 5 条 commit 记录

**示例输出** (启动时可见):
```
Current branch: main
Status:
M  Scenes/charaters/animation_hander.gd
MM Scenes/charaters/hahashin.gd
A  Util/Classes/ForceStunEffect.gd

Recent commits:
cf760c4 优化claude code配置，精简启动加载内容
06aac3d add boss battle
```

---

## 三、配置文件汇总

| 配置类型 | 文件路径 | 大小 | Token | 加载时机 | 作用 |
|---------|---------|------|-------|---------|------|
| **Settings** | `.claude/settings.local.json` | 0.5 KB | - | 启动时 | 权限、MCP启用 |
| **Memory** | `.claude/context/project_context.md` | 7.8 KB | ~3000 | 启动时 | 项目架构上下文 |
| **Skill 1** | `.claude/skills/godot-coding-standards/` | 2.5 KB | ~800 | 启动时 | Godot架构原则 |
| **Skill 2** | `.claude/skills/context-updater/` | 2.1 KB | ~550 | 启动时 | 自动更新context |
| **MCP** | `.mcp.json` | 1.2 KB | - | 启动时 | MCP服务器配置 |
| **Git** | (自动检测) | - | - | 启动时 | 仓库状态 |

**总 Token 消耗**: ~4350 tokens (已优化)

---

## 四、不会自动加载的内容

以下内容**不会**在启动时自动加载，需要手动引用或使用工具访问：

❌ `dev_log/` 目录下的历史日志
❌ `README.md` 或根目录其他文档（除非在 CLAUDE.md 中 import）
❌ 编辑器当前打开的文件（仅在对话中提及时加载）
❌ `.claude/SKILLS_GUIDE.md` (使用指南，非自动加载)
❌ Git 历史详细信息（除非使用 git 命令）

---

## 五、优化建议

### 已完成的优化 ✅

1. **Context 精简** - 从 15000 tokens → 3000 tokens (减少 80%)
2. **Godot Skill 简化** - 从 2000 tokens → 800 tokens (减少 60%)
3. **Context-updater 优化** - 从 1400 tokens → 550 tokens (减少 60%)
4. **MCP 配置优化** - 使用白名单明确启用的服务器
5. **自动授权** - Godot 工具全部预授权，减少交互
6. **自动化文档更新** - context-updater skill 确保项目文档同步

**总优化效果**: 启动 token 从 ~16000 降至 ~4350 (减少 73%)

### 可进一步优化

1. **SessionStart Hook** (未配置)
   - 可在启动时执行自定义脚本
   - 注入额外 context 或环境变量

2. **路径特定规则** (未充分利用)
   - 可为不同路径配置不同规则
   - 例如: `Scenes/**/*.gd` 使用特定规范

3. **Enterprise Memory** (未配置)
   - 组织级别的共享规范
   - 需要 `/etc/claude-code/CLAUDE.md`

---

## 六、调试和验证

### 查看加载的配置

在 Claude Code 会话中运行:
```
/memory
```

显示所有加载的 Memory 文件和优先级。

### 调试启动过程

使用调试模式启动:
```bash
claude --debug
```

显示详细的启动日志，包括:
- Settings 加载顺序
- Memory 文件发现过程
- Skills 注册
- MCP 连接状态

---

## 七、配置优先级

当多个配置文件存在时，加载优先级为（从高到低）:

```
1. Managed Settings    (系统级，通常在 ~/Library/Application Support/)
2. Command-line Args   (claude --flag value)
3. Local Settings      (.claude/settings.local.json) ⬅️ 当前使用
4. Project Settings    (.claude/settings.json)
5. User Settings       (~/.claude/settings.json)
```

**当前项目**: 主要使用 `.claude/settings.local.json`（优先级3）

---

## 八、总结

Claude Code 会话启动时自动加载了以下配置：

1. ✅ **预授权 10 个常用 Bash 命令**
2. ✅ **启用 3 个 MCP 服务器**（filesystem, github, godot）
3. ✅ **加载项目架构 context**（~3000 tokens）
4. ✅ **加载 Godot 架构原则 skill**（~800 tokens）
5. ✅ **加载项目上下文更新器 skill**（~550 tokens）
6. ✅ **自动加载 Git 仓库状态**

**总启动时间**: 1-3 秒
**总 Token 消耗**: ~4350 tokens（已优化）
**配置状态**: ✅ 生产就绪，已优化

**最近更新**:
- 2026-01-18: 新增 context-updater skill
- 2026-01-18: 优化 context-updater，从 1400 → 550 tokens（减少 60%）

---

**维护说明**:
- 定期检查 `.claude/context/project_context.md`，保持同步
- 当架构发生重大变化时，更新 context 文件
- 新增重要 MCP 服务器时，添加到 `enabledMcpjsonServers`
- Skill 保持简洁，只保留核心原则
