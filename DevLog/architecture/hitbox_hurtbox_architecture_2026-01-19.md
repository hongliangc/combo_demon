# Hahashin HitBoxComponent/HurtBoxComponent 架构设计文档

**日期**: 2026-01-19
**组件**: Player (Hahashin) 战斗系统
**架构模式**: 信号驱动的组件解耦设计

---

## 1. 架构概览

Hahashin 的战斗系统采用基于 Area2D 的碰撞检测机制，通过 HitBoxComponent（攻击区域）和 HurtBoxComponent（受击区域）实现伤害判定。整个系统遵循信号驱动的解耦设计，各组件通过信号进行通信。

### 核心组件

| 组件 | 类型 | 碰撞层/掩码 | 职责 |
|------|------|-------------|------|
| **HurtBoxComponent** | Area2D | Layer: 2, Mask: 0 | 接收伤害，发出 damaged 信号 |
| **HitBoxComponent** | Area2D | Layer: 4, Mask: 8 | 检测敌人，传递伤害数据 |
| **HealthComponent** | Node | N/A | 处理生命值、死亡逻辑 |
| **CombatComponent** | Node | N/A | 管理攻击技能、伤害切换 |

---

## 2. UML 类图

```
┌─────────────────────────────────────────────────────────────┐
│                          Hahashin                            │
│                    (CharacterBody2D)                         │
├─────────────────────────────────────────────────────────────┤
│ - alive: bool                                               │
│ - health_component: HealthComponent                          │
│ - combat_component: CombatComponent                          │
│ - movement_component: MovementComponent                      │
│ - animation_component: AnimationComponent                    │
│ - skill_manager: SkillManager                                │
├─────────────────────────────────────────────────────────────┤
│ + _ready()                                                  │
│ + _connect_component_signals()                              │
│ + switch_to_physical()                                       │
│ + switch_to_knockup()                                        │
│ + _on_died()                                                │
└────────────────┬────────────────────────────────────────────┘
                 │ owns
                 │
    ┌────────────┼────────────┐
    │            │            │
    ▼            ▼            ▼
┌─────────┐  ┌─────────┐  ┌──────────────┐
│ HurtBoxComponent │  │ HitBoxComponent  │  │HealthComponent│
│(Area2D) │  │(Area2D) │  │   (Node)      │
└─────────┘  └─────────┘  └───────────────┘
    │            │              │
    │ emits      │              │ receives
    │ damaged    │              │ signal
    └────────────┼──────────────┘
                 │
                 ▼
         [Signal Flow]


### 详细类图

```
┌────────────────────────────────────────────────────────────────┐
│                        Area2D (Godot)                          │
└────────────────────────────────────────────────────────────────┘
                            △
                            │ extends
              ┌─────────────┴─────────────┐
              │                           │
┌─────────────┴──────────────┐  ┌────────┴──────────────────────┐
│         HurtBoxComponent             │  │      HitBoxComponent (Base)            │
│    (Util/Components)        │  │   (Util/Components)           │
├─────────────────────────────┤  ├───────────────────────────────┤
│ Signals:                    │  │ @export damage: Damage        │
│  - damaged(Damage, Vector2) │  │ @export min_damage: float     │
├─────────────────────────────┤  │ @export max_damage: float     │
│ + take_damage(Damage, Vec2) │  │ @export destroy_on_hit: bool  │
│   └─> damaged.emit()        │  │ @export ignore_groups: Array  │
└─────────────────────────────┘  ├───────────────────────────────┤
                                 │ + update_attack()             │
                                 │ + _on_hitbox_area_entered_()  │
                                 └───────────────────────────────┘
                                             △
                                             │ extends
                                 ┌───────────┴───────────────────┐
                                 │  PlayerHitbox                 │
                                 │  (Scenes/charaters/hitbox.gd) │
                                 ├───────────────────────────────┤
                                 │ - player: Hahashin            │
                                 ├───────────────────────────────┤
                                 │ + update_attack()             │
                                 │   └─> 从CombatComponent获取   │
                                 │ + _on_hitbox_area_entered_()  │
                                 │   └─> player.debug_print()    │
                                 └───────────────────────────────┘


