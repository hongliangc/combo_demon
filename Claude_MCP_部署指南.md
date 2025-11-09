# Claude Code MCP 部署与配置指南

## 目录
- [前置准备](#前置准备)
- [安装 Claude Code CLI](#安装-claude-code-cli)
- [配置 MCP 服务器](#配置-mcp-服务器)
- [测试 MCP 服务](#测试-mcp-服务)
- [常见问题解决](#常见问题解决)

---

## 前置准备

### 必需环境
- **Node.js** (推荐 v18+)
- **npm/npx** (随 Node.js 安装)
- **Git for Windows** (Windows 用户必需)

### 验证环境
```bash
# 检查 Node.js
node --version

# 检查 npm/npx
npx --version

# 检查 Git Bash (Windows)
where bash.exe
```

---

## 安装 Claude Code CLI

### 方法 1: 通过 npm 全局安装
```bash
npm install -g @anthropic-ai/claude-cli
```

### 方法 2: 使用已下载的版本
如果 Claude Code 已下载到缓存目录（如 `C:\Users\<用户名>\.cache\claude\staging\2.0.36`）：

1. 添加到系统 PATH 环境变量
2. 或使用完整路径运行

### Windows 用户特别设置
设置 Git Bash 路径环境变量：
```bash
# PowerShell
$env:CLAUDE_CODE_GIT_BASH_PATH="D:\devtool\Git\usr\bin\bash.exe"

# 或在系统环境变量中永久设置
# CLAUDE_CODE_GIT_BASH_PATH=D:\devtool\Git\usr\bin\bash.exe
```

### 验证安装
```bash
claude --version
```

---

## 配置 MCP 服务器

### MCP 配置文件位置

#### 1. 全局用户配置
- **位置：** `~/.claude.json` (Windows: `C:\Users\<用户名>\.claude.json`)
- **作用范围：** 所有项目
- **适用场景：** 个人常用的 MCP 服务（如个人 GitHub 账号）

#### 2. 项目级配置
- **位置：** `<项目根目录>/.mcp.json`
- **作用范围：** 当前项目
- **适用场景：** 团队共享、项目特定的 MCP 服务
- **优势：** 可提交到 Git，团队成员共享配置

### 配置文件结构

`.mcp.json` 示例：
```json
{
  "mcpServers": {
    "服务名称": {
      "command": "命令",
      "args": ["参数1", "参数2"],
      "env": {
        "环境变量名": "值或${系统环境变量}"
      },
      "disabled": false,
      "autoApprove": ["工具名1", "工具名2"]
    }
  }
}
```

---

## 添加 MCP 服务

### 1. GitHub MCP Server

#### 获取 GitHub Personal Access Token (PAT)
1. 访问：https://github.com/settings/tokens/new
2. 配置：
   - **Note:** Claude MCP GitHub Integration
   - **Expiration:** 90 天或自定义
   - **Scopes:**
     - ✅ `repo` (完整仓库控制权限)
     - ✅ `read:org` (可选，读取组织信息)
3. 点击 "Generate token"
4. **立即复制** token（格式：`ghp_xxxxxxxxxxxx`）

#### 设置环境变量
```bash
# Windows PowerShell (临时)
$env:GITHUB_TOKEN="ghp_your_token_here"

# Windows CMD (永久 - 系统环境变量)
setx GITHUB_TOKEN "ghp_your_token_here"

# Linux/Mac
export GITHUB_TOKEN="ghp_your_token_here"
# 添加到 ~/.bashrc 或 ~/.zshrc 以永久保存
```

#### 配置 GitHub MCP
在 `.mcp.json` 中添加：
```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-github"
      ],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

### 2. Filesystem MCP Server

用于访问项目特定目录：
```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "e:\\workspace\\4.godot\\combo_demon\\Art",
        "e:\\workspace\\4.godot\\combo_demon\\Scenes",
        "e:\\workspace\\4.godot\\combo_demon\\Util"
      ],
      "env": {}
    }
  }
}
```

### 3. Godot MCP Server

Godot MCP 提供了与 Godot 游戏引擎的集成，支持启动编辑器、运行项目、获取调试输出、场景管理等功能。

**项目信息：**
- **npm 包：** `godot-mcp` (推荐使用)
- **GitHub 仓库 (npm版)：** https://github.com/craigsteyn/godot-mcp
- **GitHub 仓库 (开发版)：** https://github.com/Coding-Solo/godot-mcp
- **许可：** MIT License

#### 方式 1: 使用 npx（推荐 - 简单快速）

**优点：**
- ✅ 配置简单，无需手动构建
- ✅ 自动下载和更新
- ✅ 团队共享配置一致
- ✅ 跨平台路径统一

**步骤 1: 查找 Godot 可执行文件路径**

```bash
# Windows
where godot
# 或手动查找，例如：
# D:\devtool\godot\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe

# Linux
which godot
# 例如：/usr/bin/godot

# Mac
which godot
# 例如：/Applications/Godot.app/Contents/MacOS/Godot
```

**步骤 2: 在 `.mcp.json` 中添加配置**

```json
{
  "mcpServers": {
    "godot": {
      "command": "npx",
      "args": ["-y", "godot-mcp"],
      "env": {
        "GODOT_PATH": "D:\\devtool\\godot\\Godot_v4.4.1-stable_win64.exe\\Godot_v4.4.1-stable_win64.exe"
      },
      "disabled": false,
      "autoApprove": [
        "launch_editor",
        "run_project",
        "get_debug_output",
        "stop_project"
      ]
    }
  }
}
```

**步骤 3: 测试连接**

```bash
claude mcp list
# 应该看到: godot: npx -y godot-mcp - ✓ Connected
```

---

#### 方式 2: 本地构建（开发者/高级用户）

**适用场景：**
- 🔧 需要修改 MCP 源代码
- 🔧 需要使用 GitHub 最新开发版本
- 🔧 离线环境或内网部署

**优点：**
- ✅ 可以自定义和调试源码
- ✅ 使用最新未发布的功能
- ✅ 离线可用

**缺点：**
- ❌ 配置复杂（需要绝对路径）
- ❌ 每台机器路径不同
- ❌ 需要手动更新

**步骤 1: 克隆仓库**

```bash
# Windows 示例
cd C:\Users\ivan
mkdir .mcp
cd .mcp
git clone https://github.com/Coding-Solo/godot-mcp.git
cd godot-mcp

# Linux/Mac 示例
cd ~
mkdir -p .mcp
cd .mcp
git clone https://github.com/Coding-Solo/godot-mcp.git
cd godot-mcp
```

**步骤 2: 安装依赖**

```bash
npm install
```

**步骤 3: 构建项目**

```bash
npm run build
```

这会将 TypeScript 源代码编译为 JavaScript，输出到 `build/` 目录。

**步骤 4: 验证构建**

```bash
# 检查构建产物
ls build/index.js  # Linux/Mac
dir build\index.js  # Windows

# 应该看到 build/index.js 文件
```

**步骤 5: 在 `.mcp.json` 中添加配置**

```json
{
  "mcpServers": {
    "godot": {
      "command": "node",
      "args": [
        "C:\\Users\\ivan\\.mcp\\godot-mcp\\build\\index.js"  // Windows
        // Linux/Mac: "/home/username/.mcp/godot-mcp/build/index.js"
      ],
      "env": {
        "GODOT_PATH": "D:\\devtool\\godot\\Godot_v4.4.1-stable_win64.exe\\Godot_v4.4.1-stable_win64.exe",
        "DEBUG": "true"  // 可选：启用详细日志
      },
      "disabled": false,
      "autoApprove": [
        "launch_editor",
        "run_project",
        "get_debug_output",
        "stop_project",
        "get_godot_version",
        "list_projects",
        "get_project_info"
      ]
    }
  }
}
```

**路径注意事项：**

| 平台 | 路径格式 | 示例 |
|------|---------|------|
| Windows | 双反斜杠 `\\` 或单正斜杠 `/` | `"C:\\Users\\ivan\\.mcp\\godot-mcp\\build\\index.js"` |
| Linux | 绝对路径 | `"/home/username/.mcp/godot-mcp/build/index.js"` |
| Mac | 绝对路径 | `"/Users/username/.mcp/godot-mcp/build/index.js"` |

---

#### 配置参数详解

| 配置项 | 说明 | 示例 |
|--------|------|------|
| `command` | 执行命令 | `"npx"` (推荐) 或 `"node"` (本地构建) |
| `args` | 命令参数 | `["-y", "godot-mcp"]` 或 `["路径/to/index.js"]` |
| `GODOT_PATH` | Godot 可执行文件的完整路径（必需） | Windows: `"D:\\path\\to\\Godot.exe"`<br>Linux: `"/usr/bin/godot"`<br>Mac: `"/Applications/Godot.app/Contents/MacOS/Godot"` |
| `DEBUG` | 启用详细日志（可选） | `"true"` 或省略 |
| `disabled` | 是否禁用此 MCP | `false` (启用) 或 `true` (禁用) |
| `autoApprove` | 自动批准的工具列表 | 见下方详解 |

#### autoApprove 详解

`autoApprove` 用于指定哪些 MCP 工具可以自动执行，无需每次手动确认。

**推荐自动批准的工具（安全、常用）：**

```json
"autoApprove": [
  "launch_editor",       // 启动 Godot 编辑器
  "run_project",         // 运行项目
  "get_debug_output",    // 获取调试输出（只读）
  "stop_project",        // 停止运行的项目
  "get_godot_version",   // 获取 Godot 版本（只读）
  "list_projects",       // 列出项目（只读）
  "get_project_info"     // 获取项目信息（只读）
]
```

**可选的自动批准工具（修改文件，谨慎使用）：**

```json
"autoApprove": [
  // ... 上面的工具 ...
  "create_scene",        // 创建新场景（会创建文件）
  "add_node",            // 添加节点到场景（会修改文件）
  "load_sprite",         // 加载精灵（会修改文件）
  "save_scene",          // 保存场景（会修改文件）
  "export_mesh_library", // 导出网格库（会创建文件）
  "get_uid",             // 获取文件 UID（只读）
  "update_project_uids"  // 更新 UID 引用（会修改文件）
]
```

**不建议自动批准的工具：**
- 任何会删除文件的操作
- 任何会修改项目设置的操作
- 不熟悉的新工具

**为什么使用 autoApprove？**
- ✅ 避免频繁的手动确认，提高效率
- ✅ 对于只读操作（如获取信息）非常安全
- ⚠️ 对于修改操作需要谨慎评估

---

#### 两种方式对比总结

| 特性 | npx 方式（推荐） | 本地构建方式 |
|------|----------------|------------|
| **配置复杂度** | ✅ 简单（3行配置） | ❌ 复杂（需要绝对路径） |
| **安装步骤** | ✅ 自动（npx 自动下载） | ❌ 手动（git clone + npm install + build） |
| **团队共享** | ✅ 配置完全相同 | ❌ 每个人路径不同 |
| **更新** | ✅ npx 自动检查最新版本 | ❌ 需要手动 git pull + rebuild |
| **离线使用** | ⚠️ 首次需要网络 | ✅ 完全离线可用 |
| **调试/开发** | ❌ 不能修改源码 | ✅ 可以修改和调试 |
| **版本控制** | ⚠️ 使用 npm latest | ✅ 精确控制 git commit |
| **适用场景** | 普通用户、团队协作 | 开发者、需要定制功能 |

**推荐选择：**
- 🎯 **95% 的用户应该使用 npx 方式** - 简单、可靠、易维护
- 🔧 **只有开发者或特殊需求才使用本地构建** - 需要修改源码或使用未发布功能

---

### 4. 其他常用 MCP Servers

#### Brave Search MCP（网页搜索）
```bash
# 安装
npm install -g @modelcontextprotocol/server-brave-search
```

```json
{
  "mcpServers": {
    "brave-search": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-brave-search"],
      "env": {
        "BRAVE_API_KEY": "${BRAVE_API_KEY}"
      }
    }
  }
}
```

获取 API Key：https://brave.com/search/api/

#### PostgreSQL MCP（数据库访问）
```json
{
  "mcpServers": {
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "POSTGRES_URL": "postgresql://user:password@localhost:5432/dbname"
      }
    }
  }
}
```

#### Slack MCP（Slack 集成）
```json
{
  "mcpServers": {
    "slack": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-slack"],
      "env": {
        "SLACK_BOT_TOKEN": "${SLACK_BOT_TOKEN}",
        "SLACK_TEAM_ID": "${SLACK_TEAM_ID}"
      }
    }
  }
}
```

#### Puppeteer MCP（浏览器自动化）
```json
{
  "mcpServers": {
    "puppeteer": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-puppeteer"]
    }
  }
}
```

### 通用 MCP 配置步骤

#### 对于 npm 包形式的 MCP

1. **查找 MCP 包名**
   - 官方 MCP：`@modelcontextprotocol/server-*`
   - 社区 MCP：在 npm 或 GitHub 搜索

2. **测试 MCP 可用性**
   ```bash
   npx -y @modelcontextprotocol/server-<name> --help
   ```

3. **添加到配置文件**
   ```json
   {
     "mcpServers": {
       "名称": {
         "command": "npx",
         "args": ["-y", "@modelcontextprotocol/server-<name>"],
         "env": {
           "必要的环境变量": "${环境变量名}"
         }
       }
     }
   }
   ```

#### 对于需要本地构建的 MCP（如 Godot MCP）

1. **克隆仓库**
   ```bash
   git clone <仓库地址>
   cd <项目目录>
   ```

2. **安装依赖**
   ```bash
   npm install
   # 或
   yarn install
   ```

3. **构建项目**
   ```bash
   npm run build
   # 或
   yarn build
   ```

4. **查找入口文件**
   - 检查 `package.json` 的 `bin` 字段
   - 通常在 `build/`, `dist/`, 或 `lib/` 目录

5. **添加到配置**
   ```json
   {
     "mcpServers": {
       "名称": {
         "command": "node",
         "args": ["/绝对路径/到/入口文件.js"],
         "env": {
           "必要的环境变量": "值"
         }
       }
     }
   }
   ```

### 完整配置示例

`.mcp.json`:
```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "e:\\workspace\\4.godot\\combo_demon\\Art",
        "e:\\workspace\\4.godot\\combo_demon\\Scenes",
        "e:\\workspace\\4.godot\\combo_demon\\Util"
      ],
      "env": {}
    },
    "github": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-github"
      ],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
      }
    },
    "godot": {
      "command": "node",
      "args": [
        "C:\\Users\\ivan\\.mcp\\godot-mcp\\build\\index.js"
      ],
      "env": {
        "GODOT_PATH": "D:\\devtool\\godot\\Godot_v4.4.1-stable_win64.exe\\Godot_v4.4.1-stable_win64.exe"
      },
      "disabled": false,
      "autoApprove": [
        "launch_editor",
        "run_project",
        "get_debug_output",
        "stop_project"
      ]
    }
  }
}
```

---

## 测试 MCP 服务

### 1. 使用 CLI 检查 MCP 状态

```bash
# Windows (需要设置 Git Bash 路径)
export CLAUDE_CODE_GIT_BASH_PATH="D:\devtool\Git\usr\bin\bash.exe"

