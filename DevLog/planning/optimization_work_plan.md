# Combo Demon - 优化工作计划

> 基于 [architecture_review_2026-01-18.md](architecture_review_2026-01-18.md) 的详细执行计划
>
> **创建时间**: 2026-01-18
> **状态**: 进行中

---

## 📊 总体进度

**已完成**: 4/11
**进行中**: 0/11
**待处理**: 7/11

| 优先级 | 完成数 | 总数 |
|--------|--------|------|
| 高     | 4      | 4    |
| 中     | 0      | 4    |
| 低     | 0      | 3    |

---

## ✅ 高优先级任务 (4/4 完成)

### 1. 统一Hitbox实现 ✅ COMPLETED

**问题**: `Weapons/bullet/fire/hitbox.gd` 和 `bubble/hitbox.gd` 代码完全重复

**影响**: 代码维护困难，修改需要同步多处

**解决方案**:
- 在基类 `Util/Components/hitbox.gd` 中添加 `@export` 配置项
- 删除重复的子类脚本

**执行步骤**:
- [x] 在 HitBoxComponent 基类添加 `destroy_owner_on_hit: bool`
- [x] 在 HitBoxComponent 基类添加 `ignore_collision_groups: Array[String]`
- [x] 更新 `_on_hitbox_area_entered_` 方法实现新功能
- [x] 更新 `fire_bullet.tscn` 使用基类并配置参数
- [x] 更新 `bubble_bullet.tscn` 使用基类并配置参数
- [x] 删除 `fire/hitbox.gd` 和 `bubble/hitbox.gd`
- [x] 测试子弹击中和销毁功能

**完成时间**: 2026-01-18

---

### 2. Player类自治组件重构 ✅ COMPLETED

**问题**:
- `hahashin.gd` 278行，职责过重
- `movement_hander.gd` 和 `animation_hander.gd` 业务逻辑外泄
- 组件不自治，需要外部手动调用

**影响**:
- 业务逻辑分散在3个文件中
- 组件间紧耦合，直接相互调用
- 违反单一职责原则

**解决方案**: 完全自治的组件架构

**架构概览**:
- Hahashin 主类简化到 119行（-57%）
- 5个自治组件：HealthComponent, MovementComponent, AnimationComponent, CombatComponent, SkillManager
- 组件通过信号解耦，自动运行生命周期方法
- 删除2个冗余handler文件

**详细架构设计和实施步骤**:
→ 参见 [autonomous_component_architecture_2026-01-18.md](../refactoring/autonomous_component_architecture_2026-01-18.md)

**场景更新** (2026-01-18):
- [x] 更新 hahashin.tscn 场景结构
  - 添加 5 个组件节点（HealthComponent, MovementComponent, AnimationComponent, CombatComponent, SkillManager）
  - 删除旧节点（MovementHandler, AnimationHandler）
  - 配置组件参数

**测试验证** (2026-01-18):
- [x] 基本移动、精灵翻转 - ✅ 通过
- [x] 普通攻击、翻滚 - ✅ 通过
- [x] 特殊攻击 - ⚠️ 发现Bug
- [x] 受伤和死亡 - ✅ 通过

**Bug修复** (2026-01-19):
- [x] [特殊攻击后无法移动](../bug-fixes/player_autonomous_components_implementation_2026-01-19.md)
  - 修复：添加 `await animation_finished` 等待动画完成

**完整测试** (2026-01-19):
- [x] 特殊攻击完整流程 - ✅ 通过
- [x] 移动恢复验证 - ✅ 通过
- [x] 回归测试（所有功能） - ✅ 通过

**成果**:
- ✅ 代码量：788行 → 890行（+13%，但架构质量显著提升）
- ✅ 主类简化：278行 → 119行（-57%）
- ✅ 组件完全自治、解耦、可重用
- ✅ 删除 2 个冗余 handler 文件
- ✅ Bug修复：特殊攻击后无法移动

**完成时间**: 2026-01-18 (初次实现) + 2026-01-19 (Bug修复)

---

### 3. 修复AttackEffect的await内存泄漏 ✅ COMPLETED

**问题**: `KnockUpEffect.gd` 和 `KnockBackEffect.gd` 使用 `await timer.timeout` 可能导致内存泄漏

