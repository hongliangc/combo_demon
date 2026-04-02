# Boss 系统重构 + BladeKeeper & DemonSlime 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重构 Boss 基础设施为通用基类，迁移 Cyclops，新建 BladeKeeper 和 DemonSlime 两个 Boss。

**Architecture:** 提取 BossStateMachine/BossAttackManager 通用基类到 Shared/，Cyclops 迁移到 Bosses/Cyclops/，两个新 Boss 基于 AnimationTree BlendTree 模板实现。

**Spec:** `docs/superpowers/specs/2026-03-28-boss-redesign.md`

---

## Phase 1: 基类重构（Shared/）

### Task 1: 创建目录结构 + 迁移 BossPhaseConfig & BossComboAttack

**Files:**
- Create: `Scenes/Characters/Bosses/Shared/` 目录
- Move: `Scenes/Characters/Enemies/boss/Scripts/BossPhaseConfig.gd` → `Scenes/Characters/Bosses/Shared/BossPhaseConfig.gd`
- Move: `Scenes/Characters/Enemies/boss/Scripts/BossComboAttack.gd` → `Scenes/Characters/Bosses/Shared/BossComboAttack.gd`
- Modify: `Scenes/Characters/Bosses/Shared/BossPhaseConfig.gd` — 扩展加权选择

- [ ] **Step 1:** 创建目录结构

```bash
mkdir -p "Scenes/Characters/Bosses/Shared"
mkdir -p "Scenes/Characters/Bosses/Cyclops/States"
mkdir -p "Scenes/Characters/Bosses/Cyclops/Attacks"
mkdir -p "Scenes/Characters/Bosses/BladeKeeper/States"
mkdir -p "Scenes/Characters/Bosses/BladeKeeper/Attacks"
mkdir -p "Scenes/Characters/Bosses/DemonSlime/States"
mkdir -p "Scenes/Characters/Bosses/DemonSlime/Attacks"
```

- [ ] **Step 2:** 移动 BossPhaseConfig.gd 和 BossComboAttack.gd 到 Shared/

```bash
git mv "Scenes/Characters/Enemies/boss/Scripts/BossPhaseConfig.gd" "Scenes/Characters/Bosses/Shared/BossPhaseConfig.gd"
git mv "Scenes/Characters/Enemies/boss/Scripts/BossComboAttack.gd" "Scenes/Characters/Bosses/Shared/BossComboAttack.gd"
```

- [ ] **Step 3:** 扩展 BossPhaseConfig 支持加权选择

在 `Shared/BossPhaseConfig.gd` 的 `pick_attack()` 方法中，检测 `weight` 字段：有则加权随机，无则 `pick_random()`（向后兼容 Cyclops）。同理更新 `pick_chase_attack()` 和 `pick_retreat_attack()`。

```gdscript
## 从攻击池加权随机选取（兼容无 weight 的旧格式）
func _pick_from_pool(pool: Array) -> Dictionary:
    if pool.is_empty():
        return {}
    # 检查是否有 weight 字段
    if pool[0].has("weight"):
        return _weighted_pick(pool)
    return pool.pick_random()

func _weighted_pick(pool: Array) -> Dictionary:
    var total_weight := 0
    for entry in pool:
        total_weight += entry.get("weight", 1)
    var roll := randi() % total_weight
    var cumulative := 0
    for entry in pool:
        cumulative += entry.get("weight", 1)
        if roll < cumulative:
            return entry
    return pool.back()

func pick_attack() -> Dictionary:
    return _pick_from_pool(attacks)

func pick_chase_attack() -> Dictionary:
    var pool := chase_attacks if not chase_attacks.is_empty() else attacks
    return _pick_from_pool(pool)

func pick_retreat_attack() -> Dictionary:
    var pool := retreat_attacks if not retreat_attacks.is_empty() else attacks
    return _pick_from_pool(pool)
```

- [ ] **Step 4:** Commit

```bash
git add Scenes/Characters/Bosses/
git commit -m "refactor: create Bosses/ directory, move BossPhaseConfig with weighted selection"
```

### Task 2: 重构 BossStateMachine 通用基类

**Files:**
- Move: `Scenes/Characters/Enemies/boss/Scripts/States/BossStateMachine.gd` → `Scenes/Characters/Bosses/Shared/BossStateMachine.gd`
- Create: `Scenes/Characters/Bosses/Cyclops/CyclopsStateMachine.gd`

- [ ] **Step 1:** 重写 `Shared/BossStateMachine.gd` 为通用基类

```gdscript
extends BaseStateMachine
class_name BossStateMachine

## 通用 Boss 状态机基类
## 提供阶段转换保护，子类只需实现 _get_phase_route()

var is_transitioning_phase := false

@export var phase_transition_duration := 0.3  ## 阶段转换保护时长

func _setup_signals() -> void:
    super._setup_signals()
    if owner_node and owner_node.has_signal("phase_changed"):
        if not owner_node.is_connected("phase_changed", _on_phase_changed):
            owner_node.phase_changed.connect(_on_phase_changed)

func _on_owner_damaged(damage: Damage, attacker_position: Vector2 = Vector2.ZERO) -> void:
    if is_transitioning_phase:
        return
    super._on_owner_damaged(damage, attacker_position)

func _on_phase_changed(new_phase: int) -> void:
    is_transitioning_phase = true

    var target_state := _get_phase_route(new_phase)
    if target_state != "" and states.has(target_state):
        force_transition(target_state)

    await get_tree().create_timer(phase_transition_duration).timeout
    is_transitioning_phase = false

## 子类钩子：返回阶段切换时的目标状态名，空字符串表示不强制切换
func _get_phase_route(_new_phase: int) -> String:
    return ""
```

- [ ] **Step 2:** 创建 CyclopsStateMachine.gd 继承通用基类

```gdscript
extends BossStateMachine

## Cyclops Boss 状态机 — 阶段路由逻辑

func _get_phase_route(new_phase: int) -> String:
    if not owner_node is BossBase or not target_node:
        return ""

    var boss := owner_node as BossBase

    match new_phase:
        BossBase.Phase.PHASE_2:
            if target_node and "alive" in target_node and target_node.alive:
                var distance := boss.global_position.distance_to(target_node.global_position)
                if distance <= boss.attack_range:
                    return "circle" if states.has("circle") else "attack"
                return "chase"
        BossBase.Phase.PHASE_3:
            return "attack"
    return ""
```

- [ ] **Step 3:** Commit

```bash
git add Scenes/Characters/Bosses/Shared/BossStateMachine.gd
git add Scenes/Characters/Bosses/Cyclops/CyclopsStateMachine.gd
git commit -m "refactor: extract BossStateMachine base class, create CyclopsStateMachine"
```

### Task 3: 重构 BossAttackManager 通用基类

**Files:**
- Modify: `Scenes/Characters/Enemies/boss/Scripts/BossAttackManager.gd` → 分离为基类 + Cyclops 子类
- Create: `Scenes/Characters/Bosses/Shared/BossAttackManager.gd`（通用基类）
- Create: `Scenes/Characters/Bosses/Cyclops/CyclopsAttackManager.gd`

- [ ] **Step 1:** 创建通用 BossAttackManager 基类

`Scenes/Characters/Bosses/Shared/BossAttackManager.gd`:

