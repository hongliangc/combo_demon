# Hit State 伤害流程重构设计

## 问题

当前 `HealthComponent.take_damage()` 在扣血后、发出 `damaged` 信号之前执行 `apply_attack_effects()`。StunEffect/ForceStunEffect 的 `apply_effect()` 会直接调用 `state_machine.force_transition("stun")`，导致状态机在 `damaged` 信号到达前就已切换到 StunState。

**后果**：`_on_owner_damaged()` → `current_state.on_damaged()` 在 StunState 上执行，而非原始状态。Boss 的 poise/evasion 决策链被完全绕过，因为 StunState 继承 BaseState（无 Boss 逻辑）。

**根因**：AttackEffect 在 HealthComponent 内直接操作状态机，违反了关注点分离原则。HealthComponent 应只负责 HP 管理和信号发射，不应干预状态机。

## 设计目标

1. HealthComponent 只负责扣血 + 发信号，不再调用 `apply_attack_effects()`
2. AttackEffect 不再操作状态机（移除 `force_transition` 调用），只修改目标属性
3. **HitState 是唯一的受击反应状态**，不再路由到 Stun/Knockback 状态节点
4. HitState 内部应用效果、播放对应动画、管理持续时间
5. Boss 的 poise/evasion 决策在 `_on_owner_damaged` 中正确执行（此时状态未被篡改）
6. 框架通用，所有存量角色（Enemy、Boss、Player）统一迁移，不保留旧流程

## 核心理念

Stun、Knockback、KnockUp 等都是**攻击效果**，不是**状态**。它们修改被攻击者的属性（velocity、stunned、can_move 等）并播放对应动画/特效，但不应驱动状态机转换。HitState 统一处理所有受击反应：

- **无效果**：播放 hit 动画，短暂硬直
- **StunEffect**：播放 stunned 动画，设置 stunned 标记，持续 stun_duration
- **ForceStunEffect**：同上 + 停止移动
- **KnockBackEffect**：设置击退 velocity，HitState 内物理减速
- **KnockUpEffect**：启动击飞 tween
- **GatherEffect**：启动聚集 tween
- 以上可组合（如 KnockBack + Stun）

## 新伤害流程

```
HitBox → HurtBox.take_damage()
  → HealthComponent.take_damage()
      ├─ 扣血
      ├─ 显示伤害数字
      ├─ health_changed.emit()
      └─ damaged.emit(damage, attacker_position)
          → StateMachine._on_owner_damaged()
              ├─ [Boss] poise/evasion 检查 → counter/defend/roll（跳过效果）
              ├─ 缓存 last_damage + last_attacker_position
              └─ current_state.on_damaged() → transition to "hit"
                  → HitState.enter()
                      ├─ 从 state_machine 读取缓存的 Damage
                      ├─ 遍历 damage.effects，应用效果（修改属性）
                      ├─ 根据最高优先级效果选择动画 + 持续时间
                      ├─ 播放对应控制层动画（hit/stunned）
                      └─ 启动持续时间计时器 → 到期后 decide_next_state()
```

## 修改清单

### 1. HealthComponent.take_damage() — 移除效果应用

**文件**: `Core/Components/HealthComponent.gd`

移除 `apply_attack_effects()` 调用。`take_damage()` 只做：
1. 无敌/存活检查
2. 扣血
3. 显示伤害数字
4. 发出 `health_changed` 信号
5. 发出 `damaged` 信号
6. 检查死亡

`apply_attack_effects()` 方法可删除（HitState 直接遍历 `damage.effects` 调用各 effect 的 `apply_effect()`）。

### 2. BaseStateMachine — 缓存伤害数据

**文件**: `Core/StateMachine/BaseStateMachine.gd`

新增两个变量：
```gdscript
var last_damage: Damage = null
var last_attacker_position: Vector2 = Vector2.ZERO
```

在 `_on_owner_damaged()` 中缓存：
```gdscript
func _on_owner_damaged(damage: Damage, attacker_position: Vector2 = Vector2.ZERO) -> void:
    last_damage = damage
    last_attacker_position = attacker_position
    if current_state and current_state.has_method("on_damaged"):
        current_state.on_damaged(damage, attacker_position)
```

### 3. HitState — 统一受击反应状态

**文件**: `Core/StateMachine/CommonStates/HitState.gd`

重写为统一处理所有受击反应的状态。不再路由到其他状态。