# 在项目目录下检查
cd /path/to/your/project
claude mcp list
```

**期望输出：**
```
Checking MCP server health...

filesystem: npx -y @modelcontextprotocol/server-filesystem ... - ✓ Connected
github: npx -y @modelcontextprotocol/server-github - ✓ Connected
godot: node C:\Users\ivan\.mcp\godot-mcp\build\index.js - ✓ Connected
```

### 2. 测试 GitHub MCP 功能

在 Claude Code 中测试（VSCode 扩展或 CLI）：
```
# 搜索仓库
使用 GitHub MCP 搜索仓库：godot

# 获取仓库信息
获取 owner/repo 的仓库信息

# 列出 issues
列出 owner/repo 的 issues
```

### 3. 测试 Godot MCP 功能

使用 Claude Code MCP 工具：
```javascript
// 获取 Godot 版本
mcp__godot__get_godot_version()

// 获取项目信息
mcp__godot__get_project_info({
  projectPath: "e:\\workspace\\4.godot\\combo_demon"
})

// 启动编辑器
mcp__godot__launch_editor({
  projectPath: "e:\\workspace\\4.godot\\combo_demon"
})
```

**期望返回示例：**
```json
{
  "name": "combo_demon",
  "path": "e:\\workspace\\4.godot\\combo_demon",
  "godotVersion": "4.4.1.stable.official.49a5bc7b6",
  "structure": {
    "scenes": 7,
    "scripts": 38,
    "assets": 2217,
    "other": 2429
  }
}
```

### 4. 测试 Filesystem MCP 功能

```
# 列出目录
列出 Art 目录的文件

