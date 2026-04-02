# EnemyBase / BossBase 架构统一优化设计

**日期**: 2026-03-29
**范围**: Sprite统一 + 状态机继承链 + Boss状态复用CommonStates

## 背景

EnemyBase 和 BossBase 都继承 BaseCharacter，共享生命系统、AnimationTree 双层架构、BaseStateMachine 优先级状态切换。但存在三处可优化的不一致：

1. EnemyBase 使用 Sprite2D，BossBase 使用 AnimatedSprite2D
2. BossStateMachine 和 EnemyStateMachine 各自独立继承 BaseStateMachine，Boss 缺少便捷方法
3. BKIdle/DSIdle/DSStun 等 Boss 状态重写了 CommonStates 的逻辑（~500行重复代码）

## 改进1: EnemyBase Sprite 统一

### 变更

- `EnemyBase.tscn`: Sprite2D 节点改为 AnimatedSprite2D
- `EnemyBase.gd`:
  - `_update_sprite_facing()` 简化：去掉 `Sprite2D`/`AnimatedSprite2D` 分支判断，统一使用 `flip_h`（两者都有此属性）
  - `_find_sprite()` 保持不变（已优先查找 AnimatedSprite2D）

### 不变

- 所有具体敌人场景（~15个）不需要改，它们各自覆盖了 sprite 节点
- BaseState.gd 的 `update_sprite_facing()` 已使用 CanvasItem 通用逻辑，无需改动

### 影响范围

EnemyBase.gd（1个方法简化）+ EnemyBase.tscn（1个节点类型）

## 改进2: BossStateMachine 继承 EnemyStateMachine

### 变更

继承链改为：
```
BaseStateMachine
  └── EnemyStateMachine（预设创建 + 便捷方法）
        └── BossStateMachine（阶段路由保护）
```

- `BossStateMachine.gd`: `extends BaseStateMachine` → `extends EnemyStateMachine`
- Boss 场景的 StateMachine 节点已手动配置状态，auto_create_states 行为通过现有子节点检查自动跳过（`get_child_count() == 0` 条件）

### 获得

BossStateMachine 自动获得：`force_stun()`, `force_hit()`, `force_knockback()`, `is_controlled()`, `is_reacting()`, `can_act()`

### 不变

- 各具体 Boss 的 StateMachine 子类（CyclopsStateMachine, DSStateMachine, BKStateMachine）不变
- Boss 场景仍在 .tscn 手动配置状态节点

### 影响范围

BossStateMachine.gd（改1行继承）

## 改进3: Boss 状态复用 CommonStates

### 3a. CommonStates 添加虚方法钩子

**IdleState.gd**:
- 提取 `virtual func _evaluate_idle_transition() -> void`
- 默认实现：`try_attack()` + `try_chase()`（现有行为不变）
- `process_state()` 改为调用此虚方法

**ChaseState.gd**:
- 提取 `virtual func _on_reached_attack_range() -> String`
- 默认返回 `"attack"`
- 攻击范围判定处改为调用此虚方法获取目标状态名

**StunState.gd**:
- `_on_timer_timeout()` 改为调用已有的 `decide_next_state()`（当前未调用）
- 添加 `virtual func _on_stun_exit() -> void`，在 `exit()` 末尾调用
- 默认空实现

### 3b. Boss 状态改为继承 CommonStates

| Boss 状态 | 当前继承 | 改为继承 | 自定义内容 |
|---|---|---|---|
| BKIdle | BossState | IdleState | 重写 `_evaluate_idle_transition()`: 用 `evaluate_combat_transition()` 模式 |
| DSIdle | BossState | IdleState | 同 BKIdle |
| BKChase | BossState | ChaseState | 重写 `_on_reached_attack_range()` |
| DSStun | BossState | StunState | 重写 `_on_stun_exit()` 设 immunity + `decide_next_state()` 用 boss 决策 |

### 不动的状态（已正确或逻辑独特）

- **CyclopsIdle** — 已继承 IdleState
- **CyclopsStun** — 已继承 StunState
- **CyclopsChase** — 追击中攻击的混合模式，逻辑独特
- **DSChase** — 攻击选择器逻辑，保持独立
- **BKAttack/BKDefend/BKRoll** — 完全 Boss 特有

### BossState 基类访问问题

BKIdle/DSIdle 改为继承 IdleState 后，IdleState 的基类是 BaseState 而非 BossState，会失去 `evaluate_combat_transition()` 等 Boss 工具方法。

**解决方案**: 在重写的钩子方法中，通过 `owner_node as BossBase` 直接获取 Boss 参数（detection_radius, attack_range 等），内联简化版距离决策。代码量 3-5 行，远小于维护重复状态的成本。

## 验证策略

1. 每个改进完成后单独运行 3 个 Boss 场景 + 全项目验证 0 errors
2. 确认现有敌人场景不受影响（EnemyBase.tscn 改动向后兼容）
3. 确认状态机转换日志正常（Idle → Chase → Attack 等循环）
