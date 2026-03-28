# 场景模板、类继承与 AnimationTree 分层动画

三类角色（Player / Enemy / Boss）的场景节点树、类继承关系、状态机配置、AnimationTree BlendTree 结构的完整参考。含 Mermaid 架构图、类图、数据流图。

---

## 1. 整体架构图

```mermaid
graph TB
    subgraph Presentation["Presentation 层"]
        PTSCN["*.tscn 场景文件"]
        UI["Scenes/UI/"]
        Assets["Assets/Art, Sound"]
    end

    subgraph Business["Business 层"]
        PlayerImpl["Player 角色实现"]
        EnemyImpl["Enemy 角色实现<br/>Bear/Slime/Dragon..."]
        BossImpl["Boss 角色实现<br/>States + AttackManager"]
        LevelImpl["Level 脚本"]
    end

    subgraph Framework["Framework 层"]
        SM["StateMachine 框架<br/>BaseStateMachine + BaseState"]
        Comp["组件系统<br/>Health/HitBox/HurtBox/Movement"]
        Res["Resource 定义<br/>Damage + AttackEffect"]
        Chars["角色基类<br/>BaseCharacter/EnemyBase/BossBase"]
    end

    subgraph Services["Services 层 (Autoload)"]
        GM["GameManager"]
        LM["LevelManager"]
        UIM["UIManager"]
        DC["DebugConfig"]
        DM["DamageNumbers"]
        TM["TimeManager"]
    end

    PTSCN --> PlayerImpl
    PTSCN --> EnemyImpl
    PTSCN --> BossImpl
    PlayerImpl --> Chars
    EnemyImpl --> Chars
    BossImpl --> Chars
    Chars --> SM
    Chars --> Comp
    Chars --> Res
    LevelImpl --> LM
    PlayerImpl -.-> GM
    EnemyImpl -.-> DC
    BossImpl -.-> DM
```

---

## 2. 角色类继承图

```mermaid
classDiagram
    class CharacterBody2D {
        +velocity: Vector2
        +move_and_slide()
    }

    class BaseCharacter {
        +health_component: HealthComponent
        +hurt_box: HurtBoxComponent
        +damaged signal
        +_connect_hurt_box_to_health()
    }

    class PlayerBase {
        +movement_component: MovementComponent
        +combat_component: CombatComponent
        +skill_manager: SkillManager
        +pending_combat_skill: Dictionary
        +set_pending_skill(name)
        +consume_pending_skill() Dictionary
    }

    class EnemyBase {
        +detection_radius: float
        +chase_radius: float
        +chase_speed: float
        +wander_speed: float
        +stunned: bool
        +can_move: bool
        +use_animation_tree: bool
        +_handle_death()
    }

    class BossBase {
        +current_phase: Phase
        +phase_2_health_percent: float
        +phase_3_health_percent: float
        +attack_range: float
        +min_distance: float
        +change_phase(phase)
        +check_phase_transition()
        +activate_phase_transition_effect()
        +phase_changed signal
        +boss_defeated signal
    }

    class Boss {
        +base_move_speed: float
        +phase_configs: Array
        +DIRECTIONS_8: Array
    }

    CharacterBody2D <|-- BaseCharacter
    BaseCharacter <|-- PlayerBase
    BaseCharacter <|-- EnemyBase
    EnemyBase <|-- BossBase
    BossBase <|-- Boss
    EnemyBase <|-- Bear
    EnemyBase <|-- Slime
    EnemyBase <|-- Dragon
```

---

## 3. 状态机类继承图