┌────────────────────────────────────────────────────────────────┐
│                     HealthComponent                            │
│                        (Node)                                  │
├────────────────────────────────────────────────────────────────┤
│ Signals:                                                       │
│  - health_changed(current: float, maximum: float)              │
│  - damaged(damage: Damage, attacker_position: Vector2)         │
│  - died()                                                      │
├────────────────────────────────────────────────────────────────┤
│ @export max_health: float                                      │
│ @export health: float                                          │
│ @export auto_create_health_bar: bool                           │
│ - health_bar: Node                                             │
│ - is_alive: bool                                               │
├────────────────────────────────────────────────────────────────┤
│ + _ready()                                                     │
│ + setup_health_bar()                                           │
│ + take_damage(Damage, Vector2)                                 │
│   ├─> 扣除生命值                                               │
│   ├─> update_health_bar()                                      │
│   ├─> health_changed.emit()                                    │
│   ├─> damaged.emit()                                           │
│   ├─> display_damage_number()                                  │
│   ├─> apply_attack_effects()                                   │
│   └─> die()                                                    │
│ + heal(amount: float)                                          │
│ + die()                                                        │
│ + reset_health()                                               │
└────────────────────────────────────────────────────────────────┘


┌────────────────────────────────────────────────────────────────┐
│                        Damage                                  │
│                      (Resource)                                │
├────────────────────────────────────────────────────────────────┤
│ @export max_amount: float                                      │
│ @export min_amount: float                                      │
│ @export amount: float                                          │
│ @export effects: Array[AttackEffect]                           │
├────────────────────────────────────────────────────────────────┤
│ + randomize_damage()                                           │
│ + apply_effects(enemy, damage_source_position)                 │
│ + has_effect(effect_type) -> bool                              │
│ + get_effects_description() -> String                          │
│ + debug_print()                                                │
└────────────────────────────────────────────────────────────────┘
```

---

## 3. 序列图 - 玩家受伤流程

```
敌人Hitbox     玩家Hurtbox     HealthComponent     Player      UI/Effects
    │               │                 │              │              │
    ├──碰撞检测────>│                 │              │              │
    │               │                 │              │              │
    │        take_damage(damage, pos) │              │              │
    │               ├────────────────>│              │              │
    │               │                 │              │              │
    │               │  damaged.emit() │              │              │
    │               │────────────────>│              │              │
    │               │                 │              │              │
    │               │         扣除生命值              │              │
    │               │                 ├──────┐       │              │
    │               │                 │      │       │              │
    │               │                 │<─────┘       │              │
    │               │                 │              │              │
    │               │                 ├─更新血条────────────────────>│
    │               │                 │              │              │
    │               │   health_changed.emit()        │              │
    │               │                 ├──────────────>│              │
    │               │                 │              │              │
    │               │                 ├─显示伤害数字──────────────────>│
    │               │                 │              │              │
    │               │                 ├─应用攻击特效──────────────────>│
    │               │                 │    (击退/击飞)│              │
    │               │                 │              │              │
    │               │      检查死亡    │              │              │
    │               │                 ├──────┐       │              │
    │               │                 │      │       │              │
    │               │                 │<─────┘       │              │
    │               │                 │              │              │
    │               │         died.emit()            │              │
    │               │                 ├──────────────>│              │
    │               │                 │              │              │
    │               │                 │        _on_died()           │
    │               │                 │              ├──────┐       │
    │               │                 │              │设置死亡状态   │
    │               │                 │              │禁用碰撞      │
    │               │                 │              │<─────┘       │
    │               │                 │              │              │
    │               │                 │              ├─显示GameOver─>│
    │               │                 │              │              │
```

---

## 4. 序列图 - 玩家攻击流程

```
Player     AnimationPlayer    PlayerHitbox    敌人Hurtbox    敌人HealthComponent
  │               │                │               │                 │
  ├─播放攻击动画──>│                │               │                 │
  │               │                │               │                 │
  │        启用Hitbox碰撞          │               │                 │
  │               ├───────────────>│               │                 │
  │               │  disabled=false│               │                 │
  │               │                │               │                 │
  │               │                ├──碰撞检测────>│                 │
  │               │                │               │                 │
  │               │    area_entered.connect()      │                 │
  │               │                │<──────────────┤                 │
  │               │                │               │                 │
  │               │  _on_hitbox_area_entered_(area)│                 │
  │               │                ├───────┐       │                 │
  │               │                │       │       │                 │
  │               │        update_attack() │       │                 │
  │               │                │<──────┘       │                 │
  │               │                │               │                 │
  │               │   从CombatComponent获取伤害     │                 │
  │<──────────────┼────────────────┤               │                 │
  │  combat_component.current_damage               │                 │
  │──────────────>├────────────────>│               │                 │
  │               │                │               │                 │
  │<──player.debug_print()─────────┤               │                 │
  │               │                │               │                 │
  │               │  take_damage(damage, player_pos)                 │
  │               │                ├──────────────>│                 │
  │               │                │               │                 │
  │               │                │        damaged.emit()           │
  │               │                │               ├────────────────>│
  │               │                │               │                 │
  │               │                │               │  （处理伤害流程）│
  │               │                │               │                 │
  │        禁用Hitbox碰撞          │               │                 │
  │               ├───────────────>│               │                 │
  │               │  disabled=true │               │                 │
