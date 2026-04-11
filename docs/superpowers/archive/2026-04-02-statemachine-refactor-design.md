# State Machine Architecture Refactor — Design Spec

**日期**: 2026-04-02
**范围**: BehaviorConfig Resource + CommonState Boss 吸收 + 死代码清理
**前置**: 03-29 unification plan 已部分执行（虚方法钩子、BossStateMachine 继承链、ForestEnemyStates 删除）

## 背景

03-29 统一优化创建了 BossIdleState / BossStunState 作为中间抽象层。本次重构进一步：
1. 将 Boss 变体逻辑**内联到 CommonStates**（消除中间层文件）
2. 引入 **BehaviorConfig Resource** 替代 EnemyData + get_owner_property() 字符串查找
3. 清理所有 PARAM_ONLY 脚本和死代码（~25 个文件）

## Decision 1: BehaviorConfig Resource

### 设计

创建 `Core/Resources/BehaviorConfig.gd` 替代 `EnemyData.gd`（当前无任何 .tscn 使用 EnemyData）。

```gdscript
class_name BehaviorConfig extends Resource

# ---- Health ----
@export_group("Health")
@export var max_health := 100
@export var health := 100

# ---- Wander ----
@export_group("Wander")
@export var min_wander_time := 2.5
@export var max_wander_time := 10.0
@export var wander_speed := 50.0

# ---- Chase ----
@export_group("Chase")
@export var detection_radius := 100.0
@export var chase_abandon_distance := 200.0
@export var attack_activation_radius := 25.0
@export var chase_speed := 75.0
@export var ground_only := false  # 水平移动模式（替代 SnailChase/BoarChase）

# ---- Idle ----
@export_group("Idle")
@export var min_idle_time := 1.0
@export var max_idle_time := 3.0

# ---- Stun ----
@export_group("Stun")
@export var stun_duration := 1.0
@export var stun_anim_speed := 1.0

# ---- Hit ----
@export_group("Hit")
@export var hit_duration := 0.3

# ---- Physics ----
@export_group("Physics")
@export var has_gravity := false
@export var gravity := 800.0

# ---- Boss 扩展（gated by is_boss）----
@export_group("Boss")
@export var is_boss := false
@export var attack_range := 300.0
@export var min_distance := 150.0
@export var stun_immunity_duration := 1.5
```

### 数据访问模式

BaseState 新增 `_get_config()`:

```gdscript
func _get_config() -> BehaviorConfig:
    if owner_node and "behavior_config" in owner_node:
        return owner_node.behavior_config
    return null
```

CommonStates 优先从 config 读取，fallback 到 @export：

```gdscript
var config := _get_config()
var speed := config.chase_speed if config else default_chase_speed
```

### 迁移路径

- EnemyBase: `@export var behavior_config: BehaviorConfig` 替代 `enemy_data: EnemyData` + 散落的 @export
- BossBase: `@export var behavior_config: BehaviorConfig` 新增
- 每个 enemy/boss 场景创建对应 .tres 或在 .tscn Inspector 内联配置

## Decision 2: Preserve HEAVY Boss Scripts

以下 Boss 状态脚本逻辑复杂，保持独立继承 BaseState 或 BossState：

| 脚本 | 原因 |
|------|------|
| BKAttack | combo 选择器 + 阶段路由 |
| BKDefend | 防御状态机 |
| BKRoll | 翻滚物理 |
| BKProjectile/BKTrap | 投射物/陷阱逻辑 |
| CyclopsAttack | 阶段路由 + 攻击选择 |
| CyclopsRetreat | 传送逻辑 |
| CyclopsCircle/CyclopsPatrol | 环绕/巡逻路径 |
| CyclopsChase | 追击攻击混合模式 |
| DSCleave/DSChase | 攻击选择器 |
| CyclopeAttackState | 小怪特殊攻击 |

## Decision 3: CommonState 吸收 Boss 变体

### IdleState 吸收 BossIdleState

在 `_evaluate_idle_transition()` 中添加 boss 分支：