```gdscript
extends Node
class_name BossAttackManager

## Boss 攻击管理器通用基类
## 提供攻击池选择、冷却管理、玩家缓存
## 子类实现 _execute_attack() 执行具体攻击

@export var phase_configs: Dictionary = {}  ## Phase枚举 → BossPhaseConfig

var _boss_cache: BossBase
var _cached_player: Node2D

func _get_boss() -> BossBase:
    if not is_instance_valid(_boss_cache):
        _boss_cache = get_owner() as BossBase
    return _boss_cache

func get_player() -> Node2D:
    if is_instance_valid(_cached_player):
        return _cached_player
    _cached_player = get_tree().get_first_node_in_group("player") as Node2D
    return _cached_player

## 获取当前阶段配置
func get_current_config() -> BossPhaseConfig:
    var boss := _get_boss()
    if not boss:
        return null
    return phase_configs.get(boss.current_phase)

## 获取当前阶段冷却
func get_cooldown() -> float:
    var config := get_current_config()
    return config.cooldown if config else 1.5

## 从当前阶段攻击池加权选取
func pick_attack() -> Dictionary:
    var config := get_current_config()
    if not config:
        return {}
    return config.pick_attack()

## 执行攻击入口（调用子类钩子）
func execute_attack(entry: Dictionary, target_pos: Vector2) -> void:
    _execute_attack(entry, target_pos)

## 子类钩子：执行具体攻击
func _execute_attack(_entry: Dictionary, _target_pos: Vector2) -> void:
    push_warning("[BossAttackManager] _execute_attack() not implemented")
```

- [ ] **Step 2:** 创建 CyclopsAttackManager 继承基类

将原 `BossAttackManager.gd` 的具体攻击方法（fire_projectiles, fire_laser, fire_aoe, execute_combo 等）移到 `CyclopsAttackManager.gd`，保持所有原有功能。

`Scenes/Characters/Bosses/Cyclops/CyclopsAttackManager.gd`:

```gdscript
extends BossAttackManager
class_name CyclopsAttackManager

## Cyclops Boss 攻击管理器 — 弹幕/激光/AOE/连击

@export var projectile_scene: PackedScene
@export var laser_scene: PackedScene
@export var aoe_scene: PackedScene

@export_group("Damage Configs")
@export var projectile_damage: Damage
@export var laser_damage: Damage
@export var aoe_damage: Damage

func _execute_attack(entry: Dictionary, _target_pos: Vector2) -> void:
    var mode: String = entry.get("mode", "")
    var player := get_player()
    match mode:
        "fan_spread":
            fire_projectiles(entry.get("count", 3), entry.get("spread", PI / 6))
        "spiral":
            fire_spiral_projectiles(entry.get("count", 12))
        "laser":
            if player:
                fire_laser_at_player()
        "aoe":
            fire_aoe()
        "rapid_fire":
            if player:
                fire_rapid_projectiles(player, entry.get("count", 3))
        "combo":
            _execute_combo_entry(entry)

# ... 保留原有所有 fire_* 方法不变 ...
```

注意：将原 `BossAttackManager.gd` 的所有 `fire_projectiles`, `fire_single_projectile`, `fire_spiral_projectiles`, `spawn_projectile`, `fire_laser`, `fire_laser_at_player`, `fire_aoe`, `fire_aoe_at`, `fire_knockback_wave`, `apply_knockback_to_player`, `fire_rapid_projectiles`, `execute_combo`, `_execute_combo_step` 方法全部搬到 CyclopsAttackManager。基类的 `get_player()` 已提供，删除 CyclopsAttackManager 中的重复定义。`boss` 引用改为调用 `_get_boss()`。

- [ ] **Step 3:** Commit

```bash
git add Scenes/Characters/Bosses/Shared/BossAttackManager.gd
git add Scenes/Characters/Bosses/Cyclops/CyclopsAttackManager.gd
git commit -m "refactor: extract BossAttackManager base class, create CyclopsAttackManager"
```

### Task 4: 迁移 BossBaseState 到 Shared/

**Files:**
- Move: `Scenes/Characters/Enemies/boss/Scripts/States/BossBaseState.gd` → `Scenes/Characters/Bosses/Shared/BossBaseState.gd`

- [ ] **Step 1:** 移动文件并更新

```bash
git mv "Scenes/Characters/Enemies/boss/Scripts/States/BossBaseState.gd" "Scenes/Characters/Bosses/Shared/BossBaseState.gd"
```

更新 BossBaseState 中的引用：
- `_boss_cache` 类型从 `Boss` 改为 `BossBase`（通用化）
- `_boss` 属性检查 `owner_node is BossBase`
- `_dispatch_attack()` 改为调用 `attack_manager.execute_attack(entry, target_pos)` 而非直接 match
- `_resolve_combo_factory()` 保留（Cyclops 专用工厂移到 Cyclops 目录，基类保留通用分发逻辑）

关键改动：
```gdscript
# 旧：硬编码 Boss 类型
var _boss_cache: Boss
var _boss: Boss:
    get:
        if not _boss_cache and owner_node is Boss:
            _boss_cache = owner_node as Boss
        return _boss_cache

# 新：通用 BossBase 类型
var _boss_cache: BossBase
var _boss: BossBase:
    get:
        if not is_instance_valid(_boss_cache) and owner_node is BossBase:
            _boss_cache = owner_node as BossBase
        return _boss_cache
```

`_dispatch_attack()` 简化为：
```gdscript
func _dispatch_attack(attack_manager: BossAttackManager, entry: Dictionary) -> void:
    var target_pos := target_node.global_position if target_node else Vector2.ZERO
    attack_manager.execute_attack(entry, target_pos)
```

- [ ] **Step 2:** Commit

```bash
git add Scenes/Characters/Bosses/Shared/BossBaseState.gd
git commit -m "refactor: move BossBaseState to Shared/, generalize to BossBase type"
```

---

## Phase 2: Cyclops 迁移

### Task 5: 迁移 Cyclops 场景和脚本

**Files:**
- Move: `Scenes/Characters/Enemies/boss/Boss.gd` → `Scenes/Characters/Bosses/Cyclops/Cyclops.gd`
- Move: `Scenes/Characters/Enemies/boss/Boss.tscn` → `Scenes/Characters/Bosses/Cyclops/Cyclops.tscn`
- Move: `Scenes/Characters/Enemies/boss/Scripts/States/Boss*.gd` (7 states) → `Scenes/Characters/Bosses/Cyclops/States/`
- Move: `Scenes/Characters/Enemies/boss/Attacks/` → `Scenes/Characters/Bosses/Cyclops/Attacks/`
- Modify: `Scenes/Levels/Level3_Boss/Level3.gd` 和 `Level3.tscn` — 更新路径

- [ ] **Step 1:** 移动 Boss.gd，重命名 class_name Boss → Cyclops

```bash
git mv "Scenes/Characters/Enemies/boss/Boss.gd" "Scenes/Characters/Bosses/Cyclops/Cyclops.gd"
```

修改 `Cyclops.gd`：`class_name Boss` → `class_name Cyclops`，其余逻辑不变。

- [ ] **Step 2:** 移动 7 个状态文件到 Cyclops/States/

```bash
git mv "Scenes/Characters/Enemies/boss/Scripts/States/BossAttack.gd" "Scenes/Characters/Bosses/Cyclops/States/CyclopsAttack.gd"
git mv "Scenes/Characters/Enemies/boss/Scripts/States/BossChase.gd" "Scenes/Characters/Bosses/Cyclops/States/CyclopsChase.gd"
git mv "Scenes/Characters/Enemies/boss/Scripts/States/BossCircle.gd" "Scenes/Characters/Bosses/Cyclops/States/CyclopsCircle.gd"
git mv "Scenes/Characters/Enemies/boss/Scripts/States/BossIdle.gd" "Scenes/Characters/Bosses/Cyclops/States/CyclopsIdle.gd"
git mv "Scenes/Characters/Enemies/boss/Scripts/States/BossPatrol.gd" "Scenes/Characters/Bosses/Cyclops/States/CyclopsPatrol.gd"
git mv "Scenes/Characters/Enemies/boss/Scripts/States/BossRetreat.gd" "Scenes/Characters/Bosses/Cyclops/States/CyclopsRetreat.gd"
git mv "Scenes/Characters/Enemies/boss/Scripts/States/BossStun.gd" "Scenes/Characters/Bosses/Cyclops/States/CyclopsStun.gd"
```