```

---

## 5. 信号连接图

```
┌───────────────────────────────────────────────────────────────┐
│                     Hahashin._ready()                         │
│                 [hahashin.gd:22-29]                           │
└───────────────────────────────────────────────────────────────┘
                            │
                            │ 建立信号连接
                            ▼
    ┌───────────────────────────────────────────────────┐
    │                                                   │
    │  【连接1】HurtBoxComponent → HealthComponent                │
    │  ───────────────────────────────────────────────  │
    │  var hurtbox = get_node_or_null("HurtBoxComponent")        │
    │  hurtbox.damaged.connect(                         │
    │      health_component.take_damage                 │
    │  )                                                │
    │                                                   │
    │  连接位置: hahashin.gd:27-29                       │
    │  信号: damaged(Damage, Vector2)                   │
    │  处理: HealthComponent.take_damage()              │
    │                                                   │
    └───────────────────────────────────────────────────┘

    ┌───────────────────────────────────────────────────┐
    │                                                   │
    │  【连接2】HealthComponent → Player                 │
    │  ───────────────────────────────────────────────  │
    │  health_component.died.connect(                   │
    │      _on_died                                     │
    │  )                                                │
    │                                                   │
    │  连接位置: hahashin.gd:35                          │
    │  信号: died()                                     │
    │  处理: Player._on_died()                          │
    │                                                   │
    └───────────────────────────────────────────────────┘

    ┌───────────────────────────────────────────────────┐
    │                                                   │
    │  【连接3】MovementComponent → Player               │
    │  ───────────────────────────────────────────────  │
    │  movement_component.movement_ability_changed      │
    │      .connect(_on_movement_ability_changed)       │
    │                                                   │
    │  连接位置: hahashin.gd:39                          │
    │  信号: movement_ability_changed(bool)             │
    │  处理: Player._on_movement_ability_changed()      │
    │  用途: 调试日志                                    │
    │                                                   │
    └───────────────────────────────────────────────────┘

    ┌───────────────────────────────────────────────────┐
    │                                                   │
    │  【连接4】HitBoxComponent → area_entered (内部)             │
    │  ───────────────────────────────────────────────  │
    │  area_entered.connect(                            │
    │      _on_hitbox_area_entered_                     │
    │  )                                                │
    │                                                   │
    │  连接位置: Scenes/charaters/hitbox.gd:8            │
    │  信号: area_entered(Area2D)                       │
    │  处理: PlayerHitbox._on_hitbox_area_entered_()    │
    │                                                   │
    └───────────────────────────────────────────────────┘
```

---

## 6. 动画驱动的 HitBoxComponent 控制

Hahashin 的攻击判定完全由 AnimationPlayer 控制，通过动画轨道实时调整 HitBoxComponent 的状态。

### 动画轨道示例 - atk_1 攻击

**文件位置**: hahashin.tscn (行 582-670)

```gdscript
# 动画长度: 0.533334 秒
# 帧率: 10 FPS (每帧 0.0667 秒)

┌──────────────────────────────────────────────────────────┐
│ Track 1: AnimatedSprite2D:animation = "atk_1"            │
├──────────────────────────────────────────────────────────┤
│ Track 2: HitBoxComponent/CollisionShape2D:disabled                │
│                                                          │
│  时间      │ 状态      │ 说明                           │
│  ─────────┼──────────┼────────────────────────────────│
│  0.0s     │ false    │ 启用攻击判定（第一段）         │
│  0.0667s  │ true     │ 关闭判定                       │
│  0.1333s  │ false    │ 启用攻击判定（第二段）         │
│  0.2s     │ true     │ 关闭判定                       │
├──────────────────────────────────────────────────────────┤
│ Track 3: HitBoxComponent/CollisionShape2D:position                │
│                                                          │
│  0.0s     │ (20.5, -9.5)  │ 第一段攻击位置            │
│  0.1333s  │ (0, -2.5)     │ 第二段攻击位置            │
├──────────────────────────────────────────────────────────┤
│ Track 4: HitBoxComponent/CollisionShape2D:shape:size              │
│                                                          │
│  0.0s     │ (42, 19)      │ 第一段攻击范围            │
│  0.1333s  │ (60, 27)      │ 第二段攻击范围（更大）    │
├──────────────────────────────────────────────────────────┤
│ Track 5: AudioStreamPlayer (音效)                        │
│  0.0s     │ 播放剑斩音效                                │
│  0.1333s  │ 播放剑斩音效                                │
└──────────────────────────────────────────────────────────┘
```

### atk_3 攻击（连续多段）

**文件位置**: hahashin.tscn (行 699-788)

```gdscript
# 动画长度: 2.6 秒
# 包含多段连续攻击 + 伤害类型切换

