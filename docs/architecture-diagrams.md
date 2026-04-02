# 架构图 — Combo Demon

> 四层架构、数据流时序、状态机流转、Boss 阶段系统的可视化图。

---

## 1. 四层架构图

```mermaid
graph TB
    subgraph Presentation["Presentation 层"]
        PTSCN["*.tscn 场景文件"]
        UI["Scenes/UI/"]
        Assets["Assets/ (Art, Sound)"]
    end

    subgraph Business["Business 层"]
        PlayerImpl["Player 实现<br/>Hahashin, Princess"]
        EnemyImpl["Enemy 实现<br/>Slime/Bear/Dragon/...14+"]
        BossImpl["Boss 实现<br/>BladeKeeper/Cyclops/DemonSlime"]
        LevelImpl["Level 脚本"]
    end

    subgraph Framework["Framework 层"]
        SM["StateMachine 框架<br/>BaseStateMachine + BaseState<br/>+ 7 CommonStates"]
        Comp["组件系统<br/>Health/HitBox/HurtBox<br/>Movement/Combat"]
        Res["Resource 系统<br/>Damage + AttackEffect<br/>EnemyData + CharacterData"]
        Chars["角色基类<br/>BaseCharacter<br/>EnemyBase / BossBase / PlayerBase"]
    end

    subgraph Services["Services 层 (Autoload)"]
        GM["GameManager"]
        LM["LevelManager"]
        UIM["UIManager"]
        DC["DebugConfig"]
        DM["DamageNumbers"]
        TM["TimeManager"]
        SndM["SoundManager"]
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

    style Presentation fill:#e8f5e9
    style Business fill:#e3f2fd
    style Framework fill:#fff3e0
    style Services fill:#fce4ec
```

---

## 2. 伤害链路时序图

```mermaid
sequenceDiagram
    participant P as Player Input
    participant PS as PlayerState
    participant HB as HitBoxComponent
    participant HU as HurtBoxComponent
    participant HC as HealthComponent
    participant AE as AttackEffect[]
    participant BC as BaseCharacter
    participant SM as StateMachine
    participant CS as CurrentState
    participant NS as NewState

    P->>PS: atk_1/2/3 input
    PS->>HB: 动画帧 enable monitoring
    HB->>HU: area_entered 碰撞检测
    HU->>HC: take_damage(damage, attacker_pos)

    HC->>HC: health -= damage.amount
    HC->>HC: display_damage_number()

    loop 遍历 damage.effects
        HC->>AE: apply_effect(target, source_pos)
        Note over AE: KnockBack → 设置 velocity<br/>Stun → 设置 stunned 标志<br/>KnockUp → 设置 velocity.y
    end

    HC-->>HC: health_changed.emit(current, max)
    HC-->>BC: damaged.emit(damage, pos)
    BC-->>SM: damaged.emit(damage, pos)
    SM->>CS: on_damaged(damage, pos)

    alt has StunEffect
        CS->>SM: transitioned.emit(self, "stun")
    else has KnockBackEffect
        CS->>SM: transitioned.emit(self, "knockback")
    else default
        CS->>SM: transitioned.emit(self, "hit")
    end

    SM->>CS: exit()
    SM->>NS: enter()
    Note over NS: Hit: 0.2s 硬直<br/>Knockback: 摩擦减速<br/>Stun: 1.0s 锁定
```

---

## 3. 状态机转换流程

### 3.1 Enemy 状态流转

```mermaid
stateDiagram-v2
    [*] --> Idle

    Idle --> Wander : timer timeout
    Wander --> Idle : timer timeout
    Idle --> Chase : 检测到玩家 (detection_radius)
    Wander --> Chase : 检测到玩家
    Chase --> Attack : 距离 ≤ follow_radius
    Chase --> Wander : 距离 > chase_radius
    Chase --> SpecialSkill : can_trigger()
    Attack --> Chase : 距离 > follow_radius
    Attack --> SpecialSkill : can_trigger()
    SpecialSkill --> Chase : finish_skill()

    state "REACTION 层" as reaction {
        Hit --> Chase : timer → decide_next_state
        Hit --> Wander : timer → decide_next_state
        Knockback --> Chase : velocity 衰减
        Knockback --> Wander : velocity 衰减
    }

    state "CONTROL 层" as control {
        Stun --> Chase : timer → decide_next_state
        Stun --> Wander : timer → decide_next_state
    }

    Idle --> Hit : damaged (default)
    Chase --> Hit : damaged (default)
    Attack --> Hit : damaged (default)
    Idle --> Knockback : damaged + KnockBack
    Chase --> Knockback : damaged + KnockBack
    Hit --> Stun : damaged + Stun
    Knockback --> Stun : damaged + Stun
    Idle --> Stun : damaged + Stun
    Chase --> Stun : damaged + Stun
```

