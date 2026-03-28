---
name: testing
description: "Functional testing and verification for Combo Demon. Use after feature development to validate with GUT unit tests, debug logs, and MCP runtime verification. Triggers on: test, verify, validate, check, unit test, GUT, testing, verification."
---

# 功能验证指南

功能开发完毕后，按三层验证流程确认功能正确性。

## 测试框架

**GUT (Godot Unit Test)** — 安装在 `addons/gut/`

> **前置条件**：需先通过 Godot AssetLib 安装 GUT 插件（搜索 "Gut"），或手动下载到 `addons/gut/`。安装后在 Project → Project Settings → Plugins 中启用。

运行命令：
```bash
godot --headless -s addons/gut/gut_cmdline.gd -gdir=res://test/unit -gexit
```

## 三层验证流程

**必须按顺序执行**，每层通过后才进入下一层：

### Layer 1: 日志断言验证

在关键代码路径添加 DebugConfig 日志，通过 MCP 运行验证日志输出：

```gdscript
DebugConfig.debug("[NewFeature] 初始化完成, param=%s" % param, "", "combat")
DebugConfig.debug("[NewFeature] 效果已应用到 %s" % target.name, "", "combat")
```

执行：
1. `mcp__godot__run_project` — 运行游戏
2. 触发功能场景
3. `mcp__godot__get_debug_output` — 获取日志
4. 检查日志中包含预期的关键路径日志
5. `mcp__godot__stop_project` — 停止

**通过标准**：日志中出现所有预期的关键路径日志，无 ERROR 级别输出。

### Layer 2: GUT 单元测试

根据变更类型生成测试用例：

| 变更类型 | 测试重点 |
|---------|---------|
| 新状态 | enter()/exit() 调用、优先级阻断、信号断开 |
| 新组件 | 信号发射、@export 默认值、边界值 |
| 新 Resource | 属性默认值、has_effect() 检查、效果组合 |
| 新敌人 | 状态机切换链路、伤害触发、死亡处理 |
| 新 Boss | 阶段转换、攻击池、无敌帧 |
| 新效果 | apply_effect() 行为、叠加/互斥 |

测试文件放在 `test/unit/` 目录，命名规则：`test_模块名.gd`

执行：
```bash
godot --headless -s addons/gut/gut_cmdline.gd -gdir=res://test/unit -gexit
```

**通过标准**：所有测试 PASS，无 FAIL。

### Layer 3: MCP 集成验证

运行完整游戏，验证功能在实际场景中表现正确：

1. `mcp__godot__run_project` — 运行游戏
2. 等待游戏加载完成
3. `mcp__godot__get_debug_output` — 获取运行日志
4. 检查：
   - 无 ERROR/WARNING 日志
   - 无 GDScript 运行时错误（null reference 等）
   - 功能相关日志正常输出
5. `mcp__godot__stop_project` — 停止

**通过标准**：无运行时错误，功能日志正常。

## 测试目录结构

```
test/
├── unit/                    # GUT 单元测试
│   ├── test_state_machine.gd
│   ├── test_damage_system.gd
│   ├── test_health_component.gd
│   ├── test_attack_effects.gd
│   └── ...（按模块添加）
├── integration/             # 集成测试（场景级，可选）
├── fixtures/                # 共享测试资源
└── .gutconfig.json          # GUT 配置
```

## GUT 配置文件

`.gutconfig.json`:
```json
{
  "dirs": ["res://test/unit"],
  "should_exit": true,
  "log_level": 2,
  "include_subdirs": true
}
```

## 测试命名规范

```gdscript
# 文件名: test_模块名.gd
# 测试方法: test_功能_场景_预期结果

func test_damage_apply_reduces_health():
    # ...

func test_stun_effect_triggers_stun_state():
    # ...

func test_phase_transition_at_66_percent():
    # ...
```

## 详细测试模式

需要具体的 GUT 测试代码模板，读取 `references/gut-patterns.md`。