┌──────────────────────────────────────────────────────────┐
│ Track: HitBoxComponent/CollisionShape2D:disabled                  │
│                                                          │
│  时间      │ 状态      │ 说明                           │
│  ─────────┼──────────┼────────────────────────────────│
│  0.0s     │ false    │ 第一段攻击                      │
│  0.1s     │ true     │                                │
│  0.2s     │ false    │ 第二段攻击                      │
│  0.3s     │ true     │                                │
│  0.7s     │ false    │ 第三段攻击                      │
│  1.1s     │ true     │                                │
│  1.5s     │ false    │ 第四段攻击（切换为击飞）        │
│  2.0s     │ true     │                                │
├──────────────────────────────────────────────────────────┤
│ Track: Method Calls (方法调用)                            │
│                                                          │
│  1.4985s  │ switch_to_knockup()    │ 切换到击飞伤害     │
│  1.998s   │ switch_to_physical()   │ 恢复物理伤害       │
└──────────────────────────────────────────────────────────┘
```

### atk_sp 特殊攻击

**文件位置**: hahashin.tscn (行 790-871)

```gdscript
# 动画长度: 3.0 秒
# 大范围持续攻击 + 特殊技能触发

┌──────────────────────────────────────────────────────────┐
│ Track: Method Calls                                      │
│                                                          │
│  0.0s     │ switch_to_special_attack() │ 切换特殊伤害  │
│  0.4s     │ perform_special_attack()   │ 触发特殊技能  │
│  2.9s     │ switch_to_physical()       │ 恢复普通伤害  │
├──────────────────────────────────────────────────────────┤
│ Track: HitBoxComponent/CollisionShape2D:disabled                  │
│                                                          │
│  0.4329s  │ false    │ 启用攻击判定（长时间）         │
│  2.9304s  │ true     │ 关闭判定                       │
├──────────────────────────────────────────────────────────┤
│ 攻击判定位置动态变化 (11个关键帧)                         │
│                                                          │
│  0.4329s  │ pos=(29.5, 1),    size=(53, 36)            │
│  0.5328s  │ pos=(60, 2),      size=(60, 42)            │
│  0.8325s  │ pos=(-1.5,-68.5), size=(69, 57) ← 向上攻击 │
│  1.0323s  │ pos=(-3.5,-54.5), size=(69, 47)            │
│  1.1322s  │ pos=(3, -6.5),    size=(80, 59)            │
│  1.4319s  │ pos=(84.5,-0.5),  size=(61, 47) ← 向右冲刺 │
│  1.6317s  │ pos=(59.5,-1.5),  size=(59, 47)            │
│  1.7316s  │ pos=(-19, -3.5),  size=(108, 51) ← 大范围  │
│  1.8315s  │ pos=(-63.5,0.5),  size=(79, 55) ← 向左     │
│  1.9314s  │ pos=(30.5,-7),    size=(127, 70) ← 最大范围│
│  2.9304s  │ pos=(2, 0),       size=(58, 48)            │
└──────────────────────────────────────────────────────────┘
```

---

## 7. 碰撞层配置

Godot 的碰撞检测基于 **Layer（层）** 和 **Mask（掩码）** 系统：

- **collision_layer**: 该物体所在的层（我是谁）
- **collision_mask**: 该物体可以检测的层（我能看到谁）

### 项目碰撞层定义

```
Layer 1: 地面/墙壁（环境物体）
Layer 2: 玩家受击区域 (HurtBoxComponent)
Layer 3: [未使用]
Layer 4: 玩家攻击区域 (HitBoxComponent)
Layer 5: [未使用]
Layer 6: [未使用]
Layer 7: [未使用]
Layer 8: 敌人受击区域 (Enemy HurtBoxComponent)
```

### 配置表

| 节点 | collision_layer | collision_mask | 说明 |
|------|----------------|----------------|------|
| **Hahashin (CharacterBody2D)** | 1 | 128 (第8层) | 玩家身体在第1层，碰撞地面 |
| **Hahashin/HurtBoxComponent** | 2 | 0 | 玩家受击区在第2层，被动接收 |
| **Hahashin/HitBoxComponent** | 4 | 8 (第4层) | 玩家攻击区在第4层，检测敌人 |
| **Enemy/HurtBoxComponent** | 8 | 0 | 敌人受击区在第8层，被动接收 |
| **Enemy/HitBoxComponent** | [敌人定义] | 2 (第2层) | 敌人攻击区检测玩家 |

### 碰撞检测流程

```
玩家 HitBoxComponent (Layer 4, Mask 8)
    │
    │ 检测 Mask 8 的物体
    ▼
