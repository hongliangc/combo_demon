# 日志系统快速入门 🚀

## 1分钟快速开始

### 第一步：在代码中使用日志

```gdscript
extends CharacterBody2D

func _ready():
    # 使用新的日志方法
    DebugConfig.info("玩家初始化")
    DebugConfig.debug("调试信息")
    DebugConfig.warn("警告信息")
    DebugConfig.error("错误信息")
```

### 第二步：配置日志输出

编辑 `Util/AutoLoad/debug_config.json`：

```json
{
  "global": {
    "enabled": true,
    "min_level": "INFO"
  }
}
```

**就这么简单！** 🎉

---

## 常用操作

### 控制日志级别

```json
{
  "global": {
    "min_level": "DEBUG"    // 显示所有日志
    "min_level": "INFO"     // 只显示 INFO 及以上
    "min_level": "WARNING"  // 只显示 WARNING 和 ERROR
    "min_level": "ERROR"    // 只显示 ERROR
  }
}
```

### 关闭某个目录的日志

```json
{
  "path_configs": {
    "Util/StateMachine/": {
      "enabled": false
    }
  }
}
```

### 使用分类标签

```gdscript
# 在代码中
DebugConfig.info("造成伤害: 50", "", "combat")
DebugConfig.debug("状态切换", "", "state_machine")
```

```json
// 在配置中控制
{
  "category_configs": {
    "combat": {
      "enabled": true,
      "min_level": "INFO"
    },
    "state_machine": {
      "enabled": false
    }
  }
}
```

---

## 4个常用配置模板

### 1. 开发模式（显示所有）
```json
{"global": {"enabled": true, "min_level": "DEBUG"}}
```

### 2. 测试模式（重要信息）
```json
{"global": {"enabled": true, "min_level": "INFO"}}
```

### 3. 发布模式（只显示错误）
```json
{"global": {"enabled": true, "min_level": "ERROR"}}
```

### 4. 调试特定功能
```json
{
  "global": {"enabled": true, "min_level": "ERROR"},
  "path_configs": {
    "Scenes/enemies/boss/": {"enabled": true, "min_level": "DEBUG"}
  }
}
```

---

## 日志级别说明

| 级别 | 何时使用 | 颜色 |
|------|----------|------|
| DEBUG | 详细的调试信息 | 青色 |
| INFO | 重要的运行状态 | 绿色 |
| WARNING | 可能的问题 | 黄色 |
| ERROR | 严重错误 | 红色 |

---

## 运行时控制

```gdscript
# 在代码中动态控制
func _ready():
    # 只在 Debug 构建时开启日志
    if OS.is_debug_build():
        DebugConfig.set_global_enabled(true)
    else:
        DebugConfig.set_global_enabled(false)

    # 临时关闭某个分类
    DebugConfig.set_category_config("state_machine", false)

    # 重新加载配置
    DebugConfig.reload_config()
```

---

## 下一步

- 📖 阅读完整文档：[DEBUG_README.md](DEBUG_README.md)
- 💡 查看使用示例：[debug_usage_example.gd](debug_usage_example.gd)
- 🎨 浏览配置模板：[debug_config_templates.json](debug_config_templates.json)
- 🧪 运行测试脚本：[debug_test.gd](debug_test.gd)

---

## 常见问题

**Q: 日志没有显示？**
- 检查 `global.enabled` 是否为 `true`
- 检查日志级别是否满足 `min_level` 要求
- 检查路径/分类配置是否禁用了该日志

**Q: 如何减少日志噪音？**
- 提高 `min_level` 到 `INFO` 或 `WARNING`
- 禁用特定分类：`"state_machine": {"enabled": false}`
- 禁用特定目录：`"Util/StateMachine/": {"enabled": false}`

**Q: 发布版本如何处理？**
```gdscript
func _ready():
    if not OS.is_debug_build():
        DebugConfig.set_global_enabled(false)
```

---

## 核心优势 ✨

✅ **无需加载场景** - 直接通过配置文件控制
✅ **零代码修改** - 只需编辑 JSON 配置
✅ **层级控制** - 精确到目录和文件
✅ **彩色输出** - 不同级别不同颜色
✅ **简洁API** - 直观易用的日志方法

开始使用吧！🎮