```mermaid
classDiagram
    class BaseState {
        +priority: StatePriority
        +can_be_interrupted: bool
        +owner_node: Node
        +target_node: Node
        +enter()
        +exit()
        +process_state(delta)
        +physics_process_state(delta)
        +on_damaged(damage, pos)
        +transitioned signal
    }

    class BaseStateMachine {
        +current_state: BaseState
        +states: Dictionary
        +anim_tree: AnimationTree
        +_on_state_transition()
        +_execute_transition()
    }

    class EnemyStateMachine {
        +preset: Preset
        +idle_time_range: Vector2
        +stun_duration: float
        +force_stun(duration)
        +is_controlled() bool
        +can_act() bool
    }

    class IdleState { +min_idle_time +max_idle_time }
    class ChaseState { +default_chase_speed +default_attack_range }
    class AttackState { +attack_interval +perform_attack() +on_custom_attack() }
    class HitState { +hit_duration +reset_on_damage }
    class StunState { +stun_duration +knockback_friction }
    class KnockbackState { +friction +min_velocity }
    class SpecialSkillState { +skill_cooldown +skill_probability +can_trigger() +execute_skill() +finish_skill() }

    BaseStateMachine <|-- EnemyStateMachine
    BaseState <|-- IdleState
    BaseState <|-- WanderState
    BaseState <|-- ChaseState
    BaseState <|-- AttackState
    BaseState <|-- HitState
    BaseState <|-- StunState
    BaseState <|-- KnockbackState
    BaseState <|-- SpecialSkillState
    BaseStateMachine o-- BaseState : manages
```

---

## 4. 组件与伤害系统类图

```mermaid
classDiagram
    class HealthComponent {
        +health: float
        +max_health: float
        +is_alive: bool
        +is_invincible: bool
        +take_damage(damage, pos)
        +heal(amount)
        +die()
        +set_invincible(enabled, duration)
        +health_changed signal
        +damaged signal
        +died signal
    }

    class HitBoxComponent {
        +damage: Damage
        +destroy_owner_on_hit: bool
    }

    class HurtBoxComponent {
        +take_damage(damage, pos)
        +damaged signal
    }

    class MovementComponent {
        +can_move: bool
        +speed: float
        +direction_changed signal
        +velocity_changed signal
        +sprite_flipped signal
    }

    class CombatComponent {
        +damage_types: Array
        +current_damage: Damage
        +switch_to_physical()
        +switch_to_knockup()
        +switch_to_special_attack()
    }

    class Damage {
        +amount: float
        +effects: Array
        +has_effect(type) bool
        +randomize_damage()
    }

    class AttackEffect {
        +apply_effect(target, pos)
        +get_description() String
    }

    AttackEffect <|-- KnockBackEffect
    AttackEffect <|-- StunEffect
    AttackEffect <|-- KnockUpEffect
    AttackEffect <|-- ForceStunEffect
    AttackEffect <|-- GatherEffect
    HitBoxComponent ..> HurtBoxComponent : area_entered
    HurtBoxComponent ..> HealthComponent : damaged signal
    HitBoxComponent --> Damage : carries
    Damage *-- AttackEffect : effects array
```

---

## 5. 统一 AnimationTree BlendTree 结构

所有角色共用同一套 BlendTree 布局，区别仅在 locomotion 和 control_sm 内的具体动画：

```mermaid
graph LR
    subgraph BlendTree["AnimationNodeBlendTree (tree_root)"]
        LOCO["locomotion<br/>BlendSpace2D 或 StateMachine"]
        CTRL["control_sm<br/>StateMachine"]
        LTS["loco_timescale<br/>TimeScale"]
        CTS["ctrl_timescale<br/>TimeScale"]
        CB["control_blend<br/>Blend2"]
        OUT["output"]
        AO["attack_oneshot<br/>OneShot<br/>(仅 Enemy/Boss)"]
    end

    LOCO --> LTS
    CTRL --> CTS
    LTS -->|port 0| CB
    CTS -->|port 1| CB
    CB --> OUT
    AO -.->|叠加在 locomotion 上| LTS

    style CB fill:#f96,stroke:#333
    style OUT fill:#6f9,stroke:#333
```

### 关键参数表

| 参数路径 | 类型 | 说明 |
|---------|------|------|
| `parameters/control_blend/blend_amount` | float | **核心开关**：0.0=locomotion 层，1.0=control 层 |
| `parameters/locomotion/playback` | Playback | Player 用：travel("idle"/"run") |
| `parameters/locomotion/blend_position` | Vector2 | Enemy/Boss 用：(方向x, 速度比y) |
| `parameters/control_sm/playback` | Playback | start("hit"/"stunned"/"death"/攻击名) |
| `parameters/loco_timescale/scale` | float | locomotion 动画速度倍率 |
| `parameters/ctrl_timescale/scale` | float | control 动画速度倍率 |
| `parameters/attack_oneshot/request` | int | Enemy/Boss：FIRE=触发攻击，ABORT=中断 |

