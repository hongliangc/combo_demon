# 类图 — Combo Demon

> 所有图使用 mermaid 格式。详细 API → `project-architecture` skill 的 `references/module-registry.md`

---

## 1. 角色继承体系

```mermaid
classDiagram
    class CharacterBody2D {
        +velocity: Vector2
        +move_and_slide()
    }

    class BaseCharacter {
        +health_component: HealthComponent
        +hurt_box: HurtBoxComponent
        +alive: bool
        +damaged signal
        +_on_character_ready()
        +_handle_death()
    }

    class PlayerBase {
        +movement_component: MovementComponent
        +combat_component: CombatComponent
        +skill_manager: SkillManager
        +set_pending_skill(name)
        +consume_pending_skill() Dictionary
    }

    class EnemyBase {
        +detection_radius: float
        +chase_radius: float
        +follow_radius: float
        +chase_speed: int
        +wander_speed: float
        +stunned: bool
        +enemy_data: EnemyData
        +_apply_enemy_data()
        +_update_sprite_facing()
    }

    class BossBase {
        +current_phase: Phase
        +phase_2_health_percent: float
        +phase_3_health_percent: float
        +attack_range: float
        +check_phase_transition()
        +change_phase(phase)
        +phase_changed signal
        +boss_defeated signal
    }

    CharacterBody2D <|-- BaseCharacter
    BaseCharacter <|-- PlayerBase
    BaseCharacter <|-- EnemyBase
    EnemyBase <|-- BossBase

    PlayerBase <|-- Hahashin
    PlayerBase <|-- Princess

    EnemyBase <|-- Slime
    EnemyBase <|-- Bear
    EnemyBase <|-- BlueBat
    EnemyBase <|-- Dragon
    EnemyBase <|-- Skull
    EnemyBase <|-- ForestBee
    EnemyBase <|-- ForestBoar
    EnemyBase <|-- ForestSnail

    BossBase <|-- BladeKeeper
    BossBase <|-- Cyclops
    BossBase <|-- DemonSlime
```

---

## 2. 状态机继承体系

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
        +force_transition(name)
        +recover_from_stun()
    }

    class EnemyStateMachine {
        +preset: Preset
        +force_stun(duration)
        +is_controlled() bool
        +can_act() bool
    }

    class BossStateMachine {
        +attack_manager: BossAttackManager
        +boss: BossBase
    }

    BaseStateMachine <|-- EnemyStateMachine
    BaseStateMachine <|-- BossStateMachine
    BaseStateMachine <|-- PlayerStateMachine

    BaseState <|-- IdleState
    BaseState <|-- WanderState
    BaseState <|-- ChaseState
    BaseState <|-- AttackState
    BaseState <|-- HitState
    BaseState <|-- KnockbackState
    BaseState <|-- StunState
    BaseState <|-- SpecialSkillState
    BaseState <|-- BossBaseState
    BossBaseState <|-- BossIdleState
    BossBaseState <|-- BossStunState

    BaseStateMachine o-- BaseState : manages
```

### 优先级层次

```
CONTROL  (2)  — StunState, FallDeath     (不可被打断)
REACTION (1)  — HitState, KnockbackState (可被 CONTROL 打断)
BEHAVIOR (0)  — Idle, Wander, Chase, Attack (可被任何高优先级打断)
```

---

## 3. 组件系统

```mermaid
classDiagram
    class HealthComponent {
        +health: float
        +max_health: float
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
        +update_attack()
        +get_attacker_position() Vector2
    }

    class HurtBoxComponent {
        +take_damage(damage, pos)
        +damaged signal
    }

    class MovementComponent {
        +can_move: bool
        +max_speed: float
        +perform_jump()
        +apply_dash_speed(speed)
        +direction_changed signal
        +velocity_changed signal
        +sprite_flipped signal
    }

    class CombatComponent {
        +damage_types: Array~Damage~
        +switch_to_physical()
        +switch_to_knockup()
        +switch_to_special_attack()
        +damage_type_changed signal
    }

    class SkillManager {
        +cooldowns: Dictionary
        +trigger_skill(name)
        +is_on_cooldown(name) bool
    }

    HitBoxComponent ..> HurtBoxComponent : area_entered
    HurtBoxComponent ..> HealthComponent : damaged signal
    HitBoxComponent --> Damage : carries
```

---

## 4. 伤害与效果 Resource 体系

```mermaid
classDiagram
    class Resource {
        <<Godot>>
    }

    class Damage {
        +amount: float
        +min_amount: float
        +max_amount: float
        +effects: Array~AttackEffect~
        +apply_effects(enemy, pos)
        +has_effect(type) bool
        +randomize_damage()
    }

    class AttackEffect {
        +effect_name: String
        +duration: float
        +apply_effect(target, pos)
        +get_description() String
    }

    class KnockBackEffect {
        +knockback_force: float
        +apply_effect()
    }

    class KnockUpEffect {
        +knockup_force: float
        +apply_effect()
    }

    class StunEffect {
        +stun_duration: float
        +apply_effect()
    }

    class ForceStunEffect {
        +apply_effect()
    }

    class GatherEffect {
        +gather_speed: float
        +apply_effect()
    }

    class EnemyData {
        +health: float
        +wander_speed: float
        +chase_speed: float
        +detection_radius: float
    }

    class CharacterData {
        +id: String
        +display_name: String
        +base_health: float
        +scene_path: String
        +instantiate_character()
    }

    Resource <|-- Damage
    Resource <|-- AttackEffect
    Resource <|-- EnemyData
    Resource <|-- CharacterData

    AttackEffect <|-- KnockBackEffect
    AttackEffect <|-- KnockUpEffect
    AttackEffect <|-- StunEffect
    AttackEffect <|-- ForceStunEffect
    AttackEffect <|-- GatherEffect

    Damage *-- AttackEffect : effects array
```

---

## 5. Autoload 服务依赖

```mermaid
graph TB
    GM["GameManager<br/>游戏状态机<br/>MENU→SELECT→PLAYING→PAUSED→OVER"]
    LM["LevelManager<br/>关卡加载/进度/目标"]
    UIM["UIManager<br/>UI层管理/场景切换/Toast"]
    SM["SoundManager<br/>音频播放"]
    DC["DebugConfig<br/>结构化日志<br/>4级别×4通道"]
    DM["DamageNumbers<br/>浮动伤害数字"]
    TM["TimeManager<br/>时间控制/慢放"]

    GM -->|"start_game()"| LM
    GM -->|"scene切换"| UIM
    LM -->|"level UI"| UIM
    LM -->|"boss_defeated"| GM
    DM -.->|"被 HealthComponent 调用"| DM
    DC -.->|"被全局调用"| DC

    style GM fill:#f96
    style LM fill:#69f
    style UIM fill:#6c6
    style DC fill:#cc6
```
