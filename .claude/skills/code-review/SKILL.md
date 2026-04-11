---
name: code-review
description: "Code review for Combo Demon changes. Use after feature development and testing are complete, to review changed code for architecture compliance, coding standards, safety, and performance. Triggers on: code review, CR, review code, check code."
---

# 代码审查指南

## 流程

### Step 1: 收集变更
`git diff --name-only` + `git diff --stat` + `git diff`，按架构层归类（Framework > Services > Business > Presentation）。

### Step 2: 逐层审查

**架构合规**: 文件在正确层目录、无跨层直接调用、依赖方向正确

**编码规范**: 命名规范+类型注解、@export 配置化、信号通信、状态继承 BaseState 用 helper、exit() 断开信号+停 Timer
> 详细 → `godot-coding-standards` skill

**安全性**: `is_instance_valid()` 动态引用、懒缓存、await 后检查有效性、物理层/group 正确

**性能**: _process 无重复查询、preload 替代 load、对象池高频创建、热路径无临时对象

### Step 3: 输出报告

| 级别 | 含义 | 处理 |
|------|------|------|
| **P0** | bug/安全/架构违规 | 必须修，修后重新 testing |
| **P1** | 不符规范但不影响功能 | 用户决定 |
| **P2** | 可优化 | 记录 |
