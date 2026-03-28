---
name: feature-development
description: "General-purpose development skill for Combo Demon. Use when implementing new features: enemies, bosses, attack effects, components, traps, or any gameplay system. Triggers on: new enemy, new boss, new effect, new component, new trap, new feature, implement, develop, create, add."
---

# 通用功能开发指南

接到开发需求时，按本 skill 流程执行：识别需求类型 → 加载对应指南 → 按模式实现 → 验证 → 更新上下文。

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
| 其他 | — | 读取 `project-architecture` skill 定位涉及的架构层 |

> 如果需求跨多个类型（如"新敌人 + 新攻击效果"），依次加载相关 reference。

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

### Step 5: 上下文更新
触发 `context-updater` skill，检查是否需要更新 `.claude/context/project_context.md`。

## 开发检查清单

> 编码规范详情 → `godot-coding-standards` skill

- [ ] 新文件放在正确的架构层目录
- [ ] 遵循 `godot-coding-standards` 规范（命名、@export、信号、编辑器优先、类型注解）
- [ ] 状态继承 BaseState，exit() 断开信号 + 停止 Timer
- [ ] `is_instance_valid()` + 懒缓存
