# Combo Demon - 开发日志

> **项目**: Combo Demon
> **引擎**: Godot 4.4.1
> **开发者**: [Your Name]
> **创建日期**: 2025-12-22

---

## 📋 当前开发状态

### 🎯 当前任务
- [ ] 实现完整的技能系统工作流
- [ ] 添加 Skills 自动化工作流

### ✅ 已完成功能
- [x] 角色基础移动系统 (hahashin.gd)
- [x] 敌人AI状态机 (enemy_state_machine.gd)
- [x] 伤害类型系统 (Damage.gd: Physical, KnockUp, KnockBack)
- [x] Hitbox/Hurtbox 碰撞系统
- [x] 武器系统 (近战爪击, 远程弹药)
- [x] 音效管理器 (SoundManager)
- [x] MCP Godot 集成

### 🔧 当前架构
```
核心系统：
- 角色系统: Scenes/charaters/hahashin.gd
- 敌人系统: Scenes/enemies/dinosaur/
- 战斗系统: Util/Components/ (health, hitbox, hurtbox)
- 武器系统: Weapons/ (slash, bullet)
- 自动加载: SoundManager, DamageNumbers
```

---

## 🐛 已知问题和解决方案

### 问题列表

#### [P1] 暂无严重问题

#### [P2] 需要改进
- 缺少完整的技能系统（冷却、消耗、效果）
- 缺少技能管理器

---

## 💡 重要决策记录

### 决策 #1: 使用 Resource 系统管理技能数据
**日期**: 2025-12-22
**原因**: Godot 的 Resource 系统支持可视化编辑和序列化
**影响**: 所有技能数据将作为 .tres 资源文件存储

### 决策 #2: 实现 Skills 工作流自动化
**日期**: 2025-12-22
**原因**: 提高开发效率，确保代码质量
**内容**:
- SessionStart Hook 自动读取开发日志
- 强制记录重要问题和解决方案
- 内置编码规范自动检查

---

## 📝 开发笔记

### 2025-12-22
**主题**: 项目初始化和工作流设置
- 创建开发日志系统
- 配置 SessionStart Hook
- 设置编码规范

**遇到的问题**: 无

**解决方案**: 无

**下一步**:
1. 实现完整的技能系统基类
2. 创建技能管理器 (SkillManager)
3. 添加技能冷却和消耗机制

---

## 🎓 学到的经验

### Godot 最佳实践
1. 使用 Resource 管理数据，方便复用和编辑
2. 使用 AutoLoad 单例管理全局系统
3. 组件化设计（Health, Hitbox, Hurtbox）
4. 状态机模式管理复杂行为

### Claude Code 最佳实践
1. 使用 SessionStart Hook 实现会话自动初始化
2. 维护开发日志追踪问题和决策
3. 使用 Skills 定义工作流和编码规范

---

## 📊 代码质量检查清单

### GDScript 编码规范
- [ ] 类名使用 PascalCase
- [ ] 变量名使用 snake_case
- [ ] 导出变量使用 @export
- [ ] 类型提示完整 (func_name() -> ReturnType:)
- [ ] 信号使用 signal 关键字
- [ ] 常量使用 UPPER_CASE

### 性能检查
- [ ] 避免在 _process() 中创建对象
- [ ] 使用对象池管理频繁创建的对象
- [ ] 使用 @onready 延迟节点引用

---

## 🔗 相关资源

- [Godot 文档](https://docs.godotengine.org/)
- [GDScript 风格指南](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- [项目 README](../README.md)
- [MCP 使用指南](../MCP使用指南.md)

---

**最后更新**: 2025-12-22
**会话总结**: 项目初始化，创建工作流系统