### 状态切换 API（BaseState 方法）

```gdscript
# 切到 locomotion 层
exit_control_state()           # blend_amount = 0.0

# 切到 control 层
enter_control_state("hit")     # blend_amount = 1.0, control_sm.start("hit")

# locomotion 内切换
set_locomotion_state("idle")   # Player: playback.travel("idle")
set_locomotion(Vector2(1, 0.8))# Enemy: blend_position = (1, 0.8)

# 攻击 OneShot（Enemy/Boss）
fire_attack()                  # attack_oneshot.request = FIRE
abort_attack()                 # attack_oneshot.request = ABORT

# 时间缩放
set_control_time_scale(2.0)    # 加速 control 动画
set_locomotion_time_scale(0.5) # 减慢 locomotion 动画
reset_time_scale()             # 全部重置为 1.0
```

### 两层动画的切换时机

```
正常行为循环:  blend_amount = 0.0 (locomotion 层活跃)
  Idle/Wander: set_locomotion(0, 0) 或 set_locomotion_state("idle")
  Chase/Run:   set_locomotion(dir.x, speed_ratio) 或 set_locomotion_state("run")
  Attack:      fire_attack() (OneShot 叠加，不改 blend_amount)

受击/控制:      blend_amount = 1.0 (control 层活跃)
  Hit:     enter_control_state("hit")
  Stun:    enter_control_state("stunned")
  Death:   enter_control_state("death")
  恢复:    exit_control_state() (blend_amount 回到 0.0)

Player 攻击:    blend_amount = 1.0 (control 层)
  atk_1/2/3: enter_control_state("atk_1") + set_control_time_scale(2.0)
  完成:      animation_finished 回调 exit_control_state()
```

---

## 6. Player 场景模板

### 场景树

```
PlayerBase (CharacterBody2D) [Layer=2, Mask=128]
+-- FloorCollision (CollisionShape2D)
+-- AnimatedSprite2D
+-- AnimationPlayer
+-- AnimationTree [active]
+-- HurtBoxComponent (Area2D) [Layer=2, Mask=0]
|   +-- CollisionShape2D
+-- HitBoxComponent (Area2D) [Layer=4, Mask=8]
|   +-- CollisionShape2D (默认 disabled)
+-- HealthComponent (Node)
+-- HealthBar (ProgressBar)
+-- DamageNumbersAnchor (Node2D)
+-- MovementComponent (Node)
+-- CombatComponent (Node)
+-- SkillManager (Node)
+-- AudioStreamPlayer
+-- PlayerStateMachine (Node) [init_state="Ground"]
    +-- Ground        (BEHAVIOR, can_interrupt=true)
    +-- Air           (BEHAVIOR, can_interrupt=true)
    +-- Combat        (REACTION, can_interrupt=false)
    +-- Roll          (REACTION, can_interrupt=false)
    +-- Hit           (CONTROL,  can_interrupt=false)
    +-- SpecialAttack (REACTION, can_interrupt=false)
    +-- FallDeath     (CONTROL,  can_interrupt=false)
```

### Player 状态流转图

```mermaid
stateDiagram-v2
    [*] --> Ground
    Ground --> Air : not on_floor
    Ground --> Combat : atk_1/2/3
    Ground --> Roll : roll input
    Ground --> SpecialAttack : atk_sp (V key)
    Air --> Ground : landed
    Air --> Combat : atk_air
    Air --> SpecialAttack : atk_sp
    Combat --> Ground : anim_finished + on_floor
    Combat --> Air : anim_finished + in_air
    Roll --> Ground : anim_finished
    SpecialAttack --> Ground : skill done

    Ground --> Hit : damaged
    Air --> Hit : damaged
    Combat --> Hit : damaged (CONTROL > REACTION)
    Hit --> Ground : timer end
```

### Player locomotion / control_sm 层

```
locomotion (StateMachine): idle, run
control_sm (StateMachine): atk_1, atk_2, atk_3, atk_air, atk_sp, j_up, j_down, roll, take_hit
```