# 读取文件
读取 Scenes/main.tscn 文件内容
```

---

## 常见问题解决

### 1. MCP 服务器连接失败

**问题：** `✗ Failed to connect`

**解决方案：**

#### GitHub MCP
- 检查环境变量是否设置：`echo $GITHUB_TOKEN`
- 验证 PAT 是否有效（访问 https://github.com/settings/tokens）
- 确认 PAT 权限包含 `repo` scope
- 重启 Claude Code / VSCode

#### Filesystem MCP
- 检查路径是否存在且可访问
- 确认路径格式正确（Windows 使用 `\\` 或 `/`）

#### Godot MCP
- 验证 Godot MCP 文件存在：`test -f "path/to/index.js"`
- 检查 Node.js 版本：`node --version`
- 确认 GODOT_PATH 指向正确的可执行文件

### 2. 环境变量未展开

**问题：** `${GITHUB_TOKEN}` 没有被替换

**解决方案：**
- 确保环境变量在启动 Claude Code 之前已设置
- 重启终端/VSCode 以加载新的环境变量
- 使用系统环境变量而非临时 shell 变量

### 3. Windows Git Bash 问题

**问题：** `Claude Code on Windows requires git-bash`

**解决方案：**
```bash
# 查找 bash.exe 路径
where bash.exe