每个文件：更新 class_name（BossAttack → CyclopsAttack 等），继承保持 `extends BossState`。

- [ ] **Step 3:** 移动攻击场景和 Boss.tscn

```bash
git mv "Scenes/Characters/Enemies/boss/Attacks/" "Scenes/Characters/Bosses/Cyclops/Attacks/"
git mv "Scenes/Characters/Enemies/boss/Boss.tscn" "Scenes/Characters/Bosses/Cyclops/Cyclops.tscn"
```

更新 Cyclops.tscn 中所有脚本路径引用（script = ExtResource 指向新路径）。

- [ ] **Step 4:** 更新 Level3 引用

`Scenes/Levels/Level3_Boss/Level3.gd` 和 `Level3.tscn` 中 Boss 场景路径更新：
`res://Scenes/Characters/Enemies/boss/Boss.tscn` → `res://Scenes/Characters/Bosses/Cyclops/Cyclops.tscn`

- [ ] **Step 5:** 更新所有代码中对 `Boss` class_name 的引用为 `Cyclops`

搜索全项目 `Boss` 类型引用（BossBaseState 中的 `_boss_cache: Boss` 已在 Task 4 改为 `BossBase`），更新剩余引用。

- [ ] **Step 6:** 删除旧目录残余

```bash
rm -rf "Scenes/Characters/Enemies/boss/"
```

- [ ] **Step 7:** Commit

```bash
git add -A
git commit -m "refactor: migrate Cyclops boss to Bosses/Cyclops/, rename class Boss→Cyclops"
```

---

## Phase 3: BladeKeeper Boss

### Task 6: BladeKeeper.gd 主类

**Files:**
- Create: `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd`

- [ ] **Step 1:** 创建 BladeKeeper 主类

```gdscript
extends BossBase
class_name BladeKeeper

## BladeKeeper Boss — 快速技巧型剑士
## 3 段连击、防御反击、闪避翻滚、剑气投射、地面陷阱

const PHASE_SPEED := {
    Phase.PHASE_1: 1.0,
    Phase.PHASE_2: 1.3,
    Phase.PHASE_3: 1.5,
}

@export var base_move_speed := 180.0

@onready var sprite: Sprite2D = $Sprite2D

var move_speed: float:
    get: return base_move_speed * PHASE_SPEED.get(current_phase, 1.0)

func _on_boss_ready() -> void:
    detection_radius = 800.0
    attack_range = 200.0
    min_distance = 100.0

func _update_facing() -> void:
    if velocity.x != 0 and sprite:
        sprite.flip_h = velocity.x < 0
```

- [ ] **Step 2:** Commit

```bash
git add Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd
git commit -m "feat: add BladeKeeper boss main class"
```

### Task 7: BKAttackManager

**Files:**
- Create: `Scenes/Characters/Bosses/BladeKeeper/BKAttackManager.gd`

- [ ] **Step 1:** 创建 BKAttackManager

```gdscript
extends BossAttackManager
class_name BKAttackManager

## BladeKeeper 攻击管理器 — 剑气/陷阱/近战/连击

@export var sword_projectile_scene: PackedScene
@export var trap_scene: PackedScene

@export_group("Damage Configs")
@export var melee_damage: Damage
@export var projectile_damage: Damage
@export var trap_damage: Damage
@export var special_damage: Damage

const MAX_TRAPS := 3
var _active_traps: Array[Node] = []

func _execute_attack(entry: Dictionary, target_pos: Vector2) -> void:
    var mode: String = entry.get("mode", "")
    match mode:
        "attack":
            pass  # 近战由 BKAttack 状态直接处理动画+伤害
        "special":
            pass  # sp_atk 由 BKAttack 状态处理
        "defend":
            pass  # 由 BKDefend 状态处理
        "roll_projectile":
            pass  # 由状态序列 BKRoll→BKProjectile 处理
        "roll_trap":
            pass  # 由状态序列 BKRoll→BKTrap 处理
        "combo":
            _execute_combo_entry(entry)

func _execute_combo_entry(entry: Dictionary) -> void:
    var factory_name: String = entry.get("factory", "")
    var combo := _resolve_bk_combo(factory_name)
    if combo:
        # Combo 由 BKAttack 状态逐步执行
        pass

func fire_sword_projectile(target_pos: Vector2) -> void:
    if not sword_projectile_scene:
        return
    var boss := _get_boss()
    if not boss:
        return
    var proj := sword_projectile_scene.instantiate()
    get_tree().root.add_child(proj)
    proj.global_position = boss.global_position
    var direction := (target_pos - boss.global_position).normalized()
    if proj.has_method("set_direction"):
        proj.set_direction(direction)
    if projectile_damage and "damage_config" in proj:
        proj.damage_config = projectile_damage.duplicate(true)

func place_trap(target_pos: Vector2) -> void:
    _cleanup_traps()
    if _active_traps.size() >= MAX_TRAPS:
        return
    if not trap_scene:
        return
    var trap := trap_scene.instantiate()
    get_tree().root.add_child(trap)
    trap.global_position = target_pos + Vector2(randf_range(-30, 30), randf_range(-20, 20))
    if trap_damage and "damage_config" in trap:
        trap.damage_config = trap_damage.duplicate(true)
    _active_traps.append(trap)

func _cleanup_traps() -> void:
    _active_traps = _active_traps.filter(func(t): return is_instance_valid(t))

static func _resolve_bk_combo(factory_name: String) -> BossComboAttack:
    # 组合技工厂 — 后续 Task 实现具体 combo 定义
    return null
```

- [ ] **Step 2:** Commit

```bash
git add Scenes/Characters/Bosses/BladeKeeper/BKAttackManager.gd
git commit -m "feat: add BKAttackManager with projectile/trap/combo support"
```

### Task 8: BKStateMachine

**Files:**
- Create: `Scenes/Characters/Bosses/BladeKeeper/BKStateMachine.gd`

- [ ] **Step 1:** 创建 BKStateMachine

```gdscript
extends BossStateMachine

## BladeKeeper 状态机 — 阶段路由

func _get_phase_route(new_phase: int) -> String:
    match new_phase:
        BossBase.Phase.PHASE_2:
            return "chase"
        BossBase.Phase.PHASE_3:
            return "attack"
    return ""
```

- [ ] **Step 2:** Commit

```bash
git add Scenes/Characters/Bosses/BladeKeeper/BKStateMachine.gd
git commit -m "feat: add BKStateMachine with phase routing"
```

### Task 9: BladeKeeper 状态 — BKIdle, BKChase

**Files:**
- Create: `Scenes/Characters/Bosses/BladeKeeper/States/BKIdle.gd`
- Create: `Scenes/Characters/Bosses/BladeKeeper/States/BKChase.gd`

- [ ] **Step 1:** 创建 BKIdle

```gdscript
extends BossState

## BladeKeeper Idle 状态

@export var idle_time := 2.0
var _timer: SceneTreeTimer

func _init() -> void:
    priority = StatePriority.BEHAVIOR
    can_be_interrupted = true

func enter() -> void:
    var boss := get_boss()
    if boss:
        boss.velocity = Vector2.ZERO
    set_locomotion(Vector2.ZERO)
    _timer = get_tree().create_timer(idle_time)
    _timer.timeout.connect(_on_idle_timeout)

func process_state(_delta: float) -> void:
    var next := evaluate_combat_transition()
    if next != "idle" and next != "patrol":
        transitioned.emit(self, next)

func _on_idle_timeout() -> void:
    if is_target_alive():
        transitioned.emit(self, "chase")

func exit() -> void:
    if _timer and _timer.timeout.is_connected(_on_idle_timeout):
        _timer.timeout.disconnect(_on_idle_timeout)
```