```gdscript
func _evaluate_idle_transition() -> void:
    var boss := owner_node as BossBase if owner_node is BossBase else null
    if boss:
        if not is_target_alive():
            return
        var distance := get_distance_to_target()
        if distance <= boss.attack_range and boss.attack_cooldown <= 0:
            transition_to("attack")
        elif distance <= boss.detection_radius:
            transition_to("chase")
        return
    # 默认 enemy 行为
    if try_attack():
        return
    if try_chase():
        return
```

### StunState 吸收 BossStunState

- `_on_stun_exit()` 钩子已存在，添加 boss 默认实现：

```gdscript
func _on_stun_exit() -> void:
    var boss := owner_node as BossBase if owner_node is BossBase else null
    if boss:
        var config := _get_config()
        var immunity := config.stun_immunity_duration if config else 1.5
        boss.stun_immunity = immunity

func decide_next_state() -> void:
    var boss := owner_node as BossBase if owner_node is BossBase else null
    if boss:
        _boss_decide_next_state(boss)
        return
    super.decide_next_state()  # 或 BaseState 的默认实现
```

### ChaseState 添加 ground_only + boss cooldown

- `ground_only` 标志：仅水平移动 + 可选墙壁反弹（替代 SnailChase/BoarChase）
- boss cooldown 检查：`_on_reached_attack_range()` 中检查 `boss.attack_cooldown`

### BaseState 添加 evaluate_transition()

统一距离决策方法，替代 BossBaseState.evaluate_combat_transition() 的 4 处散落实现：

```gdscript
func evaluate_transition() -> String:
    var boss := owner_node as BossBase if owner_node is BossBase else null
    if boss:
        return _evaluate_boss_transition(boss)
    # enemy 默认
    if is_target_alive() and is_target_in_range(get_owner_property("detection_radius", detection_radius)):
        return chase_state_name
    return default_state_name
```

## Decision 4: 清理死代码

### 文件删除（~25 个）

| 类别 | 文件 |
|------|------|
| 中间抽象层 | BossIdleState.gd, BossStunState.gd |
| Boss PARAM_ONLY | BKIdle, DSIdle, CyclopsStun, CyclopsIdle |
| Enemy PARAM_ONLY | BeeChase, EnemyChase (dinosaur), SnailAttack, SnailIdle, SnailStun |
| 已删除目录 | ForestEnemyStates/ (已在 03-29 完成) |
| 过时 Resource | EnemyData.gd |

### 方法删除

**BaseState** (0 callers):
- `reset_time_scale()` — 未使用
- `get_animation_params()` — 未使用
- `move_away_from_target()` — 未使用

**EnemyStateMachine** (0 callers):
- `force_hit()` — 未使用
- `force_knockback()` — 未使用
- `force_stun()` — 未使用

### AnimationTree 三重激活修复

保留 BaseStateMachine._setup_animation_tree() 作为唯一激活点，移除：
- EnemyBase._on_character_ready() 中的 `anim_tree.active = true`
- BossBase._on_character_ready() 中的 `anim_tree.active = true`

### 死亡逻辑提取到 BaseCharacter

EnemyBase._handle_death() 和 BossBase._handle_death() 共享：
- 停止状态机
- AnimationTree death 动画播放
- fallback 白闪/直接播放

提取到 BaseCharacter._handle_death() 默认实现。

## 需保留的自定义脚本（有实际逻辑）

| 脚本 | 自定义逻辑 | 处理方式 |
|------|-----------|---------|
| BKChase | 阶段速度 + cooldown 检查 | 保留，继承 ChaseState |
| DSStun | Phase 3 免疫 | 保留，继承 StunState |
| SnailChase | 水平移动 + 墙壁检测 | ground_only flag 吸收后可删 |
| SnailWander | 水平移动 + 墙壁反弹 | ground_only flag 吸收后可删 |
| BoarChase | 水平移动 + 重力 | ground_only flag 吸收后可删 |

## 验证策略

1. 每个 Phase 完成后运行所有 enemy/boss 场景
2. 状态机日志验证：Idle → Chase → Attack → Hit/Stun 循环正常
3. AnimationTree 只激活一次（检查日志无重复）
4. .tres 配置值与原 .tscn @export 值一致