### Pending Skill 模式

```gdscript
# Ground/Air 检测输入，写入 pending，切状态
owner_node.set_pending_skill("atk_1")
transitioned.emit(self, "combat")

# Combat.enter() 消费 pending，播动画
var skill = owner_node.consume_pending_skill()
enter_control_state(skill.skill_name)

# 动画完成，回到 Ground/Air
func _on_animation_finished(anim_name):
    return_to_locomotion()
```

### 五组件协作图

```mermaid
graph TB
    SM["PlayerStateMachine"]
    MC["MovementComponent<br/>输入/跳跃/加速/翻转"]
    CC["CombatComponent<br/>伤害类型切换"]
    SKM["SkillManager<br/>V键技能6阶段"]
    HC["HealthComponent<br/>生命值/受伤/死亡"]
    FC["FollowCamera<br/>跟随/zoom"]

    SM -->|"can_move=false"| MC
    SM -->|"enter combat"| CC
    SM -->|"trigger skill"| SKM
    HC -->|"damaged signal"| SM
    SKM -->|"camera control"| FC
```

---

## 7. Enemy 场景模板

### 场景树

```
EnemyBase (CharacterBody2D) [Layer=8, Mask=128]
+-- Sprite2D (或 AnimatedSprite2D)
+-- AnimationPlayer
+-- AnimationTree [active, 可通过 use_animation_tree 关闭]
+-- HurtBoxComponent (Area2D) [Layer=8, Mask=4]
|   +-- CollisionShape2D
+-- FloorCollision (CollisionShape2D)
+-- HealthComponent (Node)
+-- HealthBar (ProgressBar)
+-- DamageNumbersAnchor (Node2D)
+-- HitBoxComponent (Area2D) [Layer=8, Mask=2]
|   +-- CollisionShape2D
+-- AttackAnchor (Node2D)
+-- EnemyStateMachine (Node) [init_state="Idle"]
    +-- Idle      (BEHAVIOR)
    +-- Wander    (BEHAVIOR)
    +-- Chase     (BEHAVIOR)
    +-- Attack    (BEHAVIOR)
    +-- Hit       (REACTION)
    +-- Knockback (REACTION)
    +-- Stun      (CONTROL)
    +-- [SpecialSkill] (BEHAVIOR, optional)
```

### Enemy 状态流转图

```mermaid
stateDiagram-v2
    [*] --> Idle

    Idle --> Wander : timer timeout
    Wander --> Idle : timer timeout
    Idle --> Chase : player detected
    Wander --> Chase : player detected
    Chase --> Attack : distance leq attack_range
    Chase --> Wander : distance gt chase_radius
    Chase --> SpecialSkill : can_trigger
    Attack --> Chase : distance gt follow_radius
    Attack --> SpecialSkill : can_trigger
    SpecialSkill --> Chase : finish_skill

    Idle --> Hit : damaged (default)
    Chase --> Hit : damaged (default)
    Attack --> Hit : damaged (default)
    Idle --> Knockback : damaged + KnockBack
    Chase --> Knockback : damaged + KnockBack
    Idle --> Stun : damaged + Stun
    Chase --> Stun : damaged + Stun
    Hit --> Stun : damaged + Stun
    Knockback --> Stun : damaged + Stun

    Hit --> Chase : timer then decide
    Hit --> Wander : timer then decide
    Knockback --> Chase : velocity decay
    Knockback --> Wander : velocity decay
    Stun --> Chase : timer then decide
    Stun --> Wander : timer then decide
```

### Enemy locomotion 层 (BlendSpace2D)

```
BlendSpace2D 坐标点:
  (0, 0)     idle
  (-1, 0.5)  left_walk
  (1, 0.5)   right_walk
  (-1, 1.0)  left_run
  (1, 1.0)   right_run

用法:
  set_locomotion(Vector2(0, 0))        -> idle
  set_locomotion(Vector2(1, 0.5))      -> right_walk
  set_locomotion(Vector2(-1, 1.0))     -> left_run
  set_locomotion(Vector2(dir.x, clamp(speed/max_speed, 0, 1)))
```

