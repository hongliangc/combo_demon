# 开发时间线

> **按日期排序** | 详细记录所有开发活动

---

## 📅 2026-02-08

### 🐛 Bug修复: Stun 效果与动画系统修复

**时间**: 全天
**类型**: Bug修复 (6个问题)
**文档**: [2026-02-08.md](sessions/2026-02-08.md)

#### 问题概述
修复 hahashin 攻击 dinosaur 时 stun 效果不触发、dinosaur 攻击行为不正确、stun 动画不播放等问题。

#### 问题1: StunEffect 调用不存在的方法
- **原因**: `StunEffect.apply_effect()` 调用 `state_machine.transition("stun")`，但 `BaseStateMachine` 没有该方法；回退路径的 `transitioned.emit` 使用了错误的 from_state 被拒绝
- **修复**: 改用 `force_transition("stun")` 强制转换
- **文件**: `Core/Resources/StunEffect.gd`

#### 问题2: Idle 状态不能直接进入 Attack
- **原因**: `IdleState.process_state()` 只调用 `try_chase()`，无论距离都先进入 chase
- **修复**: 新增 `try_attack()` 方法，IdleState 优先检查攻击范围
- **文件**: `Core/StateMachine/BaseState.gd`, `Core/StateMachine/CommonStates/IdleState.gd`

#### 问题3: AnimationTree control_sm 未连接
- **原因**: BlendTree 中 control_sm（stun/hit/death 动画）是孤立节点，没有连接到 output
- **修复**: 添加 AnimationNodeBlend2 桥接 locomotion 和 control_sm；修正参数路径从 `output/blend_amount` 到 `control_blend/blend_amount`
- **文件**: `dinosaur.tscn`, `Core/StateMachine/BaseState.gd`

#### 问题4: Stun 动画只播放一次
- **原因**: `playback.travel()` 在已处于目标状态时不重新播放
- **修复**: 改用 `playback.start(state_name, true)` 强制重播
- **文件**: `Core/StateMachine/BaseState.gd`

#### 问题5: Stunned 动画无循环
- **原因**: 动画时长 0.8s < stun 持续 1.5s，且未设置 loop_mode
- **修复**: 添加 `loop_mode = 1`
- **文件**: `dinosaur.tscn`

#### 问题6: Blend2 处理顺序
- **原因**: blend_amount=0 时 control_sm 可能不被处理，start() 调用被忽略
- **修复**: 调换顺序 — 先设 blend_amount=1.0 再调 start()
- **文件**: `Core/StateMachine/BaseState.gd`

#### 影响文件
- `Core/Resources/StunEffect.gd` - force_transition 替代 transition
- `Core/StateMachine/BaseState.gd` - 新增 try_attack()，修复 enter/exit_control_state
- `Core/StateMachine/CommonStates/IdleState.gd` - 优先检查攻击范围
- `Scenes/Characters/Enemies/dinosaur/dinosaur.tscn` - Blend2 节点 + 动画循环

#### 经验总结
1. AnimationTree BlendTree 节点必须显式连接，孤立节点不产生输出
2. `travel()` vs `start()`: 需要重复触发时用 start(reset=true)
3. Blend2 中 weight=0 的输入可能被跳过处理，操作顺序很重要
4. 状态效果使用 `force_transition` 而非通过信号间接触发

---

## 📅 2026-02-03

### 🐛 Bug修复: 敌人状态机转换问题

**时间**: 全天
**类型**: 状态机Bug修复
**文档**: [2026-02-03.md](sessions/2026-02-03.md)

#### 问题概述
修复 dinosaur 敌人的三个状态机相关问题：
1. 敌人不能移动
2. 敌人不会追人
3. 追击后停在原地不再追击

#### 问题1&2: 敌人不能移动/不追人
- **原因**: main.tscn 配置问题
  - 所有敌人 position = (0, 0)，堆叠在原点
  - Enemy 节点设置 `wander_speed = 0.0` 覆盖了默认值
- **修复**: 修改 main.tscn，设置正确位置，移除速度覆盖