**效果优先级**（决定动画和持续时间）：
1. ForceStunEffect → 动画 "stunned"，持续 stun_duration
2. StunEffect → 动画 "stunned"，持续 stun_duration
3. KnockBackEffect / KnockUpEffect → 动画 "hit"，持续由物理减速/tween 决定
4. 无效果 → 动画 "hit"，持续 hit_duration

```gdscript
func enter() -> void:
    var damage: Damage = state_machine.last_damage
    var attacker_pos: Vector2 = state_machine.last_attacker_position

    if damage and not damage.effects.is_empty():
        _apply_effects(damage, attacker_pos)
    else:
        _start_hit_stagger()

func _apply_effects(damage: Damage, attacker_pos: Vector2) -> void:
    # 应用所有效果（修改属性、设置 velocity、启动 tween 等）
    for effect in damage.effects:
        if effect:
            effect.apply_effect(owner_node as CharacterBody2D, attacker_pos)

    # 根据效果类型选择动画和持续时间
    var stun_effect := _find_effect(damage, "ForceStunEffect")
    if not stun_effect:
        stun_effect = _find_effect(damage, "StunEffect")

    if stun_effect:
        # 眩晕：播放 stunned 动画，使用 stun_duration
        var duration: float = stun_effect.stun_duration if "stun_duration" in stun_effect else 1.5
        _is_stunned = true
        enter_control_state("stunned")
        start_timer(duration)
        if "stunned" in owner_node:
            owner_node.stunned = true
    elif damage.has_effect("KnockBackEffect") or damage.has_effect("KnockUpEffect"):
        # 击退/击飞：效果已设置 velocity/tween，HitState 处理减速
        _has_knockback = true
        enter_control_state("hit")
        # 不启动定时器，由 physics_process_state 检测速度降为 0 后结束
    else:
        # 其他效果（如 GatherEffect）：普通硬直
        _start_hit_stagger()

func _start_hit_stagger() -> void:
    stop_movement()
    enter_control_state("hit")
    start_timer(hit_duration)
```

**物理处理**（击退减速）：
```gdscript
@export var knockback_friction := 8.0
var _has_knockback := false
var _is_stunned := false

func physics_process_state(delta: float) -> void:
    if not _has_knockback:
        stop_movement()
        return

    if owner_node is not CharacterBody2D:
        return
    var body := owner_node as CharacterBody2D

    # 击退减速
    if body.velocity.length() > 10.0:
        body.velocity = body.velocity.lerp(Vector2.ZERO, knockback_friction * delta)
        body.move_and_slide()
    else:
        body.velocity = Vector2.ZERO
        _has_knockback = false
        # 击退结束：如果不是眩晕状态，结束 hit
        if not _is_stunned:
            decide_next_state()
```

**退出清理**：
```gdscript
func exit() -> void:
    stop_timer()
    exit_control_state()

    # 清除眩晕标记
    if _is_stunned:
        if "stunned" in owner_node:
            owner_node.stunned = false
        if "can_move" in owner_node:
            owner_node.can_move = true
        _on_stun_exit()
    _is_stunned = false
    _has_knockback = false

## 眩晕退出钩子（Boss: 设置眩晕免疫计时器）
func _on_stun_exit() -> void:
    if owner_node is BossBase:
        var boss := owner_node as BossBase
        var config := _get_config()
        var immunity := config.stun_immunity_duration if config and config.is_boss else 1.5
        boss.stun_immunity = immunity
```

**再次受伤**：
```gdscript
func on_damaged(_damage: Damage, _attacker_position: Vector2) -> void:
    # 重新进入 hit（exit + enter 完整流程，应用新效果）
    state_machine.force_transition("hit")
```

### 4. StunEffect — 简化为纯属性修改

**文件**: `Core/Resources/StunEffect.gd`

移除 `_find_state_machine()` 和 `force_transition()` 调用：
```gdscript
func apply_effect(target: CharacterBody2D, _damage_source_position: Vector2) -> void:
    super.apply_effect(target, _damage_source_position)
    if "stunned" in target:
        target.stunned = true
    if show_debug_info:
        DebugConfig.info("眩晕: %s %.1fs" % [target.name, stun_duration], "", "effect")
```

### 5. ForceStunEffect — 简化为纯属性修改

**文件**: `Core/Resources/ForceStunEffect.gd`

