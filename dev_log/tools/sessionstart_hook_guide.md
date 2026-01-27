# SessionStart Hook 按需加载指南

**创建时间**: 2026-01-18
**用途**: 说明 SessionStart Hook 的工作原理、优势和最佳实践

---

## 一、什么是 SessionStart Hook

SessionStart Hook 是 Claude Code 的一个**启动钩子**，在会话初始化时执行自定义命令或脚本，可以：

1. **动态注入上下文** - 根据当前任务注入不同的 context
2. **设置环境变量** - 配置会话级别的环境变量
3. **按需加载配置** - 只加载当前任务需要的配置
4. **执行初始化脚本** - 运行项目初始化命令

---

## 二、工作原理

### 配置位置

`.claude/settings.local.json`

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "bash /path/to/startup-script.sh"
          }
        ]
      }
    ]
  }
}
```

### 执行流程

```
Claude Code 启动
    ↓
读取 Settings 配置
    ↓
检测 SessionStart Hook
    ↓
执行 Hook 命令（bash/powershell）
    ↓
捕获 stdout 输出 → 注入到会话 context
    ↓
读取 CLAUDE_ENV_FILE → 设置环境变量
    ↓
继续加载 Memory/Skills/MCP
    ↓
会话就绪
```

### 输出处理

1. **标准输出 (stdout)** - 直接注入为会话 context
2. **环境变量文件** - Hook 可以写入 `$CLAUDE_ENV_FILE`
3. **返回码** - 非零返回码会显示警告但不会中断启动

---

## 三、核心优势

### 🎯 优势 1: 按需加载，降低 Token 消耗

**问题**: 当前所有 context 在启动时全量加载（~4350 tokens）

**解决方案**: 根据任务动态加载

**示例场景**:

```bash
#!/bin/bash
# startup-script.sh

# 检测用户意图（通过命令行参数或环境变量）
TASK_TYPE="${CLAUDE_TASK_TYPE:-general}"

case $TASK_TYPE in
  "ui")
    # UI 任务：只加载 UI 相关 context
    cat .claude/context/ui-context.md
    ;;
  "combat")
    # 战斗系统任务：只加载战斗相关 context
    cat .claude/context/combat-context.md
    ;;
  "state-machine")
    # 状态机任务：只加载状态机 context
    cat .claude/context/state-machine-context.md
    ;;
  *)
    # 默认：加载核心架构
    cat .claude/context/core-context.md
    ;;
esac
```

**效果**:
- UI 任务: 加载 ~1500 tokens (减少 65%)
- 战斗任务: 加载 ~1800 tokens (减少 58%)
- 通用任务: 加载 ~3000 tokens (当前水平)

---

### 🚀 优势 2: 动态环境配置

**场景**: 根据项目状态动态设置环境变量

```bash
#!/bin/bash
# 检测当前分支
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# 检测是否在 Boss 开发中
if git diff --name-only | grep -q "boss"; then
    echo "CURRENT_FOCUS=boss-development" >> "$CLAUDE_ENV_FILE"
    cat .claude/context/boss-system.md
elif git diff --name-only | grep -q "UI"; then
    echo "CURRENT_FOCUS=ui-development" >> "$CLAUDE_ENV_FILE"
    cat .claude/context/ui-system.md
else
    cat .claude/context/project_context.md
fi

# 设置开发阶段
if [ "$BRANCH" = "main" ]; then
    echo "DEV_STAGE=production" >> "$CLAUDE_ENV_FILE"
else
    echo "DEV_STAGE=development" >> "$CLAUDE_ENV_FILE"
fi
```

**Claude 可以访问这些环境变量**，自动调整行为策略。

---

### 🔧 优势 3: 项目状态感知

**场景**: 根据项目当前状态提供上下文

```bash
#!/bin/bash

# 1. 检测最近的开发焦点
RECENT_FILES=$(git diff --name-only HEAD~5..HEAD)

echo "# 最近开发焦点"
echo ""

# 2. 分析最近修改的系统
if echo "$RECENT_FILES" | grep -q "StateMachine"; then
    echo "## 状态机系统"
    cat .claude/context/snippets/state-machine-recent.md
fi

if echo "$RECENT_FILES" | grep -q "Damage"; then
    echo "## 伤害系统"
    cat .claude/context/snippets/damage-system-recent.md
fi

# 3. 检测未解决的 TODO
echo ""
echo "## 待办事项"
grep -r "TODO\|FIXME" Scenes/ Util/ | head -5

# 4. 检测构建状态
if [ -f ".build-status" ]; then
    cat .build-status