#### 问题3: Attack状态无法转换回Chase
- **原因**: AttackState 的 `can_be_interrupted = false` 阻止同优先级转换
- **分析**:
  - Attack 和 Chase 都是 BEHAVIOR 优先级
  - `can_transition_to()` 检查同优先级时需要 `can_be_interrupted = true`
  - 即使 Attack 自己调用 `transition_to(chase)`，也会被拒绝
- **修复**: 将 AttackState 的 `can_be_interrupted` 改为 `true`

#### 影响文件
- `Scenes/main.tscn` - 敌人位置和参数配置
- `Core/StateMachine/CommonStates/AttackState.gd` - can_be_interrupted = true
- `Core/StateMachine/BaseStateMachine.gd` - 调试日志优化

#### 经验总结
1. 检查场景配置：位置、导出变量覆盖
2. 状态机优先级系统：`can_be_interrupted` 控制同优先级转换
3. 调试技巧：状态转换日志格式 `[Entity] From -> To`

**Token消耗**: ~2000

---

## 📅 2026-01-25

### ✨ 特性实现: V技能特殊攻击完整实现

**时间**: 全天
**类型**: 功能实现与问题修复
**文档**: [special_attack_v_skill.md](features/special_attack_v_skill.md)

#### 功能概述
完成V键特殊攻击技能的完整流程实现，包括视觉特效、敌人聚集、镜头控制和攻击动画。

#### 核心流程
```
按V键 → 残影放大效果 → 漩涡生成
→ 逐个聚集敌人 → 镜头跟踪
→ 冲刺攻击 → 恢复状态
```

#### 问题修复 (7个)

**问题1: 残影位置不对**
- 原因: 位置计算错误，动画不完整
- 修复: 使用`body.global_position`，双阶段动画（放大→缩小→渐隐）
- 文件: `GhostExpandEffect.gd`

**问题2: 敌人聚集后还会移动**
- 原因: 状态机未检查`can_move`标志，速度被覆盖
- 修复:
  - 添加`can_move`属性到Enemy类
  - 所有状态机开头检查`can_move`
  - `_stun_enemy`强制velocity归零
- 文件: `enemy.gd`, 4个状态文件

**问题3: 漩涡看不到**
- 原因: 半径太小(30px)，颜色太暗，被遮挡
- 修复: 半径增大到60px，提高亮度，设置z_index=1
- 文件: `VortexEffect.gd`

**问题4: 敌人没聚集到漩涡位置**
- 原因: 使用了`_gather_position`(100px)而非`_vortex_position`(200px)
- 修复: 改用`_vortex_position`作为聚集目标
- 文件: `SkillManager.gd:165`

**问题5: 漩涡持续时间不对**
- 原因: Phase 4结束后就隐藏，攻击时看不到
- 修复: 移到Phase 6攻击动画结束后隐藏
- 文件: `SkillManager.gd:190`

**问题6: 镜头缩放不符合需求**
- 原因: 包含了zoom属性动画
- 修复: 移除zoom调整，只改变position
- 文件: `SkillManager.gd:158-162`

**问题7: 按V时没有残影效果**
- 原因: 直接add_child导致"Parent node is busy"错误
- 修复: 使用`call_deferred`延迟添加，`await process_frame`等待
- 文件: `SkillManager.gd:77-90`

#### 技术亮点

**1. call_deferred解决节点繁忙**
```gdscript
body.get_parent().call_deferred("add_child", ghost)
await owner_node.get_tree().process_frame
ghost.create_from_sprite(sprite, body.global_position)
```

**2. 三重停止机制**
```gdscript
enemy.stunned = true      // 业务逻辑层
enemy.can_move = false    // 权限控制层
enemy.velocity = Vector2.ZERO  // 物理层
```

**3. 状态机防护层**
```gdscript
if "can_move" in owner_node and not owner_node.can_move:
    (owner_node as CharacterBody2D).velocity = Vector2.ZERO
    return
```

