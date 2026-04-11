# Skill 体系设计文档

> 日期：2026-03-28
> 目标：为 Combo Demon 项目生成一套可用于实际开发、排查、测试、审查的 Claude Code skills

---

## 1. 总体方案

**组织方式**：分层引用型（方案 B）

- `project-architecture` 作为基础层，提供架构全景
- 专项 skill 通过 references/ 子文件按需加载
- 语言：元数据（name/description/触发词）英文，正文中文

**Skill 清单**：

| Skill | 用途 | 触发场景 |
|---|---|---|
| `project-architecture` | 架构总览、分层、数据流、模块速查 | 任何 godot 开发/排查对话 |
| `feature-development` | 通用开发流程，按需求类型加载对应指南 | 新增功能/角色/关卡/系统 |
| `troubleshooting` | 按架构分层定位问题 + 日志排查 | bug、报错、异常行为 |
| `testing` | GUT 单元测试 + 日志断言 + MCP 运行验证 | 功能开发完毕后验证 |
| `code-review` | 对变更代码进行审查，输出审查报告 | 开发 + 测试验证通过后 |

**开发工作流**：
```
需求 → feature-development → testing → code-review → context-updater
```

---

## 2. project-architecture（架构总览 skill）

### 2.1 SKILL.md 结构

**触发条件**：任何涉及 godot 开发、排查、架构理解的对话

内容包含：

1. **四层架构总览表**

| 层 | 职责 | 关键目录 |
|---|---|---|
| **Framework**（核心框架） | 与业务无关的通用能力：状态机、组件基类、Resource 基类、Effect 系统 | `Core/StateMachine/`, `Core/Components/`, `Core/Resources/`, `Core/Effects/` |
| **Services**（全局服务） | 跨场景的单例服务：游戏流程、UI管理、音频、调试、对象池 | `Core/Autoloads/` |
| **Business**（业务逻辑） | 具体角色实现：敌人AI、Boss阶段、玩家技能、关卡目标 | `Scenes/Characters/`, `Scenes/Levels/*.gd` |
| **Presentation**（表现层） | 场景组合、UI界面、美术资源 | `Scenes/**/*.tscn`, `Scenes/UI/`, `Assets/` |

2. **数据流速查（三条主链路）**
   - 伤害链路：Input → HitBox → HurtBox → Health → StateMachine → State
   - 状态切换链路：trigger → priority check → exit/enter → animation
   - 关卡流程：GameManager → LevelManager → Level script → objectives

3. **分层定位法（排查用）**
   - 现象 → 判断属于哪一层 → 该层的入口文件和日志通道