fi
```

**效果**: Claude 自动了解项目的当前状态和待办事项。

---

### 📊 优势 4: 智能 Context 分片

**策略**: 将大型 context 拆分为小片段，按需组合

**目录结构**:
```
.claude/context/
├── core.md              # 核心架构（必加载，800 tokens）
├── modules/
│   ├── state-machine.md # 状态机详细（500 tokens）
│   ├── damage.md        # 伤害系统详细（400 tokens）
│   ├── ui.md            # UI 系统详细（600 tokens）
│   ├── combat.md        # 战斗系统详细（700 tokens）
│   └── weapons.md       # 武器系统详细（500 tokens）
└── snippets/
    ├── input-map.md     # 输入映射（200 tokens）
    └── physics.md       # 物理层（200 tokens）
```

**Hook 脚本**:
```bash
#!/bin/bash

# 始终加载核心
cat .claude/context/core.md

# 根据工作目录智能加载
WORK_DIR=$(pwd)
case $WORK_DIR in
  *"/Scenes/enemies/"*)
    cat .claude/context/modules/state-machine.md
    cat .claude/context/modules/combat.md
    ;;
  *"/Scenes/UI/"*)
    cat .claude/context/modules/ui.md
    ;;
  *"/Util/StateMachine/"*)
    cat .claude/context/modules/state-machine.md
    ;;
  *"/Weapons/"*)
    cat .claude/context/modules/weapons.md
    cat .claude/context/modules/combat.md
    ;;
esac
```

**效果**: 根据工作目录只加载相关模块，平均 Token 降低 40-60%。

---

### ⚡ 优势 5: 初始化自动化

**场景**: 自动执行项目初始化任务

```bash
#!/bin/bash

# 1. 检查依赖
if ! command -v godot &> /dev/null; then
    echo "⚠️  警告: Godot 未安装或不在 PATH 中"
fi

# 2. 检查项目完整性
if [ ! -f "project.godot" ]; then
    echo "❌ 错误: 未找到 project.godot"
    exit 1
fi

# 3. 检查 GDScript 语法（可选）
if command -v godot &> /dev/null; then
    # 使用 Godot 的 headless 模式检查脚本
    # godot --headless --script-check Scenes/charaters/hahashin.gd
fi

# 4. 显示开发环境状态
echo "# 开发环境状态"
echo "- Git Branch: $(git rev-parse --abbrev-ref HEAD)"
echo "- Godot Version: 4.4.1"
echo "- Modified Files: $(git status --short | wc -l)"

# 5. 加载项目 context
cat .claude/context/project_context.md
```

---

## 四、与当前配置对比

### 当前方式：全量加载

```
启动 → 加载所有 context (4350 tokens)
         ↓
    适用任何任务
```

**优点**:
- ✅ 简单直接，无需配置
- ✅ 所有信息都可用
- ✅ 不需要预判任务类型

**缺点**:
- ❌ 固定 Token 消耗
- ❌ 无法根据任务优化
- ❌ 包含当前任务不需要的信息

### SessionStart Hook：按需加载

```
启动 → Hook 检测任务类型
         ↓
    加载相关 context (1500-3000 tokens)
         ↓
    节省 30-65% tokens
```

**优点**:
- ✅ **动态优化** Token 消耗
- ✅ **智能加载**相关上下文
- ✅ **环境感知**（分支、改动、TODO）
- ✅ **自动化**初始化任务

**缺点**:
- ❌ 需要编写和维护 Hook 脚本
- ❌ 增加配置复杂度
- ❌ 依赖 bash/shell 环境
- ❌ 调试相对困难

---

## 五、推荐的使用场景

### 🟢 推荐使用 Hook

1. **大型项目** (> 10万行代码)
   - Context 超过 5000 tokens
   - 有明确的模块划分

2. **多人协作项目**
   - 不同开发者关注不同模块
   - 需要根据分支/任务动态调整

3. **多阶段开发**
   - 原型阶段 vs 优化阶段
   - 不同阶段需要不同 context

4. **性能敏感**
   - Token 成本是主要考虑因素
   - 需要频繁启动会话

### 🟡 可选使用 Hook

1. **中型项目** (当前项目规模)
   - Context 在 4000-5000 tokens
   - 有一定模块化

2. **单人开发但任务明确**
   - 长期专注某个子系统
   - 可以手动指定加载内容

### 🔴 不推荐使用 Hook

1. **小型项目** (< 5万行)
   - Context 少于 3000 tokens
   - 全量加载已足够高效

2. **快速原型**
   - 需要快速迭代
   - 不想维护额外脚本

3. **团队不熟悉 Shell**
   - 维护成本高于收益

---

## 六、实现示例（适用于当前项目）

### 方案 A: 按工作模块加载

**配置**: `.claude/settings.local.json`

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/scripts/smart-load.sh"
          }
        ]
      }
    ]
  }
}
```

**脚本**: `.claude/scripts/smart-load.sh`

