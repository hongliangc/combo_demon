# 敌人开发指南 (enemy-guide.md)

## 1. 前置条件（需要了解哪些基类）

| 类 | 路径 | 说明 |
|---|---|---|
| `BaseCharacter` | `Core/Characters/BaseCharacter.gd` | 生命系统、damaged 信号、HurtBox 连接 |
| `EnemyBase` | `Core/Characters/EnemyBase.gd` | AI 参数、精灵管理、死亡动画、`_on_enemy_ready()` 钩子 |
| `EnemyStateMachine` | `Core/StateMachine/EnemyStateMachine.gd` | Preset: BASIC/RANGED/BOSS，自动创建 7 个 CommonStates |
| `BaseState` | `Core/StateMachine/BaseState.gd` | AnimationTree helper 方法（`set_locomotion`、`fire_attack` 等） |
| `AttackState` | `Core/StateMachine/CommonStates/AttackState.gd` | 继承此类实现自定义近战攻击 |
| `SpecialSkillState` | `Core/StateMachine/CommonStates/SpecialSkillState.gd` | 继承此类实现冷却触发的特殊技能 |

---

## 2. 场景结构模板（节点树）

```
EnemyName.tscn
└── EnemyName  [CharacterBody2D]
    │   script: res://Scenes/Characters/Enemies/EnemyName/EnemyName.gd
    │   Layer: 4 (Enemy)  Mask: 1 (World) + 8 (Walls)
    ├── Sprite2D  或  AnimatedSprite2D
    │       (EnemyBase._find_sprite() 自动识别，默认朝右)
    ├── CollisionShape2D
    │       (Layer 4, 与角色碰撞体一致)
    ├── AnimationPlayer
    │       动画: idle / run / attack / hit / stun / death
    ├── AnimationTree
    │       (见下方 BlendTree 配置)
    ├── HealthComponent
    │       max_health = 100, health = 100
    ├── HurtBoxComponent  [Area2D]
    │   │   Layer: 4 (Enemy)  Mask: 2 (Player) + 3 (Player Projectile)
    │   └── CollisionShape2D
    ├── HitBoxComponent  [Area2D]
    │   │   Layer: 5 (Enemy Projectile)  Mask: 2 (Player)
    │   └── CollisionShape2D
    ├── DamageNumbersAnchor  [Node2D]
    │       (HealthComponent 用于显示伤害数字的锚点)
    ├── HealthBar  [可选, ProgressBar 或自定义节点]
    └── EnemyStateMachine
            preset: BASIC  (或 RANGED)
            auto_create_states: true
```

### AnimationTree BlendTree 配置

```
AnimationNodeBlendTree (根)
├── locomotion  [AnimationNodeBlendSpace2D]
│       轴 X: direction(-1 左, +1 右), 轴 Y: speed_ratio(0 idle, 1 run)
│       节点: "idle"(0,0) / "run_right"(1,0.5) / "run_left"(-1,0.5)
├── loco_timescale  [AnimationNodeTimeScale] → 接 locomotion
├── control_sm  [AnimationNodeStateMachine]
│       内部状态: hit / stun / death (各自 OneShot 动画)
├── ctrl_timescale  [AnimationNodeTimeScale] → 接 control_sm
└── control_blend  [AnimationNodeBlend2]
        input 0 (blend_amount=0): loco_timescale  → 正常移动层
        input 1 (blend_amount=1): ctrl_timescale  → 受击/眩晕层
        → output
```

参数路径（BaseState helper 使用）：
- `parameters/locomotion/blend_position` — BlendSpace2D 坐标
- `parameters/control_blend/blend_amount` — 0.0=locomotion, 1.0=control
- `parameters/control_sm/playback` — AnimationNodeStateMachinePlayback

---

## 3. 脚本模板（关键代码骨架）

### 基础敌人（无特殊技能）

```gdscript
extends EnemyBase
class_name EnemyName

## 可选：绑定 EnemyData 资源实现数据驱动
@export var enemy_data_override: EnemyData = null

func _on_enemy_ready() -> void:
    ## 在此做敌人特定初始化
    ## EnemyBase 已完成：精灵查找、AnimationTree 激活、EnemyData 应用
    pass
```

### 自定义近战攻击（Group A — 继承 AttackState）