**影响**:
- 如果 target 在 duration 期间被销毁，Effect 实例持有的引用无法释放
- 多次应用相同 Effect 会创建多个并发的 await

**解决方案**: 使用信号连接替代 await

**修改文件**:
- [x] KnockBackEffect.gd:32
- [x] KnockUpEffect.gd:39
- [x] GatherEffect.gd:58

**修改示例**:
```gdscript
# 旧代码（有内存泄漏风险）
await target.get_tree().create_timer(duration).timeout
if is_instance_valid(target):
    target.can_move = true

# 新代码（安全）
var timer = target.get_tree().create_timer(duration)
timer.timeout.connect(func():
    if is_instance_valid(target) and "can_move" in target:
        target.can_move = true
, CONNECT_ONE_SHOT)
```

**执行步骤**:
- [x] 更新 KnockBackEffect.gd
- [x] 更新 KnockUpEffect.gd
- [x] 更新 GatherEffect.gd
- [x] 测试击飞、击退、聚集功能

**完成时间**: 2026-01-18

---

### 4. 添加碰撞层配置到Hitbox ✅ COMPLETED

**问题**: HitBoxComponent 无法在编辑器中灵活配置碰撞层和掩码

**影响**: 需要在场景文件中手动配置，不够灵活

**解决方案**: 添加 `@export_flags_2d_physics` 参数

**修改**:
- [x] 在 `Util/Components/hitbox.gd` 添加:
  ```gdscript
  @export_group("碰撞配置")
  @export_flags_2d_physics var collision_layer_override: int = 0
  @export_flags_2d_physics var collision_mask_override: int = 0

  func _ready():
      if collision_layer_override > 0:
          collision_layer = collision_layer_override
      if collision_mask_override > 0:
          collision_mask = collision_mask_override
  ```

**执行步骤**:
- [x] 添加 @export 参数
- [x] 在 _ready() 中应用配置
- [x] 在编辑器中测试配置

**完成时间**: 2026-01-18

---

## 🔄 中优先级任务 (0/4 完成)

### 5. 重构StunState - 职责分离

**问题**: `stun_state.gd` 161行，包含眩晕逻辑 + 物理模拟 + 特效判断

**影响**: 代码复杂，难以维护和扩展

**解决方案**: 拆分为多个职责单一的类

**新架构**:
```
StunState (BaseState)
├── 核心逻辑：眩晕时间、状态切换
└── 使用组件：
    ├── KnockUpPhysicsSimulator
    │   └── 处理击飞的抛物线、重力、摩擦
    └── KnockBackHandler
        └── 处理击退的速度衰减
```

**执行步骤**:
- [ ] 1. 创建 `KnockUpPhysicsSimulator.gd` (60行)
  ```gdscript
  class_name KnockUpPhysicsSimulator

  var gravity: float = 980.0
  var friction: float = 5.0
  var vertical_offset: float = 0.0
  var vertical_velocity: float = 0.0

  func simulate(body: CharacterBody2D, delta: float): ...
  ```

- [ ] 2. 创建 `KnockBackHandler.gd` (30行)
  ```gdscript
  class_name KnockBackHandler

  func apply_friction(body: CharacterBody2D, friction: float, delta: float): ...
  ```

- [ ] 3. 重构 `stun_state.gd` (80行)
  - 移除物理模拟代码
  - 使用 KnockUpPhysicsSimulator 和 KnockBackHandler
  - 简化逻辑

- [ ] 4. 测试眩晕、击飞、击退功能

**预计工作量**: 2-3小时

---

### 6. 状态名称常量化

**问题**: 使用字符串 "idle", "chase", "attack" 等引用状态，容易拼写错误

**影响**: 运行时错误难以调试

**解决方案**: 使用常量或枚举

**方案A - 全局常量** (推荐):
```gdscript
# Util/StateMachine/state_names.gd (新文件)
class_name StateNames

const IDLE = "idle"
const CHASE = "chase"
const ATTACK = "attack"
const WANDER = "wander"
const STUN = "stun"
const PATROL = "patrol"
const CIRCLE = "circle"
const RETREAT = "retreat"
const SPECIAL = "special"
const ENRAGE = "enrage"
```

**使用**:
```gdscript
# 旧代码
state_machine.transition_to("chase")

# 新代码
state_machine.transition_to(StateNames.CHASE)
```