#### 影响文件
- ✏️ `Util/Components/SkillManager.gd` (多处修复)
- ✏️ `Util/Effects/GhostExpandEffect.gd` (双阶段动画)
- ✏️ `Util/Effects/VortexEffect.gd` (可见性优化)
- ✏️ `Scenes/enemies/dinosaur/Scripts/enemy.gd` (+can_move属性)
- ✏️ `Util/StateMachine/CommonStates/chase_state.gd` (+can_move检查)
- ✏️ `Util/StateMachine/CommonStates/wander_state.gd` (+can_move检查)
- ✏️ `Util/StateMachine/CommonStates/idle_state.gd` (+can_move检查)
- ✏️ `Util/StateMachine/CommonStates/attack_state.gd` (+can_move检查)

#### 配置参数
| 参数 | 值 | 说明 |
|------|-----|------|
| vortex_distance | 200px | 漩涡距离 |
| vortex_radius | 60px | 漩涡半径 |
| ghost_expand_scale | 2.0 | 残影放大倍数 |
| camera_move_time | 0.5s | 镜头移动时间 |
| gather_time | 0.8s | 敌人聚集时间 |

#### 验证清单
- [ ] 残影在玩家位置正确显示（放大→缩小→消失）
- [ ] 漩涡在200px前方清晰可见
- [ ] 敌人聚集到漩涡位置并完全静止
- [ ] 镜头在敌人和漩涡中点（无缩放）
- [ ] 漩涡持续到攻击动画结束
- [ ] 攻击后正确恢复状态

**Token消耗**: ~5000

---

## 📅 2026-01-19

### 🐛 Bug修复: 特殊攻击后无法移动

**时间**: 上午
**类型**: Critical Bug修复
**文档**: [player_autonomous_components_implementation_2026-01-19.md](bug-fixes/player_autonomous_components_implementation_2026-01-19.md)

#### 问题
用户报告按下V键（特殊攻击）后，玩家永久无法移动

#### 根本原因
```gdscript
// SkillManager._execute_special_attack_flow()
movement_component.can_move = false  // ✅ 禁用
_play_attack_animation()  // ❌ 立即返回，不等待
// ❌ 从未恢复 can_move
```

#### 修复方案
```gdscript
await _play_attack_animation_and_wait()  // ✅ 等待动画完成
movement_component.can_move = true  // ✅ 恢复移动
```

#### 影响文件
- `Util/Components/SkillManager.gd` (+13行)

#### 测试结果
- ✅ 特殊攻击完整流程正常
- ✅ 移动恢复验证通过
- ✅ 回归测试通过

**Token消耗**: ~800

---

### 📐 文档: UML架构图

**时间**: 下午
**类型**: 架构文档
**文档**: [architecture_uml_diagrams.md](architecture/architecture_uml_diagrams.md)

#### 内容
创建5类UML图表：
1. **Player组件类图** - 组件关系和依赖
2. **特殊攻击流程时序图** - 完整执行流程
3. **信号通信架构图** - 信号发射和监听
4. **组件生命周期状态图** - 状态转换
5. **系统架构层次图** - 整体架构

#### 格式
- Mermaid格式（GitHub可渲染）
- ASCII Art格式（文本查看）

#### 设计模式总结
- 组件模式、观察者模式、依赖注入等7种模式
- SOLID原则应用

**Token消耗**: ~2000

---

### 📋 文档: 会话总结

**时间**: 下午
**类型**: 会话记录
**文档**: [session_summary_2026-01-19.md](sessions/session_summary_2026-01-19.md)

#### 内容
- 本次会话工作记录
- Bug修复过程
- 测试结果统计
- 代码变更清单
- 经验总结

**Token消耗**: ~400

---

### 📚 文档优化: 索引系统

**时间**: 晚上
**类型**: 文档组织
**文档**: INDEX.md, TIMELINE.md, QUICK_REFERENCE.md

#### 优化内容
1. **INDEX.md** - 按类型分类索引
2. **TIMELINE.md** - 按日期时间线
3. **QUICK_REFERENCE.md** - 快速参考摘要

#### 目标
- 提升检索效率
- 降低Token消耗
- 合并重复内容

**Token消耗**: ~500

---

## 📅 2026-01-18

### 🏗️ 重构: Player自治组件架构

