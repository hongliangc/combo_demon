---
name: code-review
description: "Code review for Combo Demon changes. Use after feature development and testing are complete, to review changed code for architecture compliance, coding standards, safety, and performance. Triggers on: code review, CR, review code, check code."
---

# 代码审查指南

功能开发 + 测试验证完毕后，对本次变更代码进行审查。

## 触发条件

- 功能开发完成 + `testing` skill 验证通过后
- 用户主动要求 CR

## 审查流程

### Step 1: 收集变更范围

```bash
git diff --name-only          # 获取所有变更文件
git diff --stat               # 变更统计
git diff                      # 完整 diff
```

将变更文件按架构分层归类：

| 层 | 审查优先级 | 原因 |
|---|----------|------|
| **Framework** | 最高 | 底层变更影响面最大 |
| **Services** | 高 | 全局服务影响所有场景 |
| **Business** | 中 | 业务逻辑影响特定功能 |
| **Presentation** | 低 | 场景/资源变更影响最小 |

### Step 2: 逐层审查

按优先级从高到低审查，对每个变更文件检查以下维度：

#### 架构合规
- [ ] 文件放置在正确的架构层目录
- [ ] 没有跨层直接调用（Business 不直接操作 Framework 内部）
- [ ] 新增依赖方向正确（上层 → 下层，不反向）
- [ ] 没有在 Framework 层引入 Business 特定逻辑

#### 编码规范 + 状态机规范
> 详细检查项 → `godot-coding-standards` skill
- [ ] 命名规范（PascalCase/snake_case/UPPER_SNAKE）+ 类型注解
- [ ] `@export` 配置化，信号通信，编辑器配置节点
- [ ] 状态继承 BaseState，用内置 helper，不直接操作 AnimationTree
- [ ] `exit()` 中断开 animation_finished 信号 + 停止 Timer
- [ ] `transitioned.emit(self, ...)` 发出切换，优先级正确

#### 安全性
- [ ] `is_instance_valid()` 检查动态引用（target_node、缓存的节点）
- [ ] 懒缓存模式用于 `get_tree()` 查询（不在 _process 中重复查询）
- [ ] `await` 后检查节点有效性（`if not is_instance_valid(self): return`）
- [ ] 物理层 Layer/Mask 配置正确
- [ ] group 归属正确（"player"/"enemy"）

#### 性能
- [ ] `_process` / `_physics_process` 中无重复查询（使用缓存变量）
- [ ] `preload` 替代 `load`（已知路径时）
- [ ] 对象池用于高频创建/销毁（子弹、特效）
- [ ] 避免在热路径中创建临时对象（Array、Dictionary）

### Step 3: 输出审查报告

```markdown
# Code Review Report

## 变更概述
- **变更文件**: N 个
- **涉及架构层**: Framework / Business / ...
- **影响范围**: 简述影响的功能模块

## 问题列表

| 级别 | 文件:行号 | 问题描述 | 建议修复 |
|------|----------|---------|---------|
| P0-必须修 | path/file.gd:42 | 描述 | 修复建议 |
| P1-建议改 | path/file.gd:78 | 描述 | 修复建议 |
| P2-可优化 | path/file.gd:123 | 描述 | 修复建议 |

## 通过项
- 列出审查通过的维度
```

### 级别定义

| 级别 | 含义 | 处理方式 |
|------|------|---------|
| **P0-必须修** | 会导致 bug、安全问题、架构违规 | 修复后重新触发 `testing` skill 验证 |
| **P1-建议改** | 不符合规范但不影响功能 | 由用户决定是否修复 |
| **P2-可优化** | 可以改进但当前可接受 | 记录，后续优化 |

### Step 4: 修复验证

- P0 问题修复后，重新触发 `testing` skill 验证
- 验证通过后，更新审查报告状态
- P1/P2 由用户决定是否修复