**执行步骤**:
- [ ] 1. 创建 `state_names.gd`
- [ ] 2. 全局搜索替换所有状态字符串
  - `Grep "\"idle\"|\"chase\"|\"attack\""` 查找所有引用
  - 逐个替换为常量
- [ ] 3. 测试所有状态机切换

**影响文件** (预计15+个):
- Boss状态脚本 (9个状态)
- Enemy状态脚本 (5个状态)
- StateMachine 基类

**预计工作量**: 1-2小时

---

### 7. 统一调试输出 - 使用DebugConfig

**问题**: Boss.gd 中有10+ print() 调试语句，应该使用 DebugConfig 系统

**影响**: 日志混乱，难以过滤和管理

**解决方案**: 统一使用 DebugConfig.debug/info/warn/error

**示例**:
```gdscript
# 旧代码
print("========== Boss.on_damaged 被调用 ==========")
print("当前血量: ", health, "/", max_health)

# 新代码
DebugConfig.info("Boss受伤 血量:%d/%d" % [health, max_health], "", "combat")
```

**执行步骤**:
- [ ] 1. 搜索所有 print() 语句
  ```bash
  grep -n "print(" Scenes/enemies/boss/**/*.gd
  ```
- [ ] 2. 替换为 DebugConfig 调用
  - debug() - 详细调试信息
  - info() - 重要信息
  - warn() - 警告
  - error() - 错误
- [ ] 3. 添加合适的标签：
  - "combat" - 战斗相关
  - "boss" - Boss相关
  - "phase" - 阶段转换

**影响文件**:
- boss.gd (10+ print)
- boss state scripts (5+ print)
- hahashin.gd (若干 print)

**预计工作量**: 1小时

---

### 8. Boss阶段转换解耦

**问题**: `change_phase()` 直接调用多个方法，耦合度高

**影响**: 难以扩展新的阶段效果

**解决方案**: 使用信号通知阶段变化

**重构示例**:
```gdscript
# 旧代码
func change_phase(new_phase: Phase):
    current_phase = new_phase
    update_health_bar_color()
    activate_phase_transition_effect()
    special_attack_cooldown = 0
    phase_changed.emit(new_phase)

# 新代码
func change_phase(new_phase: Phase):
    current_phase = new_phase
    phase_changed.emit(new_phase)

# 在 _ready() 中连接信号
func _ready():
    phase_changed.connect(_on_phase_changed)

func _on_phase_changed(new_phase: Phase):
    update_health_bar_color()
    activate_phase_transition_effect()
    reset_cooldowns()
```

**执行步骤**:
- [ ] 1. 重构 `change_phase()` 方法
- [ ] 2. 创建 `_on_phase_changed()` 处理器
- [ ] 3. 将阶段效果逻辑移到处理器中
- [ ] 4. 测试阶段转换功能

**预计工作量**: 0.5小时

---

## 📁 低优先级任务 (0/3 完成)

### 9. 目录结构重构

**问题**:
- 拼写错误: `charaters` → `Characters`
- 拼写错误: `Stategy` → `Strategy`
- 脚本和场景混在一起

**影响**: 项目不够专业，可能影响协作

**解决方案**: 重新组织目录结构

**新结构**:
```
Scenes/
├── Characters/        # 修正拼写
│   ├── Player/
│   │   ├── Scripts/
│   │   │   ├── hahashin.gd
│   │   │   ├── movement_handler.gd
│   │   │   └── animation_handler.gd
│   │   └── Scenes/
│   │       └── hahashin.tscn
│   └── ...
├── Enemies/
│   ├── Common/
│   │   └── Dinosaur/
│   │       ├── Scripts/
│   │       │   ├── dinosaur.gd
│   │       │   └── States/
│   │       └── Scenes/
│   └── Boss/
│       ├── Scripts/
│       │   ├── boss.gd
│       │   ├── attack_manager.gd
│       │   └── States/
│       └── Scenes/
└── UI/

Util/
├── StateMachine/
│   ├── Scripts/
│   │   ├── base_state_machine.gd
│   │   ├── base_state.gd
│   │   └── state_names.gd  # 新增
│   └── CommonStates/
├── Components/
│   ├── Health/
│   ├── HitBoxComponent/
│   └── HurtBoxComponent/
├── Classes/
│   ├── Damage/
│   └── Effects/
└── AutoLoad/
```

