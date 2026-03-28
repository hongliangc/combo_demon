# Boss 开发指南 (boss-guide.md)

## 1. 前置条件（需要了解哪些基类）

| 类 | 路径 | 说明 |
|---|---|---|
| `BaseCharacter` | `Core/Characters/BaseCharacter.gd` | 生命系统、damaged/died 信号 |
| `BossBase` | `Core/Characters/BossBase.gd` | 阶段系统(Phase 1-3)、巡逻点、冷却管理、`_on_boss_ready()` / `_on_phase_transition()` / `_update_facing()` 钩子 |
| `BossStateMachine` | `Scenes/Characters/Enemies/boss/Scripts/States/BossStateMachine.gd` | 7 个 Boss 状态、阶段切换时更新配置 |
| `BossAttackManager` | `Scenes/Characters/Enemies/boss/Scripts/BossAttackManager.gd` | 攻击方法集合（弹幕/激光/冲锋/combo） |
| `BossPhaseConfig` | `Scenes/Characters/Enemies/boss/Scripts/BossPhaseConfig.gd` | 每阶段的攻击池、冷却、行为模式 Resource |

现有 Boss 参考：`Scenes/Characters/Enemies/boss/`

---

## 2. 场景结构模板（节点树）

```
BossName.tscn
└── BossName  [CharacterBody2D]
    │   script: res://Scenes/Characters/Enemies/BossName/BossName.gd
    │   Layer: 4 (Enemy)  Mask: 1 (World) + 8 (Walls)
    ├── Sprite2D  或  AnimatedSprite2D
    │       (8方位时用 Sprite2D + region，单方向时用 AnimatedSprite2D)
    ├── CollisionShape2D
    ├── AnimationPlayer
    │       动画: idle / run / attack / hit / stun / death / phase_transition(可选)
    ├── AnimationTree
    │       (结构同 enemy-guide: locomotion + control_sm + control_blend)
    ├── HealthComponent
    │       max_health = 500
    ├── HurtBoxComponent  [Area2D]
    │   │   Layer: 4  Mask: 2 + 3
    │   └── CollisionShape2D
    ├── HitBoxComponent  [Area2D]  (近战判定，可选)
    │   │   Layer: 5  Mask: 2
    │   └── CollisionShape2D
    ├── DamageNumbersAnchor  [Node2D]
    ├── BossStateMachine
    │       (自定义 Boss 状态，不使用 EnemyStateMachine preset)
    └── BossAttackManager  (可选，若使用内置攻击方法)
```

---

## 3. 脚本模板（关键代码骨架）

```gdscript
extends BossBase
class_name BossName

# ============ 配置参数 ============
@export_group("Movement")
@export var move_speed := 100.0
@export var phase2_speed_mult := 1.3
@export var phase3_speed_mult := 1.5

@export_group("阶段配置")
@export var phase1_config: BossPhaseConfig
@export var phase2_config: BossPhaseConfig
@export var phase3_config: BossPhaseConfig

# ============ 节点引用 ============
var _attack_manager: BossAttackManager

func _on_boss_ready() -> void:
    ## BossBase 已完成: AnimationTree 激活, health_changed 连接
    _attack_manager = get_node_or_null("BossAttackManager")

    ## 通知状态机加载阶段配置
    var sm = get_node_or_null("BossStateMachine")
    if sm and sm.has_method("load_phase_config"):
        sm.load_phase_config(phase1_config)

func _on_phase_transition() -> void:
    ## BossBase 已完成: 1s 无敌 + knockback_nearby_units() + phase_changed 信号
    match current_phase:
        Phase.PHASE_2:
            move_speed *= phase2_speed_mult
            var sm = get_node_or_null("BossStateMachine")
            if sm and sm.has_method("load_phase_config"):
                sm.load_phase_config(phase2_config)
        Phase.PHASE_3:
            move_speed *= phase3_speed_mult
            var sm = get_node_or_null("BossStateMachine")
            if sm and sm.has_method("load_phase_config"):
                sm.load_phase_config(phase3_config)

func _update_facing() -> void:
    ## 根据 velocity 翻转精灵（单方向精灵）
    if sprite and velocity.x != 0:
        if sprite is Sprite2D:
            (sprite as Sprite2D).flip_h = velocity.x < 0
        elif sprite is AnimatedSprite2D:
            (sprite as AnimatedSprite2D).flip_h = velocity.x < 0
    ## 8方位精灵由 BossStateMachine 内部处理 region_rect 切换
```

