# 风险与技术债分析

> 基于代码审查的风险点识别、技术债清单、改进建议（按 P0/P1/P2 分级）。

## 一、风险热力图

| 风险区域 | 严重度 | 影响范围 | 文件 |
|---------|--------|---------|------|
| Combo await 无状态检查 | P0 | Boss 战 | BossAttackManager.gd:28-34 |
| 玩家特殊攻击 await 链路 | P0 | 玩家战斗 | PlayerSpecialAttackState.gd, SkillManager.gd |
| BaseStateMachine 信号泄漏 | P0 | 全局 | BaseStateMachine.gd:124 |
| SkillManager God Object | P1 | 玩家战斗 | SkillManager.gd (~460行) |
| BaseState 体积过大 | P1 | 全局 | BaseState.gd (459行) |
| BK 信号连接累积 | P1 | BladeKeeper | BKAttack.gd, BKDefend.gd |
| 字符串状态引用 | P1 | 状态机 | CommonStates/*.gd |
| Boss 攻击池硬编码 | P1 | Boss 战 | BossAttack.gd:31-95 |
| 命名语义错误 | P1 | 敌人 AI | EnemyBase.gd:28-29 |
| BossRetreat 职责过多 | P2 | Boss 战 | BossRetreat.gd (241行) |

---

## 二、P0 — 必须修复（崩溃/逻辑错误风险）

### 2.1 Combo 攻击 await 链路缺少状态有效性检查

**位置**: `Scenes/Characters/Enemies/boss/Scripts/BossAttackManager.gd:28-34`

```gdscript
func execute_combo(combo: BossComboAttack) -> void:
    for step in combo.steps:
        if step.delay > 0:
            await get_tree().create_timer(step.delay).timeout  # ← 危险
        _execute_combo_step(step)  # ← await 恢复后无状态检查
```

**风险**: Combo 攻击由多个步骤组成，步骤之间有 `await` 等待延迟。如果 Boss 在 combo 执行期间被眩晕/击退/死亡导致状态切换，`await` 恢复后仍会继续执行后续攻击步骤。

**对比**: 同文件的 `fire_rapid_projectiles()` (行 228-234) 正确实现了安全检查：
```gdscript
func fire_rapid_projectiles(target, count, interval):
    for i in count:
        if not is_instance_valid(target) or not is_instance_valid(boss):
            return  # ✅ 安全检查
        fire_single_projectile(target.global_position)
```

**修复**: 在 combo 循环中添加状态有效性检查：
```gdscript
func execute_combo(combo: BossComboAttack) -> void:
    for step in combo.steps:
        if step.delay > 0:
            await get_tree().create_timer(step.delay).timeout
        if not is_instance_valid(boss) or boss.stunned:
            return  # 状态已变化，中止 combo
        _execute_combo_step(step)
```

**收益**: 防止 Boss 在眩晕/死亡状态下继续发射攻击，避免"幽灵攻击"bug。

---

### 2.2 apply_knockback_to_player 的 await 后无 Boss 有效性检查

**位置**: `BossAttackManager.gd:193-198`

```gdscript
func apply_knockback_to_player(player):
    fire_spiral_projectiles(20)
    await get_tree().create_timer(0.1).timeout  # ← 0.1s 后
    if is_instance_valid(boss):                 # ✅ 检查了 boss
        fire_aoe()                              # 但没检查 player
```

**风险**: 检查了 `boss` 但没有检查 `player` 是否仍然有效。如果玩家在 0.1s 内死亡/切换场景，`fire_aoe()` 可能发到无效位置。风险较低但应一并修复。

### 2.3 玩家特殊攻击 await 链路无节点有效性检查

**位置**: `Core/StateMachine/PlayerStates/PlayerSpecialAttackState.gd:64-87`, `Core/Components/SkillManager.gd:161-315`

**问题**: `_run_flow()` 中多个顺序 `await` 调用（create_effects → detect_enemies → gather_enemies → dash_to_target → cleanup），仅检查 `_flow_active` 标志，未验证 `owner_node`/`body` 是否仍然有效。

**风险**: 玩家在特殊攻击流程中死亡/传送/切换场景时，后续阶段继续执行，访问已释放的节点导致崩溃。`SkillManager` 中的 `_perform_camera_and_gather_sequence()` 同样有多个 await 点，涉及 camera、bullet time、enemy 数组，均无有效性验证。

**修复**: 在每个 `await` 恢复后添加 `if not is_instance_valid(owner_node): return` 检查。

---

### 2.4 BaseStateMachine damaged 信号未断开

**位置**: `Core/StateMachine/BaseStateMachine.gd:124`

```gdscript
owner_node.damaged.connect(_on_owner_damaged)  # 无对应 disconnect
```

**问题**: `_setup_signals()` 中连接了 `owner_node.damaged` 信号，但整个类中没有对应的 `disconnect()` 或 `_exit_tree()` 清理。如果状态机被销毁但 owner 节点仍存在，信号回调会尝试调用已释放的状态机引用。

**修复**: 添加 `_exit_tree()` 方法断开所有信号连接。

---

## 三、P1 — 建议修复（维护性/扩展性问题）

### 3.1 SkillManager God Object（~460 行）

**位置**: `Core/Components/SkillManager.gd`

**现状**: 单一组件承担过多职责：特殊攻击 6 阶段编排、相机控制、子弹时间管理、残影效果、漩涡管理、敌人检测、聚集效果、清理。

**风险**: 修改任何一个阶段都可能影响其他阶段。异步链路中的 bug 极难定位。

**建议**: 拆分为 `SpecialAttackOrchestrator`、`CameraSequenceController`、`BulletTimeManager`、`EnemyGatherManager`。

**收益**: 单一职责，异步链路更短更安全，独立测试各阶段。

---

### 3.2 BaseState.gd 体积过大（459 行，God Object 倾向）

**位置**: `Core/StateMachine/BaseState.gd`

**现状**: 单文件承担过多职责：
- 状态生命周期管理（enter/exit/process）
- AnimationTree 操作（locomotion/control/attack）
- Timer 管理
- 移动工具方法
- 优先级判定
- 方向计算

**风险**: 新增功能时倾向于往 BaseState 中堆砌方法，加剧膨胀。修改任何功能都需要阅读 459 行代码。

**建议**: 将 AnimationTree helper 方法（~100 行）提取为 `AnimationHelper` 工具类或 mixin。移动相关方法提取为独立 helper。

**收益**: 每个文件职责单一，新开发者更容易定位修改点。

---

### 3.3 BladeKeeper 信号连接累积

**位置**: `Scenes/Characters/Enemies/BladeKeeper/States/BKAttack.gd:27`, `BKDefend.gd:26`

**问题**: `BKAttack` 在 `_play_combo_step()` 中每次 combo 迭代都连接 `animation_finished` 信号，但仅在 `exit()` 中断开。如果 combo 重置而未完成，同一信号上累积多个连接，导致一次动画完成触发多次回调。

`BKDefend` 同样在 `_on_defend_timeout()` 回调中连接信号，中断重入时累积。

**修复**: 连接前始终检查 `is_connected()`，或在 `enter()` 中统一连接、`exit()` 中统一断开。

**收益**: 防止攻击多次触发导致连锁伤害。

---

### 3.4 字符串状态引用散布全局

**位置**: CommonStates/*.gd 中约 15+ 处硬编码字符串

```gdscript
# 散布在多个文件中的字符串引用
transition_to("specialskill")   # AttackState.gd, ChaseState.gd
transition_to("stun")           # HitState.gd, KnockbackState.gd
transition_to("chase")          # SpecialSkillState.gd
transition_to("idle")           # WanderState.gd
transition_to("wander")         # IdleState.gd
transition_to("attack")         # ChaseState.gd
```

**风险**: 重命名状态节点后需要全局搜索替换，遗漏一个就是静默 bug。BaseStateMachine 在运行时才报错（行 140 的 `push_error`），且只在启用了 state_machine 日志通道时可见。

**建议**: 创建 `StateNames` 常量类：
```gdscript
class_name StateNames
const IDLE = "idle"
const CHASE = "chase"
const ATTACK = "attack"
const STUN = "stun"
const HIT = "hit"
const KNOCKBACK = "knockback"
const WANDER = "wander"
const SPECIALSKILL = "specialskill"
```

**收益**: 编辑器自动补全，重命名只改一处，拼写错误在编译期暴露。

---

### 3.5 Boss 攻击池硬编码在状态脚本中

**位置**: `Scenes/Characters/Enemies/boss/Scripts/States/BossAttack.gd:31-95`

**现状**: 三个阶段的攻击配置（约 60 行字典数组）直接写在 BossAttack 状态脚本中，而非使用已有的 `BossPhaseConfig` Resource。

**风险**:
- 添加新 Boss 需要复制整个 BossAttack 脚本（或用大量 if/else 分支）
- 配置与代码紧耦合，策划无法通过 Inspector 调整
- 已有 BossPhaseConfig Resource 类但未被利用

**建议**: 将攻击池迁移到 BossPhaseConfig .tres 文件，BossAttack 状态从 BossBase 获取当前阶段配置。

**收益**: 新 Boss 只需新建 .tres 配置，无需修改/复制代码。

---

### 3.6 follow_radius / chase_radius 命名误导

**位置**: `Core/Characters/EnemyBase.gd:28-29`, `Core/Resources/EnemyData.gd:25-26`

**现状**:
- `follow_radius` 实际含义是"攻击激活距离"（进入此范围开始攻击）
- `chase_radius` 实际含义是"追击放弃距离"（超过此范围停止追击）

**风险**: 新开发者或 AI 工具根据名称设置参数，产生与预期相反的行为。BossBase 中正确使用了 `attack_range` 命名，加剧混淆。

**建议**: 重命名为 `attack_activation_radius` 和 `chase_abandon_distance`。

**收益**: 消除最常见的 AI/人类理解错误。

---

### 3.7 CommonStates 中无信号连接/断开

**位置**: `Core/StateMachine/CommonStates/*.gd`

**现状**: CommonStates 的 7 个状态中，`enter()` 和 `exit()` 都不涉及信号连接/断开。这本身没有问题——但与 PlayerStates 形成对比：

```gdscript
# PlayerCombatState.gd — 正确的 connect/disconnect 对
func enter(msg := {}):
    tree.animation_finished.connect(_on_animation_finished)
func exit():
    tree.animation_finished.disconnect(_on_animation_finished)
```

**风险**: 如果未来 CommonStates 需要添加信号连接（如监听动画完成），开发者可能忘记在 `exit()` 中断开，因为现有代码中没有这个模式作为参考。

**建议**: 在 BaseState 中添加注释文档，提醒状态如需连接信号必须在 exit() 中断开。

---

## 四、P2 — 优化项（代码质量提升）

### 4.1 BossRetreat 状态职责过重（241 行）

**位置**: `Scenes/Characters/Enemies/boss/Scripts/States/BossRetreat.gd`

**现状**: 单一状态同时处理：撤退移动、瞬移逻辑、物理碰撞检测、VFX 生成、攻击发射。

**建议**: 将瞬移逻辑提取为独立的 `BossTeleport` 状态或 helper 类。

**收益**: 单个状态文件更易理解和调试。

---

### 4.2 魔法数字散布

| 文件 | 行 | 值 | 含义 |
|------|----|----|------|
| StunState.gd | 33 | `10.0` | 击退速度阈值 |
| BossBase.gd | 131 | `200.0` | 相位转换击退半径 |
| BossBase.gd | 132 | `500.0` | 相位转换击退力度 |
| BossAttack.gd | 164 | `5.0` | chase 模式减速率 |
| BossAttack.gd | 173 | `10.0` | timer 模式减速率 |
| BossAoe.gd | 51 | `50.0` | 假设精灵基础大小 |
| BossLaser.gd | 66 | `10.0`, `0.5`, `0.3` | 闪烁效果参数 |

**建议**: 提取为 `@export` 变量或 `const`，添加注释说明含义。

**收益**: 参数可通过编辑器调整，代码意图更清晰。

---

### 4.3 BossComboAttack 工厂方法每次创建新对象

**位置**: `Scenes/Characters/Enemies/boss/Scripts/BossComboAttack.gd:49-100`

```gdscript
static func create_triple_shot() -> BossComboAttack:
    var combo = BossComboAttack.new()  # 每次调用都创建
    combo.add_step(...)
    return combo
```

7 个工厂方法每次调用都 `new()` 创建 BossComboAttack + 多个 AttackStep。Combo 执行频繁时可能产生 GC 压力。

**建议**: 考虑缓存 combo 实例，或使用 Resource 预定义。

**收益**: 减少高频战斗场景的 GC 压力。

---

### 4.4 缺少场景有效性断言

部分关键路径缺少 null 检查：

```gdscript
# EnemyBase.gd:44-45 — @onready 无 null 保护
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var anim_tree: AnimationTree = $AnimationTree
# 如果场景中缺少这些节点，运行时 null reference
```

**建议**: 在 `_ready()` 中添加断言：
```gdscript
assert(anim_player != null, "EnemyBase requires AnimationPlayer child node")
```

**收益**: 场景配置错误在启动时立即暴露，而非运行中随机崩溃。

---

## 五、最容易出 Bug 的区域

| 排名 | 区域 | 原因 |
|------|------|------|
| 1 | Boss combo 攻击执行 | await 链路无状态检查，状态切换后继续执行 |
| 2 | 玩家特殊攻击流程 | SkillManager 多阶段 await 无节点有效性验证 |
| 3 | BladeKeeper 连招 | 信号连接累积导致攻击多次触发 |
| 4 | 新敌人 AI 参数配置 | follow_radius/chase_radius 命名误导 |
| 5 | AnimationTree 配置 | 隐式依赖特定节点结构，缺失时静默失败 |
| 6 | 状态转换字符串 | 拼写错误运行时才暴露 |
| 7 | 新 Boss 攻击配置 | 硬编码攻击池，复制代码时易出错 |

## 六、改进建议汇总

### P0 — 必须改
| # | 建议 | 收益 |
|---|------|------|
| 1 | combo await 链路添加 boss/状态有效性检查 | 防止眩晕/死亡后幽灵攻击 |
| 2 | PlayerSpecialAttackState/SkillManager await 后添加 is_instance_valid | 防止玩家死亡后崩溃 |
| 3 | BaseStateMachine 添加 _exit_tree() 断开 damaged 信号 | 防止信号泄漏到已释放节点 |

### P1 — 建议改
| # | 建议 | 收益 |
|---|------|------|
| 4 | SkillManager 拆分为 4 个独立组件 | 消除 460 行 God Object，降低异步 bug 风险 |
| 5 | BK 信号连接前检查 is_connected() | 防止攻击多次触发 |
| 6 | 重命名 follow_radius/chase_radius | 消除最常见的参数配置错误 |
| 7 | 引入 StateNames 常量类 | 消除字符串状态引用的拼写风险 |
| 8 | Boss 攻击池迁移到 BossPhaseConfig .tres | 新 Boss 只需配置不需改代码 |
| 9 | BaseState AnimationTree helper 提取 | 降低 God Object 风险，文件更聚焦 |

### P2 — 优化项
| # | 建议 | 收益 |
|---|------|------|
| 10 | BossRetreat 瞬移逻辑提取 | 状态职责单一化 |
| 11 | 魔法数字提取为 @export/const | 参数可调，代码意图清晰 |
| 12 | BossComboAttack 实例缓存 | 减少高频场景 GC 压力 |
| 13 | 关键节点 @onready 添加断言 | 配置错误启动时暴露 |