**执行步骤**:
- [ ] 1. 创建新目录结构
- [ ] 2. 逐个移动文件（Git保留历史）
  ```bash
  git mv Scenes/charaters Scenes/Characters
  ```
- [ ] 3. 更新所有场景和脚本中的路径引用
- [ ] 4. 更新 project.godot 中的AutoLoad路径
- [ ] 5. 全面测试所有场景

**风险**:
- ⚠️ 高风险：路径引用非常多
- 建议使用脚本批量更新路径

**预计工作量**: 4-6小时

**建议**: 低优先级，可选

---

### 10. 技能Resource系统

**问题**: 技能配置分散在多个地方（animation_handler, movement_handler, hahashin）

**影响**: 难以添加新技能，配置不统一

**解决方案**: 创建抽象的 Skill Resource

**设计**:
```gdscript
# Util/Classes/Skill.gd
extends Resource
class_name Skill

@export var skill_name: String
@export var animation_name: String
@export var damage: Damage
@export var sound_effect: AudioStream
@export var time_scale: float = 1.0
@export var cooldown: float = 0.0
@export var needs_preparation: bool = false
@export var disable_movement: bool = true

func execute(player: CharacterBody2D): ...
```

**使用**:
```gdscript
# 在编辑器中创建 .tres 资源文件
# Util/Data/Skills/SpecialAttack.tres

@export var skills: Array[Skill] = []

func _ready():
    for skill in skills:
        skill.execute(self)
```

**执行步骤**:
- [ ] 1. 创建 Skill.gd 基类
- [ ] 2. 创建子类:
  - PhysicalSkill
  - KnockUpSkill
  - SpecialAttackSkill
- [ ] 3. 迁移现有技能配置到 .tres 文件
- [ ] 4. 重构 animation_handler 使用 Skill 资源
- [ ] 5. 测试所有技能

**预计工作量**: 3-4小时

**建议**: 可选，用于长期扩展

---

### 11. UI状态指示器

**问题**: 缺少视觉反馈，Boss阶段、攻击模式不直观

**影响**: 玩家体验不佳

**解决方案**: 添加UI指示器

**新增UI**:
- Boss阶段指示器 (Phase 1/2/3)
- Boss当前攻击模式提示
- Player技能冷却指示器

**执行步骤**:
- [ ] 1. 设计UI布局
- [ ] 2. 创建 BossPhaseIndicator.tscn
- [ ] 3. 创建 SkillCooldownUI.tscn
- [ ] 4. 连接信号更新UI
- [ ] 5. 美化和测试

**预计工作量**: 2-3小时

**建议**: 可选，提升体验

---

## 🎯 推荐执行顺序

**第一批** (已完成):
1. ✅ Hitbox统一 (1小时)
2. ✅ AttackEffect await修复 (0.5小时)
3. ✅ Hitbox碰撞层配置 (0.5小时)

**第二批** (中优先级，快速改进):
4. ⏭️ 统一调试输出 (1小时)
5. ⏭️ 状态名称常量化 (1.5小时)
6. ⏭️ Boss阶段转换解耦 (0.5小时)
7. ⏭️ StunState重构 (2.5小时)

**第三批** (大型重构，独立测试):
8. ⏭️ Player组件化重构 (5小时)

**第四批** (可选优化):
9. ⏭️ 目录结构重构 (5小时，高风险)
10. ⏭️ 技能Resource系统 (3.5小时)
11. ⏭️ UI状态指示器 (2.5小时)

---

## 📝 注意事项

### Git工作流
- ✅ 每个优化任务创建独立分支
- ✅ 完成后提交PR，标注 `[optimization]` 前缀
- ✅ 合并前充分测试

### 测试清单
每个任务完成后需要测试：
- [ ] 玩家移动和攻击
- [ ] 敌人AI和状态机
- [ ] Boss战斗和阶段转换
- [ ] 特殊攻击和技能
- [ ] 受伤和死亡逻辑

### 性能监控
- 使用 Godot Profiler 检查性能影响
- 确保帧率稳定 (60 FPS)

---

**最后更新**: 2026-01-18
**总预计工作量**: 约30小时（不含可选任务）
**当前状态**: 高优先级任务 3/4 完成 ✅
