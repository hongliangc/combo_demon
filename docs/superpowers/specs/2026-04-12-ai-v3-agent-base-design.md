# AI 架构 v3 — AgentAIBase 统一基类 + 精简 Stock States

- **日期**: 2026-04-12
- **前置**: `2026-04-11-ai-controller-decision-separation-design.md`（v2），本 spec 是增量修正
- **范围**: 新建 `AgentAIBase.gd` 统一基类；Stock States 去 AnimationTree / 去 move_and_slide；`_setup_transitions` 数据驱动；补巡逻行为链；DemonSlime2 适配
- **设计目标**: 不兼容存量 BossBase/EnemyBase，不区分小兵和 Boss，所有 AI 角色统一继承 AgentAIBase
- **非目标**: 旧敌人迁移、StatusEffectComponent

---

## 1. 核心改动

### 1.1 新建 `AgentAIBase.gd`（替代 BossBase/EnemyBase 作为 AI 角色根脚本）

路径：`Core/AI/AgentAIBase.gd`

```gdscript
class_name AgentAIBase extends CharacterBody2D

## AI 角色统一基类
## 职责：gravity + move_and_slide + facing + AI 信号接线
## Boss 特化（phase/poise/evasion）由子类添加

@export var has_gravity: bool = false
@export var gravity: float = 800.0

@onready var ai: AIController = $AIController
@onready var health_comp: HealthComponent = $HealthComponent
@onready var anim_player: AnimationPlayer = $AnimationPlayer
var sprite: Node2D  # 子类在 _ready 里赋值（Sprite2D 或 AnimatedSprite2D）

func _ready() -> void:
    _auto_find_sprite()
    _setup_blackboard()
    _setup_transitions()
    _setup_signals()

func _physics_process(delta: float) -> void:
    if has_gravity:
        if not is_on_floor():
            velocity.y += gravity * delta
        elif velocity.y > 0:
            velocity.y = 0
    move_and_slide()
    _update_facing()

func _update_facing() -> void:
    if sprite and "flip_h" in sprite and abs(velocity.x) > 0.1:
        sprite.flip_h = velocity.x < 0

func _auto_find_sprite() -> void:
    sprite = get_node_or_null(^"AnimatedSprite2D")
    if not sprite:
        sprite = get_node_or_null(^"Sprite2D")

# ---- 子类重写 ----
func _setup_blackboard() -> void:
    var bb := ai.blackboard
    bb.bind_var(&"health", health_comp, &"health")
    bb.bind_var(&"max_health", health_comp, &"max_health")

func _setup_transitions() -> void:
    pass  # 子类实现

func _setup_signals() -> void:
    if health_comp:
        health_comp.damaged.connect(_on_agent_damaged)
        health_comp.died.connect(_on_agent_died)

func _on_agent_damaged(damage: Damage, attacker_pos: Vector2) -> void:
    var bb := ai.blackboard
    bb.set_var(&"last_damage", damage)
    bb.set_var(&"last_attacker_pos", attacker_pos)
    bb.set_var(&"recently_hit", true)
    ai.dispatch(AIEvents.EV_DAMAGED)

func _on_agent_died() -> void:
    ai.dispatch(AIEvents.EV_DIED)

# ---- 数据驱动转换表注册 ----
func _register_rules(rules: Array) -> void:
    for r in rules:
        var from: AIState = null if r[0] == "*" else ai.get_state(StringName(r[0]))
        var to: AIState = ai.get_state(StringName(r[1]))
        if r[0] != "*" and from == null:
            continue
        if to == null:
            continue
        var guard := Callable(self, r[3]) if r[3] != "" else Callable()
        ai.add_transition(from, to, StringName(r[2]), guard, r[4])
```

**关键约定**：
- States 只设 `velocity`，**绝不调 `move_and_slide()`**
- States 播动画通过 `owner_node.anim_player.play("xxx")`（AgentAIBase 暴露 `anim_player`）
- 子类通过 `super._setup_blackboard()` 继承基础 bind，再加自己的变量

### 1.2 Stock States 精简

所有 Stock States 遵循两条规则：
1. **不调 `move_and_slide()`** — 由 AgentAIBase 统一调
2. **不依赖 AnimationTree** — 直接 `owner_node.anim_player.play()`

#### IdleState.gd

```gdscript
extends AIState

func enter() -> void:
    if owner_node is CharacterBody2D:
        (owner_node as CharacterBody2D).velocity = Vector2.ZERO
    if "anim_player" in owner_node and owner_node.anim_player:
        owner_node.anim_player.play(&"idle")
```

#### ChaseState.gd

```gdscript
extends AIState

@export var default_speed: float = 80.0

func enter() -> void:
    if "anim_player" in owner_node and owner_node.anim_player:
        owner_node.anim_player.play(&"walk")

func physics_update(_delta: float) -> void:
    if owner_node is not CharacterBody2D:
        return
    var body := owner_node as CharacterBody2D
    var target_pos: Vector2 = bb.get_var(&"target_position", body.global_position) as Vector2
    var speed := float(bb.get_var(&"chase_speed", default_speed))
    var dir: Vector2 = (target_pos - body.global_position).normalized()
    body.velocity = dir * speed
    # 不调 move_and_slide — AgentAIBase 统一调

func exit() -> void:
    if owner_node is CharacterBody2D:
        (owner_node as CharacterBody2D).velocity = Vector2.ZERO
```