- [ ] **Step 2:** 创建 BKChase

```gdscript
extends BossState

## BladeKeeper Chase 状态

func _init() -> void:
    priority = StatePriority.BEHAVIOR
    can_be_interrupted = true

func enter() -> void:
    pass  # locomotion 由 physics_process 驱动

func physics_process_state(_delta: float) -> void:
    var boss := get_boss()
    if not boss or not is_target_alive():
        transitioned.emit(self, "idle")
        return

    var distance := get_distance_to_target()

    if distance > boss.detection_radius:
        transitioned.emit(self, "idle")
        return

    if distance <= boss.attack_range and boss.attack_cooldown <= 0:
        transitioned.emit(self, "attack")
        return

    # 移动
    var bk := boss as BladeKeeper
    var direction := (target_node.global_position - boss.global_position).normalized()
    boss.velocity = direction * bk.move_speed

    # 更新 locomotion BlendSpace2D
    var speed_ratio := 1.0
    set_locomotion(Vector2(direction.x, speed_ratio))

func exit() -> void:
    var boss := get_boss()
    if boss:
        boss.velocity = Vector2.ZERO
    set_locomotion(Vector2.ZERO)
```

- [ ] **Step 3:** Commit

```bash
git add Scenes/Characters/Bosses/BladeKeeper/States/BKIdle.gd
git add Scenes/Characters/Bosses/BladeKeeper/States/BKChase.gd
git commit -m "feat: add BKIdle and BKChase states"
```

### Task 10: BladeKeeper 状态 — BKAttack

**Files:**
- Create: `Scenes/Characters/Bosses/BladeKeeper/States/BKAttack.gd`

- [ ] **Step 1:** 创建 BKAttack（支持连击链 + special）

```gdscript
extends BossState

## BladeKeeper Attack 状态 — 3 段连击或特殊攻击

const COMBO_ANIMS := ["atk_1", "atk_2", "atk_3"]

var _current_combo_step := 0
var _is_special := false
var _anim_tree_ref: AnimationTree

func _init() -> void:
    priority = StatePriority.BEHAVIOR
    can_be_interrupted = true

func enter() -> void:
    var boss := get_boss()
    if not boss:
        transitioned.emit(self, "idle")
        return

    _anim_tree_ref = get_anim_tree()

    # 从攻击管理器选择攻击类型
    var mgr := get_attack_manager()
    var entry := mgr.pick_attack() if mgr else {}
    var mode: String = entry.get("mode", "attack")

    boss.attack_cooldown = mgr.get_cooldown() if mgr else 1.5

    if mode == "special":
        _is_special = true
        _current_combo_step = 0
        enter_control_state("sp_atk")
    elif mode == "defend":
        transitioned.emit(self, "defend")
        return
    elif mode.begins_with("roll"):
        transitioned.emit(self, "roll")
        return
    elif mode.begins_with("combo"):
        # TODO: combo 序列由 BossComboAttack 驱动
        _is_special = false
        _current_combo_step = 0
        enter_control_state(COMBO_ANIMS[0])
    else:
        _is_special = false
        _current_combo_step = 0
        enter_control_state(COMBO_ANIMS[0])

    if _anim_tree_ref:
        _anim_tree_ref.animation_finished.connect(_on_animation_finished)

func _on_animation_finished(_anim_name: StringName) -> void:
    if _is_special:
        _finish_attack()
        return

    _current_combo_step += 1
    if _current_combo_step < COMBO_ANIMS.size():
        enter_control_state(COMBO_ANIMS[_current_combo_step])
    else:
        _finish_attack()

func _finish_attack() -> void:
    exit_control_state()
    var next := evaluate_combat_transition(false)
    transitioned.emit(self, next)

func exit() -> void:
    if _anim_tree_ref and _anim_tree_ref.animation_finished.is_connected(_on_animation_finished):
        _anim_tree_ref.animation_finished.disconnect(_on_animation_finished)
    _current_combo_step = 0
    _is_special = false
```

- [ ] **Step 2:** Commit

```bash
git add Scenes/Characters/Bosses/BladeKeeper/States/BKAttack.gd
git commit -m "feat: add BKAttack state with combo chain and special"
```

### Task 11: BladeKeeper 状态 — BKDefend, BKRoll

**Files:**
- Create: `Scenes/Characters/Bosses/BladeKeeper/States/BKDefend.gd`
- Create: `Scenes/Characters/Bosses/BladeKeeper/States/BKRoll.gd`

- [ ] **Step 1:** 创建 BKDefend

```gdscript
extends BossState

## BladeKeeper Defend 状态 — 格挡 + 反击

@export var defend_duration := 1.5
@export var counter_damage_multiplier := 1.5

var _timer: SceneTreeTimer
var _took_hit := false
var _anim_tree_ref: AnimationTree

func _init() -> void:
    priority = StatePriority.BEHAVIOR
    can_be_interrupted = true

func enter() -> void:
    _took_hit = false
    _anim_tree_ref = get_anim_tree()
    enter_control_state("defend")
    _timer = get_tree().create_timer(defend_duration)
    _timer.timeout.connect(_on_defend_timeout)

func on_damaged(damage: Damage, _attacker_position: Vector2 = Vector2.ZERO) -> void:
    # 格挡期间受击：减半伤害 + 标记反击
    _took_hit = true
    var boss := get_boss()
    if boss and boss.health_component:
        # 恢复 50% 伤害（模拟减伤）
        boss.health_component.heal(damage.amount * 0.5)

func _on_defend_timeout() -> void:
    exit_control_state()
    if _took_hit:
        # 反击：立即进入攻击（伤害加成由 BKAttack 读取）
        transitioned.emit(self, "attack")
    else:
        var next := evaluate_combat_transition()
        transitioned.emit(self, next)

func exit() -> void:
    if _timer and _timer.timeout.is_connected(_on_defend_timeout):
        _timer.timeout.disconnect(_on_defend_timeout)
    if _anim_tree_ref and _anim_tree_ref.animation_finished.is_connected(_on_defend_timeout):
        _anim_tree_ref.animation_finished.disconnect(_on_defend_timeout)
```

- [ ] **Step 2:** 创建 BKRoll

```gdscript
extends BossState

## BladeKeeper Roll 状态 — 侧向闪避

@export var roll_speed := 250.0

var _roll_direction := Vector2.ZERO
var _anim_tree_ref: AnimationTree

func _init() -> void:
    priority = StatePriority.BEHAVIOR
    can_be_interrupted = false

func enter() -> void:
    var boss := get_boss()
    if not boss or not target_node:
        transitioned.emit(self, "idle")
        return

    _anim_tree_ref = get_anim_tree()

    # 侧向闪避（垂直于面向玩家的方向）
    var to_player := (target_node.global_position - boss.global_position).normalized()
    _roll_direction = Vector2(-to_player.y, to_player.x)
    if randf() > 0.5:
        _roll_direction = -_roll_direction

    enter_control_state("roll")
    if _anim_tree_ref:
        _anim_tree_ref.animation_finished.connect(_on_roll_finished)

func physics_process_state(_delta: float) -> void:
    var boss := get_boss()
    if boss:
        boss.velocity = _roll_direction * roll_speed

func _on_roll_finished(_anim_name: StringName) -> void:
    var boss := get_boss()
    if boss:
        boss.velocity = Vector2.ZERO
    exit_control_state()
    var next := evaluate_combat_transition()
    transitioned.emit(self, next)

func exit() -> void:
    if _anim_tree_ref and _anim_tree_ref.animation_finished.is_connected(_on_roll_finished):
        _anim_tree_ref.animation_finished.disconnect(_on_roll_finished)
    var boss := get_boss()
    if boss:
        boss.velocity = Vector2.ZERO
```