敌人 HurtBoxComponent (Layer 8, Mask 0)
    │
    │ 被 Layer 4 的物体检测到
    ▼
触发 area_entered 信号
```

---

## 8. 伤害数据流

### 8.1 伤害来源

**CombatComponent** 管理多种伤害类型，通过 Resource 文件配置：

```gdscript
# hahashin.tscn:1161
damage_types = [
    res://Util/Data/SkillBook/Physical.tres,      # 物理伤害
    res://Util/Data/SkillBook/KnockUp.tres,       # 击飞伤害
    res://Util/Data/SkillBook/SpecialAttack.tres  # 特殊攻击
]
```

每个 Damage Resource 包含：

```gdscript
# Damage.gd
class_name Damage extends Resource

@export var max_amount: float = 50.0     # 最大伤害
@export var min_amount: float = 1.0      # 最小伤害
@export var amount: float = 10.0         # 实际伤害值
@export var effects: Array[AttackEffect] # 攻击特效数组

# 特效示例
effects = [
    KnockBackEffect.new(force=300),   # 击退特效
    KnockUpEffect.new(force=500),     # 击飞特效
    GatherEffect.new(force=200)       # 聚集特效
]
```

### 8.2 动态伤害切换

玩家的 HitBoxComponent 不存储固定伤害，而是从 CombatComponent 动态获取：

```gdscript
# Scenes/charaters/hitbox.gd:12-15
func update_attack():
    # 每次攻击时从 CombatComponent 获取当前技能的伤害
    if player and player.combat_component:
        damage = player.combat_component.current_damage
```

**切换时机**：

1. **玩家主动切换**（按键Q/E）：
   ```gdscript
   player.switch_to_physical()  # 切换到物理伤害
   player.switch_to_knockup()   # 切换到击飞伤害
   ```

2. **动画自动切换**：
   ```gdscript
   # atk_3 动画中的方法调用轨道
   1.4985s → switch_to_knockup()    # 第4段攻击切换为击飞
   1.998s  → switch_to_physical()   # 攻击结束恢复物理伤害
   ```

### 8.3 伤害应用流程

```
┌─────────────────────────────────────────────────────────────┐
│ 1. HitBoxComponent 碰撞检测                                          │
├─────────────────────────────────────────────────────────────┤
│   _on_hitbox_area_entered_(area)                            │
│       ↓                                                     │
│   update_attack()  ← 从 CombatComponent 获取 current_damage│
│       ↓                                                     │
│   area.take_damage(damage, player.global_position)          │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. HurtBoxComponent 接收伤害                                         │
├─────────────────────────────────────────────────────────────┤
│   HurtBoxComponent.take_damage(damage, attacker_position)            │
│       ↓                                                     │
│   damaged.emit(damage, attacker_position)                   │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. HealthComponent 处理伤害                                 │
├─────────────────────────────────────────────────────────────┤
│   HealthComponent.take_damage(damage_data, attacker_pos)    │
│       ↓                                                     │
│   ┌─ health -= damage_data.amount                          │
│   ├─ update_health_bar()                                    │
│   ├─ health_changed.emit()                                  │
│   ├─ damaged.emit()                                         │
│   ├─ display_damage_number(damage_amount)                   │
│   ├─ apply_attack_effects(damage_data, attacker_pos) ←关键 │
│   │       ↓                                                 │
│   │   for effect in damage_data.effects:                   │
│   │       effect.apply_effect(owner_body, attacker_pos)    │
│   │           ↓                                             │
│   │       ┌─ KnockBackEffect: velocity = direction * force │
│   │       ├─ KnockUpEffect: velocity.y = -force            │
│   │       └─ GatherEffect: velocity = -direction * force   │
│   │                                                         │
│   └─ if health <= 0: die()                                 │
└─────────────────────────────────────────────────────────────┘
```

---

## 9. 关键设计模式

### 9.1 信号驱动解耦

**优点**：
- HurtBoxComponent 不需要知道 HealthComponent 的存在
- 组件可以独立测试和替换
- 易于扩展（添加新的信号监听者）

**实现**：
```gdscript
# hahashin.gd:27-29
var hurtbox = get_node_or_null("HurtBoxComponent")
if hurtbox and hurtbox.has_signal("damaged"):
    hurtbox.damaged.connect(health_component.take_damage)