# 设置环境变量
setx CLAUDE_CODE_GIT_BASH_PATH "D:\devtool\Git\usr\bin\bash.exe"

# 或在当前会话中
export CLAUDE_CODE_GIT_BASH_PATH="D:\devtool\Git\usr\bin\bash.exe"
```

### 4. MCP 配置冲突

**问题：** 同一服务在多个配置文件中定义

**解决方案：**
- **推荐：** 删除 `.claude.json` 中的项目级 `mcpServers` 配置
- 统一使用 `.mcp.json` 管理项目 MCP 服务
- 全局配置（用户级）放在 `~/.claude.json`

### 5. npx 命令超时或失败

**问题：** npx 首次运行缓慢

**解决方案：**
```bash
# 预先安装 MCP 包
npx -y @modelcontextprotocol/server-github
npx -y @modelcontextprotocol/server-filesystem

# 或全局安装
npm install -g @modelcontextprotocol/server-github
npm install -g @modelcontextprotocol/server-filesystem
```

---

## MCP 服务管理

### 启用/禁用 MCP 服务

#### 方法 1: 使用配置文件
在 `.mcp.json` 中设置 `disabled` 字段：
```json
{
  "mcpServers": {
    "github": {
      "disabled": true,  // 禁用此服务
      ...
    }
  }
}
```

#### 方法 2: 使用 CLI（如果支持）
```bash
# 禁用服务
claude mcp disable github