### Enemy 关键状态生命周期

```gdscript
# Idle
enter(): stop_movement(), set_locomotion(0,0), start_timer(1~3s)
process_state(): try_attack() / try_chase()
timeout: -> Wander

# Chase
enter(): set_locomotion(1, 1)
physics: check SpecialSkill -> Attack (in range) -> Wander (out of range)
         move_toward_target + update blend_position

# Attack
enter(): stop_movement(), fire_attack() OneShot
physics: timer countdown -> perform_attack()
exit(): abort_attack()

# Hit (REACTION)
enter(): stop_movement(), enter_control_state("hit"), timer(0.2s)
timeout: decide_next_state() -> Chase/Wander
exit(): exit_control_state()

# Stun (CONTROL)
enter(): enter_control_state("stunned"), owner.stunned=true, timer(1.0s)
physics: friction decelerate if knockback velocity
timeout: decide_next_state(), owner.stunned=false
exit(): exit_control_state(), reset_time_scale()
```

---

## 8. Boss 场景模板

### 场景树

```
BossBase (CharacterBody2D) [Layer=8, Mask=128]
+-- Sprite2D
+-- CollisionShape2D (48x64)
+-- AnimationPlayer
+-- AnimationTree [active]
+-- HurtBoxComponent (Area2D) [Layer=8, Mask=4]
|   +-- CollisionShape2D (40x56)
+-- HealthComponent (Node) [max_health=1000]
+-- HealthBar (ProgressBar)
+-- DamageNumbersAnchor (Node2D)
+-- BossAttackManager (Node)            <-- Boss only
+-- BossStateMachine (Node) [init_state="Idle"]
    +-- Idle    (BossIdle)
    +-- Patrol  (BossPatrol)            <-- Boss only
    +-- Chase   (BossChase)
    +-- Circle  (BossCircle)            <-- Boss only
    +-- Attack  (BossAttack)
    +-- Retreat (BossRetreat)           <-- Boss only
    +-- Stun    (BossStun)
```

### Boss vs Enemy 差异表

| 维度 | Enemy | Boss |
|------|-------|------|
| 生命值 | 30~100 | 1000 |
| 状态 | 7 (Idle/Wander/Chase/Attack/Hit/Knockback/Stun) | 7 (Idle/Patrol/Chase/Circle/Attack/Retreat/Stun) |
| 攻击 | AttackState inline + OneShot | BossAttackManager + attack pools + Combo |
| 阶段 | None | 3 phases |
| 移动 | Direct pursuit | 8-dir + orbit + patrol |
| locomotion | BlendSpace2D | StateMachine (idle/walk) |

### Boss 战斗状态流转图

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Patrol : timer
    Patrol --> Chase : player detected

    Chase --> Attack : dist leq 300 and cooldown leq 0
    Chase --> Circle : dist leq 300 and cooldown gt 0
    Chase --> Retreat : dist lt 150

    Circle --> Attack : cooldown leq 0
    Circle --> Retreat : dist lt 150
    Circle --> Chase : dist gt 300

    Attack --> Chase : done and dist gt 300
    Attack --> Circle : done and mid range
    Attack --> Retreat : done and dist lt 150

    Retreat --> Chase : gained distance

    Chase --> Stun : damaged + Stun (Phase 1~2)
    Circle --> Stun : damaged + Stun (Phase 1~2)
    Stun --> Chase : timer then evaluate
    Stun --> Circle : timer then evaluate
```

### 三阶段系统

```mermaid
graph LR
    P1["Phase 1<br/>100%~67% HP<br/>speed 1.0x<br/>cooldown 1.5s<br/>timer mode"]
    P2["Phase 2<br/>67%~33% HP<br/>speed 1.3x<br/>cooldown 1.0s<br/>timer mode"]
    P3["Phase 3<br/>33%~0% HP<br/>speed 1.5x<br/>cooldown 0.5s<br/>chase mode<br/>stun immune"]

    P1 -->|"HP<=66%"| P2
    P2 -->|"HP<=33%"| P3

    style P1 fill:#6c6,stroke:#333
    style P2 fill:#cc6,stroke:#333
    style P3 fill:#c66,stroke:#333