```bash
#!/bin/bash

# 核心架构（始终加载）
cat .claude/context/core-architecture.md  # 1200 tokens

# 智能检测最近改动
RECENT_CHANGES=$(git diff --name-only HEAD~3..HEAD)

if echo "$RECENT_CHANGES" | grep -q "StateMachine\|enemies"; then
    cat .claude/context/modules/state-machine.md  # +600 tokens
fi

if echo "$RECENT_CHANGES" | grep -q "Damage\|hitbox\|hurtbox"; then
    cat .claude/context/modules/combat-system.md  # +500 tokens
fi

if echo "$RECENT_CHANGES" | grep -q "UI/"; then
    cat .claude/context/modules/ui-system.md  # +400 tokens
fi

# 总计: 1200 + 0-1500 tokens = 1200-2700 tokens
# 平均节省: 38-72%
```

### 方案 B: 按开发阶段加载

```bash
#!/bin/bash

BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [ "$BRANCH" = "main" ]; then
    # 生产分支：加载完整 context
    cat .claude/context/project_context.md  # 3000 tokens
else
    # 开发分支：只加载核心 + 当前特性
    cat .claude/context/core-only.md  # 1500 tokens

    # 根据分支名加载特定模块
    if [[ "$BRANCH" == *"boss"* ]]; then
        cat .claude/context/modules/boss-system.md
    elif [[ "$BRANCH" == *"ui"* ]]; then
        cat .claude/context/modules/ui-system.md
    fi
fi
```

---

## 七、迁移建议

### 对于当前项目（Combo Demon）

**现状分析**:
- Context: 3000 tokens（已优化）
- Skills: 1350 tokens
- 总计: 4350 tokens

**建议**: **暂不使用 SessionStart Hook**

**理由**:
1. ✅ 当前 Token 已经很低（4350），优化空间有限
2. ✅ 项目规模适中，全量加载不会造成性能问题
3. ✅ 单人开发，无需复杂的动态加载
4. ❌ Hook 脚本增加维护成本
5. ❌ 收益不明显（预计只能再降 30-50%，即 1300-2175 tokens）

**何时考虑使用 Hook**:
- 项目代码量翻倍（> 20万行）
- Context 增长到 6000+ tokens
- 团队扩展，多人协作
- 有明确的长期模块划分

---

## 八、最佳实践

### 1. Hook 脚本设计原则

```bash
# ✅ 推荐：快速失败
set -e  # 遇到错误立即退出

# ✅ 推荐：提供默认值
TASK_TYPE="${CLAUDE_TASK_TYPE:-general}"

# ✅ 推荐：输出简洁的 Markdown
echo "# Context for $TASK_TYPE"
cat .claude/context/${TASK_TYPE}.md

# ❌ 避免：复杂的逻辑判断
# ❌ 避免：外部 API 调用（会拖慢启动）
# ❌ 避免：生成超大 context（> 5000 tokens）
```

### 2. Context 分片策略

```
核心原则：
1. core.md 始终 < 1500 tokens（高频引用）
2. 模块 context < 800 tokens（可组合）
3. 总加载量控制在 2000-3500 tokens
```

### 3. 调试 Hook

```bash
# 测试 Hook 输出
bash .claude/scripts/smart-load.sh

# 检查 Token 数量（粗略估算）
bash .claude/scripts/smart-load.sh | wc -w
# 1 word ≈ 1.3 tokens

# 设置环境变量测试
export CLAUDE_TASK_TYPE=ui
bash .claude/scripts/smart-load.sh
```

---

## 九、总结对比表

| 维度 | 当前配置（全量加载） | SessionStart Hook（按需加载） |
|------|---------------------|------------------------------|
| **Token 消耗** | 固定 4350 | 动态 1500-3500 (-35%~-65%) |
| **启动速度** | 1-3秒 | 2-4秒（Hook 执行 +0.5-1秒） |
| **配置复杂度** | 低 ⭐ | 中高 ⭐⭐⭐⭐ |
| **维护成本** | 低 | 中高（需维护脚本） |
| **灵活性** | 低 | 高（可动态调整） |
| **适合场景** | 中小项目 | 大型项目、多模块 |
| **团队友好** | 高 | 中（需熟悉 Shell） |

---

## 十、结论

### 对于当前项目

**建议保持当前配置**（全量加载），原因：
1. 4350 tokens 已经非常高效
2. 项目规模适中，全量加载无性能问题
3. 简单直接，易于维护
4. Hook 带来的收益（约 1000-1500 tokens）不足以抵消复杂度

### 未来考虑 Hook 的时机

当满足以下**任一条件**时：
- ✅ Context 增长到 6000+ tokens
- ✅ 项目代码量 > 20万行
- ✅ 团队规模扩大（> 3人）
- ✅ 有明确的长期模块划分

---

**维护建议**:
- 持续监控 Context 大小
- 定期评估是否需要引入 Hook
- 如果引入，从简单的模块划分开始
- 逐步增加智能检测逻辑

**相关文档**:
- [Claude Code Hooks 官方文档](https://docs.claude.com/hooks)
- [项目启动配置文档](./claude_session_startup.md)