# 启用服务
claude mcp enable github
```

### 删除 MCP 服务

#### 从 `.mcp.json` 删除
直接删除对应的服务配置块。

#### 从 `.claude.json` 删除（用户级）
```bash
# 使用 CLI
claude mcp remove github

# 或手动编辑 ~/.claude.json
# 删除 projects[项目路径].mcpServers.github
```

---

## 最佳实践

### 1. 配置文件管理
- ✅ 项目共享的 MCP 配置放在 `.mcp.json`，提交到 Git
- ✅ 个人私有的 MCP 配置放在 `~/.claude.json`
- ✅ 敏感信息（如 token）使用环境变量
- ❌ 不要将 token 硬编码到配置文件中

### 2. 环境变量安全
```bash
# ✅ 推荐：使用 .env 文件（不提交到 Git）
# .env
GITHUB_TOKEN=ghp_your_token_here

# .gitignore
.env

# ❌ 避免：硬编码 token
"env": {
  "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_hardcoded_token"  // 不安全！
}
```

### 3. autoApprove 使用
仅对安全、常用的工具启用自动批准：
```json
{
  "autoApprove": [
    "get_debug_output",  // ✅ 只读操作，安全
    "launch_editor",     // ✅ 常用且可控
    "delete_all_files"   // ❌ 危险操作，不要自动批准
  ]
}
```

### 4. 故障排查流程
1. 检查 `claude mcp list` 输出
2. 验证环境变量：`echo $VARIABLE_NAME`
3. 手动测试命令：`npx -y @modelcontextprotocol/server-github`
4. 查看 Claude Code 日志
5. 重启 VSCode / Claude Code

---

## 如何发现和添加新的 MCP 服务器

### 1. 官方 MCP 服务器列表

访问官方 MCP 仓库查看可用的服务器：
- **官方仓库：** https://github.com/modelcontextprotocol
- **官方文档：** https://modelcontextprotocol.io/docs/servers/

### 2. 社区 MCP 服务器

**Awesome MCP Servers：**
- https://github.com/punkpeye/awesome-mcp-servers
- https://github.com/wong2/awesome-mcp-servers

**搜索平台：**
- **npm 搜索：** https://www.npmjs.com/search?q=mcp-server
- **GitHub 搜索：** 搜索关键词 "mcp server"

### 3. 常用 MCP 服务器列表

#### 开发工具类
| MCP Server | 包名 | 功能 |
|-----------|------|------|
| GitHub | `@modelcontextprotocol/server-github` | GitHub 仓库管理 |
| GitLab | `@modelcontextprotocol/server-gitlab` | GitLab 集成 |
| Git | `@modelcontextprotocol/server-git` | Git 操作 |
| Docker | 社区提供 | Docker 容器管理 |
| Kubernetes | 社区提供 | K8s 集群管理 |

#### 文件和数据类
| MCP Server | 包名 | 功能 |
|-----------|------|------|
| Filesystem | `@modelcontextprotocol/server-filesystem` | 文件系统访问 |
| PostgreSQL | `@modelcontextprotocol/server-postgres` | PostgreSQL 数据库 |
| SQLite | `@modelcontextprotocol/server-sqlite` | SQLite 数据库 |
| MongoDB | 社区提供 | MongoDB 数据库 |
| Google Drive | `@modelcontextprotocol/server-gdrive` | Google Drive 访问 |

#### 通信和协作类
| MCP Server | 包名 | 功能 |
|-----------|------|------|
| Slack | `@modelcontextprotocol/server-slack` | Slack 消息和频道 |
| Discord | 社区提供 | Discord 集成 |
| Email | 社区提供 | 电子邮件处理 |

#### 搜索和信息类
| MCP Server | 包名 | 功能 |
|-----------|------|------|
| Brave Search | `@modelcontextprotocol/server-brave-search` | 网页搜索 |
| Google Search | 社区提供 | Google 搜索 |
| Wikipedia | 社区提供 | 维基百科查询 |

#### 浏览器和自动化类
| MCP Server | 包名 | 功能 |
|-----------|------|------|
| Puppeteer | `@modelcontextprotocol/server-puppeteer` | 浏览器自动化 |
| Playwright | 社区提供 | 浏览器测试 |

#### 游戏开发类
| MCP Server | 包名 | 功能 |
|-----------|------|------|
| Godot | `godot-mcp` (npm) 或 https://github.com/Coding-Solo/godot-mcp | Godot 引擎集成 |
| Unity | 社区提供（如有） | Unity 引擎集成 |

### 4. 添加新 MCP 的标准流程

#### 步骤 1: 确定 MCP 类型

**npm 包类型：**
- 可以直接用 `npx` 运行
- 示例：`@modelcontextprotocol/server-*`

**Git 仓库类型：**
- 需要克隆并构建
- 示例：Godot MCP

#### 步骤 2: 阅读文档

查找 MCP 的 README 或文档，了解：
- 安装方法
- 必需的环境变量
- 可用的工具/功能
- 配置示例

#### 步骤 3: 测试 MCP

```bash
# npm 包类型
npx -y <包名> --help

