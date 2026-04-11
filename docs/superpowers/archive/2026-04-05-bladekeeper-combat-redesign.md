# BladeKeeper 战斗系统重设计

**日期**: 2026-04-05
**范围**: BKAttack 统一攻击状态 + 动画补全 + BossBase 模板清理 + 状态修复

---

## 问题总结

1. **继承节点无法删除**: BossBase.tscn 模板预置 7 个状态节点，继承场景无法删除
2. **Roll 原地不动**: 侧向闪避方向计算正确但缺少面朝玩家逻辑
3. **攻击找不到目标/漂移**: 攻击状态 enter() 未清零 velocity、未面朝玩家
4. **技能乱释放**: Projectile/Trap 同样缺少面朝 + 清零逻辑
5. **投射物/陷阱缺少动画**: 只用了 throw 单帧，缺少 land/detonate 动画
6. **combo 系统缺失**: 当前只有 3 段顺序连击，无随机选择、无 sp_atk 概率触发、无 dodge 后跳
7. **跳跃攻击缺失**: 有完整素材（jump_up/air_atk/jump_down）但未实现

---

## 设计方案

### 改动 1: BossBase.tscn 模板清理

**文件**: `Scenes/Characters/Templates/BossBase.tscn`

删除 StateMachine 下所有 7 个状态子节点（Idle, Patrol, Chase, Circle, Attack, Retreat, Stun）。模板只保留空的 StateMachine 节点。

每个 Boss 继承场景自行添加需要的状态节点：
- **BladeKeeper**: Idle, Chase, Attack, Stun, Defend, Roll, Projectile, Trap
- **DemonSlime**: 需同步调整，自行添加其状态
- **Cyclops**: 需同步调整，自行添加其状态

### 改动 2: BossBaseState.gd 移除占位逻辑

**文件**: `Scenes/Characters/Bosses/Shared/BossBaseState.gd`

完全移除 `process_state()` 占位安全退出逻辑。BossBase 模板不再有占位状态节点，此逻辑无用。

### 改动 3: BKAttack.gd 重写为统一攻击状态

**文件**: `Scenes/Characters/Bosses/BladeKeeper/States/BKAttack.gd`

BKAttack 内部使用步骤机（enum Step）管理所有攻击模式。mode 从 `BossAttackManager.last_picked_entry` 读取。

#### 攻击模式

| mode | 步骤流程 | 说明 |
|------|----------|------|
| `attack` | 随机 atk_1/2/3 单次 → 结束 | 普通攻击 |
| `combo` | 随机 atk_1/2/3 → 概率 sp_atk → dodge 后跳 | 地面连招 |
| `special` | sp_atk → 结束 | 特殊攻击 |
| `jump` | jump_up(向 player 靠近) → 可选 air_atk → jump_down → 可选接地面 combo(随机 atk → 概率 sp_atk → dodge 后跳) | 跳跃突进 |

#### 统一 enter() 逻辑

所有 mode 进入时：
- `boss.velocity = Vector2.ZERO`（停止移动）
- `boss.can_move = false`（禁止移动，防止其他逻辑干扰）
- 面朝 player（`sprite.flip_h = boss.global_position.x > target.global_position.x`）
- `can_be_interrupted = false`（不可被同优先级打断）

exit() 时恢复 `boss.can_move = true`。

**例外：** jump_up 步骤期间允许向 player 移动（由 BKAttack 自身的 physics_process_state 控制，不走通用移动逻辑）。dodge 后跳同理。

#### combo 中 sp_atk 触发概率

- Phase 1: 10%
- Phase 2: 30%
- Phase 3: 60%

概率通过 BossPhaseConfig 或 BKAttack 内部常量配置。

#### jump 模式详细流程

1. **jump_up**: 播放 jump_up 动画，`physics_process_state` 中向 player 方向移动（速度可配置，如 350），到达一定距离（如 attack_range 内）或动画结束时停止
2. **air_atk（可选）**: 概率触发空中攻击动画，附带伤害判定
3. **jump_down**: 播放下落动画，落地
4. **接地面 combo（可选）**: 落地后概率进入地面 combo 流程（随机 atk → 概率 sp_atk → dodge 后跳），或直接 dodge 后跳

#### dodge 后跳

- 方向：背离 player 的方向
- 距离/速度：可配置（如 speed=300, duration=0.3s）
- 动画：复用 roll 动画或 jump_down 动画
- 后跳结束后调用 `evaluate_combat_transition()` 决定下一个状态

#### 步骤机设计

```gdscript
enum Step {
    NONE,
    ATK,           # 普通攻击（随机 atk_1/2/3）
    SP_ATK,        # 特殊攻击
    DODGE,         # 后跳撤退
    JUMP_UP,       # 跳跃上升 + 靠近
    AIR_ATK,       # 空中攻击
    JUMP_DOWN,     # 下落
}

var _current_step: Step = Step.NONE
var _mode: String = "attack"
```

