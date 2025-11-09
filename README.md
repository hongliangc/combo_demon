# Combo Demon - Godot游戏项目

这是一个使用Godot 4.4.1开发的游戏项目。

## 🚀 快速开始

### 打开项目

**方法1：使用MCP（推荐）**
- 在Claude Code中输入: "打开Godot编辑器"

**方法2：使用批处理文件**
- 双击 `启动Godot.bat`

**方法3：手动打开**
- 打开Godot引擎
- 导入此项目目录

## 📁 项目结构

```
combo_demon/
├── .vscode/
│   └── settings.json         # VSCode工作区设置
├── .mcp.json                 # MCP服务器配置（项目根目录）
├── Art/                      # 美术资源
├── Scenes/                   # 游戏场景
│   ├── charaters/           # 角色
│   └── enemies/             # 敌人
├── Util/                     # 工具脚本
│   ├── AutoLoad/            # 自动加载
│   ├── Classes/             # 类定义
│   └── Components/          # 组件
├── Weapons/                  # 武器系统
├── check_mcp.sh             # MCP诊断脚本
├── 启动Godot.bat            # Godot启动脚本
├── MCP使用指南.md           # MCP使用文档
└── project.godot            # Godot项目文件
```

## 🎮 游戏系统

### 角色系统
- 位置: `Scenes/charaters/`
- 主角: Hahashin

### 敌人系统
- 位置: `Scenes/enemies/`
- 包含状态机和AI逻辑

### 战斗系统
- 伤害系统: `Util/Classes/Damage.gd`
- 生命值组件: `Util/Components/health.gd`
- Hitbox/Hurtbox: `Util/Components/`

### 武器系统
- 位置: `Weapons/`
- 近战攻击: `Weapons/slash/`

## 🛠️ 开发工具

### MCP集成

本项目配置了Model Context Protocol (MCP)，可以通过Claude Code控制Godot：

- **查看详细说明**: [MCP使用指南.md](MCP使用指南.md)
- **运行诊断**: `bash check_mcp.sh`

**可用的MCP功能：**
- 启动/停止Godot编辑器
- 运行项目
- 获取调试输出
- 创建场景和节点
- 加载资源

### VSCode配置

推荐的VSCode扩展：
- Claude Code (anthropic.claude-code)
- Godot Tools (可选)

## 🔧 技术栈

- **引擎**: Godot 4.4.1-stable
- **脚本语言**: GDScript
- **版本控制**: Git
- **开发工具**: VSCode + Claude Code + MCP

## 📝 Git状态

当前分支: `main`

最近修改：
- 角色系统 (hahashin.gd/tscn)
- 敌人系统 (enemy.gd, enemy_health.gd)
- 战斗系统 (Damage.gd, hitbox/hurtbox)
- 对象池 (bullet_pool.gd)

## 🚨 故障排查

### Godot无法启动

1. 检查Godot路径是否正确
2. 尝试使用 `启动Godot.bat`
3. 查看错误信息

### MCP不工作

1. 运行诊断: `bash check_mcp.sh`
2. 查看 [MCP使用指南.md](MCP使用指南.md)
3. 重启VSCode

## 📚 文档

- [MCP使用指南](MCP使用指南.md) - MCP配置和使用说明

## 🔗 相关链接

- [Godot官网](https://godotengine.org/)
- [Godot文档](https://docs.godotengine.org/)
- [Claude Code](https://docs.claude.com/)

---

**开发环境**: Windows | Node.js v24.11.0 | Godot 4.4.1