- [ ] **Step 3:** Commit

```bash
git add Scenes/Characters/Bosses/BladeKeeper/States/BKDefend.gd
git add Scenes/Characters/Bosses/BladeKeeper/States/BKRoll.gd
git commit -m "feat: add BKDefend and BKRoll states"
```

### Task 12: BladeKeeper 状态 — BKProjectile, BKTrap, BKStun

**Files:**
- Create: `Scenes/Characters/Bosses/BladeKeeper/States/BKProjectile.gd`
- Create: `Scenes/Characters/Bosses/BladeKeeper/States/BKTrap.gd`
- Create: `Scenes/Characters/Bosses/BladeKeeper/States/BKStun.gd`

- [ ] **Step 1:** 创建 BKProjectile

```gdscript
extends BossState

## BladeKeeper Projectile 状态 — 释放剑气

var _anim_tree_ref: AnimationTree

func _init() -> void:
    priority = StatePriority.BEHAVIOR
    can_be_interrupted = true

func enter() -> void:
    _anim_tree_ref = get_anim_tree()
    enter_control_state("projectile_cast")
    if _anim_tree_ref:
        _anim_tree_ref.animation_finished.connect(_on_cast_finished)

func _on_cast_finished(_anim_name: StringName) -> void:
    # 动画播放到位后发射
    var mgr := get_attack_manager() as BKAttackManager
    if mgr and target_node:
        mgr.fire_sword_projectile(target_node.global_position)
    exit_control_state()
    var next := evaluate_combat_transition(false)
    transitioned.emit(self, next)

func exit() -> void:
    if _anim_tree_ref and _anim_tree_ref.animation_finished.is_connected(_on_cast_finished):
        _anim_tree_ref.animation_finished.disconnect(_on_cast_finished)
```

- [ ] **Step 2:** 创建 BKTrap

```gdscript
extends BossState

## BladeKeeper Trap 状态 — 放置地面陷阱

var _anim_tree_ref: AnimationTree

func _init() -> void:
    priority = StatePriority.BEHAVIOR
    can_be_interrupted = true

func enter() -> void:
    _anim_tree_ref = get_anim_tree()
    enter_control_state("trap_cast")
    if _anim_tree_ref:
        _anim_tree_ref.animation_finished.connect(_on_cast_finished)

func _on_cast_finished(_anim_name: StringName) -> void:
    var mgr := get_attack_manager() as BKAttackManager
    if mgr and target_node:
        mgr.place_trap(target_node.global_position)
    exit_control_state()
    var next := evaluate_combat_transition(false)
    transitioned.emit(self, next)

func exit() -> void:
    if _anim_tree_ref and _anim_tree_ref.animation_finished.is_connected(_on_cast_finished):
        _anim_tree_ref.animation_finished.disconnect(_on_cast_finished)
```

- [ ] **Step 3:** 创建 BKStun

```gdscript
extends BossState

## BladeKeeper Stun 状态

@export var stun_duration := 1.5

var _timer: SceneTreeTimer

func _init() -> void:
    priority = StatePriority.CONTROL
    can_be_interrupted = false

func enter() -> void:
    var boss := get_boss()
    if boss:
        boss.stunned = true
        boss.velocity = Vector2.ZERO
    enter_control_state("stun")
    _timer = get_tree().create_timer(stun_duration)
    _timer.timeout.connect(_on_stun_timeout)

func _on_stun_timeout() -> void:
    var boss := get_boss()
    if boss:
        boss.stunned = false
        boss.stun_immunity = 1.5
    exit_control_state()
    var next := evaluate_combat_transition()
    transitioned.emit(self, next)

func on_damaged(damage: Damage, _attacker_position: Vector2 = Vector2.ZERO) -> void:
    # 眩晕中再次受到 StunEffect → 刷新计时器
    for effect in damage.effects:
        if effect is StunEffect:
            if _timer:
                _timer.timeout.disconnect(_on_stun_timeout)
            _timer = get_tree().create_timer(stun_duration)
            _timer.timeout.connect(_on_stun_timeout)
            return

func exit() -> void:
    if _timer and _timer.timeout.is_connected(_on_stun_timeout):
        _timer.timeout.disconnect(_on_stun_timeout)
    var boss := get_boss()
    if boss:
        boss.stunned = false
```

- [ ] **Step 4:** Commit

```bash
git add Scenes/Characters/Bosses/BladeKeeper/States/BKProjectile.gd
git add Scenes/Characters/Bosses/BladeKeeper/States/BKTrap.gd
git add Scenes/Characters/Bosses/BladeKeeper/States/BKStun.gd
git commit -m "feat: add BKProjectile, BKTrap, BKStun states"
```

### Task 13: BladeKeeper 攻击实体 — BKSwordProjectile, BKTrap 场景

**Files:**
- Create: `Scenes/Characters/Bosses/BladeKeeper/Attacks/BKSwordProjectile.gd`
- Create: `Scenes/Characters/Bosses/BladeKeeper/Attacks/BKSwordProjectile.tscn`（MCP 创建）
- Create: `Scenes/Characters/Bosses/BladeKeeper/Attacks/BKTrap.gd`
- Create: `Scenes/Characters/Bosses/BladeKeeper/Attacks/BKTrap.tscn`（MCP 创建）

- [ ] **Step 1:** 创建 BKSwordProjectile.gd

```gdscript
extends Area2D
class_name BKSwordProjectile

## 剑气投射物 — 直线飞行，命中消失

@export var speed := 400.0
@export var lifetime := 4.0
@export var damage_config: Damage

var _direction := Vector2.RIGHT
var _lifetime_timer: SceneTreeTimer

func _ready() -> void:
    _lifetime_timer = get_tree().create_timer(lifetime)
    _lifetime_timer.timeout.connect(queue_free)
    # HitBoxComponent 子节点处理碰撞

func set_direction(dir: Vector2) -> void:
    _direction = dir.normalized()
    rotation = dir.angle()

func _physics_process(delta: float) -> void:
    position += _direction * speed * delta
```

- [ ] **Step 2:** 创建 BKTrap.gd

```gdscript
extends Area2D
class_name BKTrap

## 地面陷阱 — 接触触发，爆炸 + ForceStun

@export var trap_lifetime := 8.0
@export var damage_config: Damage
@export var stun_duration := 0.5

var _triggered := false

func _ready() -> void:
    modulate.a = 0.3
    var lifetime_timer := get_tree().create_timer(trap_lifetime)
    lifetime_timer.timeout.connect(_expire)
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
    if _triggered:
        return
    if not body.is_in_group("player"):
        return
    _triggered = true
    _trigger(body)

func _trigger(_body: Node2D) -> void:
    modulate.a = 1.0
    # 通过 HitBoxComponent 子节点应用伤害
    # 添加 ForceStunEffect
    if damage_config:
        var dmg := damage_config.duplicate(true) as Damage
        var stun_effect := ForceStunEffect.new()
        stun_effect.duration = stun_duration
        dmg.effects.append(stun_effect)
    await get_tree().create_timer(0.3).timeout
    queue_free()

func _expire() -> void:
    if _triggered:
        return
    var tween := create_tween()
    tween.tween_property(self, "modulate:a", 0.0, 0.5)
    tween.tween_callback(queue_free)
```

- [ ] **Step 3:** 使用 MCP 创建 .tscn 场景（BKSwordProjectile.tscn 和 BKTrap.tscn），包含 CollisionShape2D + HitBoxComponent 子节点

- [ ] **Step 4:** Commit

```bash
git add Scenes/Characters/Bosses/BladeKeeper/Attacks/
git commit -m "feat: add BKSwordProjectile and BKTrap attack entities"
```

