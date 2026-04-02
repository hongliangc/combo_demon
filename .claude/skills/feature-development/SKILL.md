---
name: feature-development
description: "General-purpose development skill for Combo Demon. Use when implementing new features, refactoring, or optimizing: enemies, bosses, attack effects, components, traps, gameplay systems, architecture adjustments, code cleanup, or performance optimization. Triggers on: new enemy, new boss, new effect, new component, new trap, new feature, implement, develop, create, add, refactor, optimize, split, decouple, migrate, restructure, cleanup, 重构, 优化, 拆分, 解耦, 迁移, 架构调整, 代码清理."
---

# 通用功能开发指南

接到开发需求时，按本 skill 流程执行：识别需求类型 → 加载对应指南 → 按模式实现 → 验证 → CR → 更新文档。

## 需求分类与指南映射

接到需求后，先判断类型，读取对应 reference：

| 需求类型 | 关键词 | 读取的 reference |
|---------|-------|-----------------|
| 新敌人/角色 | 敌人, enemy, 怪物, mob | `references/enemy-guide.md` |
| 新 Boss | Boss, 首领, 头目 | `references/boss-guide.md` |
| 新攻击效果/伤害类型 | 效果, effect, 击退, 眩晕, 伤害 | `references/effect-guide.md` |
| 新组件/系统 | 组件, component, 系统, system | `references/component-guide.md` |
| 新陷阱/机关 | 陷阱, trap, 机关, 障碍 | `references/trap-guide.md` |
| 新关卡 | 关卡, level, 地图 | 触发 `godot-level-design` skill |
| **重构/优化** | 重构, refactor, 拆分, split, 解耦, decouple, 优化, optimize, 迁移, migrate, 架构调整, restructure, 代码清理, cleanup | `references/refactoring-guide.md` |
| 其他 | — | 读取 `project-architecture` skill 定位涉及的架构层 |

> 如果需求跨多个类型（如"新敌人 + 新攻击效果"），依次加载相关 reference。
> 重构和优化也是开发——遵循同样的完整流程。

## 通用开发流程

**所有类型共用此流程**：

### Step 1: 架构定位
读取 `project-architecture` skill，确认：
- 需求涉及哪些架构层（Framework / Services / Business / Presentation）
- 新代码应放在哪个目录
- 需要继承/使用哪些基类

### Step 2: 加载开发指南
根据需求类型，读取对应 reference 文件，获取：
- 场景结构模板（节点树）
- 脚本代码骨架
- 需要连接的信号
- 需要创建的 Resource 文件

### Step 3: 实现
按 reference 中的模板实现，遵循以下规则：
- **继承优先**：使用已有基类（BaseState, EnemyBase, BossBase），只重写钩子方法
- **信号解耦**：组件间通过信号通信，不直接引用
- **编辑器配置**：Node 派生对象在编辑器创建，代码只控制参数
- **@export 配置化**：可调参数用 @export 暴露，不硬编码
- **懒缓存**：`get_tree()` 查询结果缓存，不在 _process 中重复查询

### Step 4: 验证
触发 `testing` skill，执行三层验证（日志 → GUT → MCP）。

### Step 5: Code Review
触发 `code-review` skill，审查代码质量和架构合规。

### Step 6: 架构文档与 Skill 更新（CR 通过后）
**仅在开发完毕 + 测试通过 + CR 无问题后**，触发 `context-updater` skill，按更新检查矩阵逐项判断：
- 架构文档（ARCHITECTURE.md、class-diagrams.md、architecture-diagrams.md）
- Skill references（module-registry、scene-templates、enemy/boss/effect guide 等）
- 入口文件（CLAUDE.md 概览信息）

## 重构/优化开发流程

**当需求类型为重构或优化时**，使用此专用流程：

### Step 1: 影响范围分析
- 读取 `project-architecture` skill 确认涉及的架构层
- 用 `grep` 搜索所有引用点（类名、方法名、信号名）
- 列出所有受影响的文件清单

### Step 2: 加载重构指南
读取 `references/refactoring-guide.md`，匹配重构模式：
- God Object 拆分
- 信号解耦
- Resource 迁移
- 硬编码提取
- 命名规范化

### Step 3: 分步实施
- **一次只改一件事**，每步可独立验证
- 保持 API 兼容（如果有外部调用者）
- 先改结构再改行为

### Step 4: 回归验证
- 运行所有相关 GUT 测试
- MCP 运行游戏验证无回归
- 检查受影响文件的信号连接完整性

### Step 5: Code Review
触发 `code-review` skill，审查重构质量和架构合规。

### Step 6: 架构文档与 Skill 更新（CR 通过后）
**仅在开发完毕 + 测试通过 + CR 无问题后**，触发 `context-updater` skill：
- 如果改变了类结构/继承关系 → 更新 `docs/class-diagrams.md`
- 如果改变了数据流/状态 → 更新 `docs/architecture-diagrams.md`
- 如果引入了新开发模式/踩坑经验 → 更新对应 skill reference
- 如果改变了项目统计 → 更新 `CLAUDE.md` 和 `docs/ARCHITECTURE.md`

## 完整流程图

```
实现 → 测试(testing) → CR(code-review) → [CR 通过?]
                                              │
                                    Yes ──→ 更新文档(context-updater)
                                    No  ──→ 返回修改 → 重新测试 → 重新 CR
```

## 开发检查清单

> 编码规范详情 → `godot-coding-standards` skill

- [ ] 新文件放在正确的架构层目录
- [ ] 遵循 `godot-coding-standards` 规范（命名、@export、信号、编辑器优先、类型注解）
- [ ] 状态继承 BaseState，exit() 断开信号 + 停止 Timer
- [ ] `is_instance_valid()` + 懒缓存
- [ ] 重构：所有引用点已更新，无遗留旧引用
- [ ] 重构：受影响场景 .tscn 已验证节点引用正确
