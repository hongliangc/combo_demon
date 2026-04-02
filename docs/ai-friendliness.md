# AI 友好性分析报告

> 分析项目中哪些结构、命名、隐式逻辑会误导 AI 辅助开发工具，并给出具体优化建议。

## 问题总览

| 严重度 | 数量 | 类别 |
|--------|------|------|
| HIGH | 4 | 命名误导 (2), AnimationTree 隐式依赖 (1), 多路径攻击逻辑 (1) |
| MEDIUM | 6 | 魔法数字 (3), 状态转换不一致 (1), 隐式信号连接 (1), 双模式状态 (1) |
| LOW | 2 | 类型检查模式不一致 (1), 字符串状态引用 (1) |

---

## HIGH — 必须关注

### 1. `follow_radius` 语义错误：实际是攻击激活距离

**位置**: `Core/Characters/EnemyBase.gd:29`, `Core/Resources/EnemyData.gd:26`

**问题**: `follow_radius` 名称暗示"跟随距离"，但实际用途是**攻击激活范围** — 进入此距离后敌人从 Chase 切换到 Attack 状态。

**证据**:
- `ChaseState.gd:48` — 变量命名 `attack_range`，值取自 `follow_radius`
- `AttackState.gd:62` — 用作 `effective_range` 判断是否足够近以发起攻击
- `BossBase.gd:27` — Boss 正确使用了 `attack_range` 命名

**AI 误导场景**: AI 在添加新敌人时，会将 `follow_radius` 设置为较大值（以为是跟随距离），实际导致敌人在很远距离就发起攻击。

**修复**: 重命名 `follow_radius` → `attack_activation_radius` 或 `attack_range`，统一 EnemyBase/EnemyData 中的命名。

---

### 2. `chase_radius` 语义反转：实际是放弃追击距离

**位置**: `Core/Characters/EnemyBase.gd:28`, `Core/Resources/EnemyData.gd:25`

**问题**: `chase_radius` 名称暗示"追击范围"，但实际是**追击放弃距离** — 目标超过此距离后敌人停止追击。

**证据**:
- `ChaseState.gd:47` — 变量命名 `give_up_range`，值取自 `chase_radius`
- `ChaseState.gd:52-54` — `if distance > give_up_range: transition to wander`
- 另有 `detection_radius`（行 27）才是真正的"发现目标并开始追击"的距离

**AI 误导场景**: AI 看到 `chase_radius = 300` 会理解为"300 像素内开始追击"，实际是"超过 300 像素放弃追击"。

**修复**: 重命名为 `chase_abandon_distance` 或 `give_up_distance`。

---

### 3. AnimationTree 隐式结构依赖

**位置**: `Core/StateMachine/BaseState.gd:371-414`

**问题**: BaseState 假定 AnimationTree 包含以下节点路径，但没有任何文档或验证：
```
parameters/control_blend/blend_amount    # Blend2 — 切换 locomotion/control
parameters/locomotion/blend_position     # BlendSpace2D — 移动方向
parameters/attack_oneshot/request        # OneShot — 攻击触发
parameters/control_sm/playback           # StateMachine — 受击/死亡
parameters/loco_timescale/scale          # TimeScale — 移动速度
parameters/ctrl_timescale/scale          # TimeScale — 控制层速度
```

**AI 误导场景**: AI 创建新角色场景时，不知道 AnimationTree 必须包含这些特定名称的节点。缺少任何一个节点时代码静默失败（不报错），动画不播放但没有提示原因。

**修复**:
1. 在 BaseState 中添加结构文档注释
2. 在 `get_anim_tree()` 中添加验证，缺失节点时 `push_warning()`
3. 提供 AnimationTree 模板场景供复用

---

### 4. 攻击执行的多路径实现

**问题**: 伤害发出有 3 条不同路径，没有统一接口：

| 路径 | 文件 | 机制 |
|------|------|------|
| AttackComponent | `AttackState.gd:89-98` | `attack_component.perform_attack()` |
| 自定义回调 | `AttackState.gd:98` | `on_custom_attack()` 虚方法 |
| 直接 HurtBox | `BKAttack.gd:39-45` | `_try_melee_damage()` 直接调用 |
| Manager 模式 | `BossAttackManager.gd` | 投射物池 + 组合攻击 |

**AI 误导场景**: AI 在添加新敌人攻击时，需要猜测使用哪条路径。查看不同敌人发现每个的实现方式不同，无法建立一致的认知模型。