移除 `_find_state_machine()` 和 `force_transition()` 调用：
```gdscript
func apply_effect(target: CharacterBody2D, damage_source_position: Vector2) -> void:
    super.apply_effect(target, damage_source_position)
    if stop_movement:
        target.velocity = Vector2.ZERO
    if "can_move" in target:
        target.can_move = false
    if "stunned" in target:
        target.stunned = true
    if show_debug_info:
        DebugConfig.info("强制眩晕: %s %.1fs" % [target.name, stun_duration], "", "effect")
```

### 6. KnockBackEffect / KnockUpEffect / GatherEffect — 保留不变

这些 Effect 只修改属性（velocity、position tween），不操作状态机，无需修改。

### 7. 删除 StunState、KnockbackState 及所有子类

职责已被 HitState 吸收。删除以下文件：

**框架层**:
- `Core/StateMachine/CommonStates/StunState.gd` — 删除
- `Core/StateMachine/CommonStates/KnockbackState.gd` — 删除

**Boss Stun 子类**:
- `Scenes/Characters/Bosses/Shared/BossStunState.gd` — 删除（stun_immunity 已迁移到 HitState._on_stun_exit）
- `Scenes/Characters/Bosses/BladeKeeper/States/BKStun.gd` — 删除（extends BossState，自定义 stun 逻辑）
- `Scenes/Characters/Bosses/DemonSlime/States/DSStun.gd` — 删除（Phase 3 免疫已在 BossBaseState.on_damaged 处理）
- `Scenes/Characters/Bosses/Cyclops/States/CyclopsStun.gd` — 删除（仅参数覆盖）

**Enemy Stun 子类**（全部为空壳，无自定义逻辑）:
- `Scenes/Characters/Enemies/ForestBee/States/BeeStun.gd` — 删除
- `Scenes/Characters/Enemies/ForestBoar/States/BoarStun.gd` — 删除
- `Scenes/Characters/Enemies/ForestSnail/States/SnailStun.gd` — 删除
- `Scenes/Characters/Enemies/Dinosaur/Scripts/States/EnemyStun.gd` — 删除

职责迁移对照：
- StunState 眩晕计时 → HitState 的 stun_duration 计时器
- StunState 击退物理 → HitState 的 `_has_knockback` 减速
- StunState `_on_stun_exit()` → HitState `_on_stun_exit()`
- BossStunState stun_immunity → HitState `_on_stun_exit()` 读取 BossBase 数据
- BKStun 自定义逻辑 → HitState 通用逻辑已覆盖
- KnockbackState 物理减速 → HitState `knockback_friction` 减速

### 8. EnemyStateMachine — 移除 Stun/Knockback 状态创建

**文件**: `Core/StateMachine/EnemyStateMachine.gd`

`_create_basic_states()` 中移除 Stun 和 Knockback 状态的创建，只保留 Hit：
```gdscript
# Hit（反应层）- 统一受击状态
var hit = _create_state("res://Core/StateMachine/CommonStates/HitState.gd", "Hit")
hit.hit_duration = hit_duration
# 移除: Knockback 和 Stun 状态创建
```

移除 `stun_duration` 导出参数（不再需要，由 Effect 携带）。

### 9. BossStateMachine._on_owner_damaged — 保持决策链 + 清理 debug

**文件**: `Scenes/Characters/Bosses/Shared/BossStateMachine.gd`

保持当前逻辑（阶段锁 → stun 免疫 → poise → evasion），移除临时 debug prints。poise/evasion 触发时跳过 `super._on_owner_damaged()`，不缓存伤害、不进入 Hit，效果不被应用。

```gdscript
func _on_owner_damaged(damage: Damage, attacker_position: Vector2 = Vector2.ZERO) -> void:
    if is_transitioning_phase:
        return
    var boss := owner_node as BossBase
    if boss:
        if boss.stun_immunity > 0:
            return
        if boss.poise_enabled and boss.take_poise_hit():
            force_transition("counter")
            return
        if boss.evasion_enabled:
            var chance: float = boss.evasion_chance_per_phase.get(boss.current_phase, 0.0)
            if chance > 0 and randf() < chance:
                var evasion_state: String = ["defend", "roll"].pick_random()
                force_transition(evasion_state)
                return
    super._on_owner_damaged(damage, attacker_position)
```

### 10. BossBaseState.on_damaged — 路由到 hit

**文件**: `Scenes/Characters/Bosses/Shared/BossBaseState.gd`

```gdscript
func on_damaged(_damage: Damage, _attacker_position: Vector2 = Vector2.ZERO) -> void:
    var boss := get_boss()
    if not boss:
        return
    if boss.current_phase == BossBase.Phase.PHASE_3:
        return
    transitioned.emit(self, "hit")
```