### Task 14: BladeKeeper 组合技定义

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/BKAttackManager.gd` — 添加 combo 工厂方法

- [ ] **Step 1:** 在 BKAttackManager 中实现组合技工厂

```gdscript
# 添加到 BKAttackManager.gd

static func _resolve_bk_combo(factory_name: String) -> BossComboAttack:
    match factory_name:
        "blade_storm": return _create_blade_storm()
        "shadow_strike": return _create_shadow_strike()
        "ultimate_chain": return _create_ultimate_chain()
    return null

## 剑刃风暴: atk_1 → atk_2 → atk_3 → projectile_cast (Phase 1+)
static func _create_blade_storm() -> BossComboAttack:
    var combo := BossComboAttack.new()
    combo.combo_name = "blade_storm"
    combo.steps = [
        {"type": "state", "state": "atk_1", "delay": 0.0},
        {"type": "state", "state": "atk_2", "delay": 0.1},
        {"type": "state", "state": "atk_3", "delay": 0.1},
        {"type": "state", "state": "projectile_cast", "delay": 0.2},
    ]
    return combo

## 影步突袭: roll → atk_1 → atk_2 → defend (Phase 2+)
static func _create_shadow_strike() -> BossComboAttack:
    var combo := BossComboAttack.new()
    combo.combo_name = "shadow_strike"
    combo.steps = [
        {"type": "state", "state": "roll", "delay": 0.0},
        {"type": "state", "state": "atk_1", "delay": 0.1},
        {"type": "state", "state": "atk_2", "delay": 0.1},
        {"type": "state", "state": "defend", "delay": 0.2},
    ]
    return combo

## 绝剑连环: roll → trap → atk_1 → atk_2 → atk_3 → sp_atk (Phase 3)
static func _create_ultimate_chain() -> BossComboAttack:
    var combo := BossComboAttack.new()
    combo.combo_name = "ultimate_chain"
    combo.steps = [
        {"type": "state", "state": "roll", "delay": 0.0},
        {"type": "state", "state": "trap_cast", "delay": 0.1},
        {"type": "state", "state": "atk_1", "delay": 0.2},
        {"type": "state", "state": "atk_2", "delay": 0.1},
        {"type": "state", "state": "atk_3", "delay": 0.1},
        {"type": "state", "state": "sp_atk", "delay": 0.3},
    ]
    return combo
```

- [ ] **Step 2:** Commit

```bash
git add Scenes/Characters/Bosses/BladeKeeper/BKAttackManager.gd
git commit -m "feat: add BladeKeeper combo definitions (blade_storm, shadow_strike, ultimate_chain)"
```

### Task 15: BladeKeeper.tscn 场景搭建

**Files:**
- Create: `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn`（MCP 创建）

- [ ] **Step 1:** 使用 MCP 工具创建场景

场景节点树：
```
BladeKeeper (CharacterBody2D, script: BladeKeeper.gd)
├── Sprite2D (texture from BLADE_KEEPER spritesheet)
├── AnimationPlayer
├── AnimationTree (BlendTree: locomotion + control_sm + control_blend)
├── CollisionShape2D (RectangleShape2D ~40x56)
├── HurtBoxComponent (Area2D + CollisionShape2D)
├── HealthComponent
├── DamageNumbersAnchor (Marker2D)
├── BKAttackManager (Node, script: BKAttackManager.gd)
└── BKStateMachine (script: BKStateMachine.gd)
    ├── BKIdle (init_state)
    ├── BKChase
    ├── BKAttack
    ├── BKDefend
    ├── BKRoll
    ├── BKProjectile
    ├── BKTrap
    └── BKStun
```

- [ ] **Step 2:** 在编辑器中配置 AnimationTree BlendTree

使用 AnimationPlayer 创建动画（从 PNG 帧序列 `Assets/Art/BLADE_KEEPER/PNG animations/`），然后配置 BlendTree：
- locomotion: BlendSpace2D (idle↔run)
- control_sm: StateMachine (atk_1, atk_2, atk_3, sp_atk, defend, roll, projectile_cast, trap_cast, take_hit, stun, death)
- control_blend: Blend2
- loco_timescale, ctrl_timescale: TimeScale 节点

- [ ] **Step 3:** 配置 BossPhaseConfig Resource (.tres 文件)

为 Phase 1/2/3 各创建一个 BossPhaseConfig .tres，设置攻击池权重。在 BKAttackManager 的 phase_configs 中引用。

- [ ] **Step 4:** Commit

```bash
git add Scenes/Characters/Bosses/BladeKeeper/
git commit -m "feat: add BladeKeeper.tscn with AnimationTree and phase configs"
```

---

## Phase 4: DemonSlime Boss

### Task 16: DemonSlime.gd 主类

**Files:**
- Create: `Scenes/Characters/Bosses/DemonSlime/DemonSlime.gd`

- [ ] **Step 1:** 创建 DemonSlime 主类

```gdscript
extends BossBase
class_name DemonSlime

## DemonSlime Boss — 慢速重击型，冲击波施压

const PHASE_SPEED := {
    Phase.PHASE_1: 1.0,
    Phase.PHASE_2: 1.3,
    Phase.PHASE_3: 1.5,
}

@export var base_move_speed := 80.0
@export var health_multiplier := 1.5  ## 相对默认血量的倍率

@onready var sprite: Sprite2D = $Sprite2D

var move_speed: float:
    get: return base_move_speed * PHASE_SPEED.get(current_phase, 1.0)

func _on_boss_ready() -> void:
    detection_radius = 600.0
    attack_range = 250.0
    min_distance = 80.0
    if health_component:
        health_component.max_health *= health_multiplier
        health_component.health = health_component.max_health
        max_health = int(health_component.max_health)
        health = max_health

func _update_facing() -> void:
    if velocity.x != 0 and sprite:
        sprite.flip_h = velocity.x < 0
```

- [ ] **Step 2:** Commit

```bash
git add Scenes/Characters/Bosses/DemonSlime/DemonSlime.gd
git commit -m "feat: add DemonSlime boss main class"
```

### Task 17: DSAttackManager

**Files:**
- Create: `Scenes/Characters/Bosses/DemonSlime/DSAttackManager.gd`

- [ ] **Step 1:** 创建 DSAttackManager

```gdscript
extends BossAttackManager
class_name DSAttackManager

## DemonSlime 攻击管理器 — 冲击波生成 + 组合技

@export var shockwave_scene: PackedScene

@export_group("Damage Configs")
@export var cleave_damage: Damage
@export var slam_damage: Damage

func _execute_attack(entry: Dictionary, target_pos: Vector2) -> void:
    var mode: String = entry.get("mode", "")
    match mode:
        "cleave", "slam":
            pass  # 由 DSCleave/DSSlam 状态调用 spawn 方法
        "combo":
            _execute_combo_entry(entry)

func spawn_fan_shockwave(origin: Vector2, facing_dir: Vector2) -> void:
    if not shockwave_scene:
        return
    var sw := shockwave_scene.instantiate()
    get_tree().root.add_child(sw)
    sw.global_position = origin
    if sw.has_method("setup_fan"):
        var radius := _get_cleave_radius()
        sw.setup_fan(facing_dir, deg_to_rad(120), radius)
    if cleave_damage and "damage_config" in sw:
        sw.damage_config = cleave_damage.duplicate(true)

func spawn_ring_shockwave(origin: Vector2) -> void:
    if not shockwave_scene:
        return
    var sw := shockwave_scene.instantiate()
    get_tree().root.add_child(sw)
    sw.global_position = origin
    if sw.has_method("setup_ring"):
        sw.setup_ring(250.0)
    if slam_damage and "damage_config" in sw:
        sw.damage_config = slam_damage.duplicate(true)

func _get_cleave_radius() -> float:
    var boss := _get_boss()
    if boss and boss.current_phase == BossBase.Phase.PHASE_3:
        return 260.0
    return 200.0

