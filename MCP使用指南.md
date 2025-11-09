# Godot MCP 使用指南

## 📋 目录

- [快速开始](#快速开始)
- [安装状态](#安装状态)
- [如何使用](#如何使用)
- [故障排查](#故障排查)
- [可用功能](#可用功能)

---

## 快速开始

### ✅ 安装已完成

所有MCP服务器已安装并配置完成：

| 服务器 | 状态 | 功能 |
|--------|------|------|
| **godot** | ✅ 已配置 | 控制Godot编辑器、运行项目、获取调试输出 |
| **filesystem** | ✅ 已配置 | 访问项目的Art、Scenes、Util目录 |
| **github** | ⚠️ 需要Token | GitHub集成（可选）|

### 🔄 如何启用MCP

**重要：** 首次使用或修改配置后，必须重启VSCode！

```
1. 按 Ctrl+Q 完全退出VSCode
2. 重新打开VSCode
3. 打开此项目文件夹
```

### ✅ 验证MCP已加载

**方法1：查看输出面板**

1. 按 `Ctrl+Shift+U` 打开输出面板
2. 点击右侧下拉菜单
3. 应该看到 `MCP: godot` 选项

**方法2：运行诊断脚本**

```bash
bash check_mcp.sh
```

### 🧪 测试MCP功能

在Claude Code对话框中输入：

```
打开Godot编辑器
```

如果Godot编辑器自动启动，说明MCP工作正常！✅

---

## 安装状态

### 系统信息

```
Node.js:  v24.11.0
npm:      11.6.1
Godot:    v4.4.1.stable.official
平台:     Windows
```

### 安装位置

```
Godot MCP:     C:\Users\ivan\.mcp\godot-mcp
配置文件:      .mcp.json (项目根目录)
Godot路径:     D:\devtool\godot\Godot_v4.4.1-stable_win64.exe\
               Godot_v4.4.1-stable_win64.exe
```

### 配置文件

[.mcp.json](.mcp.json) 包含所有MCP服务器配置。

**重要：** 配置文件必须在项目根目录，不是`.vscode/`目录！

**自动批准的操作：**
- `launch_editor` - 启动编辑器
- `run_project` - 运行项目
- `get_debug_output` - 获取调试输出
- `stop_project` - 停止项目

这些操作无需确认即可执行。

---

## 如何使用

### Godot相关命令示例

**启动编辑器**
```
打开Godot编辑器
启动Godot
```

**运行项目**
```
运行当前Godot项目
启动游戏并显示调试信息
```

**获取项目信息**
```
显示Godot项目信息
获取项目配置
```

**获取版本信息**
```
查看Godot版本
```

**停止运行的项目**
```
停止Godot项目
```

### 场景和节点管理

**创建场景**
```
创建一个新的2D场景，名为MainScene
```

**添加节点**
```
在当前场景添加一个Sprite2D节点
```

**加载资源**
```
加载Art目录中的sprite.png到场景中
```

---

## 故障排查

### 问题1：输出面板看不到MCP选项

**症状：** 按Ctrl+Shift+U后，下拉菜单中没有"MCP: godot"

**解决方案：**

1. **确认配置文件位置正确**
   ```bash
   ls -la .mcp.json
   ```
   应该显示文件存在（在项目根目录）

2. **验证JSON格式**
   ```bash
   python -m json.tool .mcp.json
   ```
   不应该有错误

3. **完全重启VSCode**
   - 不要使用"重新加载窗口"
   - 必须完全退出后重新打开

4. **检查Claude Code扩展版本**
   ```bash
   code --list-extensions --show-versions | grep claude
   ```
   应该显示 `anthropic.claude-code@2.0.31` 或更高

### 问题2：MCP服务器启动失败

**检查MCP日志：**

1. 打开输出面板 (Ctrl+Shift+U)
2. 选择 `MCP: godot`
3. 查看错误信息

**常见错误及解决方案：**

**错误：找不到Godot可执行文件**
```
[ERROR] Could not find Godot executable
```
**解决：** 验证Godot路径
```bash
"/d/devtool/godot/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64.exe" --version
```

**错误：找不到Node.js**
```
Error: Cannot find module 'node'
```
**解决：** 验证Node.js安装
```bash
node --version
```

**错误：构建文件缺失**
```
Cannot find module '...index.js'
```
**解决：** 重新构建Godot MCP
```bash
cd "$HOME/.mcp/godot-mcp"
npm run build
```

### 问题3：命令无响应

**可能原因：**
- 项目路径问题
- Godot已经在运行
- 权限不足

**解决方案：**

1. 确认在正确的项目目录
   ```bash
   ls project.godot
   ```

2. 关闭已运行的Godot实例

3. 以管理员身份运行VSCode

### 问题4：GitHub MCP不工作

**这是正常的！** GitHub MCP需要配置GitHub Token才能使用。

**如果需要GitHub功能：**

1. 创建GitHub Personal Access Token
   - 访问: https://github.com/settings/tokens
   - 生成新Token（需要`repo`权限）

2. 设置环境变量
   ```
   变量名: GITHUB_TOKEN
   变量值: 你的Token
   ```

3. 重启VSCode

**不影响Godot MCP的使用！**

---

## 可用功能

### Godot MCP工具列表

| 工具 | 功能 | 自动批准 |
|------|------|---------|
| `launch_editor` | 启动Godot编辑器 | ✅ |
| `run_project` | 运行项目 | ✅ |
| `get_debug_output` | 获取调试输出 | ✅ |
| `stop_project` | 停止运行的项目 | ✅ |
| `get_version` | 获取Godot版本 | ❌ |
| `get_project_info` | 获取项目信息 | ❌ |
| `create_scene` | 创建新场景 | ❌ |
| `add_node` | 添加节点到场景 | ❌ |
| `load_sprite` | 加载精灵资源 | ❌ |
| `save_scene` | 保存场景 | ❌ |
| `export_mesh_library` | 导出网格库 | ❌ |
| `get_uid` | 获取资源UID | ❌ |
| `update_project_uids` | 更新项目UID | ❌ |

### Filesystem MCP

访问项目的以下目录：
- `Art/` - 艺术资源
- `Scenes/` - 场景文件
- `Util/` - 工具脚本

### GitHub MCP

需要配置Token后可用：
- 创建Issues
- 管理Pull Requests
- 查看仓库信息
- 创建Releases

---

## 快速参考

### 诊断命令

```bash
# 运行完整诊断
bash check_mcp.sh

# 检查配置文件
cat .mcp.json

# 验证Godot
"/d/devtool/godot/Godot_v4.4.1-stable_win64.exe/Godot_v4.4.1-stable_win64.exe" --version

# 检查Godot MCP构建
ls -lh "$HOME/.mcp/godot-mcp/build/index.js"
```

### 手动启动Godot

如果MCP暂时不可用，使用批处理文件：

双击 [启动Godot.bat](启动Godot.bat)

或命令行：
```bash
"D:\devtool\godot\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe" --editor --path "$(pwd)"
```

### 更新Godot MCP

如果需要更新到最新版本：

```bash
cd "$HOME/.mcp/godot-mcp"
git pull
npm install
npm run build
```

然后重启VSCode。

---

## 相关链接

- [Godot MCP GitHub](https://github.com/Coding-Solo/godot-mcp)
- [MCP官方文档](https://modelcontextprotocol.io/)
- [Claude Code文档](https://docs.claude.com/)
- [VSCode MCP配置](https://code.visualstudio.com/docs/copilot/customization/mcp-servers)

---

## 获取帮助

如果遇到问题：

1. **运行诊断脚本**: `bash check_mcp.sh`
2. **查看MCP日志**: Ctrl+Shift+U → 选择 "MCP: godot"
3. **检查配置文件**: `.vscode/mcp.json`
4. **完全重启VSCode**: Ctrl+Q → 重新打开

---

**最后更新：** 2025-11-02
**状态：** ✅ 已配置并可用
