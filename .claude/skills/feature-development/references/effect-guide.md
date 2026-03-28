# 攻击效果开发指南 (effect-guide.md)

## 1. 前置条件（需要了解哪些基类）

| 类 | 路径 | 说明 |
|---|---|---|
| `AttackEffect` | `Core/Resources/AttackEffect.gd` | 基类 Resource，提供 `apply_effect()` 和 `get_description()` |
| `Damage` | `Core/Resources/Damage.gd` | 携带 `effects: Array[AttackEffect]`，提供 `has_effect(type)` |
| `HurtBoxComponent` | `Core/Components/HurtBoxComponent.gd` | 调用 `take_damage(damage, pos)` 触发伤害链 |
| `HealthComponent` | `Core/Components/HealthComponent.gd` | 接收伤害，调用 `apply_attack_effects()`，再 emit `damaged` 信号 |
| `BaseState` | `Core/StateMachine/BaseState.gd` | `on_damaged()` 中检查效果类型，决定切换到哪个状态 |

### 已有效果（直接复用，无需重写）

| 类名 | 路径 | 效果 |
|---|---|---|
| `KnockBackEffect` | `Core/Resources/KnockBackEffect.gd` | 水平击退，`knockback_force` 控制力度 |
| `KnockUpEffect` | `Core/Resources/KnockUpEffect.gd` | 垂直击飞，触发 "knockback" 状态 |
| `StunEffect` | `Core/Resources/StunEffect.gd` | 眩晕，触发 "stun" 状态 |
| `ForceStunEffect` | `Core/Resources/ForceStunEffect.gd` | 强制眩晕，禁止移动 |
| `GatherEffect` | `Core/Resources/GatherEffect.gd` | 聚集周围敌人 |

---

## 2. 场景结构模板（节点树）

攻击效果是纯 `Resource`，**不需要场景节点**。`.tres` 文件直接配置到 `Damage.effects` 数组中。

如果效果需要视觉反馈（粒子/闪光），使用 `VfxHelper`（`Core/Effects/VfxHelper.gd`）在 `apply_effect()` 中生成。

---

## 3. 脚本模板（关键代码骨架）

### 新效果脚本

```gdscript
extends AttackEffect
class_name NewEffect

## 效果参数（在 Inspector 或 .tres 中配置）
@export var param: float = 1.0
@export var secondary_param: float = 0.5

func apply_effect(target: CharacterBody2D, source_position: Vector2) -> void:
    if not is_instance_valid(target):
        return

    DebugConfig.debug("[NewEffect] applied to %s" % target.name, "", "combat")

    ## 示例：对目标施加速度变化
    ## 注意：HealthComponent 在 apply_effects 之后才 emit damaged 信号
    ## 因此此处设置的 velocity 不会被状态机覆盖
    var direction := (target.global_position - source_position).normalized()
    target.velocity += direction * param

    ## 示例：触发目标的视觉状态（可选）
    ## var sm = target.get_node_or_null("EnemyStateMachine")
    ## if sm and sm.has_method("force_stun"):
    ##     sm.force_stun(secondary_param)

func get_description() -> String:
    return "效果名称：力度 %.1f，持续 %.1f 秒" % [param, duration]
```

### 需要触发特定状态机状态的效果

若效果需要切换到 `BaseState` 框架中的新状态（如自定义冻结状态），在 `BaseState.on_damaged()` 中检测：

```gdscript
## 在自定义 State 子类或 BaseState 扩展中
func on_damaged(damage: Damage, attacker_pos: Vector2) -> void:
    if damage.has_effect("NewEffect"):
        transition_to("frozen")   ## 切换到你新建的 FrozenState
        return
    ## 继续默认 damaged 处理
    super.on_damaged(damage, attacker_pos)
```

### 代码内构建 Damage（不用 .tres）

```gdscript
func _make_combo_damage() -> Damage:
    var dmg := Damage.new()
    dmg.amount = 25.0
    dmg.min_amount = 20.0
    dmg.max_amount = 30.0

    var kb := KnockBackEffect.new()
    kb.knockback_force = 200.0
    dmg.effects.append(kb)

    var stun := StunEffect.new()
    stun.duration = 1.5
    dmg.effects.append(stun)

    return dmg
```

---

## 4. 信号接入清单

攻击效果通过伤害链被动触发，不需要主动连接信号。完整流程：

```
HitBoxComponent.area_entered
  → HurtBoxComponent.take_damage(damage, pos)
      → HurtBoxComponent.damaged.emit(damage, pos)
          → HealthComponent.take_damage(damage, pos)
              → HealthComponent.apply_attack_effects()
                  → effect.apply_effect(owner_body, attacker_pos)  ← 效果在此执行
              → HealthComponent.damaged.emit(damage, pos)
                  → StateMachine._on_owner_damaged()
                      → current_state.on_damaged(damage, pos)     ← 状态在此响应
```

关键顺序：**效果先执行，状态后响应**。因此效果设置的 `velocity` 不会被状态切换覆盖。

---

## 5. Resource 配置

### .tres 文件（推荐用于可复用配置）

```
res://Data/Effects/StrongKnockback.tres
Class: KnockBackEffect  (继承 AttackEffect)
  effect_name: "Strong Knockback"
  duration: 0.3
  knockback_force: 350.0
  show_debug_info: false
```

### 挂载到 Damage Resource

```
res://Data/Enemies/EnemyNameDamage.tres
Class: Damage
  amount: 15.0
  min_amount: 12.0
  max_amount: 18.0
  effects:
    [0]: res://Data/Effects/StrongKnockback.tres
    [1]: res://Data/Effects/LightStun.tres
```

### 挂载到 BaseTrap

```
res://Scenes/Levels/Components/Traps/SpikeTrap/SpikeTrap.tscn
  SpikeTrap.effects:
    [0]: KnockBackEffect (inline, knockback_force: 100.0)
```

---

## 6. 验证要点

- [ ] `apply_effect()` 执行：在 `DebugConfig.debug` 日志中看到 `[NewEffect] applied to ...`（需开启 combat 频道）
- [ ] `Damage.has_effect("NewEffect")` 返回 `true`（用于状态机条件判断）
- [ ] 效果数值正确：实际 velocity/状态变化与 `param` 一致
- [ ] 与其他效果组合不冲突：同一 `Damage` 挂多个效果时都正常执行
- [ ] `is_instance_valid(target)` 保护：目标已死亡 `queue_free()` 时不报错
- [ ] 如触发状态切换：状态机日志中看到正确的 `transition_to("xxx")`
- [ ] .tres 文件加载正常：无 `load() returned null` 错误