func _execute_combo_entry(entry: Dictionary) -> void:
    var factory_name: String = entry.get("factory", "")
    # combo 通过状态序列执行，由状态机驱动
    pass

## 组合技工厂
static func resolve_ds_combo(factory_name: String) -> BossComboAttack:
    match factory_name:
        "earthquake": return _create_earthquake()
        "devastation": return _create_devastation()
        "annihilation": return _create_annihilation()
    return null

## 大地震颤: cleave(fan) → 0.3s → cleave(fan, 反方向)
static func _create_earthquake() -> BossComboAttack:
    var combo := BossComboAttack.new()
    combo.combo_name = "earthquake"
    combo.steps = [
        {"type": "attack", "mode": "cleave", "params": {"direction": "forward"}, "delay": 0.0},
        {"type": "attack", "mode": "cleave", "params": {"direction": "backward"}, "delay": 0.3},
    ]
    return combo

## 毁灭重压: slam(ring) → 0.5s → cleave(fan, 加大范围)
static func _create_devastation() -> BossComboAttack:
    var combo := BossComboAttack.new()
    combo.combo_name = "devastation"
    combo.steps = [
        {"type": "attack", "mode": "slam", "delay": 0.0},
        {"type": "attack", "mode": "cleave", "params": {"radius_multiplier": 1.3}, "delay": 0.5},
    ]
    return combo

## 灭世连击: cleave → cleave → slam(加大范围)
static func _create_annihilation() -> BossComboAttack:
    var combo := BossComboAttack.new()
    combo.combo_name = "annihilation"
    combo.steps = [
        {"type": "attack", "mode": "cleave", "delay": 0.0},
        {"type": "attack", "mode": "cleave", "delay": 0.2},
        {"type": "attack", "mode": "slam", "params": {"radius_multiplier": 1.3}, "delay": 0.2},
    ]
    return combo
```

- [ ] **Step 2:** Commit

```bash
git add Scenes/Characters/Bosses/DemonSlime/DSAttackManager.gd
git commit -m "feat: add DSAttackManager with shockwave spawning and combo definitions"
```

### Task 18: DSStateMachine + DemonSlime 状态

**Files:**
- Create: `Scenes/Characters/Bosses/DemonSlime/DSStateMachine.gd`
- Create: `Scenes/Characters/Bosses/DemonSlime/States/DSIdle.gd`
- Create: `Scenes/Characters/Bosses/DemonSlime/States/DSChase.gd`
- Create: `Scenes/Characters/Bosses/DemonSlime/States/DSCleave.gd`
- Create: `Scenes/Characters/Bosses/DemonSlime/States/DSSlam.gd`
- Create: `Scenes/Characters/Bosses/DemonSlime/States/DSStun.gd`

- [ ] **Step 1:** 创建 DSStateMachine

```gdscript
extends BossStateMachine

## DemonSlime 状态机 — 阶段路由

func _get_phase_route(new_phase: int) -> String:
    match new_phase:
        BossBase.Phase.PHASE_2:
            return "chase"
        BossBase.Phase.PHASE_3:
            return "cleave"
    return ""
```

- [ ] **Step 2:** 创建 DSIdle（与 BKIdle 类似）

```gdscript
extends BossState

## DemonSlime Idle 状态

@export var idle_time := 2.0
var _timer: SceneTreeTimer

func _init() -> void:
    priority = StatePriority.BEHAVIOR
    can_be_interrupted = true

func enter() -> void:
    var boss := get_boss()
    if boss:
        boss.velocity = Vector2.ZERO
    set_locomotion(Vector2.ZERO)
    _timer = get_tree().create_timer(idle_time)
    _timer.timeout.connect(_on_idle_timeout)

func process_state(_delta: float) -> void:
    var next := evaluate_combat_transition()
    if next != "idle" and next != "patrol":
        transitioned.emit(self, next)

func _on_idle_timeout() -> void:
    if is_target_alive():
        transitioned.emit(self, "chase")

func exit() -> void:
    if _timer and _timer.timeout.is_connected(_on_idle_timeout):
        _timer.timeout.disconnect(_on_idle_timeout)
```

- [ ] **Step 3:** 创建 DSChase

```gdscript
extends BossState

## DemonSlime Chase 状态

func _init() -> void:
    priority = StatePriority.BEHAVIOR
    can_be_interrupted = true

func physics_process_state(_delta: float) -> void:
    var boss := get_boss()
    if not boss or not is_target_alive():
        transitioned.emit(self, "idle")
        return

    var distance := get_distance_to_target()

    if distance > boss.detection_radius:
        transitioned.emit(self, "idle")
        return

    if distance <= boss.attack_range and boss.attack_cooldown <= 0:
        # 从攻击池选择
        var mgr := get_attack_manager()
        var entry := mgr.pick_attack() if mgr else {}
        var mode: String = entry.get("mode", "cleave")
        if mode == "slam":
            transitioned.emit(self, "slam")
        elif mode.begins_with("combo"):
            transitioned.emit(self, "cleave")  # combo 由 cleave 状态驱动
        else:
            transitioned.emit(self, "cleave")
        return

    var ds := boss as DemonSlime
    var direction := (target_node.global_position - boss.global_position).normalized()
    boss.velocity = direction * ds.move_speed
    set_locomotion(Vector2(direction.x, 1.0))

func exit() -> void:
    var boss := get_boss()
    if boss:
        boss.velocity = Vector2.ZERO
    set_locomotion(Vector2.ZERO)
```

- [ ] **Step 4:** 创建 DSCleave

```gdscript
extends BossState

## DemonSlime Cleave 状态 — 扇形冲击波

var _anim_tree_ref: AnimationTree

func _init() -> void:
    priority = StatePriority.BEHAVIOR
    can_be_interrupted = true

func enter() -> void:
    var boss := get_boss()
    if boss:
        boss.velocity = Vector2.ZERO
        boss.attack_cooldown = get_attack_manager().get_cooldown() if get_attack_manager() else 2.5

    _anim_tree_ref = get_anim_tree()
    enter_control_state("cleave")
    if _anim_tree_ref:
        _anim_tree_ref.animation_finished.connect(_on_cleave_finished)

func _on_cleave_finished(_anim_name: StringName) -> void:
    # 生成扇形冲击波
    var mgr := get_attack_manager() as DSAttackManager
    var boss := get_boss()
    if mgr and boss and target_node:
        var facing := (target_node.global_position - boss.global_position).normalized()
        mgr.spawn_fan_shockwave(boss.global_position, facing)

    exit_control_state()
    var next := evaluate_combat_transition(false)
    transitioned.emit(self, next)

func exit() -> void:
    if _anim_tree_ref and _anim_tree_ref.animation_finished.is_connected(_on_cleave_finished):
        _anim_tree_ref.animation_finished.disconnect(_on_cleave_finished)
```

- [ ] **Step 5:** 创建 DSSlam

```gdscript
extends BossState

## DemonSlime Slam 状态 — 圆形冲击波（共用 cleave 动画）

var _anim_tree_ref: AnimationTree

func _init() -> void:
    priority = StatePriority.BEHAVIOR
    can_be_interrupted = true

func enter() -> void:
    var boss := get_boss()
    if boss:
        boss.velocity = Vector2.ZERO
        boss.attack_cooldown = get_attack_manager().get_cooldown() if get_attack_manager() else 2.0

    _anim_tree_ref = get_anim_tree()
    enter_control_state("cleave")  # 共用 cleave 动画
    if _anim_tree_ref:
        _anim_tree_ref.animation_finished.connect(_on_slam_finished)

func _on_slam_finished(_anim_name: StringName) -> void:
    var mgr := get_attack_manager() as DSAttackManager
    var boss := get_boss()
    if mgr and boss:
        mgr.spawn_ring_shockwave(boss.global_position)

    exit_control_state()
    var next := evaluate_combat_transition(false)
    transitioned.emit(self, next)