---

## 4. 信号接入清单

| 信号 | 来源 | 连接目标 | 连接位置 |
|---|---|---|---|
| `HealthComponent.damaged` | HealthComponent | `BossStateMachine._on_owner_damaged()` | BaseStateMachine._ready() 自动 |
| `HealthComponent.died` | HealthComponent | `BossBase._handle_death()` | BaseCharacter._ready() 自动 |
| `HealthComponent.health_changed` | HealthComponent | `BossBase._on_health_changed()` → `check_phase_transition()` | BossBase._on_character_ready() 自动 |
| `BossBase.phase_changed(new_phase)` | BossBase | 外部 UI / LevelManager | 手动连接（Level 脚本中） |
| `BossBase.boss_defeated()` | BossBase | LevelManager 或 HUD | 手动连接（Level 脚本中） |

手动连接示例（Level3.gd）：
```gdscript
func _ready() -> void:
    var boss = $Boss
    boss.boss_defeated.connect(_on_boss_defeated)
    boss.phase_changed.connect(_on_boss_phase_changed)

func _on_boss_defeated() -> void:
    LevelManager.level_complete()

func _on_boss_phase_changed(phase: int) -> void:
    UIManager.show_phase_transition(phase)
```

---

## 5. Resource 配置

### BossPhaseConfig（每阶段一个 .tres）

```
res://Data/Boss/BossName/Phase1Config.tres
Class: BossPhaseConfig (Scenes/Characters/Enemies/boss/Scripts/BossPhaseConfig.gd)

attacks: [
    { "mode": "fan_spread", "count": 3, "spread": 0.4 },
    { "mode": "single", "count": 1, "spread": 0.0 },
]
chase_attacks: []          # 空 = 回退到 attacks
retreat_attacks: []        # 空 = 回退到 attacks
cooldown: 2.0
attack_duration: 1.2
behavior: "timer"          # "timer" 站桩开火 | "chase" 边追边打
speed_multiplier: 1.0
immune: false
```

三阶段各一份，Phase3 建议 `behavior: "chase"`, `immune: true`。

### 攻击 mode 速查表（BossAttackManager 支持）

| mode | 说明 | 额外字段 |
|---|---|---|
| `"fan_spread"` | 扇形弹幕 | `count`, `spread` |
| `"spiral"` | 螺旋弹幕 | `count`, `offset` |
| `"laser"` | 激光 | 无 |
| `"rapid"` | 快速连射 | `count`, `interval` |
| `"single"` | 单发 | 无 |

---

## 6. 验证要点

- [ ] **三阶段触发**：血量 67% → Phase 2，33% → Phase 3（各只触发一次）
- [ ] **阶段转换保护**：转换时 1s 无敌（`HealthComponent.is_invincible = true`），击退范围内单位被弹飞
- [ ] **攻击池切换**：每阶段加载对应 `BossPhaseConfig`，攻击模式和冷却正确变化
- [ ] **`boss_defeated` 信号**：死亡时发出，Level 脚本正确响应（过场/结算）
- [ ] **死亡动画**：AnimationTree control_sm 播放 death → `queue_free()`
- [ ] **物理层**：Layer 4, HurtBox Layer4/Mask2+3, HitBox Layer5/Mask2（与敌人相同）
- [ ] **`_update_facing()` 实现**：运动时精灵朝向正确
- [ ] **`patrol_points` 配置**（若使用巡逻）：在 Level 场景中通过脚本赋值 `Vector2` 数组
