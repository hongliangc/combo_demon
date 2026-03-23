# 角色模板系统架构

> **文档类型**: 核心架构 - 角色模板系统
> **更新日期**: 2026-03-15
> **Godot版本**: 4.x
> **架构模式**: 继承 + 组件化 + 信号驱动 + 数据驱动
> **模板数量**: 3 个（EnemyBase, PlayerBase, BossBase）

---

## 目录

1. [设计背景与目标](#1-设计背景与目标)
2. [架构总览](#2-架构总览)
3. [三层继承体系](#3-三层继承体系)
4. [模板场景设计](#4-模板场景设计)
5. [组件系统详解](#5-组件系统详解)
6. [Resource 数据系统](#6-resource-数据系统)
7. [信号链路与通信流](#7-信号链路与通信流)
8. [具体角色实现](#8-具体角色实现)
9. [创建新角色指南](#9-创建新角色指南)
10. [架构优缺点分析](#10-架构优缺点分析)
11. [待提升项与改进建议](#11-待提升项与改进建议)

---

## 1. 设计背景与目标

### 1.1 痛点

项目初期每个角色独立实现，导致：
- **大量重复代码** — HitBox/HurtBox/HealthComponent/状态机在每个角色场景中重复搭建
- **维护困难** — 修改一个通用行为需要逐个修改所有角色
- **不一致性** — 碰撞层、信号连接方式不统一
- **新角色创建成本高** — 从零搭建完整节点树

### 1.2 设计目标

| 目标 | 说明 |
|------|------|
| **可复用** | 通用功能在模板中实现一次，所有角色继承 |
| **可继承** | Godot Inherited Scene 实现场景级继承 |
| **可配置** | 通过 Inspector 导出属性即可定制差异化行为 |
| **可组合** | 非通用功能按需添加（RayCast、特殊攻击等） |
| **零代码创建** | 简单角色无需编写 GDScript，纯配置即可 |

---

## 2. 架构总览

### 2.1 系统全景图

```
                    ┌─────────────────────────┐
                    │    BaseCharacter.gd      │
                    │   (CharacterBody2D)      │
                    │  生命系统、信号路由、死亡判定  │
                    └─────────┬───────────────┘
                              │ extends
              ┌───────────────┼───────────────┐
              │               │               │
     ┌────────┴──────┐ ┌─────┴──────┐ ┌──────┴──────┐
     │ EnemyBase.gd  │ │PlayerBase.gd│ │ BossBase.gd │
     │ AI参数/精灵管理│ │组件引用/委托│ │阶段系统/巡逻│
     │ 动画树/重力/死亡│ │死亡UI处理   │ │攻击冷却/击退│
     └───────┬───────┘ └─────┬──────┘ └──────┬──────┘
             │               │               │
    ┌────────┼────────┐      │               │
    │        │        │      │               │
 ForestBee  Boar   Snail  Hahashin        Boss
 (零代码)  (RayCast) (简单)  (最小覆盖)    (8方位+纹理)

场景继承:
  EnemyBase.tscn → ForestBee.tscn, ForestBoar.tscn, ForestSnail.tscn
  PlayerBase.tscn → Hahashin.tscn
  BossBase.tscn → Boss.tscn
```

### 2.2 核心设计决策

| 决策 | 选择 | 理由 |
|------|------|------|
| 脚本继承 vs 组件 | **混合** | 脚本继承处理核心生命周期，组件处理可插拔功能 |
| 场景继承 vs 实例化 | **Inherited Scene** | Godot 原生支持，Inspector 直接覆盖属性 |
| 动画方案 | **AnimationTree BlendTree** (主) / **AnimatedSprite2D** (简) | 复杂角色用 BlendTree，简单角色用帧动画 |
| 状态机位置 | **模板内置** | 所有角色共享相同的基础状态结构 |
| Boss 继承 | **独立 BossBase** (非 EnemyBase) | Boss 差异过大，强行复用会导致混乱 |

---

## 3. 三层继承体系

### 3.1 第一层：BaseCharacter（所有角色的根基）

**文件**: `Core/Characters/BaseCharacter.gd`

**职责**: 健康信号链路、死亡判定、子类钩子

```gdscript
extends CharacterBody2D

signal damaged(damage: Damage, attacker_position: Vector2)

@export var max_health: int = 100
@export var health: int = 100
var alive: bool = true

func _ready() -> void:
    _setup_health_signals()   # 自动连接 HurtBox → Health → 状态机
    _on_character_ready()     # 子类钩子

func _setup_health_signals():
    # HurtBox.damaged → HealthComponent.take_damage
    # HealthComponent.died → _on_died()
    # HealthComponent.health_changed → HealthBar

func _on_died():
    alive = false
    velocity = Vector2.ZERO
    _handle_death()           # 子类实现

# 子类钩子
func _on_character_ready(): pass
func _handle_death(): pass
```

### 3.2 第二层A：EnemyBase（敌人通用逻辑）

**文件**: `Core/Characters/EnemyBase.gd`

**职责**: AI 参数导出、精灵管理、AnimationTree 激活、重力、死亡动画

```gdscript
extends BaseCharacter

@export_group("Wander")
@export var min_wander_time: float = 2.5
@export var max_wander_time: float = 10.0
@export var wander_speed: float = 50.0

@export_group("Chase")
@export var detection_radius: float = 100.0
@export var chase_radius: float = 200.0
@export var follow_radius: float = 25.0
@export var chase_speed: int = 75

@export_group("Physics")
@export var has_gravity: bool = false
@export var gravity: float = 800.0

@export_group("Animation")
@export var use_animation_tree: bool = true

var stunned: bool = false
var can_move: bool = true
var sprite: Node2D  # 自动检测 Sprite2D 或 AnimatedSprite2D

func _on_character_ready():
    _find_sprite()
    if use_animation_tree:
        anim_tree.active = true
    _on_enemy_ready()  # 子类钩子

func _handle_death():
    # 1. 停止状态机
    # 2. 播放 death 动画 (AnimationTree) 或白闪渐隐效果
    # 3. queue_free()
```

### 3.2B 第二层B：PlayerBase（玩家通用逻辑）

**文件**: `Core/Characters/PlayerBase.gd`

**职责**: 组件引用、委托 API、死亡 UI

```gdscript
extends BaseCharacter
class_name PlayerBase

@export var has_gravity: bool = true
@export var gravity: float = 980.0

@onready var movement_component: MovementComponent
@onready var combat_component: CombatComponent
@onready var skill_manager: SkillManager

var pending_combat_skill: String = ""  # 状态间技能传递

func _physics_process(delta):
    if has_gravity:
        if not is_on_floor():
            velocity.y += gravity * delta
        elif velocity.y > 0:
            velocity.y = 0

# 委托方法（Animation Method Track 调用）
func switch_to_physical():       combat_component.switch_to_damage_type(0)
func switch_to_knockup():        combat_component.switch_to_damage_type(1)
func switch_to_special_attack(): combat_component.switch_to_damage_type(2)

func _handle_death():
    visible = false
    # 显示 GameOver UI
    _show_game_over()
```

### 3.2C 第二层C：BossBase（Boss 通用逻辑）

**文件**: `Core/Characters/BossBase.gd`

**职责**: 阶段系统、阶段转换特效、巡逻点、攻击冷却

```gdscript
extends BaseCharacter
class_name BossBase

signal phase_changed(new_phase: int)
signal boss_defeated()

enum Phase { PHASE_1, PHASE_2, PHASE_3 }

@export var detection_radius := 800.0
@export var attack_range := 300.0
@export var min_distance := 150.0
@export var phase_2_health_percent := 0.66
@export var phase_3_health_percent := 0.33

var current_phase: Phase = Phase.PHASE_1
var attack_cooldown: float = 0.0
var special_attack_cooldown: float = 0.0
var patrol_points: Array[Vector2] = []

func check_phase_transition():
    var hp_pct = float(health) / float(max_health)
    if hp_pct <= phase_3_health_percent and current_phase != Phase.PHASE_3:
        change_phase(Phase.PHASE_3)
    elif hp_pct <= phase_2_health_percent and current_phase == Phase.PHASE_1:
        change_phase(Phase.PHASE_2)

func change_phase(new_phase: Phase):
    current_phase = new_phase
    activate_phase_transition_effect()  # 1秒无敌 + 击退附近单位
    phase_changed.emit(new_phase)

# 子类钩子
func _on_boss_ready(): pass
func _on_phase_transition(): pass
func _update_facing(): pass
```

### 3.3 第三层：具体角色

```gdscript
# ForestBee.gd — 零自定义代码
extends EnemyBase

# Hahashin.gd — 最小化
extends PlayerBase
class_name Hahashin
func _on_player_ready(): pass

# Boss.gd — 特化逻辑
extends BossBase
class_name Boss
@export var textures: Array[Texture2D] = []
@export var base_move_speed := 150.0
const DIRECTIONS_8 = [...]  # 8方位

var move_speed: float:
    get:
        match current_phase:
            Phase.PHASE_1: return base_move_speed * 1.0
            Phase.PHASE_2: return base_move_speed * 1.3
            Phase.PHASE_3: return base_move_speed * 1.5
```

---

## 4. 模板场景设计

### 4.1 EnemyBase.tscn

**文件**: `Scenes/Characters/Templates/EnemyBase.tscn`

```
EnemyBase (CharacterBody2D) [EnemyBase.gd]
│   collision_layer=8, collision_mask=128
│
├── Sprite2D                          ← 空，子场景填充纹理
├── AnimationPlayer                   ← 仅含 RESET，子场景覆盖
├── AnimationTree                     ← 完整 BlendTree（共享结构）
│
├── HurtBoxComponent (Area2D)         ← 受击检测
│   └── CollisionShape2D (CircleShape2D r=12)
│
├── FloorCollision (CollisionShape2D) ← 物理碰撞 (CapsuleShape2D)
├── HealthComponent (Node)
│
├── EnemyStateMachine (Node)          ← 7 个通用状态
│   ├── Idle      [IdleState.gd]
│   ├── Wander    [WanderState.gd]
│   ├── Chase     [ChaseState.gd]
│   ├── Attack    [AttackState.gd]
│   ├── Hit       [HitState.gd]
│   ├── Stun      [StunState.gd]
│   └── Knockback [KnockbackState.gd]
│
├── HitBoxComponent (Area2D)          ← 攻击判定
│   └── CollisionShape2D (CircleShape2D r=12)
│
├── HealthBar (ProgressBar)
├── DamageNumbersAnchor (Node2D)
└── AttackAnchor (Node2D)
```

### 4.2 PlayerBase.tscn

**文件**: `Scenes/Characters/Templates/PlayerBase.tscn`

```
PlayerBase (CharacterBody2D) [PlayerBase.gd]
│   collision_layer=2, collision_mask=128, groups=["player"]
│
├── FloorCollision (CollisionShape2D)  ← CircleShape2D r=15
├── AnimatedSprite2D                   ← 空，子场景填充 SpriteFrames
├── AnimationPlayer                    ← 仅含 RESET
├── AnimationTree                      ← 设置 anim_player 路径
│
├── HurtBoxComponent (Area2D)          ← collision_layer=2, mask=0
│   └── CollisionShape2D (CircleShape2D r=15)
│
├── DamageNumbersAnchor (Node2D)
├── HitBoxComponent (Area2D) [PlayerHitbox.gd]  ← collision_layer=4, mask=8
│   └── CollisionShape2D (RectangleShape2D, disabled)
│
├── HealthComponent (Node)
├── HealthBar (ProgressBar)            ← 玩家血条（绿色）
│
├── MovementComponent (Node)           ← 移动逻辑
├── CombatComponent (Node)             ← 战斗/伤害类型
├── SkillManager (Node)                ← V-技能管理
├── AudioStreamPlayer
│
└── PlayerStateMachine (Node)          ← 5+1 个状态
    ├── Ground (PlayerGroundState)     ← BEHAVIOR, interruptible
    ├── Air (PlayerAirState)           ← BEHAVIOR, interruptible
    ├── Combat (PlayerCombatState)     ← REACTION, not interruptible
    ├── Roll (PlayerRollState)         ← REACTION, not interruptible
    ├── Hit (PlayerHitState)           ← CONTROL, not interruptible
    └── SpecialAttack (PlayerSpecialAttackState) ← REACTION, not interruptible
```

### 4.3 BossBase.tscn

**文件**: `Scenes/Characters/Templates/BossBase.tscn`

```
BossBase (CharacterBody2D) [BossBase.gd]
│   collision_layer=8, collision_mask=128, groups=["enemy"]
│
├── Sprite2D                           ← 空，子场景填充纹理
├── CollisionShape2D                   ← RectangleShape2D 40x60
├── DamageNumbersAnchor (Node2D)       ← position(0, -40)
├── AnimationPlayer
│
├── HurtBoxComponent (Area2D)          ← collision_layer=8, mask=0
│   └── CollisionShape2D (RectangleShape2D 40x56)
│
├── HealthComponent (Node)
├── HealthBar (ProgressBar)            ← Boss 血条（红色，较大）
│
├── BossAttackManager (Node)           ← 攻击技能管理器
│
└── StateMachine (BossStateMachine)    ← 9 个 Boss 状态
    ├── Idle          [BossIdle.gd]
    ├── Patrol        [BossPatrol.gd]
    ├── Chase         [BossChase.gd]
    ├── Circle        [BossCircle.gd]
    ├── Attack        [BossAttack.gd]
    ├── Retreat       [BossRetreat.gd]
    ├── Stun          [BossStun.gd]
    ├── Enrage        [BossEnrage.gd]
    └── SpecialAttack [BossSpecialAttack.gd]
```

### 4.4 三种模板对比

| 特性 | EnemyBase | PlayerBase | BossBase |
|------|-----------|-----------|----------|
| **状态数量** | 7 (Idle ~ Knockback) | 5+1 (Ground ~ SpecialAttack) | 9 (多 Patrol/Circle/Retreat/Enrage) |
| **专用组件** | AttackAnchor | MovementComponent, CombatComponent, SkillManager | BossAttackManager |
| **动画方案** | AnimationTree 或 AnimatedSprite2D | AnimatedSprite2D + AnimationTree | AnimationPlayer |
| **朝向逻辑** | flip_h（简单翻转） | MovementComponent 处理 | 8 方位旋转 |
| **特殊系统** | AI参数、重力 | 技能系统、跳跃 | 阶段系统、巡逻点 |
| **碰撞层** | Layer 8 | Layer 2 | Layer 8 |

### 4.5 模板 vs 组合 决策表

| 节点 | 归属 | 理由 |
|------|------|------|
| 状态机 + 所有状态 | **模板** | 所有同类角色共享相同状态结构 |
| HitBox / HurtBox | **模板** | 所有角色都有，形状/damage 可覆盖 |
| HealthComponent + HealthBar | **模板** | 所有角色都有 |
| AnimationTree | **模板** | BlendTree 结构统一，子场景只提供动画数据 |
| RayGround / RayWall | **组合** | 仅地面敌人需要，飞行敌人不需要 |
| AnimatedSprite2D | **组合** | Forest 敌人用帧动画，与 Sprite2D 方案互斥 |

---

## 5. 组件系统详解

### 5.1 HealthComponent

**文件**: `Core/Components/HealthComponent.gd`

**职责**: 生命值管理、伤害处理、效果应用、死亡判定

```
信号流:
  take_damage(damage, attacker_pos)
    ├→ 检查无敌
    ├→ 扣血
    ├→ 显示伤害数字
    ├→ 应用攻击效果 (KnockBack/KnockUp/Stun/Gather)  ← 先应用效果
    ├→ emit health_changed → HealthBar 更新
    ├→ emit damaged → 状态机响应                       ← 后发信号
    └→ if health <= 0 → emit died
```

**无敌系统**:
```gdscript
func set_invincible(enabled: bool, duration: float = 0.0):
    is_invincible = enabled
    if enabled and duration > 0:
        # 定时取消无敌
```

### 5.2 HurtBoxComponent + HitBoxComponent

**文件**: `Core/Components/HurtBoxComponent.gd`, `Core/Components/HitBoxComponent.gd`

```
HitBoxComponent (攻击方)              HurtBoxComponent (受击方)
│                                    │
│ area_entered(area)                 │
├────────────────────────────────────→│
│ update_attack() → randomize        │
│ take_damage(damage, pos)           │
│                                    │ damaged.emit(damage, pos)
│                                    │    │
│                                    │    ▼
│                                    │ HealthComponent.take_damage()
```

**HitBoxComponent 特性**:
- `destroy_owner_on_hit`: 弹幕/冲撞型敌人命中后自毁
- `ignore_collision_groups`: 忽略特定组的碰撞
- **PlayerHitbox.gd**: 玩家专用覆盖，读取 CombatComponent 的 current_damage

### 5.3 MovementComponent

**文件**: `Core/Components/MovementComponent.gd` (263行)

**职责**: 输入处理、移动物理、跳跃检测、精灵翻转

**信号**:
```gdscript
signal direction_changed(new_direction: Vector2)
signal movement_ability_changed(can_move: bool)
signal velocity_changed(velocity: Vector2)
signal sprite_flipped(flip_h: bool)
signal jump_started()
signal jump_apex_reached()
signal landed()
```

**核心逻辑**:
```gdscript
func process_movement(delta):
    handle_jump_input()
    # 加速度模型
    var target_vx = input_direction.x * max_speed if can_move else 0.0
    var accel = (1.0 / acceleration_time) * max_speed * delta
    owner_body.velocity.x = move_toward(velocity.x, target_vx, accel)
    update_sprite_flip()    # 自动翻转精灵 + HitBox
    owner_body.move_and_slide()
```

**跳跃检测**:
```
起跳 → is_jumping=true → 到达顶点(velocity.y>0) → jump_apex_reached
                                                    → is_falling=true
下落 → 着地(on_floor) → landed → is_jumping=false, is_falling=false
```

### 5.4 CombatComponent

**文件**: `Core/Components/CombatComponent.gd`

**职责**: 管理多种伤害类型，Animation Method Track 调用切换

```gdscript
@export var damage_types: Array[Damage] = []
var current_damage: Damage = null

# 伤害类型索引:
# 0 = Physical (普通斩击)
# 1 = KnockUp (击飞)
# 2 = SpecialAttack (V技能)

func switch_to_damage_type(index: int):
    current_damage = damage_types[index]
    damage_type_changed.emit(current_damage)
```

**调用链**:
```
Animation Method Track → PlayerBase.switch_to_physical()
                       → CombatComponent.switch_to_damage_type(0)
                       → current_damage 更新
                       → HitBoxComponent 读取 current_damage
```

### 5.5 SkillManager

**文件**: `Core/Components/SkillManager.gd` (458行)

**职责**: V-技能特殊攻击的完整生命周期管理

**6 阶段流程**:
```
Phase 1: create_effects()     → 残影扩散 + 心跳 + 漩涡
Phase 2: detect_enemies()     → 锥形检测 (radius=300, angle=45)
Phase 3: gather_enemies()     → 相机移动 + 子弹时间 + 眩晕
Phase 4: dash_to_target()     → 残影冲刺
Phase 5: play_attack_sound()  → 音效
Phase 6: cleanup()            → 解除眩晕、隐藏特效
```

**关键配置**:
```gdscript
@export var detection_radius: float = 300.0
@export var detection_angle: float = 45.0
@export var gather_distance: float = 200.0
@export var move_duration: float = 0.2
@export var enable_camera_effects: bool = true
@export var enable_bullet_time: bool = true
@export var enable_after_image: bool = true
```

### 5.6 FollowCamera

**文件**: `Core/Components/FollowCamera.gd`

**职责**: 相机跟随、震动效果、焦点切换

```
模式:
  Follow Mode → 跟随 "player" 组的目标，lerp 平滑
  Focus Mode  → Tween 到指定目标，可选 zoom
  Shake Mode  → 随机偏移 + 衰减

信号:
  camera_focus_started(target)
  camera_focus_finished()
  camera_shake_started()
  camera_shake_finished()
```

### 5.7 AttackComponent

**文件**: `Core/Components/AttackComponent.gd` (45行)

**职责**: 攻击实体生成

```gdscript
func perform_attack(attack_name, facing_direction, anchor):
    # 根据 attack_name 加载攻击场景
    # 设置旋转/偏移
    # 实例化到场景树
```

---

## 6. Resource 数据系统

### 6.1 Damage

**文件**: `Core/Resources/Damage.gd`

```gdscript
@export var max_amount: float = 50.0
@export var min_amount: float = 1.0
@export var amount: float = 10.0
@export var effects: Array[AttackEffect] = []

func randomize_damage():
    amount = rng.randf_range(min_amount, max_amount)

func apply_effects(enemy, damage_source_position):
    for effect in effects:
        effect.apply_effect(enemy, damage_source_position)
```

### 6.2 AttackEffect 体系

**基类**: `Core/Resources/AttackEffect.gd`

```
AttackEffect (基类)
├── KnockBackEffect     → 击退 (velocity = direction * force)
├── KnockUpEffect       → 击飞 (Tween: 上升 → 下落)
├── StunEffect          → 眩晕 (force_transition("stun"))
├── GatherEffect        → 聚拢 (Tween 到目标点)
└── ForceStunEffect     → 强制眩晕 (停止移动 + 强制状态切换)
```

**效果应用链**:
```
Damage.apply_effects(enemy, pos)
  ├→ KnockBackEffect: enemy.velocity = dir * 200
  ├→ KnockUpEffect: Tween 弧形飞行
  ├→ StunEffect: state_machine.force_transition("stun")
  └→ GatherEffect: Tween 到聚拢点
```

### 6.3 CharacterData

**文件**: `Core/Resources/CharacterData.gd`

```gdscript
@export var id: String
@export var display_name: String
@export var description: String
@export var portrait: Texture2D
@export_file("*.tscn") var scene_path: String

@export_group("Base Stats")
@export var base_health: float = 100.0
@export var base_speed: float = 100.0
@export var base_damage: float = 10.0

func instantiate_character() -> Node:
    return load(scene_path).instantiate()
```

---

## 7. 信号链路与通信流

### 7.1 完整伤害链路

```
Player HitBoxComponent 碰撞 Enemy HurtBoxComponent
    │ (area_entered)
    ▼
HitBoxComponent._on_hitbox_area_entered(area)
    ├→ update_attack()  [随机化伤害]
    └→ area.take_damage(damage, attacker_position)
        │
        ▼
Enemy HurtBoxComponent.damaged.emit(damage, attacker_pos)
    │ (BaseCharacter._setup_health_signals 连接)
    ▼
Enemy HealthComponent.take_damage(damage, attacker_pos)
    ├→ health -= damage.amount
    ├→ display_damage_number()
    ├→ damage.apply_effects(enemy, pos)        ← 先应用效果
    │   ├→ KnockBackEffect → velocity 设置
    │   ├→ StunEffect → force_transition("stun")
    │   └→ ...
    │
    ├→ health_changed.emit(health, max_health)  ← 后发信号
    │   └→ HealthBar 更新
    │
    ├→ damaged.emit(damage, pos)
    │   └→ BaseCharacter.damaged.emit()
    │       └→ 状态机 on_damaged()
    │           └→ force_transition("hit")
    │
    └→ if health <= 0:
        └→ died.emit()
            └→ BaseCharacter._on_died()
                └→ EnemyBase._handle_death()
                    ├→ 停止状态机
                    ├→ 播放死亡动画
                    └→ queue_free()
```

**关键设计**: 攻击效果在 `emit damaged` **之前**应用，确保状态机收到信号时速度已正确设置。

### 7.2 碰撞层配置

| Layer | 用途 | 数值 |
|-------|------|------|
| Layer 2 | 玩家 | 2 |
| Layer 3 | 玩家攻击 | 4 |
| Layer 4 | 敌人 | 8 |
| Layer 8 | 地形碰撞 | 128 |

| 组件 | collision_layer | collision_mask | 含义 |
|------|----------------|----------------|------|
| Player Body | 2 | 128 | 玩家，与地形碰撞 |
| Player HitBox | 4 | 8 | 玩家攻击，命中敌人 |
| Player HurtBox | 2 | 0 | 玩家受击区 |
| Enemy Body | 8 | 128 | 敌人，与地形碰撞 |
| Enemy HitBox | 8 | 2 | 敌人攻击，命中玩家 |
| Enemy HurtBox | 8 | 4 | 敌人受击区，接收玩家攻击 |

---

## 8. 具体角色实现

### 8.1 ForestBee — 零代码飞行敌人

```
继承: EnemyBase.tscn
脚本: extends EnemyBase (空)
配置覆盖:
  max_health = 30
  wander_speed = 40
  detection_radius = 150
  chase_speed = 80
  use_animation_tree = false
  has_gravity = false (飞行)
新增节点:
  AnimatedSprite2D (帧动画: fly, idle)
状态覆盖:
  5 个状态替换为 Bee 专用 (BeeIdle, BeeWander, BeeChase, BeeAttack, BeeStun)
```

### 8.2 ForestBoar — 带 RayCast 地面敌人

```
继承: EnemyBase.tscn
脚本: extends EnemyBase
配置覆盖:
  max_health = 50
  wander_speed = 40
  chase_speed = 100
  has_gravity = true (地面)
新增节点:
  AnimatedSprite2D (idle, run, walk, hit, stunned, death)
  RayGround: position(20,0), target(0,20)  ← 边缘检测
  RayWall: target(25,0)                     ← 墙壁检测
覆盖节点:
  HitBoxComponent: damage + destroy_owner_on_hit=true (冲撞自毁)
  CollisionShape2D: 调整碰撞形状
状态覆盖:
  5 个状态替换为 Boar/Forest 专用
```

### 8.3 Hahashin — 玩家角色

```
继承: PlayerBase.tscn
脚本: extends PlayerBase (最小)
配置覆盖:
  max_health = 10000
  MovementComponent.max_speed = 200
  CombatComponent.damage_types = [Physical, KnockUp, SpecialAttack]
覆盖节点:
  AnimatedSprite2D: Hahashin 精灵 (idle, run, atk_1/2/3, atk_air, atk_sp, roll, j_up, j_down, take_hit)
  AnimationPlayer: 完整动画库 (包括 HitBox 启用/禁用动画)
  AnimationTree: 完整 BlendTree (locomotion SM + control SM)
  CollisionShape2D: 调整碰撞形状

HitBox 动画驱动 (AnimationPlayer Method Track):
  atk_1: Frame 1-3 启用 HitBox, 位置 (20.5, -9.5), 尺寸 (42, 19)
  atk_2: 无 HitBox (远程型)
  atk_3: Frame 0-2, 7-11, 15-20 分段启用 (连击)
  atk_air: Frame 1-6 启用, 向上移动
```

### 8.4 Boss (DemonCyclop) — 阶段战斗

```
继承: BossBase.tscn
脚本: extends BossBase (8方位 + 纹理 + 速度倍率)
配置覆盖:
  max_health = 1001
  BossAttackManager: 配置 projectile/laser/aoe 场景和 damage 资源
覆盖节点:
  Sprite2D: DemonCyclop 纹理 (48x64)

特化逻辑:
  move_speed: Phase1 x1.0 → Phase2 x1.3 → Phase3 x1.5
  8方位旋转: DIRECTIONS_8 数组 + 平滑旋转
  巡逻点: setup_patrol_points() 初始化
```

---

## 9. 创建新角色指南

### 9.1 创建新敌人

1. **Godot 编辑器** → 右键 `EnemyBase.tscn` → **New Inherited Scene**
2. **设置参数** → Inspector 配置 health, speed, detection 等
3. **添加动画**:
   - **方案 A** (AnimationTree): `use_animation_tree = true` + 覆盖 Sprite2D 纹理 + AnimationPlayer 库
   - **方案 B** (AnimatedSprite2D): `use_animation_tree = false` + 新增 AnimatedSprite2D 节点
4. **(可选) 自定义状态** → 覆盖需要的状态节点脚本
5. **(可选) 调整碰撞** → 覆盖 CollisionShape2D

### 9.2 创建新玩家

1. **Godot 编辑器** → 右键 `PlayerBase.tscn` → **New Inherited Scene**
2. **覆盖动画** → AnimatedSprite2D + AnimationPlayer + AnimationTree
3. **配置组件** → MovementComponent.max_speed + CombatComponent.damage_types
4. **(可选) 自定义脚本** → 覆盖 `_on_player_ready()` 钩子

### 9.3 创建新 Boss

1. **Godot 编辑器** → 右键 `BossBase.tscn` → **New Inherited Scene**
2. **设置参数** → max_health, detection_radius, phase 阈值
3. **配置攻击** → BossAttackManager 的攻击场景和 damage 资源
4. **添加纹理** → 覆盖 Sprite2D
5. **(可选) 自定义逻辑** → `_on_boss_ready()`, `_update_facing()` 钩子

---

## 10. 架构优缺点分析

### 10.1 优点

**场景继承降低创建成本**
- ForestBee 仅需一个空 GDScript + Inspector 配置即可创建
- Hahashin 仅需覆盖动画和参数，状态机完全继承
- 新建敌人从"数小时"降低到"数分钟"

**三层继承职责清晰**
- BaseCharacter: 生命系统（不变）
- 二层基类: 角色类型逻辑（偶尔修改）
- 三层具体: 个体差异化（频繁修改）
- 修改二层基类自动惠及所有同类角色

**钩子方法避免 _ready() 重写**
- `_on_character_ready()` → `_on_enemy_ready()` → 子类自定义
- 避免忘记调用 `super._ready()` 导致信号断裂
- 清晰的初始化顺序保证

**组件化可插拔**
- MovementComponent, CombatComponent 等独立运作
- 通过信号通信，无直接耦合
- 可以在子场景中按需添加/移除组件

**信号驱动松耦合**
- HurtBox → HealthComponent → StateMachine 全部通过信号连接
- 替换某个组件不影响其他组件
- 外部系统（如 AttackEffect）通过信号/方法调用与状态机交互

**Resource 数据驱动**
- Damage 资源包含效果列表，Inspector 可视化配置
- AttackEffect 子类支持多种效果组合
- 新增攻击效果只需创建新的 AttackEffect 子类

### 10.2 缺点

**动画方案不统一**
- EnemyBase 支持两种方案 (AnimationTree / AnimatedSprite2D)
- PlayerBase 使用 AnimatedSprite2D + AnimationTree
- BossBase 仅使用 AnimationPlayer
- 三种模板使用三种不同的动画控制方式，新开发者容易混淆
- `use_animation_tree` 标志增加了条件分支

**BaseCharacter._setup_health_signals() 过于隐式**
- 信号连接在 `_ready()` 中自动完成
- 如果节点命名不匹配（如 "HurtBoxComponent" 写错），信号静默失败
- 依赖硬编码的节点路径（如 `get_node_or_null("HurtBoxComponent")`）
- 调试困难：信号未连接时没有明确的错误提示

**Boss 缺少 AnimationTree**
- BossBase.tscn 没有 AnimationTree 节点
- Boss 状态直接操作 AnimationPlayer，绕过了 BaseState 的动画 helper
- 导致 Boss 状态代码与 Player/Enemy 状态代码风格不一致
- 无法利用 BlendTree 的混合和过渡功能

**碰撞层配置分散**
- 碰撞层在多个 .tscn 文件中各自配置
- 缺少集中的碰撞层文档/常量定义
- 容易出现配置不一致（如新角色忘记设置正确的 mask）

**EnemyData Resource 未充分利用**
- `EnemyBase.gd` 有 `enemy_data: EnemyData` 导出属性和 `_apply_enemy_data()` 方法
- 但大部分敌人直接在 Inspector 中覆盖 `@export` 属性，没有使用 EnemyData
- 两套配置方式并存（直接导出 vs Resource），增加混淆

**SkillManager 承担过多职责**
- 458 行代码管理特效、检测、聚拢、冲刺、相机、子弹时间
- 与 PlayerSpecialAttackState 高度耦合
- 难以复用到其他技能或其他角色

**HitBox 启用/禁用依赖动画帧**
- 攻击动画通过 AnimationPlayer Method Track 启用/禁用 HitBox
- 时机精确但难以调试（需要在 AnimationPlayer 中逐帧查看）
- 修改攻击范围需要同时修改动画和碰撞形状

---

## 11. 待提升项与改进建议

### 11.1 短期改进

#### A. 碰撞层常量化

```gdscript
# Core/Constants/CollisionLayers.gd
class_name CollisionLayers

const PLAYER_BODY = 2          # Layer 2
const PLAYER_ATTACK = 4        # Layer 3
const ENEMY = 8                # Layer 4
const TERRAIN = 128            # Layer 8

const PLAYER_HURTBOX_MASK = 0
const PLAYER_HITBOX_MASK = ENEMY
const ENEMY_HURTBOX_MASK = PLAYER_ATTACK
const ENEMY_HITBOX_MASK = PLAYER_BODY
```

**收益**: 集中管理，减少配置错误

#### B. 信号连接验证

```gdscript
# BaseCharacter._setup_health_signals() 增加验证
func _setup_health_signals():
    var hurtbox = get_node_or_null("HurtBoxComponent")
    if not hurtbox:
        push_warning("%s: HurtBoxComponent not found" % name)
        return

    if not health_component:
        push_warning("%s: HealthComponent not found" % name)
        return

    hurtbox.damaged.connect(health_component.take_damage)
    # ...
```

**收益**: 开发阶段快速发现配置错误

#### C. 统一 EnemyData 使用

```
当前: 直接导出属性 + EnemyData Resource 并存
建议: 选择一种方案:
  方案 A: 全部使用 EnemyData Resource（数据驱动）
  方案 B: 移除 EnemyData，全部使用直接导出（简单直接）
推荐: 方案 B（当前项目规模不需要额外的 Resource 抽象层）
```

### 11.2 中期改进

#### D. BossBase 添加 AnimationTree

```
当前: Boss 直接使用 AnimationPlayer
建议: BossBase.tscn 添加 AnimationTree，使用与 EnemyBase 相同的 BlendTree 结构

步骤:
1. BossBase.tscn 添加 AnimationTree 节点
2. 配置 BlendTree (locomotion + control_sm)
3. BossBaseState 改用 enter_control_state() 等 helper
4. 更新现有 Boss 状态脚本

收益:
- 统一的动画控制接口
- Boss 动画混合更平滑
- 代码风格一致
```

#### E. SkillManager 拆分

```
当前: SkillManager (458行) 管理所有技能阶段
建议: 拆分为 SkillManager (协调) + 独立的 Phase 类

# SkillManager — 协调器
func execute_skill(skill_data: SkillData):
    for phase in skill_data.phases:
        await phase.execute(self)

# SkillPhase — 独立阶段
class DetectPhase extends SkillPhase:
    func execute(context):
        context.detect_enemies_in_cone(...)

class GatherPhase extends SkillPhase:
    func execute(context):
        context.gather_enemies()
```

**收益**: 技能阶段可组合、可复用、可独立测试

#### F. 动画方案统一策略

```
方案 1: 全部统一到 AnimationTree
  - 为 AnimatedSprite2D 类型创建简化的 BlendTree 适配
  - ForestEnemy 也使用 AnimationTree 控制

方案 2: 在 BaseState 中增加 AnimatedSprite2D 支持
  - 新增 play_sprite_animation(name) helper
  - ForestEnemyState 不再需要独立的动画控制代码

方案 3: 接受双系统（推荐）
  - AnimationTree 用于复杂角色（方向+速度混合）
  - AnimatedSprite2D 用于简单角色（仅帧动画）
  - 但在 BaseState 中统一暴露接口
```

### 11.3 长期改进

#### G. 模板场景版本管理

```
问题: 修改模板会影响所有继承场景
建议: 制定模板修改流程
  1. 修改前列出所有继承场景
  2. 验证修改不会破坏现有行为
  3. 必要时创建新版本模板 (V2) 而非修改原模板
```

#### H. 组件自动发现

```
当前: BaseCharacter 硬编码节点路径
建议: 组件通过 class_name 自动发现

func _find_component(type) -> Node:
    for child in get_children():
        if child is type:
            return child
    return null

# 用法:
health_component = _find_component(HealthComponent)
```

**收益**: 组件可以在子场景中重命名或重新排列而不破坏功能

### 11.4 改进优先级

| 优先级 | 改进项 | 原因 |
|--------|--------|------|
| P0 | B. 信号连接验证 | 开发体验提升，改动极小 |
| P0 | A. 碰撞层常量化 | 减少配置错误，改动小 |
| P1 | C. 统一 EnemyData 策略 | 减少混淆，改动小 |
| P2 | D. Boss AnimationTree | 架构一致性，改动中等 |
| P2 | E. SkillManager 拆分 | 可维护性提升，改动中等 |
| P3 | F. 动画方案统一 | 架构一致性，可选 |
| P3 | H. 组件自动发现 | 灵活性提升，需评估 |
| P4 | G. 模板版本管理 | 流程优化，非代码改动 |

---

## 文件索引

**模板场景**:
- `Scenes/Characters/Templates/EnemyBase.tscn`
- `Scenes/Characters/Templates/PlayerBase.tscn`
- `Scenes/Characters/Templates/BossBase.tscn`

**基类脚本**:
- `Core/Characters/BaseCharacter.gd`
- `Core/Characters/EnemyBase.gd`
- `Core/Characters/PlayerBase.gd`
- `Core/Characters/BossBase.gd`

**组件**:
- `Core/Components/HealthComponent.gd`
- `Core/Components/HurtBoxComponent.gd`
- `Core/Components/HitBoxComponent.gd`
- `Core/Components/MovementComponent.gd`
- `Core/Components/CombatComponent.gd`
- `Core/Components/SkillManager.gd`
- `Core/Components/FollowCamera.gd`
- `Core/Components/AttackComponent.gd`

**Resource**:
- `Core/Resources/Damage.gd`
- `Core/Resources/AttackEffect.gd`
- `Core/Resources/KnockBackEffect.gd`
- `Core/Resources/KnockUpEffect.gd`
- `Core/Resources/StunEffect.gd`
- `Core/Resources/GatherEffect.gd`
- `Core/Resources/ForceStunEffect.gd`
- `Core/Resources/CharacterData.gd`

**具体角色**:
- `Scenes/Characters/Player/Hahashin/Hahashin.tscn` + `hahashin.gd`
- `Scenes/Characters/Enemies/ForestBee/ForestBee.tscn`
- `Scenes/Characters/Enemies/ForestBoar/ForestBoar.tscn`
- `Scenes/Characters/Enemies/ForestSnail/ForestSnail.tscn`
- `Scenes/Characters/Enemies/Boss/Boss.tscn` + `Scripts/boss.gd`

---

> **相关文档**:
> - [状态机 + AnimationTree 架构](01_state_machine_architecture.md) — 状态机和动画混合详解
> - [战斗系统架构](02_combat_system_architecture.md) — 战斗系统
> - [组件系统架构](03_component_system_architecture.md) — 组件系统
> - [信号驱动架构](04_signal_driven_architecture.md) — 信号通信
>
> **更新历史**:
> - 2026-02-25: 创建文档，EnemyBase 模板系统
> - 2026-02-26: 新增 PlayerBase 和 BossBase 模板
> - 2026-03-15: 全面重写，深度分析三种模板的优缺点和改进建议，完善组件/Resource/信号链路文档