func exit() -> void:
    if _anim_tree_ref and _anim_tree_ref.animation_finished.is_connected(_on_slam_finished):
        _anim_tree_ref.animation_finished.disconnect(_on_slam_finished)
```

- [ ] **Step 6:** 创建 DSStun

```gdscript
extends BossState

## DemonSlime Stun 状态

@export var stun_duration := 1.5

var _timer: SceneTreeTimer

func _init() -> void:
    priority = StatePriority.CONTROL
    can_be_interrupted = false

func enter() -> void:
    var boss := get_boss()
    if boss:
        boss.stunned = true
        boss.velocity = Vector2.ZERO
    enter_control_state("stun")
    _timer = get_tree().create_timer(stun_duration)
    _timer.timeout.connect(_on_stun_timeout)

func _on_stun_timeout() -> void:
    var boss := get_boss()
    if boss:
        boss.stunned = false
        boss.stun_immunity = 1.5
    exit_control_state()
    var next := evaluate_combat_transition()
    transitioned.emit(self, next)

func on_damaged(damage: Damage, _attacker_position: Vector2 = Vector2.ZERO) -> void:
    # Phase 3 免疫眩晕
    var boss := get_boss()
    if boss and boss.current_phase == BossBase.Phase.PHASE_3:
        return
    # 刷新眩晕
    for effect in damage.effects:
        if effect is StunEffect:
            if _timer and _timer.timeout.is_connected(_on_stun_timeout):
                _timer.timeout.disconnect(_on_stun_timeout)
            _timer = get_tree().create_timer(stun_duration)
            _timer.timeout.connect(_on_stun_timeout)
            return

func exit() -> void:
    if _timer and _timer.timeout.is_connected(_on_stun_timeout):
        _timer.timeout.disconnect(_on_stun_timeout)
    var boss := get_boss()
    if boss:
        boss.stunned = false
```

- [ ] **Step 7:** Commit

```bash
git add Scenes/Characters/Bosses/DemonSlime/
git commit -m "feat: add DemonSlime state machine and all 5 states"
```

### Task 19: DSShockwave 攻击实体

**Files:**
- Create: `Scenes/Characters/Bosses/DemonSlime/Attacks/DSShockwave.gd`
- Create: `Scenes/Characters/Bosses/DemonSlime/Attacks/DSShockwave.tscn`（MCP 创建）

- [ ] **Step 1:** 创建 DSShockwave.gd

```gdscript
extends Area2D
class_name DSShockwave

## DemonSlime 冲击波 — 支持扇形和圆形模式

@export var damage_config: Damage
@export var shockwave_lifetime := 0.5

var _mode := "ring"  # "fan" or "ring"
var _fan_direction := Vector2.RIGHT
var _fan_angle := deg_to_rad(120)
var _radius := 200.0

func setup_fan(direction: Vector2, angle: float, radius: float) -> void:
    _mode = "fan"
    _fan_direction = direction.normalized()
    _fan_angle = angle
    _radius = radius
    _update_collision()

func setup_ring(radius: float) -> void:
    _mode = "ring"
    _radius = radius
    _update_collision()

func _update_collision() -> void:
    # 设置 CollisionShape2D 的半径
    var shape := $CollisionShape2D
    if shape and shape.shape is CircleShape2D:
        (shape.shape as CircleShape2D).radius = _radius

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    var timer := get_tree().create_timer(shockwave_lifetime)
    timer.timeout.connect(queue_free)

func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group("player"):
        return

    # 扇形模式：检查角度
    if _mode == "fan":
        var to_body := (body.global_position - global_position).normalized()
        var angle_diff := abs(_fan_direction.angle_to(to_body))
        if angle_diff > _fan_angle / 2.0:
            return  # 不在扇形范围内

    # 应用伤害（通过 HurtBoxComponent）
    if damage_config:
        for child in body.get_children():
            if child.has_method("take_damage"):
                child.take_damage(damage_config.duplicate(true), global_position)
                break
```

- [ ] **Step 2:** 使用 MCP 创建 DSShockwave.tscn 场景（Area2D + CollisionShape2D(CircleShape2D)）

- [ ] **Step 3:** Commit

```bash
git add Scenes/Characters/Bosses/DemonSlime/Attacks/
git commit -m "feat: add DSShockwave attack entity with fan/ring modes"
```

### Task 20: DemonSlime.tscn 场景搭建

**Files:**
- Create: `Scenes/Characters/Bosses/DemonSlime/DemonSlime.tscn`（MCP 创建）

- [ ] **Step 1:** 使用 MCP 创建场景

场景节点树：
```
DemonSlime (CharacterBody2D, script: DemonSlime.gd)
├── Sprite2D (texture from BOSS_SLIME spritesheet)
├── AnimationPlayer
├── AnimationTree (BlendTree: locomotion + control_sm + control_blend)
├── CollisionShape2D (RectangleShape2D ~48x64)
├── HurtBoxComponent (Area2D + CollisionShape2D)
├── HealthComponent
├── DamageNumbersAnchor (Marker2D)
├── DSAttackManager (Node, script: DSAttackManager.gd)
└── DSStateMachine (script: DSStateMachine.gd)
    ├── DSIdle (init_state)
    ├── DSChase
    ├── DSCleave
    ├── DSSlam
    └── DSStun
```

- [ ] **Step 2:** 配置 AnimationTree BlendTree + AnimationPlayer 动画（从 PNG 帧序列）

- [ ] **Step 3:** 创建 BossPhaseConfig .tres（Phase 1/2/3 攻击池权重）

- [ ] **Step 4:** Commit

```bash
git add Scenes/Characters/Bosses/DemonSlime/
git commit -m "feat: add DemonSlime.tscn with AnimationTree and phase configs"
```

---

## Phase 5: 清理 + 验证

### Task 21: 删除旧实现

**Files:**
- Delete: `Scenes/Characters/Enemies/BladeKeeper/` 整个目录
- Delete: `Scenes/Characters/Enemies/DemonSlime/` 整个目录

- [ ] **Step 1:** 删除旧文件

```bash
rm -rf "Scenes/Characters/Enemies/BladeKeeper/"
rm -rf "Scenes/Characters/Enemies/DemonSlime/"
```

- [ ] **Step 2:** 检查全项目无残留引用

```bash
grep -r "BladeKeeperBoss\|DemonSlimeBoss\|BKBaseState\|DSBaseState" --include="*.gd" --include="*.tscn"
```

- [ ] **Step 3:** Commit

```bash
git add -A
git commit -m "chore: remove old BladeKeeper and DemonSlime implementations"
```

### Task 22: 全局验证

- [ ] **Step 1:** Godot 脚本检查

```bash
godot --headless --check-only --script res://Scenes/Characters/Bosses/Shared/BossStateMachine.gd
godot --headless --check-only --script res://Scenes/Characters/Bosses/Shared/BossAttackManager.gd
godot --headless --check-only --script res://Scenes/Characters/Bosses/Cyclops/Cyclops.gd
godot --headless --check-only --script res://Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd
godot --headless --check-only --script res://Scenes/Characters/Bosses/DemonSlime/DemonSlime.gd
```

- [ ] **Step 2:** MCP 运行验证

```
mcp__godot__run_project → 运行游戏
mcp__godot__get_debug_output → 检查无 ERROR
mcp__godot__stop_project → 停止
```

- [ ] **Step 3:** 验证 Cyclops Boss 在 Level3 正常工作

- [ ] **Step 4:** 最终 commit

```bash
git add -A
git commit -m "feat: complete Boss system redesign — Shared base classes + Cyclops migration + BladeKeeper + DemonSlime"
```
