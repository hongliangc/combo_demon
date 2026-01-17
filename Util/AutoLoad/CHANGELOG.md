# 调试日志系统更新日志

## v2.0.0 - 2026-01-11

### 🎉 重大更新：全新的日志系统

完全重写了调试日志系统，移除了之前需要加载场景才能使用的限制，现在通过配置文件即可灵活控制所有日志输出。

### ✨ 新增功能

1. **日志级别支持**
   - 新增 4 个日志级别：DEBUG, INFO, WARNING, ERROR
   - 支持按级别过滤日志输出
   - 不同级别使用不同颜色显示

2. **目录层级配置**
   - 可以为不同目录设置不同的日志级别
   - 支持最长路径匹配（更具体的配置优先）
   - 示例：关闭 `Util/StateMachine/` 目录的所有日志

3. **分类标签系统**
   - 支持按功能分类（combat, state_machine, player, ai, ui 等）
   - 分类配置优先级高于路径配置
   - 方便按功能模块控制日志

4. **配置文件驱动**
   - 新增 `debug_config.json` 配置文件
   - 无需修改代码，只需编辑 JSON 即可控制日志
   - 支持运行时重新加载配置

5. **运行时动态控制**
   - 新增 API 支持运行时修改配置
   - `set_global_enabled()` - 全局开关
   - `set_global_min_level()` - 设置全局最低级别
   - `set_path_config()` - 设置路径配置
   - `set_category_config()` - 设置分类配置
   - `reload_config()` - 重新加载配置文件

6. **文件输出功能**
   - 可选将日志输出到文件
   - 配置 `output_to_file` 和 `file_path`
   - 适用于性能分析和长期调试

7. **彩色输出**
   - DEBUG - 青色
   - INFO - 绿色
   - WARNING - 黄色
   - ERROR - 红色

### 🔧 API 变更

#### 新增方法
```gdscript
# 便捷方法
DebugConfig.debug(message, caller_path, category)
DebugConfig.info(message, caller_path, category)
DebugConfig.warn(message, caller_path, category)
DebugConfig.error(message, caller_path, category)

# 主方法
DebugConfig.print_log(message, level, caller_path, category)

# 配置控制
DebugConfig.set_global_enabled(enabled)
DebugConfig.set_global_min_level(level)
DebugConfig.set_path_config(path, enabled, min_level)
DebugConfig.set_category_config(category, enabled, min_level)
DebugConfig.set_file_output(enabled)
DebugConfig.reload_config()
```

#### 移除的方法和变量

**移除的旧方法：**
- `print_state()` → 改用 `DebugConfig.debug(msg, "", "state_machine")`
- `print_combat()` → 改用 `DebugConfig.info(msg, "", "combat")`
- `print_player()` → 改用 `DebugConfig.info(msg, "", "player")`
- `print_boss()` → 改用 `DebugConfig.debug(msg, "", "ai")`
- `print_enemy()` → 改用 `DebugConfig.debug(msg, "", "ai")`

**移除的变量：**
- `debug_state_machine` → 改用配置文件或 `set_category_config()`
- `debug_combat` → 改用配置文件或 `set_category_config()`
- `debug_player` → 改用配置文件或 `set_category_config()`
- `debug_boss` → 改用配置文件或 `set_category_config()`
- `debug_enemy` → 改用配置文件或 `set_category_config()`
- `debug_all` → 改用 `set_global_min_level(LogLevel.DEBUG)`

### 📁 新增文件

1. **debug_config.json** - 主配置文件
2. **DEBUG_README.md** - 完整使用文档
3. **QUICK_START.md** - 快速入门指南
4. **debug_usage_example.gd** - 使用示例代码
5. **debug_config_templates.json** - 常用配置模板
6. **debug_test.gd** - 测试脚本
7. **CHANGELOG.md** - 更新日志（本文件）

### 🔄 迁移指南

#### 从 v1.x 迁移到 v2.0

**旧代码（v1.x）：**
```gdscript
# 通过变量控制
DebugConfig.debug_combat = true
DebugConfig.debug_state_machine = false

# 打印日志
if DebugConfig.debug_combat:
    print("造成伤害: ", damage)
```

**新代码（v2.0）方式一 - 使用配置文件：**
```json
{
  "category_configs": {
    "combat": {"enabled": true, "min_level": "INFO"},
    "state_machine": {"enabled": false}
  }
}
```
```gdscript
# 直接使用新 API
DebugConfig.info("造成伤害: %d" % damage, "", "combat")
```

**新代码（v2.0）方式二 - 运行时控制：**
```gdscript
func _ready():
    DebugConfig.set_category_config("combat", true, DebugConfig.LogLevel.INFO)
    DebugConfig.set_category_config("state_machine", false)
```

### 📊 性能改进

- 配置文件只在启动时加载一次（除非调用 `reload_config()`）
- 路径匹配使用缓存，提高查找效率
- 禁用的日志会在早期检查中被过滤，不会执行字符串格式化

### 🐛 已知问题

- 暂无

### 💡 使用建议

1. **开发时**：使用 `min_level: "DEBUG"` 查看所有日志
2. **测试时**：使用 `min_level: "INFO"` 只看重要信息
3. **发布时**：使用 `min_level: "ERROR"` 或关闭日志
4. **调试特定功能**：使用路径配置或分类配置精确控制

### 🙏 致谢

感谢所有使用和反馈的开发者！

---

## v1.0.0 - 之前

### 初始版本
- 基本的调试开关功能
- 需要通过导出变量控制
- 简单的 `print_*()` 方法
