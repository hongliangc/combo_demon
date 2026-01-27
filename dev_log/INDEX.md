# 开发日志索引

> **快速导航** | 按类型分类 | 按日期排序 | 快速检索

---

## 🚀 快速访问

| 文档 | 类型 | 用途 | Token估算 |
|------|------|------|----------|
| [📅 时间线](TIMELINE.md) | 索引 | 按日期查看所有开发记录 | ~500 |
| [📋 快速参考](QUICK_REFERENCE.md) | 摘要 | 核心信息速览（低Token） | ~300 |
| [📊 优化计划](optimization_work_plan.md) | 计划 | 整体优化任务追踪 | ~1000 |

---

## 📂 按类型分类

### 🐛 Bug修复

| 日期 | 标题 | 问题 | Token |
|------|------|------|-------|
| 2026-01-19 | [特殊攻击后无法移动](bug-fixes/player_autonomous_components_implementation_2026-01-19.md#问题发现) | SkillManager未恢复can_move | ~800 |
| 2026-01-18 | [await内存泄漏修复](bug-fixes/await_memory_leak_fix_2026-01-18.md) | Effect使用await可能泄漏 | ~800 |

---

### ✨ 特性开发

| 日期 | 标题 | 功能 | Token |
|------|------|------|-------|
| 2026-01-25 | [V技能特殊攻击](features/special_attack_v_skill.md) | 残影+漩涡聚集攻击完整实现 | ~5000 |
| 2026-01-18 | [Hitbox统一实现](planning/optimization_work_plan.md#1-统一hitbox实现) | 统一子弹Hitbox配置 | ~200 |
| 2026-01-18 | [Hitbox碰撞层配置](planning/optimization_work_plan.md#4-添加碰撞层配置到hitbox) | @export_flags_2d_physics | ~100 |

---

### 🏗️ 重构优化

| 日期 | 标题 | 改进 | Token |
|------|------|------|-------|
| 2026-01-18~19 | [Player自治组件架构](refactoring/autonomous_component_architecture_2026-01-18.md) | 5组件自治架构 | ~800 |
| 2026-01-18 | [架构评审](architecture/architecture_review_2026-01-18.md) | 11项优化建议 | ~1200 |

---

### 📐 架构设计

#### 模块化架构文档 ⭐⭐⭐

| # | 模块 | 文档 | Token |
|---|------|------|-------|
| 0 | **总览** | [架构总览](architecture/00_architecture_overview.md) | ~600 |
| 1 | **状态机** | [状态机系统](architecture/01_state_machine_architecture.md) | ~1000 |
| 2 | **战斗系统** | [战斗系统](architecture/02_combat_system_architecture.md) | ~1500 |
| 3 | **组件系统** | [组件系统](architecture/03_component_system_architecture.md) | ~1000 |
| 4 | **信号驱动** | [信号驱动](architecture/04_signal_driven_architecture.md) | ~900 |
| 5 | **Autoload** | [Autoload系统](architecture/05_autoload_system_architecture.md) | ~800 |
| 6 | **技能系统** | [技能系统](architecture/06_skill_system_architecture.md) | ~1000 |

#### 原有架构文档

| 日期 | 标题 | 内容 | Token |
|------|------|------|-------|
| 2026-01-19 | [UML架构图](architecture/architecture_uml_diagrams.md) | 5类UML图表 | ~2000 |
| 2026-01-19 | [Hitbox/Hurtbox架构](architecture/hitbox_hurtbox_architecture_2026-01-19.md) | 战斗系统详细设计 | ~2000 |
| 2026-01-18 | [架构评审](architecture/architecture_review_2026-01-18.md) | 11项优化建议 | ~800 |
| 2026-01-18 | [组件架构设计](refactoring/autonomous_component_architecture_2026-01-18.md) | 自治组件模式 | ~800 |
- **生命周期**: 完整的状态管理

---

### 📋 规划文档

| 日期 | 标题 | 用途 | Token |
|------|------|------|-------|
| 2026-01-18 | [优化工作计划](planning/optimization_work_plan.md) | 11项任务追踪 | ~1000 |
| 2026-01-19 | [会话总结](sessions/session_summary_2026-01-19.md) | 本次会话记录 | ~400 |

---

### 🔧 工具文档

| 日期 | 标题 | 用途 | Token |
|------|------|------|-------|
| 2026-01-18 | [Session Hook指南](tools/sessionstart_hook_guide.md) | Hook使用说明 | ~800 |
| 2026-01-18 | [Token优化报告](tools/token_optimization_report.md) | Token使用分析 | ~800 |

---

## 📅 按日期浏览

### 2026-01-25
- ✨ [V技能特殊攻击完整实现](features/special_attack_v_skill.md)

### 2026-01-19
- 🐛 [特殊攻击Bug修复](bug-fixes/player_autonomous_components_implementation_2026-01-19.md)
- 📐 [UML架构图](architecture/architecture_uml_diagrams.md)
- 📋 [会话总结](planning/session_summary_2026-01-19.md)

### 2026-01-18
- 🏗️ [Player组件重构](refactoring/autonomous_component_architecture_2026-01-18.md)
- 🐛 [await内存泄漏修复](bug-fixes/await_memory_leak_fix_2026-01-18.md)
- 📐 [架构评审](architecture/architecture_review_2026-01-18.md)
- 📋 [优化计划](planning/optimization_work_plan.md)

完整时间线 → [TIMELINE.md](TIMELINE.md)

---

## 🔍 快速检索

### 按关键词

| 关键词 | 相关文档 |
|--------|---------|
| **V技能** | [完整实现文档](features/special_attack_v_skill.md), [技能系统架构](architecture/06_skill_system_architecture.md) |
| **残影特效** | [V技能实现](features/special_attack_v_skill.md#1-残影放大效果实现), [GhostExpandEffect](features/special_attack_v_skill.md#技术细节) |
| **敌人聚集** | [V技能实现](features/special_attack_v_skill.md#2-敌人聚集位置修正), [问题解决](features/special_attack_v_skill.md#问题与解决方案) |
| **自治组件** | [架构设计](refactoring/autonomous_component_architecture_2026-01-18.md), [实施记录](bug-fixes/player_autonomous_components_implementation_2026-01-19.md), [UML图](architecture/architecture_uml_diagrams.md) |
| **特殊攻击** | [V技能完整文档](features/special_attack_v_skill.md), [Bug修复](bug-fixes/player_autonomous_components_implementation_2026-01-19.md#问题发现), [流程图](architecture/architecture_uml_diagrams.md#2-特殊攻击流程时序图) |
| **信号通信** | [架构设计](refactoring/autonomous_component_architecture_2026-01-18.md#信号通信), [UML图](architecture/architecture_uml_diagrams.md#3-信号通信架构图) |
| **await问题** | [V技能-call_deferred](features/special_attack_v_skill.md#问题7-按v时没有残影效果), [内存泄漏](bug-fixes/await_memory_leak_fix_2026-01-18.md), [特殊攻击Bug](bug-fixes/player_autonomous_components_implementation_2026-01-19.md#技术细节) |
| **状态机** | [架构评审](architecture/architecture_review_2026-01-18.md#状态机系统), [优化计划](planning/optimization_work_plan.md#5-重构stunstate---职责分离) |

### 按组件

| 组件 | 相关文档 |
|------|---------|
| **SkillManager** | [V技能完整实现](features/special_attack_v_skill.md), [Bug修复](bug-fixes/player_autonomous_components_implementation_2026-01-19.md), [UML图](architecture/architecture_uml_diagrams.md) |
| **MovementComponent** | [架构设计](refactoring/autonomous_component_architecture_2026-01-18.md#movementcomponent), [类图](architecture/architecture_uml_diagrams.md#1-player组件类图) |
| **CombatComponent** | [架构设计](refactoring/autonomous_component_architecture_2026-01-18.md#combatcomponent), [信号图](architecture/architecture_uml_diagrams.md#3-信号通信架构图) |
| **Hitbox** | [优化计划](planning/optimization_work_plan.md#1-统一hitbox实现), [架构评审](architecture/architecture_review_2026-01-18.md) |

---

## 📊 统计信息

### 开发进度
- **已完成任务**: 4/11 (36%)
- **高优先级**: 4/4 完成 ✅
- **中优先级**: 0/4 待处理
- **低优先级**: 0/3 可选

### 代码指标
- **Player主类**: -57% (278行 → 119行)
- **组件数量**: 5个
- **删除文件**: 2个
- **Bug修复**: 2个

### 文档统计
- **总文档数**: 11个
- **总字数**: ~80,000
- **平均Token**: ~800/文档

---

## 💡 使用建议

### 1. 新手入门
阅读顺序：
1. [快速参考](QUICK_REFERENCE.md) - 了解整体架构
2. [优化计划](optimization_work_plan.md) - 了解任务进度
3. [UML图](architecture_uml_diagrams.md) - 可视化理解

### 2. Bug排查
查找路径：
1. [时间线](TIMELINE.md) - 找到相关日期
2. Bug修复章节 - 查看详细分析
3. [UML图](architecture_uml_diagrams.md) - 理解流程

### 3. 架构学习
学习路径：
1. [架构评审](architecture_review_2026-01-18.md) - 了解问题
2. [架构设计](autonomous_component_architecture_2026-01-18.md) - 学习方案
3. [UML图](architecture_uml_diagrams.md) - 深入理解
4. [实施记录](player_autonomous_components_implementation_2026-01-19.md) - 实践经验

### 4. 日常开发
工作流程：
1. [优化计划](optimization_work_plan.md) - 查看待办任务
2. 相关文档 - 了解背景知识
3. 实施 → 测试 → 记录

---

## 🔄 更新日志

| 日期 | 变更 |
|------|------|
| 2026-01-25 | ✅ 完成V技能特殊攻击完整实现文档 |
| 2026-01-25 | ✅ 修复所有V技能相关问题（残影、聚集、镜头、漩涡） |
| 2026-01-19 | ✅ 创建索引系统，优化文档组织 |
| 2026-01-19 | ✅ 添加UML架构图 |
| 2026-01-19 | ✅ 修复特殊攻击Bug |
| 2026-01-18 | ✅ 完成Player组件重构 |
| 2026-01-18 | ✅ 修复await内存泄漏 |

---

**最后更新**: 2026-01-25
**维护者**: Claude + 用户
**版本**: v1.1