```

Phase transition triggers: 1s invincibility + 200px knockback wave + VFX

### BossPhaseConfig (Resource)

```gdscript
@export var attacks: Array        # main attack pool
@export var chase_attacks: Array  # attacks while chasing
@export var retreat_attacks: Array # attacks while retreating
@export var cooldown: float       # attack cooldown
@export var attack_duration: float
@export_enum("timer", "chase") var behavior: String
@export var speed_multiplier: float
@export var immune: bool          # stun immunity
```

### BossAttackManager methods

```gdscript
fire_projectiles(count, spread_angle)    # fan spread
fire_spiral_projectiles(count, offset)   # 360 spiral
fire_rapid_projectiles(target, count, interval)  # rapid fire
fire_laser_at_player()                   # charge 2.5s + fire 1.5s
fire_aoe() / fire_aoe_at(position)      # expanding circle r=200
execute_combo(BossComboAttack)           # multi-step sequence
```

### Boss 距离判定图

```mermaid
graph LR
    A["dist gt 800<br/>Patrol"]
    B["300~800<br/>Chase"]
    C["150~300<br/>Attack/Circle"]
    D["dist lt 150<br/>Retreat"]

    A --- B --- C --- D

    style A fill:#eee,stroke:#333
    style B fill:#cef,stroke:#333
    style C fill:#fce,stroke:#333
    style D fill:#fcc,stroke:#333
```

---

## 9. 必需动画清单

### Enemy

| 动画名 | 用途 | 所属层 |
|--------|------|--------|
| idle | 静止 | locomotion (BlendSpace2D) |
| left_walk / right_walk | 走 | locomotion |
| left_run / right_run | 跑 | locomotion |
| attack | 攻击 | attack_oneshot |
| hit | 受击 | control_sm |
| stunned | 眩晕 | control_sm |
| death | 死亡 | control_sm |

### Player

| 动画名 | 用途 | 所属层 |
|--------|------|--------|
| idle, run | 静止/跑 | locomotion (StateMachine) |
| atk_1, atk_2, atk_3 | 地面连招 | control_sm |
| atk_air | 空中攻击 | control_sm |
| atk_sp | 特殊技能 | control_sm |
| j_up, j_down | 跳跃 | control_sm |
| roll | 翻滚 | control_sm |
| take_hit | 受击 | control_sm |

### Boss

| 动画名 | 用途 | 所属层 |
|--------|------|--------|
| idle, walk | 静止/走 | locomotion (StateMachine) |
| attack | 攻击 | control_sm |
| hit | 受击 | control_sm |
| stunned | 眩晕 | control_sm |
| death | 死亡 | control_sm |
| phase_transition | 阶段转换(optional) | control_sm |

---

## 10. 伤害系统完整数据流

```mermaid
sequenceDiagram
    participant P as Player
    participant HB as HitBoxComponent
    participant HU as HurtBoxComponent
    participant HC as HealthComponent
    participant AE as AttackEffect
    participant BC as BaseCharacter
    participant SM as StateMachine
    participant ST as CurrentState
    participant NS as NewState

    P->>HB: attack anim enables monitoring
    HB->>HU: area_entered
    HU->>HC: take_damage(damage, pos)
    HC->>HC: health -= damage.amount
    HC->>HC: display_damage_number()

    loop for each damage.effect
        HC->>AE: apply_effect(target, source_pos)
        Note over AE: KnockBack sets velocity<br/>Stun sets stunned<br/>KnockUp sets velocity.y
    end

    HC-->>HC: health_changed.emit(current, max)
    HC-->>BC: damaged.emit(damage, pos)
    BC-->>SM: damaged.emit(damage, pos)
    SM->>ST: on_damaged(damage, pos)

    alt has StunEffect
        ST->>SM: transitioned.emit(self, "stun")
    else has KnockBackEffect
        ST->>SM: transitioned.emit(self, "knockback")
    else default
        ST->>SM: transitioned.emit(self, "hit")
    end

    SM->>ST: exit()
    SM->>NS: enter()
    Note over NS: Hit: 0.2s stagger<br/>Knockback: friction decel<br/>Stun: 1.0s lock
```
