# 快速参考

> **核心信息速览** | 低Token消耗 (~300 tokens) | 快速上手

---

## 🎯 项目状态

**优化进度**: 4/11 (36%)
**主要成果**: Player自治组件架构 + 2个Bug修复
**当前阶段**: 第一阶段完成，第二阶段待启动

---

## 🏗️ Player自治组件架构 (核心重构)

### 架构概览
```
Hahashin (119行, -57%)
├── HealthComponent - 生命值管理
├── MovementComponent - 自动输入/移动
├── AnimationComponent - AnimationTree管理
├── CombatComponent - 技能输入检测
└── SkillManager - 特殊攻击完整流程
```

### 关键特性
- ✅ **自治运行**: 组件自己执行_process/_physics_process
- ✅ **信号解耦**: 组件间通过信号通信，零依赖
- ✅ **依赖注入**: call_deferred("_find_components")
- ✅ **生命周期**: 完整的状态管理（初始化→执行→恢复）

### 设计模式
组件模式、观察者模式、模板方法、依赖注入、策略模式

---

## 🐛 已修复Bug

- ✅ [特殊攻击后无法移动](bug-fixes/player_autonomous_components_implementation_2026-01-19.md) - 添加 `await animation_finished`
- ✅ [await内存泄漏](bug-fixes/await_memory_leak_fix_2026-01-18.md) - 改用信号连接

详见 [TIMELINE.md](TIMELINE.md) § 2026-01-19 和 2026-01-18

---

## 📋 待办任务

### 中优先级 (推荐下一步)
5. **StunState重构** - 拆分物理模拟和状态管理 (2-3h)
6. **状态名称常量化** - 避免字符串拼写错误 (1-2h)
7. **统一调试输出** - 替换print()为DebugConfig (1h)
8. **Boss阶段转换解耦** - 使用信号通知 (0.5h)

### 低优先级 (可选)
9. 目录结构重构 (5h, ⚠️高风险)
10. 技能Resource系统 (3.5h)
11. UI状态指示器 (2.5h)

---

## 📐 核心流程

### 特殊攻击流程 (SkillManager)
```
1. 检测 → 扇形范围检测敌人
2. 禁用 → can_move = false
3. 移动 → Tween移动到敌人
4. 动画 → await play + await finished 🔑
5. 恢复 → can_move = true ✅
```

### 组件生命周期
```
_ready() → _find_components() → connect signals → [运行]
                                                      ↓
                                    _process / _physics_process
```

---

## 🔍 快速检索

### 按问题查找
| 问题 | 查看文档 |
|------|---------|
| 特殊攻击不能移动 | [Bug修复](bug-fixes/player_autonomous_components_implementation_2026-01-19.md) |
| 内存泄漏 | [await修复](bug-fixes/await_memory_leak_fix_2026-01-18.md) |
| 组件如何通信 | [架构设计](refactoring/autonomous_component_architecture_2026-01-18.md) |
| 如何添加新组件 | [重构指南](refactoring/player_refactoring_guide_2026-01-18.md) |

### 按学习路径
1. **入门**: [INDEX.md](INDEX.md) → [TIMELINE.md](TIMELINE.md)
2. **架构**: [架构设计](refactoring/autonomous_component_architecture_2026-01-18.md) → [UML图](architecture/architecture_uml_diagrams.md)
3. **实战**: [重构指南](refactoring/player_refactoring_guide_2026-01-18.md) → [优化计划](planning/optimization_work_plan.md)

---

## 💡 关键经验

### await正确使用
```gdscript
// ❌ 错误：调用但不等待
_async_function()

// ✅ 正确：传递await
await _async_function()
```

### 生命周期管理
```gdscript
func autonomous_operation():
    save_state()    // 1. 保存
    modify_state()  // 2. 修改
    await execute() // 3. 执行
    restore_state() // 4. 恢复 ← 必须！
```

### 信号驱动
```gdscript
// 发射者
signal skill_started(name: String)
skill_started.emit("atk_sp")

// 接收者
combat_component.skill_started.connect(_on_skill_started)
```

---

## 📊 关键指标

| 指标 | 数值 |
|------|------|
| 主类代码量 | -57% (278→119行) |
| 组件数量 | 5个 |
| 组件耦合度 | 0 (纯信号) |
| 已修复Bug | 2个 |
| 删除重复代码 | 4个文件 |

---

## 🚀 下一步建议

### 立即可做 (1-2小时)
- 统一调试输出 (1h)
- 状态名称常量化 (1.5h)
- Boss阶段转换解耦 (0.5h)

### 中期优化 (2-3小时)
- StunState重构 (2.5h)
- Todo.md中的SP攻击优化

---

**Token估算**: ~300
**最后更新**: 2026-01-19
**用途**: 快速了解项目状态和核心信息
