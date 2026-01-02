# Claude Code Skills 部署和使用指南

## 📋 已部署的 Skills

### 1. **godot-coding-standards**
**位置**: `.claude/skills/godot-coding-standards.md`
**用途**: Godot 4.x 项目编码规范
**状态**: ✅ 已激活

**功能特性**:
- 命名规范（变量、函数、类、常量）
- 类型注解最佳实践
- Export 变量组织规范
- 组件化设计模式
- 性能优化指南
- 错误处理标准
- 代码组织结构
- 完整的检查清单

---

## 🔍 如何检测已部署的 Skills

### 方法 1: 使用文件系统查找

```bash
# 在项目根目录执行
ls -la .claude/skills/
# 或
find .claude/skills -name "*.md"
```

### 方法 2: 使用 Glob 模式搜索

在 Claude Code 中执行：
```
搜索 .claude/skills/**/*.md
```

### 方法 3: 检查配置文件

查看 `.claude/settings.local.json` 确认启用的 skills：
```json
{
  "skills": {
    "enabled": ["godot-coding-standards"]
  }
}
```

---

## 💡 如何使用 Skills

### 自动激活

Skills 会在相关场景下自动激活。例如：

#### 示例 1: 编写新代码时
```
用户: "帮我创建一个新的敌人类"
Claude: [自动引用 godot-coding-standards skill]
        根据编码规范，我会创建一个符合标准的敌人类...
```

#### 示例 2: 代码审查时
```
用户: "检查这段代码是否符合规范"
Claude: [自动应用 coding standards 检查清单]
        让我检查这段代码...
```

### 手动调用

你也可以明确请求使用 skill：

```
"根据 godot-coding-standards 重构这段代码"
"使用编码规范创建一个新的组件"
"检查代码是否符合我们的 coding standards"
```

---

## 🧪 测试 Skills 功能

### 运行编码规范测试

1. **打开测试场景**
   ```bash
   # 在 Godot 编辑器中打开
   test_scene.tscn
   ```

2. **运行测试**
   - 在 Godot 中按 F5 运行场景
   - 或使用命令行：
   ```bash
   godot --headless test_scene.tscn
   ```

3. **查看测试结果**
   ```
   ========== 测试总结 ==========
   总测试数: 6
   通过: 6 (100.0%)
   失败: 0
   ==============================
   ```

### 测试覆盖范围

| 测试项 | 检查内容 |
|--------|----------|
| 命名规范 | snake_case、PascalCase、UPPER_SNAKE_CASE |
| 类型注解 | 变量和函数的类型声明 |
| Export 分组 | @export_group 使用 |
| 信号使用 | 信号声明和连接 |
| 组件模式 | 组件独立性和复用性 |
| 错误处理 | 空值检查和安全访问 |
| 性能优化 | 节点缓存和常量使用 |

---

## 📖 Skills 详细内容

### godot-coding-standards

#### 核心设计原则

1. **通用性 (Universality)**
   - 适用于任何 Godot 4.x 项目
   - 不依赖特定项目结构
   - 基于官方最佳实践

2. **模块化 (Modularity)**
   - 单一职责原则
   - 组件化设计
   - 松耦合架构

3. **可复用性 (Reusability)**
   - 可重用的组件
   - Resource 类模板
   - 跨项目共享

4. **简洁实用 (Simplicity)**
   - 代码简洁明了
   - 避免过度抽象
   - 注重性能

#### 快速参考

**命名规范**:
```gdscript
class_name Player          # PascalCase
var max_health: float      # snake_case
const MAX_SPEED = 200.0    # UPPER_SNAKE_CASE
signal health_changed()    # snake_case (过去式)
```

**类型注解**:
```gdscript
var health: float = 100.0
var enemies: Array[Enemy] = []
func take_damage(damage: Damage) -> void:
```

**Export 组织**:
```gdscript
@export_group("Health")
@export var max_health: float = 100.0

@export_group("Movement")
@export var move_speed: float = 150.0
```

**组件化设计**:
```gdscript
# 创建可复用组件
extends Node
class_name Health

signal health_changed(current: float, max: float)
signal died()

@export var max_health: float = 100.0
var health: float = max_health
```

---

## ✅ 检查清单

使用此清单确保代码符合规范：

### 通用性检查
- [ ] 使用 `@export` 使组件可配置
- [ ] 避免硬编码路径和值
- [ ] 可以在不同场景中复用

### 模块化检查
- [ ] 遵循单一职责原则
- [ ] 使用组件而非巨型类
- [ ] 通过信号而非直接调用通信

### 可复用性检查
- [ ] 有清晰的公共接口
- [ ] 有文档注释说明用途
- [ ] 可以独立使用

### 代码质量检查
- [ ] 所有变量和函数都有类型注解
- [ ] 使用了正确的命名规范
- [ ] 有必要的错误检查
- [ ] 避免了性能陷阱

### 文档检查
- [ ] 有类级文档注释（##）
- [ ] 复杂方法有参数和返回值说明
- [ ] 使用分隔注释组织代码

---

## 🚀 创建新的 Skills

如果需要创建新的 skill：

### 1. 创建 Skill 文件

```bash
# 在 .claude/skills/ 目录下创建 markdown 文件
.claude/skills/my-new-skill.md
```

### 2. Skill 文件结构

```markdown
# Skill 名称

简短描述这个 skill 的用途

## 使用场景

描述何时应该使用这个 skill

## 核心内容

详细的指导内容、示例代码等

## 检查清单

提供可操作的检查项
```

### 3. 测试 Skill

创建对应的测试文件验证 skill 功能。

---

## 📊 Skills 效果评估

### godot-coding-standards 效果

**测试结果**: ✅ 6/6 通过（100%）

**代码质量提升**:
- ✅ 统一的命名规范
- ✅ 完整的类型注解
- ✅ 良好的代码组织
- ✅ 优化的性能实践
- ✅ 健壮的错误处理

**开发效率提升**:
- ⚡ 减少代码审查时间
- ⚡ 降低 bug 率
- ⚡ 提高代码可维护性
- ⚡ 加速新人上手

---

## 🔧 故障排除

### Skill 未激活

**问题**: Skill 存在但未生效

**解决方案**:
1. 检查文件位置是否正确（`.claude/skills/`）
2. 确认文件扩展名为 `.md`
3. 验证 markdown 格式正确
4. 重启 Claude Code

### 测试失败

**问题**: 运行测试时出现错误

**解决方案**:
1. 检查 Godot 版本（需要 4.4.1+）
2. 确认测试场景路径正确
3. 查看错误日志定位问题
4. 参考 [test_coding_standards.gd](../test_coding_standards.gd)

---

## 📚 相关资源

- [编码规范完整文档](skills/godot-coding-standards.md)
- [测试脚本](../test_coding_standards.gd)
- [测试场景](../test_scene.tscn)
- [实施总结](../CODING_STANDARDS_SUMMARY.md)

---

## 💬 反馈和改进

如果发现 skills 有问题或需要改进：

1. 记录具体问题
2. 提出改进建议
3. 更新 skill 文档
4. 重新运行测试验证

---

*最后更新: 2025-12-20*
*当前 Skills 版本: 1.0*
*Godot 版本: 4.4.1*
