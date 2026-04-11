# 状态机 Bug 修复设计 — BladeKeeper 攻击后卡死

**日期**: 2026-04-05
**范围**: BaseStateMachine 语义修复 + BKAttack 路由重构 + 模板状态清理

---

## 问题根因

BladeKeeper 攻击后卡死,排查发现三个层面的问题:

### 1. `can_be_interrupted` 语义缺陷

`can_transition_to()` 不区分"自发转换"和"外部中断":

```gdscript
if new_state.priority == priority:
    return can_be_interrupted  # ← 连自己 emit 的转换也拦截
```

导致 `can_be_interrupted = false` 的状态(如 BKRoll)在自行结束后也无法转换到同优先级状态。

### 2. `enter()` 中发起状态转换

BKAttack.enter() 根据 `pick_attack()` 的 mode 直接 emit 转换:

```gdscript
elif mode == "defend":
    transitioned.emit(self, "defend")  # enter() 中转换
    return
```

`enter()` 应只做初始化。路由决策属于 Chase 层的职责。

### 3. 模板占位状态死锁

BossBase.tscn 预置 7 个状态节点,脚本都是 BossBaseState.gd(无 enter/process/exit 实现)。BladeKeeper 和 DemonSlime 未覆盖 Patrol/Circle/Retreat,进入后永久死锁。

---

## 设计方案

### 改动 1: `can_transition_to` 语义修复

**文件**: `Core/StateMachine/BaseStateMachine.gd`

**规则**:
- 自发转换(`from_state == current_state`通过 `transitioned` 信号): **始终允许**,跳过 `can_transition_to` 检查
- 外部中断(`on_damaged` 等触发的转换): 走正常优先级检查
- `force_transition`: 已有,不变

**`can_be_interrupted` 的含义变为**: "同优先级的外部事件不能打断我,但我自己可以决定何时结束"

**实现**: `_on_state_transition()` 中识别自发转换并跳过优先级检查。由于所有 `transitioned.emit(self, ...)` 中 `self` 就是 `current_state`,`from_state == current_state` 天然成立,直接作为"自发"的判据。

外部中断的入口是 `on_damaged()`,它也通过 `transitioned.emit(self, "stun")` 发出。但 `on_damaged` 触发的目标状态(stun/hit/knockback)优先级为 REACTION(1) 或 CONTROL(2),高于 BEHAVIOR(0),天然通过 `new_state.priority > priority` 检查。因此无需额外区分外部/自发来源。

**回滚**: 撤销 `_execute_transition` 中 `current_state` 赋值顺序的临时修改,恢复原始顺序(`enter()` 之后赋值)。

### 改动 2: BKAttack mode 路由上移到 BKChase

**文件**: `Scenes/Characters/Bosses/BladeKeeper/States/BKChase.gd`, `BKAttack.gd`

**参考模式**: DSChase.physics_process_state() — 在 Chase 中调用 `pick_attack()` 根据 mode 路由到不同状态。

**BKChase._on_reached_attack_range()** 改为:

```gdscript
func _on_reached_attack_range() -> String:
    var boss := owner_node as BossBase
    if boss and boss.attack_cooldown > 0:
        return ""

    var mgr: BossAttackManager = null
    if boss is BossBase:
        for child in boss.get_children():
            if child is BossAttackManager:
                mgr = child
                break
    if not mgr:
        return "attack"

    var entry: Dictionary = mgr.pick_attack()
    var mode: String = entry.get("mode", "attack")
    boss.attack_cooldown = mgr.get_cooldown()

    match mode:
        "defend":
            return "defend"
        "projectile":
            return "projectile"
        "trap":
            return "trap"
        _:
            if mode.begins_with("roll"):
                return "roll"
            return "attack"
```

**BKAttack.enter()** 简化: 移除 defend/roll/combo 转发分支,只处理 combo 和 special:

```gdscript
func enter() -> void:
    var boss := get_boss()
    if not boss:
        return

    _anim_tree_ref = get_anim_tree()
    var mgr := get_attack_manager()
    var entry: Dictionary = mgr.pick_attack() if mgr else {}
    var mode: String = entry.get("mode", "attack")

    if mode == "special":
        _is_special = true
        _current_combo_step = 0
        enter_control_state("sp_atk")
    else:
        _is_special = false
        _current_combo_step = 0
        enter_control_state(COMBO_ANIMS[0])

    if _anim_tree_ref:
        _anim_tree_ref.animation_finished.connect(_on_animation_finished)
```

注意: BKAttack.enter() 不再调用 `pick_attack()`(已在 BKChase 中调用并设置了 cooldown)。如需传递 mode 到 Attack,可通过 boss 属性或直接让 Attack 只做 combo/special。

### 改动 3: 移除不需要的模板状态节点

**BladeKeeper.tscn**: 移除 Patrol, Circle, Retreat 节点(Godot 继承场景中标记删除)

**DemonSlime.tscn**: 移除 Patrol, Circle, Retreat 节点

`evaluate_combat_transition()` 中 `_resolve_state("retreat", "chase")` 找不到 retreat → 自动 fallback 到 chase。

### 改动 4: 清理 BossBaseState 占位逻辑

**文件**: `Scenes/Characters/Bosses/Shared/BossBaseState.gd`

移除之前添加的 `enter()`、`process_state()` 占位默认行为。模板状态被移除后不再需要这些防御代码。

---

## 影响范围

| Boss | 改动 1 | 改动 2 | 改动 3 | 改动 4 |
|------|--------|--------|--------|--------|
| BladeKeeper | ✓ 受益 | ✓ 直接改动 | ✓ 移除 3 节点 | ✓ |
| DemonSlime | ✓ 受益 | — 已正确(DSChase) | ✓ 移除 3 节点 | ✓ |
| Cyclops | ✓ 受益 | — 已正确 | — 无需(全覆盖) | ✓ |
| Enemies | ✓ 受益 | — 不涉及 | — 不涉及 | — |
| Player | ✓ 受益 | — 不涉及 | — 不涉及 | — |

## 不改动的部分

- BossBase.tscn 模板本身保持 7 个状态节点不变(Cyclops 需要全部)
- `evaluate_combat_transition()` 逻辑不变(`_resolve_state` fallback 机制已足够)
- Player 状态机和 Enemy 状态机结构不变
- `force_transition()` 行为不变

## 规范(新 Boss/Enemy 适用)

- 模板中的占位状态: 需要就覆盖实现,不需要就在继承场景中删除节点
- `enter()` 只做初始化: 路由决策放在 Chase/process_state/回调中
- `can_be_interrupted = false`: 仅表示"外部同优先级不可打断",自发转换始终通过