### 3.2 Boss 战斗状态流转

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Patrol : timer
    Patrol --> Chase : 检测到玩家

    Chase --> Attack : dist ≤ 300 且 cooldown ≤ 0
    Chase --> Circle : dist ≤ 300 且 cooldown > 0
    Chase --> Retreat : dist < 150

    Circle --> Attack : cooldown ≤ 0
    Circle --> Retreat : dist < 150
    Circle --> Chase : dist > 300

    Attack --> Chase : 完成且 dist > 300
    Attack --> Circle : 完成且中距离
    Attack --> Retreat : 完成且 dist < 150

    Retreat --> Chase : 拉开距离

    Chase --> Stun : damaged + Stun (Phase 1~2)
    Circle --> Stun : damaged + Stun (Phase 1~2)
    Stun --> Chase : timer → evaluate
```

### 3.3 Player 状态流转

```mermaid
stateDiagram-v2
    [*] --> Ground
    Ground --> Air : 不在地面
    Ground --> Combat : atk_1/2/3
    Ground --> Roll : roll 输入
    Ground --> SpecialAttack : atk_sp (V)
    Air --> Ground : 落地
    Air --> Combat : 空中攻击
    Air --> SpecialAttack : atk_sp
    Combat --> Ground : anim_finished + 在地面
    Combat --> Air : anim_finished + 在空中
    Roll --> Ground : anim_finished
    SpecialAttack --> Ground : 技能完成

    Ground --> Hit : damaged
    Air --> Hit : damaged
    Combat --> Hit : damaged (CONTROL > REACTION)
    Hit --> Ground : timer 结束
```

---

## 4. Boss 三阶段系统

```mermaid
graph LR
    P1["Phase 1<br/>100%~67% HP<br/>speed 1.0x<br/>cooldown 1.5s<br/>timer mode"]
    P2["Phase 2<br/>67%~33% HP<br/>speed 1.3x<br/>cooldown 1.0s<br/>timer mode"]
    P3["Phase 3<br/>33%~0% HP<br/>speed 1.5x<br/>cooldown 0.5s<br/>chase mode<br/>stun immune"]

    P1 -->|"HP ≤ 66%<br/>1s 无敌 + 击退波"| P2
    P2 -->|"HP ≤ 33%<br/>1s 无敌 + 击退波"| P3

    style P1 fill:#6c6,stroke:#333,color:#000
    style P2 fill:#cc6,stroke:#333,color:#000
    style P3 fill:#c66,stroke:#333,color:#fff
```

### Boss 距离判定区间

```mermaid
graph LR
    A["dist > 800<br/>Patrol"]
    B["300~800<br/>Chase"]
    C["150~300<br/>Attack/Circle"]
    D["dist < 150<br/>Retreat"]

    A --- B --- C --- D

    style A fill:#eee,stroke:#333
    style B fill:#cef,stroke:#333
    style C fill:#fce,stroke:#333
    style D fill:#fcc,stroke:#333
```

---

## 5. AnimationTree BlendTree 结构

```mermaid
graph LR
    subgraph BlendTree["AnimationNodeBlendTree"]
        LOCO["locomotion<br/>(BlendSpace2D 或 StateMachine)"]
        CTRL["control_sm<br/>(StateMachine)"]
        LTS["loco_timescale<br/>(TimeScale)"]
        CTS["ctrl_timescale<br/>(TimeScale)"]
        CB["control_blend<br/>(Blend2)"]
        OUT["output"]
        AO["attack_oneshot<br/>(OneShot, Enemy/Boss)"]
    end

    LOCO --> LTS
    CTRL --> CTS
    LTS -->|"port 0"| CB
    CTS -->|"port 1"| CB
    CB --> OUT
    AO -.->|"叠加在 locomotion"| LTS

    style CB fill:#f96,stroke:#333
    style OUT fill:#6f9,stroke:#333
```

**核心参数:**

| 参数 | 用途 |
|------|------|
| `parameters/control_blend/blend_amount` | **核心开关**: 0.0=locomotion, 1.0=control |
| `parameters/locomotion/blend_position` | Enemy/Boss: (方向x, 速度比y) |
| `parameters/control_sm/playback` | start("hit"/"stunned"/"death") |
| `parameters/attack_oneshot/request` | FIRE=触发, ABORT=中断 |

---

## 6. 组件通信信号图

```mermaid
graph TB
    HB["HitBoxComponent<br/>(Area2D)"]
    HU["HurtBoxComponent<br/>(Area2D)"]
    HC["HealthComponent"]
    BC["BaseCharacter"]
    SM["StateMachine"]
    UI["HealthBar UI"]
    DN["DamageNumbers<br/>(Autoload)"]
    AE["AttackEffect[]"]

    HB -->|"area_entered"| HU
    HU -->|"damaged signal"| HC
    HC -->|"apply_effects"| AE
    HC -->|"health_changed"| UI
    HC -->|"display_damage_number"| DN
    HC -->|"damaged signal"| BC
    BC -->|"damaged signal"| SM
    SM -->|"on_damaged()"| SM

    style HC fill:#f96
    style SM fill:#69f
```