```

### 9.2 动画驱动控制

**优点**：
- 攻击判定时机精确（逐帧控制）
- 美术和程序解耦（调整不需要改代码）
- 支持复杂的多段攻击

**实现**：
- 动画轨道控制 HitBoxComponent 的 disabled 属性
- 动画轨道控制 HitBoxComponent 的 position 和 size
- 动画轨道调用方法切换伤害类型

### 9.3 组件化架构

**优点**：
- 职责清晰，单一责任原则
- 组件可复用（HealthComponent 可用于 Player/Boss/Enemy）
- 易于维护和扩展

**组件划分**：
```
Hahashin
├─ HealthComponent      # 生命值管理
├─ MovementComponent    # 移动控制
├─ CombatComponent      # 战斗/技能管理
├─ AnimationComponent   # 动画状态机
├─ SkillManager         # 特殊技能管理
├─ HurtBoxComponent              # 受击区域（被动）
└─ HitBoxComponent               # 攻击区域（主动）
```

### 9.4 策略模式 - 攻击特效

**优点**：
- 特效可组合（一次攻击可附加多个特效）
- 易于添加新特效类型
- 数据驱动（通过 Resource 配置）

**实现**：
```gdscript
# Damage.gd:27-30
func apply_effects(enemy: Enemy, damage_source_position: Vector2):
    for effect in effects:
        if effect != null:
            effect.apply_effect(enemy, damage_source_position)
```

---

## 10. 代码示例

### 10.1 玩家 HitBoxComponent 实现

**文件**: Scenes/charaters/hitbox.gd

```gdscript
extends HitBoxComponent

@onready var player : Hahashin = get_owner()

func _ready() -> void:
    # 跳过基类的 _ready，避免创建默认 damage
    # 玩家的 hitbox 直接使用 player.current_damage
    area_entered.connect(_on_hitbox_area_entered_)

## 玩家的伤害使用 combat_component.current_damage，不需要随机化
## 重写基类方法，使用玩家配置的伤害数据
func update_attack():
    # 玩家的伤害从 CombatComponent 获取，支持动态切换技能
    if player and player.combat_component:
        damage = player.combat_component.current_damage

func _on_hitbox_area_entered_(area: Area2D):
    # 更新攻击伤害（获取玩家当前技能的伤害）
    update_attack()
    if area is HurtBoxComponent:
        # 传递伤害数据和攻击者位置（用于计算击飞/击退方向）
        player.debug_print()  # 调试输出
        area.take_damage(damage, player.global_position)
```

### 10.2 HurtBoxComponent 实现

**文件**: Util/Components/hurtbox.gd

```gdscript
extends Area2D
class_name HurtBoxComponent

# 受到伤害时发出的信号
# @param damage: 伤害数据
# @param attacker_position: 攻击者位置（用于计算击飞/击退方向）
signal damaged(damage: Damage, attacker_position: Vector2)

# 接收伤害并发出信号
# @param damage: 伤害数据
# @param attacker_position: 攻击者位置（可选，默认为Vector2.ZERO）
func take_damage(damage: Damage, attacker_position: Vector2 = Vector2.ZERO):
    damaged.emit(damage, attacker_position)
```

**设计要点**：
- HurtBoxComponent 只负责接收伤害和发出信号
- 不处理具体的伤害逻辑（交给 HealthComponent）
- 传递攻击者位置，用于计算击退方向

### 10.3 HealthComponent 核心逻辑

**文件**: Util/Components/HealthComponent.gd

```gdscript
## 接收伤害
func take_damage(damage_data: Damage, attacker_position: Vector2 = Vector2.ZERO):
    if not is_alive:
        return

    # 1. 扣除生命值
    var damage_amount = damage_data.amount
    health -= damage_amount
    health = max(0, health)

    # 2. 更新血条
    update_health_bar()

    # 3. 发出信号
    health_changed.emit(health, max_health)
    damaged.emit(damage_data, attacker_position)

    # 4. 显示伤害数字
    display_damage_number(damage_amount)

    # 5. 应用攻击特效（击退、击飞等）
    apply_attack_effects(damage_data, attacker_position)

    # 6. 检查死亡
    if health <= 0:
        die()