**时间**: 全天
**类型**: 重大架构重构
**文档**:
- [autonomous_component_architecture_2026-01-18.md](refactoring/autonomous_component_architecture_2026-01-18.md) - 设计文档
- [player_refactoring_guide_2026-01-18.md](archive/player_refactoring_guide_2026-01-18.md) - 实施指南（已归档）

#### 架构变更

**旧架构**:
```
Hahashin (278行，单体类)
├── movement_hander.gd (63行)
└── animation_hander.gd (121行)
```

**新架构**:
```
Hahashin (119行，-57%)
├── HealthComponent (150行)
├── MovementComponent (180行)
├── AnimationComponent (97行)
├── CombatComponent (235行)
└── SkillManager (256行)
```

#### 关键特性
- ✅ 组件完全自治（自己运行_process/_physics_process）
- ✅ 信号驱动通信（零耦合）
- ✅ 依赖注入（自动查找依赖）
- ✅ 可重载方法（支持继承扩展）

#### 实施步骤
1. 重构MovementComponent（180行）
2. 创建AnimationComponent（97行）
3. 重构CombatComponent（235行）
4. 重构SkillManager（256行）
5. 简化hahashin.gd（119行）
6. 更新hahashin.tscn场景
7. 删除冗余文件（2个）

#### 测试结果
- ✅ 基本移动、精灵翻转
- ✅ 普通攻击、翻滚
- ⚠️ 特殊攻击（发现Bug）
- ✅ 受伤和死亡

**Token消耗**: ~1500

---

### 🐛 Bug修复: await内存泄漏

**时间**: 下午
**类型**: 内存泄漏修复
**文档**: [await_memory_leak_fix_2026-01-18.md](bug-fixes/await_memory_leak_fix_2026-01-18.md)

#### 问题
`KnockUpEffect`, `KnockBackEffect`, `GatherEffect` 使用 `await timer.timeout` 可能导致内存泄漏

#### 原因
- target在duration期间被销毁
- Effect实例持有的引用无法释放
- 多次应用Effect创建多个并发await

#### 修复方案
```gdscript
// 旧代码（有泄漏风险）
await target.get_tree().create_timer(duration).timeout
if is_instance_valid(target):
    target.can_move = true

// 新代码（安全）
var timer = target.get_tree().create_timer(duration)
timer.timeout.connect(func():
    if is_instance_valid(target) and "can_move" in target:
        target.can_move = true
, CONNECT_ONE_SHOT)
```

#### 影响文件
- `Util/Classes/KnockBackEffect.gd`
- `Util/Classes/KnockUpEffect.gd`
- `Util/Classes/GatherEffect.gd`

**Token消耗**: ~800

---

### ✨ 特性: Hitbox统一实现