```gdscript
extends AttackState
class_name EnemyNameAttack

func on_custom_attack() -> void:
    ## 手动触发 HitBox 或 Damage 逻辑
    var hitbox: HitBoxComponent = owner_node.get_node_or_null("HitBoxComponent")
    if hitbox:
        hitbox.monitoring = true
        await owner_node.get_tree().create_timer(0.2).timeout
        hitbox.monitoring = false
```

在 EnemyStateMachine 中替换默认 Attack 状态：
```gdscript
# EnemyStateMachine.preset = CUSTOM, 手动 add_child 或在场景中添加子节点
```

### 特殊技能（Group B — 继承 SpecialSkillState）

```gdscript
extends SpecialSkillState
class_name EnemyNameSpecial

func _check_condition(distance: float) -> bool:
    return distance < 200.0  # 自定义触发范围

func execute_skill() -> void:
    ## await 动画/移动/伤害逻辑
    set_locomotion(Vector2.ZERO)
    fire_attack()
    await owner_node.get_tree().create_timer(0.6).timeout
    _apply_damage_to_player(_make_damage(15.0, 200.0))
    finish_skill()  # 必须调用，重置冷却并返回 chase
```

将此状态添加为 EnemyStateMachine 的子节点（名称 `SpecialSkill`），AttackState 会自动调用 `can_trigger()` 检测。

### EnemyData Resource（数据驱动配置）

```gdscript
## res://Data/Enemies/EnemyNameData.tres
## 在 Inspector 中赋值 EnemyBase.enemy_data
var enemy_data: EnemyData
## 字段: max_health, wander_speed, detection_radius, chase_speed, has_gravity ...
```

---

## 4. 信号接入清单

所有信号由基类**自动连接**，子类无需手动 `connect`。

| 信号链 | 自动连接位置 |
|---|---|
| `HurtBoxComponent.damaged` → `HealthComponent.take_damage()` | `BaseCharacter._ready()` |
| `HealthComponent.damaged` → `StateMachine._on_owner_damaged()` | `BaseStateMachine._ready()` |
| `HealthComponent.died` → `EnemyBase._handle_death()` | `BaseCharacter._ready()` |
| `HealthComponent.health_changed` → `HealthBar` (可选) | 子类手动连接或 UI 自动绑定 |

子类需要额外监听的场景：
```gdscript
func _on_enemy_ready() -> void:
    ## 如需监听血量变化（如切换行为）
    health_component.health_changed.connect(_on_health_changed)

func _on_health_changed(current: float, _max: float) -> void:
    pass
```

---

## 5. Resource 配置

### EnemyData（可选，数据驱动替代 @export）

```
res://Data/Enemies/EnemyNameData.tres
Class: EnemyData
Fields:
  max_health: 80.0
  min_wander_time: 2.0 / max_wander_time: 8.0
  wander_speed: 40.0
  detection_radius: 120.0
  chase_radius: 250.0
  follow_radius: 30.0
  chase_speed: 80.0
  has_gravity: false
```

赋值方式：在 Inspector 将 `.tres` 拖入 `EnemyBase.enemy_data` 插槽。

### Damage Resource（攻击伤害配置）

```
res://Data/Enemies/EnemyNameDamage.tres
Class: Damage
  amount: 10.0
  min_amount: 8.0
  max_amount: 12.0
  effects:
    - KnockBackEffect (knockback_force: 150.0)
```

---

## 6. 验证要点

- [ ] `idle` / `wander` 状态循环正常，精灵朝向随机游走方向翻转
- [ ] 进入 `detection_radius` 时切换到 `chase`，离开 `chase_radius` 时返回 idle/wander
- [ ] 进入 `follow_radius` 时切换到 `attack`，攻击动画通过 AnimationTree 触发
- [ ] 受击时：白闪 / 进入 `hit` 状态 / 眩晕效果正确触发
- [ ] 死亡时：状态机停止 → 播放 death 动画 → `queue_free()` 清除节点
- [ ] 物理层正确：Layer 4, HurtBox Layer4/Mask2+3, HitBox Layer5/Mask2
- [ ] `DamageNumbersAnchor` 节点存在，伤害数字正常显示
- [ ] 没有孤立的 `_on_*` 连接警告（信号全部由基类自动连接）