4. **索引指向 references/**

### 2.2 references/ 子文件

| 文件 | 内容 | 何时加载 |
|---|---|---|
| `layer-map.md` | 四层架构详细说明：每层包含的文件清单、职责边界、层间通信规则、依赖方向约束 | 需要理解架构细节时 |
| `data-flow.md` | 完整信号链路图（mermaid）、控制流时序图、事件总线清单、Autoload 信号列表 | 排查数据流问题或理解系统交互时 |
| `module-registry.md` | 核心类速查表：类名、文件路径、职责一句话、公共 API 列表、继承关系、依赖关系 | 开发/排查需要定位具体类时 |

---

## 3. feature-development（通用开发 skill）

### 3.1 SKILL.md 结构

**触发条件**：新增功能、新增角色、新增关卡、新增系统等开发需求

内容包含：

1. **需求分类识别** — 接到需求后判断类型，加载对应 reference：

| 需求类型 | 加载的 reference | 备注 |
|---------|-----------------|------|
| 新敌人/角色 | `enemy-guide.md` | |
| 新 Boss | `boss-guide.md` | |
| 新攻击效果/伤害类型 | `effect-guide.md` | |
| 新组件/系统 | `component-guide.md` | |
| 新关卡 | 触发 `godot-level-design` skill | 已有 skill 处理 |
| 新陷阱/机关 | `trap-guide.md` | |
| 其他 | 读取 `project-architecture` 定位涉及的层 | |

2. **通用开发流程**（所有类型共用）：
   - Step 1: 读取 `project-architecture` 确认涉及的架构层
   - Step 2: 读取对应 reference 获取开发模式
   - Step 3: 按模式实现（文件创建、信号接入、Resource 配置）
   - Step 4: 触发 `testing` skill 验证
   - Step 5: 触发 `context-updater` 检查是否需要更新上下文

3. **开发检查清单**（通用）：
   - [ ] 遵循 `godot-coding-standards`
   - [ ] 新文件放在正确的架构层目录
   - [ ] 信号通信而非直接调用
   - [ ] `@export` 配置化，避免硬编码
   - [ ] 编辑器配置节点，代码只控制参数

### 3.2 references/ 子文件

| 文件 | 内容 |
|---|---|
| `enemy-guide.md` | 敌人开发全流程：场景结构模板 → EnemyStateMachine 类型选择（BASIC/RANGED） → 动画接入（BlendTree 规范） → CommonStates 配置 → SpecialSkillState 扩展 → 信号接线清单 |
| `boss-guide.md` | Boss 开发流程：BossBase 继承 → BossPhaseConfig 三阶段配置 → BossAttackManager 攻击池 → 状态机定制 → 相位转换 VFX |
| `effect-guide.md` | 攻击效果开发：AttackEffect 子类 → Damage Resource 组合 → HitBox/HurtBox 接入 → .tres 文件创建 |
| `component-guide.md` | 组件开发：Node 基类 → 信号定义 → @export 参数 → 与现有组件交互模式 → 挂载方式 |
| `trap-guide.md` | 陷阱开发：BaseTrap 继承 → TrapConfig Resource → 激活/冷却循环 → 伤害区域配置 |

**每个 guide 统一结构**：
1. 前置条件（需要了解哪些基类）
2. 场景结构模板（节点树 + 必需组件）
3. 脚本模板（关键代码骨架）
4. 信号接入清单（需要连接/发射的信号）
5. Resource 配置（需要创建的 .tres 文件）
6. 验证要点（该功能的测试检查项）

---

## 4. troubleshooting（问题排查 skill）

### 4.1 SKILL.md 结构

**触发条件**：bug、报错、异常行为、功能不生效、状态卡死等排查场景

内容包含：

1. **分层定位法**（核心方法论）：

| 现象类型 | 可能涉及的层 | 首先检查 |
|---------|------------|---------|
| 动画不播放/错误 | Presentation + Framework | AnimationTree 参数、BlendTree 连接 |
| 伤害不触发 | Framework（组件层） | HitBox/HurtBox 碰撞层、Damage Resource |
| 状态卡死/不切换 | Framework（状态机） | 优先级、exit() 清理、信号断开 |
| 敌人不追踪/不攻击 | Business | chase_range、target 引用、group 配置 |
| UI 不更新 | Services + Presentation | 信号连接、UIManager 层级 |
| 关卡流程异常 | Services | LevelManager 状态、objectives 配置 |

2. **日志排查流程**：
   - Step 1: 确认 DebugConfig 对应通道已开启
   - Step 2: 运行游戏 → MCP 获取日志输出
   - Step 3: 按日志链路追踪数据流

   通道速查：
   - `combat`: 伤害计算、效果触发
   - `state_machine`: 状态切换、优先级判定
   - `animation`: AnimationTree 参数变化
   - `movement`: 移动、物理碰撞

3. **排查检查清单**：
   - [ ] 确认物理层配置（Layer/Mask 对应关系）
   - [ ] 确认信号是否已连接（编辑器 or `_ready()`）
   - [ ] 确认 `is_instance_valid()` 防空引用
   - [ ] 确认 group 归属（player/enemy）

### 4.2 references/ 子文件

| 文件 | 内容 |
|---|---|
| `common-issues.md` | 按模块分类的常见问题速查：现象 → 原因 → 修复步骤。覆盖状态机、伤害系统、动画、物理层、Boss 阶段等高频问题 |

---

## 5. testing（功能验证 skill）

### 5.1 SKILL.md 结构

**触发条件**：功能开发完毕、需要验证、需要编写测试用例

**测试框架**：GUT (Godot Unit Test)

内容包含：

1. **三层验证流程**（必须按顺序执行）：

   **Layer 1: 日志断言验证**
   - 在关键路径插入 `DebugConfig.debug()`
   - MCP 运行游戏 → 获取日志输出
   - 检查日志中是否包含预期链路

   **Layer 2: GUT 单元测试**
   - 根据变更涉及的模块生成/补充测试用例
   - `godot --headless -s addons/gut/gut_cmdline.gd`
   - 验证测试全部通过

   **Layer 3: MCP 集成验证**
   - `mcp__godot__run_project` 运行游戏
   - `mcp__godot__get_debug_output` 获取运行日志
   - 确认无报错、功能表现正常
   - `mcp__godot__stop_project` 停止

2. **测试用例生成规则**：

| 变更类型 | 测试重点 |
|---------|---------|
| 新状态 | enter/exit 调用、优先级阻断、信号断开 |
| 新组件 | 信号发射、@export 默认值、边界值 |
| 新 Resource | 属性默认值、序列化、效果组合 |
| 新敌人 | 状态机切换完整链路、伤害触发 |
| 新 Boss | 阶段转换、攻击池切换、无敌帧 |
| 新效果 | apply_effect 行为、叠加/互斥 |

3. **测试目录结构**：
```
test/
├── unit/              # GUT 单元测试
│   ├── test_state_machine.gd
│   ├── test_damage_system.gd
│   ├── test_components.gd
│   └── ...
├── integration/       # 集成测试（场景级）
└── .gutconfig.json    # GUT 配置
```

4. **GUT 测试模板**：
   - 继承 GutTest
   - `before_each()` / `after_each()` 清理
   - `assert_signal_emitted` / `assert_eq` / `assert_true`
   - 状态机测试：模拟 transition → 验证 current_state
   - 伤害测试：构造 Damage → take_damage → 验证 health

### 5.2 references/ 子文件

| 文件 | 内容 |
|---|---|
| `gut-patterns.md` | GUT 测试模式库：状态机测试模板、信号测试模板、Resource 测试模板、组件测试模板、mock 用法、异步测试（yield）模式 |

---

## 6. code-review（代码审查 skill）

### 6.1 SKILL.md 结构

**触发条件**：功能开发 + 测试验证完毕后，对变更代码进行审查

内容包含：

1. **审查流程**：
   - Step 1: `git diff` 收集变更范围 → 按架构分层归类
   - Step 2: 逐层审查（Framework > Services > Business > Presentation，底层优先）
   - Step 3: 输出审查报告

2. **审查维度检查清单**：

   **架构合规**：
   - [ ] 文件放置在正确的架构层
   - [ ] 没有跨层直接调用（Business 不直接操作 Framework 内部）
   - [ ] 新增依赖方向正确（上层依赖下层，不反向）

   **编码规范**（对齐 `godot-coding-standards`）：
   - [ ] 命名规范：PascalCase 类名、snake_case 变量/函数、UPPER_SNAKE 常量
   - [ ] `@export` 配置化，无硬编码魔法值
   - [ ] 编辑器配置节点，代码不 `new()` Node 派生对象
   - [ ] 信号通信，无不必要的直接引用
   - [ ] 类型注解完整（参数 + 返回值）

   **状态机规范**：
   - [ ] 状态继承 BaseState，使用内置 helper
   - [ ] `animation_finished` 信号在 `exit()` 中断开
   - [ ] 优先级设置正确
   - [ ] 不直接操作 AnimationTree

   **安全性**：
   - [ ] `is_instance_valid()` 防空引用
   - [ ] 懒缓存模式用于 `get_tree()` 查询
   - [ ] `await` 后检查节点有效性
   - [ ] 物理层 Layer/Mask 正确

   **性能**：
   - [ ] `_process` / `_physics_process` 中无重复查询
   - [ ] `preload` 替代 `load`（已知路径时）
   - [ ] 对象池用于高频创建/销毁（子弹、特效）

3. **审查报告格式**：
```markdown
# Code Review Report
## 变更概述
- 变更文件数、涉及架构层、影响范围

## 问题列表
| 级别 | 文件:行号 | 问题描述 | 建议修复 |
|------|----------|---------|---------|
| P0-必须修 | ... | ... | ... |
| P1-建议改 | ... | ... | ... |
| P2-可优化 | ... | ... | ... |

## 通过项
- 列出审查通过的维度
```

4. **修复验证**：
   - P0 问题修复后，重新触发 `testing` skill 验证
   - P1/P2 由用户决定是否修复

---

## 7. 文件结构总览

```
.claude/skills/
├── project-architecture/
│   ├── SKILL.md
│   └── references/
│       ├── layer-map.md
│       ├── data-flow.md
│       └── module-registry.md
│
├── feature-development/
│   ├── SKILL.md
│   └── references/
│       ├── enemy-guide.md
│       ├── boss-guide.md
│       ├── effect-guide.md
│       ├── component-guide.md
│       └── trap-guide.md
│
├── troubleshooting/
│   ├── SKILL.md
│   └── references/
│       └── common-issues.md
│
├── testing/
│   ├── SKILL.md
│   └── references/
│       └── gut-patterns.md
│
├── code-review/
│   └── SKILL.md
│
├── godot-coding-standards/     (已有)
│   └── SKILL.md
├── context-updater/            (已有)
│   └── SKILL.md
└── godot-level-design/         (已有)
    ├── SKILL.md
    └── references/
```

**总计**：5 个新 skill + 3 个已有 skill = 8 个 skill
**新增文件数**：5 个 SKILL.md + 10 个 reference 文件 = 15 个文件

---

## 8. Skill 间协作关系

```
需求输入
  │
  ▼
feature-development ──读取──▶ project-architecture
  │                              │
  │ 开发完毕                      │ 提供架构上下文
  ▼                              ▼
testing ◀─────────────── troubleshooting（如有问题）
  │
  │ 测试通过
  ▼
code-review
  │
  │ P0 问题 → 修复 → 回到 testing
  │ 审查通过
  ▼
context-updater（检查是否需要更新上下文）
```

---

## 9. 与现有 Skill 的关系

| 已有 Skill | 与新 Skill 的关系 |
|---|---|
| `godot-coding-standards` | `code-review` 审查维度对齐其规范；`feature-development` 开发检查清单引用其原则 |
| `context-updater` | `feature-development` 流程最后一步触发其检查 |
| `godot-level-design` | `feature-development` 中关卡类需求直接转发到此 skill |