（当前已是此逻辑，只需将 `"stun"` 改为 `"hit"`）

### 11. BaseState.on_damaged — 统一路由到 hit

**文件**: `Core/StateMachine/BaseState.gd` (line 146-163)

当前根据 effect 类型分别路由到 stun/knockback/hit，改为统一路由到 hit：
```gdscript
func on_damaged(damage: Damage, _attacker_position: Vector2 = Vector2.ZERO) -> void:
    if not state_machine:
        return
    if state_machine.states.has("hit"):
        transitioned.emit(self, "hit")
```

同时清理该方法中的临时 `print()` 调用。

### 12. BaseStateMachine — 清理 debug prints + 更新 recover_from_stun

**文件**: `Core/StateMachine/BaseStateMachine.gd`

- 移除 `_on_state_transition()` 和 `_on_owner_damaged()` 中的临时 `print()` 调用
- `recover_from_stun()` 方法：不再依赖 StunState，改为直接清理标记 + force_transition 到恢复状态：
```gdscript
func recover_from_stun() -> void:
    if owner_node:
        if "stunned" in owner_node:
            owner_node.stunned = false
        if "can_move" in owner_node:
            owner_node.can_move = true
    var recovery_state = StateNames.WANDER if states.has(StateNames.WANDER) else StateNames.IDLE
    if states.has(recovery_state):
        force_transition(recovery_state)
```

### 13. SkillManager — 更新眩晕控制

**文件**: `Core/Components/SkillManager.gd` (line 382-409)

V 技能的 `_stun_enemy()` 当前直接 `force_transition("stun")` + 停止 stun timer。改为 `force_transition("hit")`，HitState 内部会根据 ForceStunEffect 设置眩晕：
```gdscript
func _stun_enemy(enemy: Node) -> void:
    # ... 设置属性 ...
    var state_machine = _find_state_machine(enemy)
    if state_machine:
        if state_machine.has_method("force_transition"):
            state_machine.force_transition("hit")
            var hit_state = state_machine.states.get("hit")
            if hit_state and hit_state.has_method("stop_timer"):
                hit_state.stop_timer()
```

`_unstun_enemy()` 保持调用 `recover_from_stun()`（已在上一项更新）。

### 14. CyclopsAttack.on_damaged — "stun" → "hit"

**文件**: `Scenes/Characters/Bosses/Cyclops/States/CyclopsAttack.gd` (line 191)

```gdscript
transitioned.emit(self, "hit")  # was "stun"
```

### 15. 更新 .tscn — 移除 Stun/Knockback 节点

以下场景文件中手动添加了 Stun/Knockback 节点，需要移除节点及对应的 ext_resource：

- `Scenes/Characters/Templates/EnemyBase.tscn` — 移除 Stun + Knockback 节点
- `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn` — 移除 Stun 节点
- `Scenes/Characters/Bosses/DemonSlime/DemonSlime.tscn` — 移除 Stun 节点
- `Scenes/Characters/Bosses/Cyclops/Cyclops.tscn` — 移除 Stun 节点
- `Scenes/Characters/Enemies/Dinosaur/Dinosaur.tscn` — 移除 Stun + Knockback 节点
- `Scenes/Characters/Enemies/ForestBee/ForestBee.tscn` — 移除 Stun 节点
- `Scenes/Characters/Enemies/ForestBoar/ForestBoar.tscn` — 移除 Stun 节点

### 16. StateNames 常量 — 移除 STUN/KNOCKBACK

**文件**: `Core/StateMachine/StateNames.gd`

移除 `STUN` 和 `KNOCKBACK` 常量，保留 `HIT`。

## 影响范围

