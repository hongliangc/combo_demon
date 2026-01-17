# 调试日志系统使用说明

全新的调试日志系统，支持日志级别、目录层级配置和运行时动态控制。**无需加载场景，直接通过配置文件控制日志输出！**

## 核心特性

✅ **日志级别控制** - 支持 DEBUG, INFO, WARNING, ERROR 四个级别
✅ **目录层级配置** - 可以为不同目录设置不同的日志级别
✅ **分类标签** - 支持按功能分类（combat, ai, ui等）
✅ **配置文件驱动** - 通过 JSON 配置文件控制，无需修改代码
✅ **彩色输出** - 不同级别使用不同颜色，便于查看
✅ **文件输出** - 可选将日志输出到文件
✅ **运行时动态控制** - 可在运行时修改配置

---

## 快速开始

### 1. 基本使用

在任何脚本中使用新的日志方法：

```gdscript
# 方式一：使用便捷方法
DebugConfig.debug("这是调试信息")
DebugConfig.info("玩家血量: %d" % health)
DebugConfig.warn("敌人数量过多!")
DebugConfig.error("无法加载资源!")

# 方式二：使用主方法（更灵活）
DebugConfig.print_log("自定义消息", DebugConfig.LogLevel.INFO)

# 方式三：带分类标签
DebugConfig.info("造成伤害: 50", "", "combat")
DebugConfig.debug("状态切换: Idle -> Chase", "", "state_machine")
```

### 2. 配置文件

编辑 `Util/AutoLoad/debug_config.json` 来控制日志输出：

```json
{
  "global": {
    "enabled": true,           // 全局开关
    "min_level": "DEBUG",      // 全局最低级别
    "output_to_file": false,   // 是否输出到文件
    "file_path": "user://debug.log"
  },

  "path_configs": {
    // 关闭整个 StateMachine 目录的日志
    "Util/StateMachine/": {
      "enabled": false,
      "min_level": "WARNING"
    },

    // Boss 目录显示所有日志
    "Scenes/enemies/boss/": {
      "enabled": true,
      "min_level": "DEBUG"
    },

    // 恐龙敌人只显示 INFO 及以上
    "Scenes/enemies/dinosaur/": {
      "enabled": true,
      "min_level": "INFO"
    }
  },

  "category_configs": {
    // 关闭状态机分类的日志
    "state_machine": {
      "enabled": false,
      "min_level": "DEBUG"
    },

    // 只显示战斗相关的 INFO 及以上日志
    "combat": {
      "enabled": true,
      "min_level": "INFO"
    }
  }
}
```

---

## 日志级别说明

| 级别 | 用途 | 示例 | 颜色 |
|------|------|------|------|
| **DEBUG** | 详细的开发调试信息 | 状态转换、变量值 | 青色 |
| **INFO** | 重要的运行状态信息 | 玩家死亡、关卡完成 | 绿色 |
| **WARNING** | 可能的问题或异常 | 资源未找到、性能警告 | 黄色 |
| **ERROR** | 严重错误 | 空引用、加载失败 | 红色 |

---

## 配置优先级

日志系统按以下优先级判断是否输出：

1. **全局开关** - 如果 `global.enabled = false`，所有日志都不输出
2. **分类配置** - 如果指定了 `category`，使用分类配置（优先级最高）
3. **路径配置** - 使用**最长匹配**的路径配置
4. **全局最低级别** - 最后检查全局最低级别

### 示例

假设配置如下：
```json
{
  "global": {
    "enabled": true,
    "min_level": "INFO"
  },
  "path_configs": {
    "Scenes/enemies/": {
      "enabled": true,
      "min_level": "WARNING"
    },
    "Scenes/enemies/boss/": {
      "enabled": true,
      "min_level": "DEBUG"
    }
  }
}
```

结果：
- `Scenes/UI/menu.gd` 调用 `debug()` → ❌ 不显示（全局最低级别是 INFO）
- `Scenes/UI/menu.gd` 调用 `info()` → ✅ 显示
- `Scenes/enemies/dinosaur/dinosaur.gd` 调用 `info()` → ❌ 不显示（目录最低级别是 WARNING）
- `Scenes/enemies/boss/boss.gd` 调用 `debug()` → ✅ 显示（更具体的路径配置）

---

## 运行时动态控制

### 临时开启/关闭日志

```gdscript
# 在游戏运行时动态控制
func _ready():
    # 关闭所有日志
    DebugConfig.set_global_enabled(false)

    # 只在 Debug 构建时开启日志
    if OS.is_debug_build():
        DebugConfig.set_global_enabled(true)
        DebugConfig.set_global_min_level(DebugConfig.LogLevel.DEBUG)

# 临时开启某个目录的日志
func enable_boss_debug():
    DebugConfig.set_path_config(
        "Scenes/enemies/boss/",
        true,
        DebugConfig.LogLevel.DEBUG
    )

# 临时关闭某个分类的日志
func disable_state_machine_logs():
    DebugConfig.set_category_config("state_machine", false)

# 重新加载配置文件
func reload_log_config():
    DebugConfig.reload_config()

# 启用文件输出
func enable_log_file():
    DebugConfig.set_file_output(true)
```