# 本地构建类型
cd <项目目录>
npm install
npm run build
node build/index.js --help
```

#### 步骤 4: 添加到配置文件

根据 MCP 类型选择配置模板（参考本文档"通用 MCP 配置步骤"部分）

#### 步骤 5: 验证连接

```bash
claude mcp list
```

### 5. 创建自定义 MCP 服务器

如果找不到合适的 MCP，可以创建自己的：

**官方 SDK：**
- **TypeScript/JavaScript：** `@modelcontextprotocol/sdk`
- **Python：** `mcp`

**快速开始：**
```bash
# 克隆模板
git clone https://github.com/modelcontextprotocol/typescript-sdk-template
cd typescript-sdk-template
npm install
npm run build
```

**参考文档：**
- MCP SDK 文档：https://modelcontextprotocol.io/docs/sdk/
- 示例项目：https://github.com/modelcontextprotocol/servers

---

## 参考资源

### 官方文档
- **Claude Code 文档：** https://docs.claude.com/en/docs/claude-code
- **MCP 协议规范：** https://modelcontextprotocol.io
- **MCP SDK 文档：** https://modelcontextprotocol.io/docs/sdk/
- **GitHub MCP Server：** https://github.com/github/github-mcp-server

### 官方 MCP 服务器
- **官方仓库列表：** https://github.com/modelcontextprotocol
- **Filesystem：** `@modelcontextprotocol/server-filesystem`
- **GitHub：** `@modelcontextprotocol/server-github`
- **Brave Search：** `@modelcontextprotocol/server-brave-search`
- **PostgreSQL：** `@modelcontextprotocol/server-postgres`
- **Slack：** `@modelcontextprotocol/server-slack`
- **Puppeteer：** `@modelcontextprotocol/server-puppeteer`
- **Google Drive：** `@modelcontextprotocol/server-gdrive`

### 社区资源
- **Claude Code Issues：** https://github.com/anthropics/claude-code/issues
- **MCP Awesome List 1：** https://github.com/punkpeye/awesome-mcp-servers
- **MCP Awesome List 2：** https://github.com/wong2/awesome-mcp-servers
- **Godot MCP：** https://github.com/Coding-Solo/godot-mcp

### 学习资源
- **MCP 介绍视频：** https://www.youtube.com/results?search_query=model+context+protocol
- **社区论坛：** https://github.com/modelcontextprotocol/discussions

---

## 附录：项目实际配置

### 当前项目配置（combo_demon）

**文件位置：** `e:\workspace\4.godot\combo_demon\.mcp.json`

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "e:\\workspace\\4.godot\\combo_demon\\Art",
        "e:\\workspace\\4.godot\\combo_demon\\Scenes",
        "e:\\workspace\\4.godot\\combo_demon\\Util"
      ],
      "env": {}
    },
    "github": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-github"
      ],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
      }
    },
    "godot": {
      "command": "npx",
      "args": [
        "-y",
        "godot-mcp"
      ],
      "env": {
        "GODOT_PATH": "D:\\devtool\\godot\\Godot_v4.4.1-stable_win64.exe\\Godot_v4.4.1-stable_win64.exe"
      },
      "disabled": false,
      "autoApprove": [
        "launch_editor",
        "run_project",
        "get_debug_output",
        "stop_project"
      ]
    }
  }
}
```

**配置说明：**
- ✅ 使用 npx 方式配置所有 MCP 服务器（推荐）
- ✅ 环境变量使用 `${GITHUB_TOKEN}` 引用系统变量
- ✅ Godot MCP 只需配置 `GODOT_PATH`，无需本地构建
- ✅ `autoApprove` 只包含安全的只读和常用操作

### 测试验证结果

```bash
Checking MCP server health...

filesystem: npx -y @modelcontextprotocol/server-filesystem ... - ✓ Connected
github: npx -y @modelcontextprotocol/server-github - ✓ Connected
godot: npx -y godot-mcp - ✓ Connected
```

**验证成功标志：**
- ✓ 所有 MCP 服务器显示 "Connected"
- ✓ 无错误消息
- ✓ 可以在 Claude Code 中使用所有 MCP 工具

**项目统计：**
- Godot 版本：4.4.1.stable.official.49a5bc7b6
- 场景文件：7 个
- 脚本文件：38 个
- 资源文件：2217 个

---

**文档版本：** 1.0
**更新日期：** 2025-11-09
**适用版本：** Claude Code 2.0.36+