| 文件 | 变更类型 |
|---|---|
| **框架层** | |
| `Core/Components/HealthComponent.gd` | 移除 `apply_attack_effects()` 调用 |
| `Core/StateMachine/BaseStateMachine.gd` | 新增缓存变量 + 清理 debug + 更新 recover_from_stun |
| `Core/StateMachine/BaseState.gd` | on_damaged 统一路由到 hit + 清理 debug |
| `Core/StateMachine/CommonStates/HitState.gd` | 重写: 统一受击 + 效果应用 + 物理减速 + 眩晕 |
| `Core/StateMachine/CommonStates/StunState.gd` | **删除** |
| `Core/StateMachine/CommonStates/KnockbackState.gd` | **删除** |
| `Core/StateMachine/StateNames.gd` | 移除 STUN/KNOCKBACK 常量 |
| `Core/StateMachine/EnemyStateMachine.gd` | 移除 Stun/Knockback 创建 |
| `Core/Resources/StunEffect.gd` | 移除 `_find_state_machine` + `force_transition` |
| `Core/Resources/ForceStunEffect.gd` | 移除 `_find_state_machine` + `force_transition` |
| `Core/Components/SkillManager.gd` | V 技能 `"stun"` → `"hit"` + 更新 timer 引用 |
| **Boss 层** | |
| `Scenes/Characters/Bosses/Shared/BossStateMachine.gd` | 清理 debug prints + 注释 |
| `Scenes/Characters/Bosses/Shared/BossBaseState.gd` | `"stun"` → `"hit"` + 清理注释 |
| `Scenes/Characters/Bosses/Shared/BossStunState.gd` | **删除** |
| `Scenes/Characters/Bosses/BladeKeeper/States/BKStun.gd` | **删除** |
| `Scenes/Characters/Bosses/DemonSlime/States/DSStun.gd` | **删除** |
| `Scenes/Characters/Bosses/Cyclops/States/CyclopsStun.gd` | **删除** |
| `Scenes/Characters/Bosses/Cyclops/States/CyclopsAttack.gd` | `"stun"` → `"hit"` |
| **Enemy 层** | |
| `Scenes/Characters/Enemies/ForestBee/States/BeeStun.gd` | **删除** |
| `Scenes/Characters/Enemies/ForestBoar/States/BoarStun.gd` | **删除** |
| `Scenes/Characters/Enemies/ForestSnail/States/SnailStun.gd` | **删除** |
| `Scenes/Characters/Enemies/Dinosaur/Scripts/States/EnemyStun.gd` | **删除** |
| **场景文件 (.tscn)** | |
| `Scenes/Characters/Templates/EnemyBase.tscn` | 移除 Stun + Knockback 节点 |
| `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn` | 移除 Stun 节点 |
| `Scenes/Characters/Bosses/DemonSlime/DemonSlime.tscn` | 移除 Stun 节点 |
| `Scenes/Characters/Bosses/Cyclops/Cyclops.tscn` | 移除 Stun 节点 |
| `Scenes/Characters/Enemies/Dinosaur/Dinosaur.tscn` | 移除 Stun + Knockback 节点 |
| `Scenes/Characters/Enemies/ForestBee/ForestBee.tscn` | 移除 Stun 节点 |
| `Scenes/Characters/Enemies/ForestBoar/ForestBoar.tscn` | 移除 Stun 节点 |
| **测试文件** | |
| `test/unit/test_state_machine.gd` | 更新 stun/knockback 引用 |
| `test/integration/test_damage_pipeline.gd` | 更新 stun/knockback 引用 |

## 不受影响

- `KnockBackEffect.gd` — 只设置 velocity，不操作状态机
- `KnockUpEffect.gd` — 只启动 tween，不操作状态机
- `GatherEffect.gd` — 只做位移，不操作状态机
- `HurtBoxComponent.gd` — 只转发信号
- `HitBoxComponent.gd` — 只检测碰撞
- `Damage.gd` — 纯数据

## 测试要点

1. **普通敌人受击**：无效果攻击 → Hit 播放 hit 动画 + 短暂硬直 → 恢复
2. **普通敌人眩晕**：StunEffect 攻击 → Hit 播放 stunned 动画 + stun_duration → 恢复
3. **普通敌人击退**：KnockBackEffect → Hit 播放 hit 动画 + 物理减速 → 速度归零后恢复
4. **普通敌人击飞**：KnockUpEffect → Hit + tween 完成后恢复
5. **击退 + 眩晕组合**：KnockBack + Stun → 击退减速 + 眩晕计时，两者都结束后恢复
6. **Boss poise**：攻击 BK → poise 触发 → counter（不进入 Hit，不应用效果）
7. **Boss evasion**：攻击 BK → evasion 触发 → defend/roll（不进入 Hit）
8. **Boss 正常受击**：poise/evasion 未触发 → Hit → 效果正常应用
9. **Boss Phase 3 免疫**：Phase 3 时 on_damaged 直接 return
10. **Boss 眩晕免疫**：Hit 退出时设置 stun_immunity，后续攻击被 BossStateMachine 拦截
11. **连续受伤**：Hit 中再次受伤 → force_transition("hit") 重新 enter，旧效果清理 + 新效果应用