## 应用攻击特效
func apply_attack_effects(damage_data: Damage, attacker_position: Vector2):
    for effect in damage_data.effects:
        if effect != null:
            # 检查是否有 apply_effect 方法（通用特效系统）
            if effect.has_method("apply_effect"):
                effect.apply_effect(owner_body, attacker_position)
```

### 10.4 信号连接

**文件**: Scenes/charaters/hahashin.gd

```gdscript
func _ready() -> void:
    # 连接组件信号
    _connect_component_signals()

    # 连接 HurtBoxComponent 的受伤信号到 HealthComponent
    var hurtbox = get_node_or_null("HurtBoxComponent")
    if hurtbox and hurtbox.has_signal("damaged"):
        hurtbox.damaged.connect(health_component.take_damage)

func _connect_component_signals() -> void:
    # 健康组件信号
    if health_component:
        health_component.died.connect(_on_died)

    # 移动组件信号（可选，用于调试）
    if movement_component:
        movement_component.movement_ability_changed.connect(
            _on_movement_ability_changed
        )

func _on_died() -> void:
    alive = false
    visible = false
    set_collision_layer_value(1, false)
    set_collision_mask_value(1, false)
    show_game_over_ui()
```

---

## 11. 性能优化要点

### 11.1 避免频繁的节点查找

**不好的做法**：
```gdscript
# 每帧都查找节点
func _process(delta):
    var hitbox = get_node("HitBoxComponent")
    hitbox.do_something()
```

**正确做法**：
```gdscript
# 使用 @onready 缓存节点引用
@onready var hitbox = $HitBoxComponent

func _process(delta):
    hitbox.do_something()
```

### 11.2 碰撞检测优化

1. **精确设置碰撞层/掩码**，避免不必要的检测
2. **使用合适的碰撞形状**：
   - 简单形状（Circle, Rectangle）性能最好
   - 避免使用复杂的 Polygon
3. **动态启用/禁用碰撞**：
   - 攻击结束后立即禁用 HitBoxComponent
   - 无敌状态时禁用 HurtBoxComponent

### 11.3 信号优化

1. **及时断开不再使用的信号**：
   ```gdscript
   # 节点销毁前断开信号
   func _exit_tree():
       if hurtbox:
           hurtbox.damaged.disconnect(health_component.take_damage)
   ```

2. **避免信号循环连接**：
   - 确保信号只沿一个方向传递
   - 使用延迟调用打破循环

---

## 12. 调试技巧

### 12.1 可视化碰撞形状

在编辑器中启用：
```
Debug → Visible Collision Shapes
```

在运行时启用：
```gdscript
# project.godot
[debug]
shapes/collision/shape_color=Color(0, 0.6, 0.7, 0.42)
shapes/collision/draw_2d_outlines=true
```

### 12.2 调试输出

使用项目的 DebugConfig 系统：

```gdscript
# 战斗调试
DebugConfig.debug("HitBoxComponent 碰撞检测", area.name, "combat")

# 伤害调试
damage.debug_print()  # 输出伤害详细信息

# 玩家状态调试
player.debug_print()  # 输出完整状态信息
```

### 12.3 动画调试

在 AnimationPlayer 中：
1. 降低播放速度（0.1x - 0.5x）观察判定框变化
2. 使用 "编辑时预览" 功能检查关键帧
3. 查看方法调用轨道的时机

---

## 13. 扩展点

### 13.1 添加新的伤害类型

1. 创建新的 Damage Resource：
   ```
   Util/Data/SkillBook/NewDamageType.tres
   ```

2. 在 CombatComponent 中添加：
   ```gdscript
   @export var damage_types: Array[Damage] = [
       Physical, KnockUp, SpecialAttack,
       NewDamageType  # 新增
   ]
   ```

3. 添加切换方法：
   ```gdscript
   func switch_to_new_damage_type():
       current_damage = damage_types[3]
   ```

### 13.2 添加新的攻击特效

1. 创建特效类：
   ```gdscript
   # Util/Classes/FreezeEffect.gd
   extends AttackEffect
   class_name FreezeEffect

   @export var freeze_duration: float = 2.0

   func apply_effect(target: Node, source_pos: Vector2):
       if target.has_method("freeze"):
           target.freeze(freeze_duration)
   ```

2. 在 Damage Resource 中配置：
   ```gdscript
   effects = [
       KnockBackEffect.new(),
       FreezeEffect.new(freeze_duration=3.0)
   ]
   ```

### 13.3 添加伤害倍率系统

在 Damage 类中添加：
```gdscript
@export var critical_chance: float = 0.1  # 暴击率
@export var critical_multiplier: float = 2.0  # 暴击倍率