#### WanderState.gd

```gdscript
extends AIState

@export var default_speed: float = 50.0
@export var min_time: float = 2.0
@export var max_time: float = 5.0

var _direction: Vector2
var _timer: Timer

func enter() -> void:
    _direction = Vector2.RIGHT.rotated(randf_range(0, TAU))
    if "anim_player" in owner_node and owner_node.anim_player:
        owner_node.anim_player.play(&"walk")
    _ensure_timer()
    _timer.wait_time = randf_range(min_time, max_time)
    _timer.start()

func physics_update(_delta: float) -> void:
    if owner_node is not CharacterBody2D:
        return
    var speed := float(bb.get_var(&"wander_speed", default_speed))
    (owner_node as CharacterBody2D).velocity = _direction * speed

func exit() -> void:
    if _timer: _timer.stop()
    if owner_node is CharacterBody2D:
        (owner_node as CharacterBody2D).velocity = Vector2.ZERO

func _ensure_timer() -> void:
    if not _timer:
        _timer = Timer.new()
        _timer.one_shot = true
        _timer.timeout.connect(func(): dispatch(AIEvents.EV_ATTACK_FINISHED))
        add_child(_timer)
```

#### HitState.gd

```gdscript
extends AIState

@export var default_duration: float = 0.3

var _timer: Timer

func enter() -> void:
    if owner_node is CharacterBody2D:
        (owner_node as CharacterBody2D).velocity = Vector2.ZERO
    var damage: Damage = bb.get_var(&"last_damage")
    var attacker_pos: Vector2 = bb.get_var(&"last_attacker_pos", Vector2.ZERO) as Vector2
    if damage and not damage.effects.is_empty():
        for effect in damage.effects:
            if effect:
                effect.apply_effect(owner_node as CharacterBody2D, attacker_pos)
    if "anim_player" in owner_node and owner_node.anim_player:
        owner_node.anim_player.play(&"hit")
    _ensure_timer()
    _timer.wait_time = default_duration
    _timer.start()

func physics_update(delta: float) -> void:
    if owner_node is CharacterBody2D:
        var body := owner_node as CharacterBody2D
        body.velocity = body.velocity.lerp(Vector2.ZERO, 8.0 * delta)

func exit() -> void:
    if _timer: _timer.stop()
    bb.set_var(&"recently_hit", false)

func _ensure_timer() -> void:
    if not _timer:
        _timer = Timer.new()
        _timer.one_shot = true
        _timer.timeout.connect(func(): dispatch(AIEvents.EV_HIT_RECOVERED))
        add_child(_timer)
```

#### StunState.gd

```gdscript
extends AIState

@export var default_duration: float = 1.5

var _timer: Timer

func enter() -> void:
    if owner_node is CharacterBody2D:
        (owner_node as CharacterBody2D).velocity = Vector2.ZERO
    if "anim_player" in owner_node and owner_node.anim_player:
        owner_node.anim_player.play(&"stunned")
    _ensure_timer()
    _timer.wait_time = default_duration
    _timer.start()

func exit() -> void:
    if _timer: _timer.stop()

func _ensure_timer() -> void:
    if not _timer:
        _timer = Timer.new()
        _timer.one_shot = true
        _timer.timeout.connect(func(): dispatch(AIEvents.EV_STUN_RECOVERED))
        add_child(_timer)
```

#### DeathState.gd

```gdscript
extends AIState

func enter() -> void:
    if owner_node is CharacterBody2D:
        (owner_node as CharacterBody2D).velocity = Vector2.ZERO
    if "anim_player" in owner_node and owner_node.anim_player:
        owner_node.anim_player.play(&"death")
    if owner_node:
        owner_node.set_physics_process(false)
        var col: CollisionShape2D = owner_node.get_node_or_null(^"CollisionShape2D")
        if col:
            col.set_deferred(&"disabled", true)
```

### 1.3 _setup_transitions 数据驱动

子类只需要定义一个 rules 数组，调 `_register_rules(rules)` ：

```gdscript
# DemonSlime2._setup_transitions 示例
func _setup_transitions() -> void:
    var rules := [
        ["idle",    "wander", "",                          "",                  5],
        ["idle",    "chase",  "",                          "_guard_detected",   10],
        ["wander",  "chase",  "",                          "_guard_detected",   10],
        ["chase",   "idle",   "",                          "_guard_target_lost", 0],
        ["chase",   "slam",   "",                          "_guard_can_slam",   20],
        ["chase",   "cleave", "",                          "_guard_can_cleave", 10],
        ["cleave",  "chase",  AIEvents.EV_ATTACK_FINISHED, "",                  0],
        ["slam",    "chase",  AIEvents.EV_ATTACK_FINISHED, "",                  0],
        ["*",       "death",  AIEvents.EV_DIED,            "",                  100],
        ["*",       "hit",    AIEvents.EV_DAMAGED,         "",                  10],
        ["hit",     "chase",  AIEvents.EV_HIT_RECOVERED,   "_guard_target_alive", 10],
        ["hit",     "idle",   AIEvents.EV_HIT_RECOVERED,   "",                  0],
    ]
    _register_rules(rules)
```

