---
name: feature-development
description: "General-purpose development skill for Combo Demon. Use when implementing new features, refactoring, or optimizing: enemies, bosses, attack effects, components, traps, gameplay systems, architecture adjustments, code cleanup, or performance optimization. Triggers on: new enemy, new boss, new effect, new component, new trap, new feature, implement, develop, create, add, refactor, optimize, split, decouple, migrate, restructure, cleanup, 重构, 优化, 拆分, 解耦, 迁移, 架构调整, 代码清理."
---

# 通用功能开发指南

## 需求路由

根据任务类型，Read 对应 reference 后按流程执行：

| 需求类型 | 关键词 | 读取 reference |
|---------|-------|---------------|
| 敌人 | enemy, 怪物, mob | `references/enemy-guide.md` |
| Boss | boss, 首领 | `references/boss-guide.md` |
| 攻击效果 | effect, 击退, 眩晕, 伤害 | `references/effect-guide.md` |
| 组件/系统 | component, 系统 | `references/component-guide.md` |
| 陷阱 | trap, 机关, 障碍 | `references/trap-guide.md` |
| 重构/优化 | refactor, optimize, cleanup | `references/refactoring-guide.md` |
| 关卡 | level, 地图 | 触发 `godot-level-design` skill |
| 其他 | — | 触发 `project-architecture` skill 定位架构层 |

跨多类型时依次加载相关 reference。

## 开发流程

1. **架构定位** — 触发 `project-architecture` skill，确认涉及层/目录/基类
2. **加载指南** — Read 对应 reference，获取模板/信号/Resource
3. **实现** — 继承基类只重写钩子、信号解耦、@export 配置化、懒缓存
4. **验证** — 触发 `testing` skill
5. **CR** — 触发 `code-review` skill
6. **提交** — CR 通过后统一 commit（禁止边开发边提交）
7. **文档更新** — 触发 `context-updater` skill

重构流程同上，Step 1 额外做影响范围分析（grep 所有引用点）。

## 检查清单

- [ ] 文件在正确架构层目录
- [ ] 遵循 `godot-coding-standards`
- [ ] 状态继承 BaseState，exit() 断开信号+停止 Timer
- [ ] `is_instance_valid()` + 懒缓存
- [ ] 重构：所有引用点已更新，.tscn 节点引用正确