func calculate_final_damage() -> float:
    var base_damage = amount
    if randf() < critical_chance:
        return base_damage * critical_multiplier
    return base_damage
```

---

## 14. 常见问题 (FAQ)

### Q1: 为什么 HitBoxComponent 要在动画中启用/禁用？

**A**: 为了精确控制攻击判定的时机。如果 HitBoxComponent 一直启用，会导致：
- 攻击前摇阶段就能造成伤害（不合理）
- 一次攻击造成多次伤害（连续碰撞）
- 无法实现多段攻击

### Q2: 为什么需要传递 attacker_position？

**A**: 攻击者位置用于：
- 计算击退方向（远离攻击者）
- 计算聚集方向（朝向攻击者）
- 判断攻击来自哪个方向（用于防御检测）

### Q3: 为什么 HurtBoxComponent 的 collision_mask 是 0？

**A**: HurtBoxComponent 是被动接收区域，不需要主动检测任何物体。碰撞由 HitBoxComponent 的 `collision_mask` 检测触发。

### Q4: 一次攻击如何避免多次伤害？

**A**: 通过动画控制：
```gdscript
# 启用 → 立即禁用 → 等待 → 再启用
0.0s:  disabled = false
0.01s: disabled = true  # 极短时间后关闭
```

或在代码中添加冷却：
```gdscript
var hit_enemies = []  # 记录已命中的敌人

func _on_hitbox_area_entered_(area):
    if area in hit_enemies:
        return  # 已经命中，跳过
    hit_enemies.append(area)
    area.take_damage(damage, player.global_position)
```

### Q5: 如何调试碰撞不触发的问题？

**A**: 检查清单：
1. ✅ HitBoxComponent 的 `collision_mask` 是否包含目标的 `layer`
2. ✅ HitBoxComponent 的 `CollisionShape2D.disabled` 是否为 `false`
3. ✅ HitBoxComponent 的 `CollisionShape2D.shape` 是否有效（size > 0）
4. ✅ 目标 HurtBoxComponent 的 `collision_layer` 是否正确
5. ✅ 使用 "Visible Collision Shapes" 可视化检查

---

## 15. 总结

### 核心设计原则

1. **信号驱动解耦**：组件通过信号通信，不直接依赖
2. **动画驱动控制**：攻击判定由动画精确控制
3. **组件化架构**：职责清晰，易于维护和扩展
4. **数据驱动配置**：伤害和特效通过 Resource 配置

### 关键文件清单

| 文件路径 | 职责 |
|---------|------|
| `Scenes/charaters/hahashin.gd` | 玩家主类，组件协调 |
| `Scenes/charaters/hahashin.tscn` | 场景配置，动画轨道 |
| `Scenes/charaters/hitbox.gd` | 玩家 HitBoxComponent 实现 |
| `Util/Components/hitbox.gd` | HitBoxComponent 基类 |
| `Util/Components/hurtbox.gd` | HurtBoxComponent 组件 |
| `Util/Components/HealthComponent.gd` | 生命值管理 |
| `Util/Components/CombatComponent.gd` | 战斗/技能管理 |
| `Util/Classes/Damage.gd` | 伤害数据类 |
| `Util/Classes/KnockBackEffect.gd` | 击退特效 |
| `Util/Classes/KnockUpEffect.gd` | 击飞特效 |
| `Util/Classes/GatherEffect.gd` | 聚集特效 |

### 架构优势

✅ **可扩展性**：添加新伤害类型、新特效无需修改核心代码
✅ **可维护性**：组件职责清晰，修改影响范围小
✅ **可复用性**：组件可用于 Player/Boss/Enemy
✅ **可测试性**：组件可独立测试
✅ **性能优化**：碰撞层精确配置，动态启用/禁用

---

**文档版本**: 1.0
**最后更新**: 2026-01-19
**作者**: Claude Code
**项目**: Combo Demon (Godot 4.x)