**修复**: 文档中明确三种攻击模式的适用场景：
- 简单近战 → 使用 `AttackComponent`
- 自定义近战 → 覆写 `on_custom_attack()`
- 投射物/范围技 → 使用 `AttackManager` 模式

---

## MEDIUM — 建议改进

### 5. 眩晕状态的魔法数字

**位置**: `Core/StateMachine/CommonStates/StunState.gd:33,61`

```gdscript
var has_knockback = body.velocity.length() > 10.0
```

`10.0` 决定敌人在进入眩晕时是否保留当前速度（有击退效果）还是清零速度（纯眩晕）。无注释、无 @export。

**修复**: `@export var knockback_velocity_threshold := 10.0`

### 6. Boss 相位转换的硬编码击退参数

**位置**: `Core/Characters/BossBase.gd:131-132`

```gdscript
var knockback_radius := 200.0  # 击退范围
var knockback_force := 500.0   # 击退力度
```

相位转换时的击退效果参数内嵌在方法中，不可配置。

**修复**: 提取为 `@export_group("Phase Transition")` 导出变量。

### 7. Boss 攻击状态的减速率差异

**位置**: `Scenes/Characters/Enemies/boss/Scripts/States/BossAttack.gd:164,173`

```gdscript
_boss.velocity = _boss.velocity.lerp(Vector2.ZERO, 5.0 * delta)   # chase 模式
_boss.velocity = _boss.velocity.lerp(Vector2.ZERO, 10.0 * delta)  # timer 模式
```

两个减速率（5.0 vs 10.0）的差异没有解释。

**修复**: 导出为配置变量，添加注释说明设计意图。

### 8. `transition_to()` vs `transitioned.emit()` 不一致

**问题**: 部分状态使用 `transition_to()`（安全检查后转换），部分直接使用 `transitioned.emit()`（跳过检查）。两者行为不同但没有文档说明使用场景。

**位置示例**:
- `HitState.gd:52` — `transition_to("stun")`
- `BladeKeeper/BKAttack.gd:45` — `transitioned.emit(self, next)`

**修复**: 在 BaseState 中文档化两者区别，推荐统一使用 `transition_to()`。

### 9. 隐式信号连接缺少验证

**位置**: `BladeKeeper/States/BKAttack.gd:25-27`

```gdscript
if not _bk.sprite.animation_finished.is_connected(_on_anim_finished):
    _bk.sprite.animation_finished.connect(_on_anim_finished)
```

假定 `_bk.sprite` 存在且有 `animation_finished` 信号，无空值检查。

**修复**: 添加 null 检查和文档注释。

### 10. BossAttack 双模式设计无文档

**位置**: `BossAttack.gd:110-141`

一个状态内部包含两种行为模式（`"timer"` 站桩射击 vs `"chase"` 追击射击），通过 `config.behavior` 字符串切换。无注释解释设计原因。

**AI 误导场景**: AI 看到 `if _config.behavior == "timer"` 时不理解这是架构设计还是临时方案。

**修复**: 添加类级文档注释说明双模式设计意图，或拆分为两个状态。

---

## LOW — 可选优化

### 11. 字符串状态引用的拼写风险

多处状态转换使用硬编码字符串：
```gdscript
transition_to("specialskill")   # AttackState.gd
transition_to("stun")           # HitState.gd
transition_to("chase")          # SpecialSkillState.gd
```

重命名状态节点后需全局搜索替换，容易遗漏。

**修复**: 使用常量类 `StateNames.STUN` 替代字符串字面量。

### 12. 类型检查模式不统一

项目中混用三种类型检查方式：
- `effect.has_method("apply_effect")` — duck typing
- `owner_node is CharacterBody2D` — 类型检查
- `child is BossLaser` — 具体类检查

无统一规范指导何时使用哪种方式。

**修复**: 制定类型检查优先级：`is` 优先 → `has_method()` 用于可选鸭子类型 → 避免字符串类名比较。

---

## 优化优先级建议

### P0 — 立即修复（防止 AI 产生错误代码）
1. 重命名 `follow_radius` → `attack_range`（影响所有新敌人开发）
2. 重命名 `chase_radius` → `chase_abandon_distance`
3. 文档化 AnimationTree 必需结构（影响所有新角色开发）

### P1 — 短期改进（提升 AI 代码质量）
4. 文档化攻击执行的三种模式及适用场景
5. 统一 `transition_to()` 使用，弃用直接 `transitioned.emit()`
6. 将魔法数字提取为 `@export` 变量

### P2 — 长期优化（提升整体一致性）
7. 引入 `StateNames` 常量类替代字符串
8. 制定类型检查规范
9. 添加 AnimationTree 结构验证