---

## 实际应用场景

### 场景 1: 调试 Boss AI

只想看 Boss 的日志，其他都关闭：

```json
{
  "global": {
    "enabled": true,
    "min_level": "ERROR"  // 全局只显示错误
  },
  "path_configs": {
    "Scenes/enemies/boss/": {
      "enabled": true,
      "min_level": "DEBUG"  // Boss 显示所有日志
    }
  }
}
```

### 场景 2: 只看战斗相关

使用分类标签过滤：

```json
{
  "category_configs": {
    "combat": {
      "enabled": true,
      "min_level": "INFO"
    },
    "state_machine": {
      "enabled": false
    },
    "ui": {
      "enabled": false
    }
  }
}
```

### 场景 3: 发布前准备

```json
{
  "global": {
    "enabled": true,
    "min_level": "ERROR"  // 只显示错误
  }
}
```

或在代码中：
```gdscript
func _ready():
    if not OS.is_debug_build():
        DebugConfig.set_global_enabled(false)
```

---

## 日志输出格式

```
[时间] [级别] [分类] [文件名] 消息内容
```

示例：
```
[14:25:30] [INFO] [combat] [player.gd] 玩家受到伤害: 20
[14:25:31] [DEBUG] [state_machine] [boss_idle.gd] 状态切换: Idle -> Chase
[14:25:32] [ERROR] [boss_attack.gd] 攻击目标不存在!
```

---

## 性能建议

1. **发布版本前关闭调试日志**
   ```gdscript
   if not OS.is_debug_build():
       DebugConfig.set_global_enabled(false)
   ```

2. **只开启需要的日志**
   - 不要使用 `min_level = "DEBUG"` 在全局
   - 使用路径配置精确控制

3. **避免频繁调用**
   ```gdscript
   # 不好：每帧打印
   func _process(_delta):
       DebugConfig.debug("玩家位置: %v" % position)

   # 好：按需打印
   func take_damage(amount: int):
       DebugConfig.info("受到伤害: %d" % amount, "", "combat")
   ```

4. **文件输出影响性能**
   - 只在需要时启用 `output_to_file`
   - 日志文件位置：`user://debug.log`（通常在 `%APPDATA%/Godot/app_userdata/项目名/`）

---

## 故障排查

### 日志没有输出？

1. 检查 `global.enabled` 是否为 `true`
2. 检查日志级别是否满足要求
3. 检查路径/分类配置是否禁用了该日志
4. 确认配置文件 JSON 格式正确

### 如何查看配置是否加载成功？

启动时会打印：
```
[DebugConfig] 配置加载成功
```
或
```
[DebugConfig] 配置文件不存在: xxx，使用默认配置
```

### 如何调试配置本身？

临时在代码中打印配置：
```gdscript
func _ready():
    print("路径配置: ", DebugConfig.path_configs)
    print("分类配置: ", DebugConfig.category_configs)
    print("全局级别: ", DebugConfig.global_min_level)
```

---

## 完整示例

```gdscript
# player.gd
extends CharacterBody2D

func _ready():
    DebugConfig.info("玩家初始化完成")

func take_damage(amount: int):
    health -= amount
    DebugConfig.info("受到伤害: %d, 剩余血量: %d" % [amount, health], "", "combat")

    if health <= 0:
        DebugConfig.warn("玩家血量为0", "", "player")
        die()

func die():
    DebugConfig.error("玩家死亡!", "", "player")
```

配置文件：
```json
{
  "global": {
    "enabled": true,
    "min_level": "INFO"
  },
  "category_configs": {
    "combat": {
      "enabled": true,
      "min_level": "INFO"
    },
    "player": {
      "enabled": true,
      "min_level": "WARNING"
    }
  }
}
```

输出结果：
```
[14:30:00] [INFO] [player.gd] 玩家初始化完成
[14:30:05] [INFO] [combat] [player.gd] 受到伤害: 20, 剩余血量: 80
[14:30:10] [INFO] [combat] [player.gd] 受到伤害: 50, 剩余血量: 30
[14:30:15] [INFO] [combat] [player.gd] 受到伤害: 30, 剩余血量: 0
[14:30:15] [WARNING] [player] [player.gd] 玩家血量为0
[14:30:15] [ERROR] [player] [player.gd] 玩家死亡!
```

---

## 迁移指南

从旧的调试系统迁移：

```gdscript
# 旧代码
if DebugConfig.debug_combat:
    print("造成伤害: ", damage)

# 新代码
DebugConfig.info("造成伤害: %d" % damage, "", "combat")
```

---

## 常见配置模板

### 开发模式（全开）
```json
{
  "global": {"enabled": true, "min_level": "DEBUG"}
}
```

### 测试模式（关键信息）
```json
{
  "global": {"enabled": true, "min_level": "INFO"}
}
```

### 发布模式（只显示错误）
```json
{
  "global": {"enabled": true, "min_level": "ERROR"}
}
```

### 调试特定功能
```json
{
  "global": {"enabled": true, "min_level": "ERROR"},
  "path_configs": {
    "Scenes/enemies/boss/": {"enabled": true, "min_level": "DEBUG"}
  }
}
```
