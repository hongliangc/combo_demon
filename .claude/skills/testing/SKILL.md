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