**自动跳过不存在的状态**：如果 StateMachine 里没有 "wander" 节点，`ai.get_state("wander")` 返回 null，`_register_rules` 跳过该条 → 不报错、不需要 `if wander:` 判断。

### 1.4 完整行为链

```
idle ──(timer 超时)──→ wander ──(timer 超时)──→ idle (循环巡逻)
  ↓ (检测到玩家)           ↓ (检测到玩家)
chase ←─────────────────────┘
  ↓ (进入攻击范围 + cooldown ready)
cleave / slam
  ↓ (attack_finished)
chase
  ↓ (玩家跑出 abandon_distance 或死亡)
idle
```

反应层（ANYSTATE 事件式）：
- `damaged → hit`（priority=10）
- `died → death`（priority=100）
- Boss 子类可加：`damaged → counter`（priority=30）等

### 1.5 AgentAIBase.tscn 模板

```
AgentAIBase (CharacterBody2D, script=AgentAIBase.gd)
├── Sprite2D                     空 texture
├── AnimationPlayer              带 RESET 动画
├── CollisionShape2D
├── HurtBoxComponent (Area2D)
│   └── CollisionShape2D
├── HitBoxComponent (Area2D)
│   └── CollisionShape2D
├── HealthComponent
├── HealthBar (ProgressBar)
├── DamageNumbersAnchor (Node2D)
└── AIController
    └── StateMachine
        ├── Idle
        ├── Chase
        ├── Hit
        └── Death
```

**删除 AnimationTree 节点**。

### 1.6 DemonSlime2 适配

```gdscript
class_name DemonSlime2 extends AgentAIBase

# Boss 特化字段
@export var phase_2_hp_pct: float = 0.66
@export var phase_3_hp_pct: float = 0.33
var current_phase: int = 0

func _ready() -> void:
    sprite = $AnimatedSprite2D  # 覆盖基类的 auto_find
    super._ready()

func _setup_blackboard() -> void:
    super._setup_blackboard()
    var bb := ai.blackboard
    bb.bind_var(&"current_phase", self, &"current_phase")
    bb.set_var(&"detection_radius", 600.0)
    bb.set_var(&"attack_range", 250.0)
    bb.set_var(&"chase_speed", 80.0)
    # ...

func _setup_transitions() -> void:
    _register_rules([
        ["idle",    "chase",  "", "_guard_detected", 10],
        ["chase",   "idle",   "", "_guard_target_lost", 0],
        ["chase",   "slam",   "", "_guard_can_slam", 20],
        ["chase",   "cleave", "", "_guard_can_cleave", 10],
        ["cleave",  "chase",  AIEvents.EV_ATTACK_FINISHED, "", 0],
        ["slam",    "chase",  AIEvents.EV_ATTACK_FINISHED, "", 0],
        ["*",       "death",  AIEvents.EV_DIED, "", 100],
        ["*",       "hit",    AIEvents.EV_DAMAGED, "", 10],
        ["hit",     "chase",  AIEvents.EV_HIT_RECOVERED, "_guard_target_alive", 10],
        ["hit",     "idle",   AIEvents.EV_HIT_RECOVERED, "", 0],
    ])

# guard 方法...
```

DS2 攻击状态（DS2Cleave/DS2Slam）也改为 `owner_node.anim_player.play(&"cleave")`，不再操作 AnimationTree。

---

## 2. 删除清单（本次改动）

- ~~AgentAIBase.tscn 里的 AnimationTree 节点~~
- Stock States 里所有 `body.move_and_slide()` 调用
- Stock States 里所有 `AnimationTree` 相关代码（`parameters/control_blend`、`parameters/locomotion`、`control_sm/playback`）
- DemonSlime2.gd 不再 `extends BossBase`，改 `extends AgentAIBase`

## 3. 交付物

1. `Core/AI/AgentAIBase.gd`（新建）
2. `Core/AI/Stock/*.gd`（6 个，全部重写精简）
3. `Scenes/Characters/Templates/AgentAIBase.tscn`（删除 AnimationTree）
4. `Scenes/Characters/Bosses/DemonSlime2/DemonSlime2.gd`（改 extends + 数据驱动 rules）
5. `Scenes/Characters/Bosses/DemonSlime2/States/DS2Cleave.gd` / `DS2Slam.gd`（改用 anim_player）
6. 测试更新

## 4. 风险

1. **AnimationPlayer 没有对应动画名时** — `anim_player.play("stunned")` 会报 warning 但不崩溃。Stock State 可以加 `if anim_player.has_animation(name)` 保护。
2. **BossBase 的 phase/poise/evasion** — DemonSlime2 需要自己实现（从 BossBase 复制核心逻辑到 DS2 子类，约 50 行）。后续可以做成 mixin Resource 或 Component。