**时间**: 上午
**类型**: 代码重构
**文档**: [optimization_work_plan.md#1](planning/optimization_work_plan.md#1-统一hitbox实现)

#### 问题
`fire/hitbox.gd` 和 `bubble/hitbox.gd` 代码完全重复

#### 解决方案
在基类 `Util/Components/hitbox.gd` 添加@export配置：
- `destroy_owner_on_hit: bool`
- `ignore_collision_groups: Array[String]`

#### 成果
- 删除2个重复子类脚本
- 统一在基类实现
- 场景中配置参数

**Token消耗**: ~200

---

### ✨ 特性: Hitbox碰撞层配置

**时间**: 上午
**类型**: 功能增强
**文档**: [optimization_work_plan.md#4](planning/optimization_work_plan.md#4-添加碰撞层配置到hitbox)

#### 新增功能
```gdscript
@export_flags_2d_physics var collision_layer_override: int = 0
@export_flags_2d_physics var collision_mask_override: int = 0

func _ready():
    if collision_layer_override > 0:
        collision_layer = collision_layer_override
    if collision_mask_override > 0:
        collision_mask = collision_mask_override
```

#### 好处
- 在编辑器直接配置碰撞层
- 无需修改代码
- 更灵活的配置方式

**Token消耗**: ~100

---

### 📐 文档: 架构评审

**时间**: 上午
**类型**: 架构分析
**文档**: [architecture_review_2026-01-18.md](architecture/architecture_review_2026-01-18.md)

#### 内容
对整个项目进行全面架构评审，提出11项优化建议：

**高优先级** (4项):
1. 统一Hitbox实现
2. Player类自治组件重构 ⭐
3. 修复AttackEffect的await内存泄漏
4. 添加碰撞层配置到Hitbox

**中优先级** (4项):
5. 重构StunState - 职责分离
6. 状态名称常量化
7. 统一调试输出 - 使用DebugConfig
8. Boss阶段转换解耦

**低优先级** (3项):
9. 目录结构重构
10. 技能Resource系统
11. UI状态指示器

#### 代码分析
- 状态机系统 ⭐⭐⭐⭐⭐
- 伤害系统 ⭐⭐⭐⭐
- Boss战 ⭐⭐⭐⭐⭐
- Player技能 ⭐⭐⭐

**Token消耗**: ~1200

---

### 📋 文档: 优化工作计划

**时间**: 全天更新
**类型**: 任务管理
**文档**: [optimization_work_plan.md](planning/optimization_work_plan.md)

#### 内容
- 11项优化任务详细计划
- 执行步骤和预计工作量
- 进度追踪（4/11完成）
- 推荐执行顺序

#### 当前状态
- 高优先级: 4/4 ✅
- 中优先级: 0/4 ⏭️
- 低优先级: 0/3 📁

**Token消耗**: ~1000

---

## 📅 2026-01-17

### 📝 文档: 归档整理

**时间**: 全天
**类型**: 文档管理

#### 操作
- 创建 `archive/` 目录
- 移动旧版本文档
- 整理README.md

---

## 📊 统计汇总

### 按类型统计

| 类型 | 数量 | Token总计 |
|------|------|----------|
| 🐛 Bug修复 | 4 | ~5,600 |
| ✨ 特性开发 | 3 | ~5,300 |
| 🏗️ 重构优化 | 1 | ~1,500 |
| 📐 架构设计 | 3 | ~4,000 |
| 📋 规划文档 | 2 | ~1,400 |
| 🔧 工具文档 | 2 | ~1,600 |
| **总计** | **14** | **~17,400** |

### 按日期统计

| 日期 | 活动数 | Token消耗 |
|------|--------|----------|
| 2026-02-03 | 1 | ~2,000 |
| 2026-01-25 | 1 | ~5,000 |
| 2026-01-19 | 4 | ~3,700 |
| 2026-01-18 | 7 | ~6,300 |
| 2026-01-17 | 1 | ~400 |
| **总计** | **14** | **~17,400** |

### 代码变更统计

| 指标 | 数值 |
|------|------|
| 新增文件 | 5个组件 + 3个文档索引 |
| 删除文件 | 2个handler + 2个重复hitbox |
| 修改文件 | SkillManager (+多处修复), 8个Effect/State文件 |
| 主类简化 | -57% (278→119行) |
| Bug修复 | 2个 |
| V技能问题修复 | 7个 |

---

## 🎯 里程碑

### 第一阶段: 架构重构 ✅ (2026-01-18~19)
- ✅ Player自治组件架构
- ✅ 代码重复消除
- ✅ 内存泄漏修复
- ✅ Bug修复完成

### 第二阶段: 中优先级优化 ⏭️ (计划中)
- ⏭️ StunState重构
- ⏭️ 状态名称常量化
- ⏭️ 统一调试输出
- ⏭️ Boss阶段转换解耦

### 第三阶段: 可选优化 📁 (待定)
- 📁 目录结构重构
- 📁 技能Resource系统
- 📁 UI状态指示器

---

## 📖 阅读建议

### 按时间倒序（最新优先）
适合了解最新进展：
1. 2026-01-19 活动
2. 2026-01-18 活动
3. 2026-01-17 活动

### 按时间正序（从头开始）
适合完整学习：
1. 2026-01-17: 项目初始状态
2. 2026-01-18: 架构重构和优化
3. 2026-01-19: Bug修复和文档完善

### 按主题查找
使用 [INDEX.md](INDEX.md) 按类型快速定位相关文档

---

**最后更新**: 2026-02-03
**总活动数**: 14项
**总Token消耗**: ~17,400