每个步骤通过 `animation_finished` 信号推进到下一步骤。jump_up 阶段额外在 `physics_process_state` 中处理移动。

### 改动 4: BKChase.gd 路由更新

**文件**: `Scenes/Characters/Bosses/BladeKeeper/States/BKChase.gd`

`_on_reached_attack_range()` 更新：
- 移除 `"defend"`, `"projectile"`, `"trap"` 的单独路由（这些仍是独立状态）
- 添加 `"jump"` → `"attack"`（jump 由 BKAttack 统一处理）
- `"combo"` → `"attack"`（combo 由 BKAttack 统一处理）

实际路由逻辑：
- `"defend"` → `"defend"`（独立状态）
- `"roll"` → `"roll"`（独立状态）
- `"projectile"` → `"projectile"`（独立状态）
- `"trap"` → `"trap"`（独立状态）
- `"attack"`, `"combo"`, `"special"`, `"jump"` → `"attack"`（BKAttack 统一处理，mode 由 last_picked_entry 传递）

### 改动 5: 攻击/技能状态统一修复

**适用文件**:
- `Scenes/Characters/Bosses/BladeKeeper/States/BKDefend.gd`
- `Scenes/Characters/Bosses/BladeKeeper/States/BKRoll.gd`
- `Scenes/Characters/Bosses/BladeKeeper/States/BKProjectile.gd`
- `Scenes/Characters/Bosses/BladeKeeper/States/BKTrap.gd`

所有攻击/技能状态 enter() 统一添加：
```gdscript
var boss := get_boss()
if boss:
    boss.velocity = Vector2.ZERO
    boss.can_move = false  # 禁止移动
if target_node and owner_node:
    var sprite = owner_node.get_node_or_null("AnimatedSprite2D")
    if sprite:
        sprite.flip_h = owner_node.global_position.x > target_node.global_position.x
```

exit() 统一恢复：
```gdscript
var boss := get_boss()
if boss:
    boss.can_move = true
```

**例外：** BKRoll 的 physics_process_state 需要移动（侧向翻滚），由其自身控制 velocity。

### 改动 6: AnimationTree 补充动画状态

**文件**: `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn`

在 control_sm（AnimationNodeStateMachine）中新增：
- `jump_up` — 使用 `03_jump_up` 素材
- `air_atk` — 使用 `air_atk` 素材
- `jump_down` — 使用 `03_jump_down` 素材
- `dodge` — 复用 roll 动画或 jump_down 动画

需要在 AnimationPlayer 中创建对应 Animation，然后在 control_sm 中添加 AnimationNodeAnimation 状态。

### 改动 7: 投射物/陷阱动画完善

**BKSwordProjectile.tscn**:
- 添加 AnimatedSprite2D 或 AnimationPlayer
- 飞行中：`projectile_throw.png`（当前单帧）
- 命中/落地：播放 `projectile_land` 动画（5 帧），播完后 queue_free

**BKTrapEntity.tscn**:
- 添加 AnimatedSprite2D 或 AnimationPlayer
- 投掷飞行：`trap_throw.png`（当前单帧）
- 落地待机：`trap_land` 动画（3 帧）
- 触发爆炸：`trap_detonate` 动画（5 帧），播完后 queue_free

### 改动 8: Phase Config 更新

**文件**: `Scenes/Characters/Bosses/BladeKeeper/BKAttackManager.gd`

更新 `_setup_default_phases()`：

```
Phase 1: attack(5), combo(2), defend(2), projectile(1)
Phase 2: attack(3), combo(3), jump(2), defend(2), roll(2), projectile(2), trap(2), special(1)
Phase 3: attack(2), combo(3), jump(3), defend(1), roll(2), projectile(2), trap(2), special(2)
```

---

## 影响范围

| 组件 | 改动 |
|------|------|
| BossBase.tscn | 删除 7 个状态节点 |
| BossBaseState.gd | 移除占位 process_state() |
| BladeKeeper.tscn | 添加状态节点 + AnimationTree 新动画 |
| DemonSlime.tscn | 同步调整：自行添加状态节点 |
| Cyclops.tscn | 同步调整：自行添加状态节点 |
| BKAttack.gd | 完全重写为统一攻击状态 |
| BKChase.gd | 路由逻辑更新 |
| BKDefend/Roll/Projectile/Trap.gd | enter() 添加 velocity 清零 + 面朝 |
| BKAttackManager.gd | phase config 更新 |
| BKSwordProjectile.tscn | 添加 land 动画 |
| BKTrapEntity.tscn | 添加 land + detonate 动画 |

## 不改动的部分

- BaseStateMachine.gd（上一轮已修复）
- BossAttackManager.gd 基类（last_picked_entry 已添加）
- StunState/BKStun.gd（已正确实现）
- Player 状态机和 Enemy 状态机
- Cyclops/DemonSlime 的状态脚本（只需调整 .tscn 节点结构）
