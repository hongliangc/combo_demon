# Two New Bosses (BladeKeeper + DemonSlime) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create two new bosses (BladeKeeper and DemonSlime) with independent state machines, attack managers, attack entities, and dedicated levels (Level4, Level5).

**Architecture:** Both bosses extend `BossBase` directly (not `Boss`). Each has its own StateMachine, AttackManager, and attack entities. They use `AnimatedSprite2D` + `SpriteFrames` instead of `AnimationTree` since assets are PNG sequences. State transitions use the existing `transitioned.emit(self, "state_name")` pattern.

**Tech Stack:** Godot 4.4.1, GDScript, existing state machine framework (`BaseState`/`BaseStateMachine`), `BossBase` phase system, `HitBoxComponent`/`HurtBoxComponent` damage pipeline.

**Spec:** `docs/superpowers/specs/2026-03-27-two-new-bosses-design.md`

---

## File Structure

### BladeKeeper Boss
| Action | Path | Purpose |
|--------|------|---------|
| Create | `Scenes/Characters/Enemies/BladeKeeper/BladeKeeperBoss.gd` | Boss script (extends BossBase) |
| Create | `Scenes/Characters/Enemies/BladeKeeper/BladeKeeperBoss.tscn` | Boss scene |
| Create | `Scenes/Characters/Enemies/BladeKeeper/BladeKeeperAttackManager.gd` | Attack manager |
| Create | `Scenes/Characters/Enemies/BladeKeeper/States/BKBaseState.gd` | State base class |
| Create | `Scenes/Characters/Enemies/BladeKeeper/States/BKStateMachine.gd` | State machine |
| Create | `Scenes/Characters/Enemies/BladeKeeper/States/BKIdle.gd` | Idle state |
| Create | `Scenes/Characters/Enemies/BladeKeeper/States/BKChase.gd` | Chase state |
| Create | `Scenes/Characters/Enemies/BladeKeeper/States/BKAttack.gd` | 3-hit combo state |
| Create | `Scenes/Characters/Enemies/BladeKeeper/States/BKDefend.gd` | Defend + counter state |
| Create | `Scenes/Characters/Enemies/BladeKeeper/States/BKRoll.gd` | Roll dodge state |
| Create | `Scenes/Characters/Enemies/BladeKeeper/States/BKProjectile.gd` | Sword projectile cast state |
| Create | `Scenes/Characters/Enemies/BladeKeeper/States/BKTrapState.gd` | Trap cast state |
| Create | `Scenes/Characters/Enemies/BladeKeeper/States/BKSpecial.gd` | Phase 3 special attack state |
| Create | `Scenes/Characters/Enemies/BladeKeeper/States/BKStun.gd` | Stun state |
| Create | `Scenes/Characters/Enemies/BladeKeeper/Attacks/BKSwordProjectile.gd` | Flying sword entity |
| Create | `Scenes/Characters/Enemies/BladeKeeper/Attacks/BKSwordProjectile.tscn` | Flying sword scene |
| Create | `Scenes/Characters/Enemies/BladeKeeper/Attacks/BKTrap.gd` | Ground trap entity |
| Create | `Scenes/Characters/Enemies/BladeKeeper/Attacks/BKTrap.tscn` | Ground trap scene |

### DemonSlime Boss
| Action | Path | Purpose |
|--------|------|---------|
| Create | `Scenes/Characters/Enemies/DemonSlime/DemonSlimeBoss.gd` | Boss script (extends BossBase) |
| Create | `Scenes/Characters/Enemies/DemonSlime/DemonSlimeBoss.tscn` | Boss scene |
| Create | `Scenes/Characters/Enemies/DemonSlime/DemonSlimeAttackManager.gd` | Attack manager |
| Create | `Scenes/Characters/Enemies/DemonSlime/States/DSBaseState.gd` | State base class |
| Create | `Scenes/Characters/Enemies/DemonSlime/States/DSStateMachine.gd` | State machine |
| Create | `Scenes/Characters/Enemies/DemonSlime/States/DSIdle.gd` | Idle state |
| Create | `Scenes/Characters/Enemies/DemonSlime/States/DSChase.gd` | Chase state |
| Create | `Scenes/Characters/Enemies/DemonSlime/States/DSCleave.gd` | Cleave + shockwave state |
| Create | `Scenes/Characters/Enemies/DemonSlime/States/DSSlam.gd` | Jump slam state |
| Create | `Scenes/Characters/Enemies/DemonSlime/States/DSStun.gd` | Stun state |
| Create | `Scenes/Characters/Enemies/DemonSlime/Attacks/DSShockwave.gd` | Shockwave entity |
| Create | `Scenes/Characters/Enemies/DemonSlime/Attacks/DSShockwave.tscn` | Shockwave scene |
| Create | `Scenes/Characters/Enemies/DemonSlime/MiniSlime/MiniSlime.gd` | Mini slime script |
| Create | `Scenes/Characters/Enemies/DemonSlime/MiniSlime/MiniSlime.tscn` | Mini slime scene |

### Levels
| Action | Path | Purpose |
|--------|------|---------|
| Create | `Scenes/Levels/Level4_BladeKeeper/Level4.gd` | Level 4 script |
| Create | `Scenes/Levels/Level4_BladeKeeper/Level4.tscn` | Level 4 scene |
| Create | `Scenes/Levels/Level5_DemonSlime/Level5.gd` | Level 5 script |
| Create | `Scenes/Levels/Level5_DemonSlime/Level5.tscn` | Level 5 scene |
| Modify | `Core/Autoloads/LevelManager.gd:20-31` | Register Level 4 & 5 |

---

## Task 1: BladeKeeper Boss Script + SpriteFrames

**Files:**
- Create: `Scenes/Characters/Enemies/BladeKeeper/BladeKeeperBoss.gd`

- [ ] **Step 1: Create BladeKeeperBoss.gd**

```gdscript
extends BossBase
class_name BladeKeeperBoss

## BladeKeeper Boss - 技巧型剑士
## 近战连击 + 防御反击 + 翻滚闪避 + 飞剑投射 + 陷阱布置

# ============ 配置参数 ============
@export_group("Movement")
@export var base_move_speed := 180.0

# 阶段速度倍率
const PHASE_SPEED := {
	BossBase.Phase.PHASE_1: 1.0,
	BossBase.Phase.PHASE_2: 1.3,
	BossBase.Phase.PHASE_3: 1.5,
}

var move_speed: float:
	get:
		return base_move_speed * PHASE_SPEED.get(current_phase, 1.0)

# ============ 节点引用 ============
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# ============ Boss 初始化 ============
func _on_boss_ready() -> void:
	if sprite:
		sprite.play("idle")

# ============ 朝向更新 ============
func _update_facing() -> void:
	if not sprite:
		return
	if velocity.length() < 10:
		return
	sprite.flip_h = velocity.x < 0
```

- [ ] **Step 2: Create the SpriteFrames resource**

Use GDScript to load all PNG sequences from `res://Assets/Art/BLADE_KEEPER/PNG animations/`. Since the boss scene will use AnimatedSprite2D, the SpriteFrames resource will be created within the .tscn file. The animation names and their source directories:

| Animation | Directory | Frames | FPS | Loop |
|-----------|-----------|--------|-----|------|
| idle | 01_idle | 8 | 10 | yes |
| run | 02_run | 8 | 10 | yes |
| roll | 04_roll | 7 | 12 | no |
| projectile_cast | 05_projectile_cast | 7 | 10 | no |
| trap_cast | 06_trap_cast | 10 | 10 | no |
| atk_1 | 07_1_atk | 6 | 12 | no |
| atk_2 | 08_2_atk | 8 | 12 | no |
| atk_3 | 09_3_atk | 18 | 14 | no |
| sp_atk | 10_sp_atk | 11 | 12 | no |
| defend | 11_defend | 12 | 10 | no |
| take_hit | 12_take_hit | 6 | 10 | no |
| death | 13_death | 12 | 10 | no |

- [ ] **Step 3: Commit**

```bash
git add Scenes/Characters/Enemies/BladeKeeper/BladeKeeperBoss.gd
git commit -m "feat(boss): add BladeKeeperBoss script with AnimatedSprite2D support"
```

---

## Task 2: BladeKeeper State Base + State Machine

**Files:**
- Create: `Scenes/Characters/Enemies/BladeKeeper/States/BKBaseState.gd`
- Create: `Scenes/Characters/Enemies/BladeKeeper/States/BKStateMachine.gd`

- [ ] **Step 1: Create BKBaseState.gd**

This is the base for all BladeKeeper states. Unlike the existing `BossState` which caches a `Boss` typed reference, this caches `BladeKeeperBoss`. It also provides AnimatedSprite2D-based animation helpers instead of AnimationTree.

```gdscript
extends BaseState
class_name BKBaseState

## BladeKeeper 状态基类
## 提供缓存引用、距离决策、AnimatedSprite2D 动画控制

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true

# ============ 缓存引用 ============
var _bk_cache: BladeKeeperBoss

var _bk: BladeKeeperBoss:
	get:
		if not _bk_cache and owner_node is BladeKeeperBoss:
			_bk_cache = owner_node as BladeKeeperBoss
		return _bk_cache

var _attack_mgr_cache: Node

func get_attack_manager() -> Node:
	if is_instance_valid(_attack_mgr_cache):
		return _attack_mgr_cache
	if owner_node:
		_attack_mgr_cache = owner_node.get_node_or_null("BladeKeeperAttackManager")
	return _attack_mgr_cache

# ============ 动画控制（AnimatedSprite2D） ============

func play_anim(anim_name: String) -> void:
	if _bk and _bk.sprite and _bk.sprite.sprite_frames:
		if _bk.sprite.sprite_frames.has_animation(anim_name):
			_bk.sprite.play(anim_name)

func get_anim_name() -> String:
	if _bk and _bk.sprite:
		return _bk.sprite.animation
	return ""

func is_anim_playing() -> bool:
	if _bk and _bk.sprite:
		return _bk.sprite.is_playing()
	return false

# ============ 距离决策（与 BossState 相同逻辑） ============

func evaluate_combat_transition(include_attack: bool = true) -> String:
	if not _bk:
		return "idle"
	if not is_target_alive():
		return "idle"

	var distance := get_distance_to_target()

	if distance > _bk.detection_radius:
		return "idle"
	if distance <= _bk.attack_range:
		if include_attack and _bk.attack_cooldown <= 0:
			return "attack"
		return "idle"
	return "chase"

# ============ 受伤响应 ============

func on_damaged(_damage: Damage, _attacker_position: Vector2 = Vector2.ZERO) -> void:
	if not _bk:
		return
	if _bk.current_phase == BossBase.Phase.PHASE_3:
		return
	if _bk.stun_immunity > 0:
		return
	transitioned.emit(self, "stun")
```

- [ ] **Step 2: Create BKStateMachine.gd**

```gdscript
extends BaseStateMachine
class_name BKStateMachine

## BladeKeeper 状态机
## 处理阶段转换时的状态路由

var is_transitioning_phase: bool = false

func _setup_signals() -> void:
	super._setup_signals()
	if owner_node and owner_node.has_signal("phase_changed"):
		owner_node.phase_changed.connect(_on_phase_changed)

func _on_owner_damaged(damage: Damage, attacker_position: Vector2) -> void:
	if is_transitioning_phase:
		return
	super._on_owner_damaged(damage, attacker_position)

func _on_phase_changed(new_phase: int) -> void:
	is_transitioning_phase = true

	match new_phase:
		BossBase.Phase.PHASE_2:
			force_transition("chase")
		BossBase.Phase.PHASE_3:
			force_transition("attack")

	# 短暂延迟后解除转换锁定
	await owner_node.get_tree().create_timer(0.1).timeout
	is_transitioning_phase = false
```

- [ ] **Step 3: Commit**

```bash
git add Scenes/Characters/Enemies/BladeKeeper/States/BKBaseState.gd Scenes/Characters/Enemies/BladeKeeper/States/BKStateMachine.gd
git commit -m "feat(boss): add BladeKeeper state base and state machine"
```

---

## Task 3: BladeKeeper Core States (Idle, Chase, Stun)

**Files:**
- Create: `Scenes/Characters/Enemies/BladeKeeper/States/BKIdle.gd`
- Create: `Scenes/Characters/Enemies/BladeKeeper/States/BKChase.gd`
- Create: `Scenes/Characters/Enemies/BladeKeeper/States/BKStun.gd`

- [ ] **Step 1: Create BKIdle.gd**

```gdscript
extends BKBaseState

## BladeKeeper 待机状态

var idle_time := 2.0

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true

func enter() -> void:
	if _bk:
		_bk.velocity = Vector2.ZERO
	play_anim("idle")
	start_timer(idle_time, _on_idle_timeout)

func process_state(_delta: float) -> void:
	if not _bk:
		return
	# 检测玩家
	if is_target_alive():
		var dist := get_distance_to_target()
		if dist <= _bk.attack_range and _bk.attack_cooldown <= 0:
			transitioned.emit(self, "attack")
			return
		if dist <= _bk.detection_radius:
			transitioned.emit(self, "chase")
			return

func _on_idle_timeout() -> void:
	if is_target_alive() and get_distance_to_target() <= _bk.detection_radius:
		transitioned.emit(self, "chase")

func exit() -> void:
	stop_timer()
```

- [ ] **Step 2: Create BKChase.gd**

```gdscript
extends BKBaseState

## BladeKeeper 追击状态

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true

func enter() -> void:
	play_anim("run")

func physics_process_state(_delta: float) -> void:
	if not _bk:
		return

	if not is_target_alive():
		transitioned.emit(self, "idle")
		return

	var distance := get_distance_to_target()

	# 超出检测 → 返回待机
	if distance > _bk.detection_radius:
		transitioned.emit(self, "idle")
		return

	# 进入攻击范围 → 选择攻击
	if distance <= _bk.attack_range and _bk.attack_cooldown <= 0:
		transitioned.emit(self, "attack")
		return

	# 追击移动
	var direction := get_direction_to_target()
	_bk.velocity = direction * _bk.move_speed
	_bk.move_and_slide()

	# 更新朝向和动画
	update_sprite_facing(false)
	if get_anim_name() != "run":
		play_anim("run")

func exit() -> void:
	if _bk:
		_bk.velocity = Vector2.ZERO
```

- [ ] **Step 3: Create BKStun.gd**

```gdscript
extends BKBaseState

## BladeKeeper 眩晕状态

@export var stun_duration := 1.5

func _init():
	priority = StatePriority.CONTROL
	can_be_interrupted = false

func enter() -> void:
	if _bk:
		_bk.stunned = true
		_bk.velocity = Vector2.ZERO
	play_anim("take_hit")
	start_timer(stun_duration, _on_stun_timeout)

func _on_stun_timeout() -> void:
	if _bk:
		_bk.stunned = false
		_bk.stun_immunity = 1.5
	var next := evaluate_combat_transition()
	transitioned.emit(self, next)

func on_damaged(damage: Damage, _attacker_position: Vector2 = Vector2.ZERO) -> void:
	# 眩晕中被击中重置计时器
	if damage.has_effect(StunEffect):
		start_timer(stun_duration, _on_stun_timeout)

func exit() -> void:
	stop_timer()
	if _bk:
		_bk.stunned = false
```

- [ ] **Step 4: Commit**

```bash
git add Scenes/Characters/Enemies/BladeKeeper/States/BKIdle.gd Scenes/Characters/Enemies/BladeKeeper/States/BKChase.gd Scenes/Characters/Enemies/BladeKeeper/States/BKStun.gd
git commit -m "feat(boss): add BladeKeeper idle, chase, and stun states"
```

---

## Task 4: BladeKeeper Attack Manager

**Files:**
- Create: `Scenes/Characters/Enemies/BladeKeeper/BladeKeeperAttackManager.gd`

- [ ] **Step 1: Create BladeKeeperAttackManager.gd**

```gdscript
extends Node
class_name BladeKeeperAttackManager

## BladeKeeper 攻击管理器
## 管理攻击选择逻辑（按阶段+距离权重）和攻击实体生成

@export var sword_projectile_scene: PackedScene
@export var trap_scene: PackedScene
@export var sword_damage: Damage
@export var trap_damage: Damage
@export var melee_damage: Damage

var boss: BladeKeeperBoss
var _active_traps: Array[Node] = []
const MAX_TRAPS := 3

# ============ 近距离攻击池（按阶段） ============
# 返回状态名
var _melee_pools: Dictionary = {
	BossBase.Phase.PHASE_1: [
		{ "state": "attack", "weight": 80 },
		{ "state": "defend", "weight": 20 },
	],
	BossBase.Phase.PHASE_2: [
		{ "state": "attack", "weight": 50 },
		{ "state": "defend", "weight": 20 },
		{ "state": "roll", "weight": 30 },
	],
	BossBase.Phase.PHASE_3: [
		{ "state": "attack", "weight": 40 },
		{ "state": "special", "weight": 20 },
		{ "state": "defend", "weight": 20 },
		{ "state": "roll", "weight": 20 },
	],
}

# ============ 远距离攻击池（Phase 2+） ============
var _ranged_pools: Dictionary = {
	BossBase.Phase.PHASE_2: [
		{ "state": "projectile", "weight": 60 },
		{ "state": "trap", "weight": 40 },
	],
	BossBase.Phase.PHASE_3: [
		{ "state": "projectile", "weight": 50 },
		{ "state": "trap", "weight": 50 },
	],
}

# ============ 冷却（按阶段） ============
var _cooldowns: Dictionary = {
	BossBase.Phase.PHASE_1: 1.5,
	BossBase.Phase.PHASE_2: 1.2,
	BossBase.Phase.PHASE_3: 1.0,
}

func _ready() -> void:
	boss = get_parent() as BladeKeeperBoss

# ============ 攻击选择 ============

## 根据阶段和距离选择下一个攻击状态
func pick_attack_state(distance: float) -> String:
	if not boss:
		return "attack"

	var phase := boss.current_phase
	var is_close := distance <= boss.attack_range

	if is_close:
		return _weighted_pick(_melee_pools.get(phase, _melee_pools[BossBase.Phase.PHASE_1]))
	else:
		# 远距离：Phase 2+ 有远程攻击
		if _ranged_pools.has(phase):
			return _weighted_pick(_ranged_pools[phase])
		return "chase"

## 获取当前阶段冷却时间
func get_cooldown() -> float:
	if not boss:
		return 1.5
	return _cooldowns.get(boss.current_phase, 1.5)

# ============ 攻击实体生成 ============

## 发射飞剑
func fire_sword_projectile(target_pos: Vector2) -> void:
	if not sword_projectile_scene or not boss:
		return
	var proj := sword_projectile_scene.instantiate()
	proj.global_position = boss.global_position
	var dir := (target_pos - boss.global_position).normalized()
	boss.get_parent().add_child(proj)
	proj.set_direction(dir)
	if sword_damage and "damage_config" in proj:
		proj.damage_config = sword_damage

## 放置陷阱
func place_trap(target_pos: Vector2) -> void:
	if not trap_scene or not boss:
		return
	# 清理超出上限的旧陷阱
	_cleanup_invalid_traps()
	if _active_traps.size() >= MAX_TRAPS:
		var oldest := _active_traps.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	var trap := trap_scene.instantiate()
	trap.global_position = target_pos
	if trap_damage and "damage_config" in trap:
		trap.damage_config = trap_damage
	boss.get_parent().add_child(trap)
	_active_traps.append(trap)

func _cleanup_invalid_traps() -> void:
	_active_traps = _active_traps.filter(func(t): return is_instance_valid(t))

# ============ 工具方法 ============

func _weighted_pick(pool: Array) -> String:
	var total_weight := 0
	for entry in pool:
		total_weight += entry["weight"]
	var roll := randi() % total_weight
	var cumulative := 0
	for entry in pool:
		cumulative += entry["weight"]
		if roll < cumulative:
			return entry["state"]
	return pool[0]["state"]

## 获取缓存的玩家引用
var _cached_player: Node = null

func get_player() -> Node:
	if not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
	return _cached_player
```

- [ ] **Step 2: Commit**

```bash
git add Scenes/Characters/Enemies/BladeKeeper/BladeKeeperAttackManager.gd
git commit -m "feat(boss): add BladeKeeper attack manager with weighted phase pools"
```

---

## Task 5: BladeKeeper Attack States (Attack, Defend, Roll)

**Files:**
- Create: `Scenes/Characters/Enemies/BladeKeeper/States/BKAttack.gd`
- Create: `Scenes/Characters/Enemies/BladeKeeper/States/BKDefend.gd`
- Create: `Scenes/Characters/Enemies/BladeKeeper/States/BKRoll.gd`

- [ ] **Step 1: Create BKAttack.gd (3-hit combo)**

```gdscript
extends BKBaseState

## BladeKeeper 3段连击状态
## atk_1 → atk_2 → atk_3，每段之间可被打断

var _combo_step := 0
const COMBO_ANIMS := ["atk_1", "atk_2", "atk_3"]

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true

func enter() -> void:
	_combo_step = 0
	if _bk:
		_bk.velocity = Vector2.ZERO
		update_sprite_facing(false)
	_play_combo_step()

func _play_combo_step() -> void:
	if _combo_step >= COMBO_ANIMS.size():
		_finish_attack()
		return
	play_anim(COMBO_ANIMS[_combo_step])
	if _bk and _bk.sprite:
		if not _bk.sprite.animation_finished.is_connected(_on_anim_finished):
			_bk.sprite.animation_finished.connect(_on_anim_finished)

func _on_anim_finished() -> void:
	_combo_step += 1
	if _combo_step < COMBO_ANIMS.size():
		# 检查玩家是否还在范围内
		if is_target_alive() and get_distance_to_target() <= _bk.attack_range * 1.5:
			_play_combo_step()
		else:
			_finish_attack()
	else:
		_finish_attack()

func _finish_attack() -> void:
	if _bk:
		_bk.attack_cooldown = get_attack_manager().get_cooldown() if get_attack_manager() else 1.5
	# 在连击中段对近距离玩家造成伤害
	_try_melee_damage()
	var next := evaluate_combat_transition()
	transitioned.emit(self, next)

## 近战伤害判定（在攻击动画播放时由 HitBoxComponent 处理）
## 此方法作为额外伤害保障
func _try_melee_damage() -> void:
	if not is_target_alive() or not _bk:
		return
	var mgr := get_attack_manager()
	if not mgr or not "melee_damage" in mgr or not mgr.melee_damage:
		return
	var dist := get_distance_to_target()
	if dist > _bk.attack_range:
		return
	var hurtbox: HurtBoxComponent = target_node.get_node_or_null("HurtBoxComponent")
	if hurtbox:
		var dmg := mgr.melee_damage.duplicate(true)
		dmg.randomize_damage()
		hurtbox.take_damage(dmg, _bk.global_position)

func exit() -> void:
	if _bk and _bk.sprite and _bk.sprite.animation_finished.is_connected(_on_anim_finished):
		_bk.sprite.animation_finished.disconnect(_on_anim_finished)
```

- [ ] **Step 2: Create BKDefend.gd (defend + counter)**

```gdscript
extends BKBaseState

## BladeKeeper 防御反击状态
## 举盾防御 1-2秒，期间受击伤害减半，防御结束 → sp_atk 反击

@export var defend_duration := 1.5
var _defending := false
var _original_health_modifier: float = 1.0

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true

func enter() -> void:
	_defending = true
	if _bk:
		_bk.velocity = Vector2.ZERO
		update_sprite_facing(false)
	play_anim("defend")

	# 启用减伤（通过修改 HealthComponent 的 damage_multiplier 如果有的话）
	# 简单实现：在 on_damaged 中减半
	start_timer(defend_duration, _on_defend_timeout)

func _on_defend_timeout() -> void:
	_defending = false
	# 反击：播放 sp_atk
	play_anim("sp_atk")
	if _bk and _bk.sprite:
		if not _bk.sprite.animation_finished.is_connected(_on_counter_finished):
			_bk.sprite.animation_finished.connect(_on_counter_finished)

	# 反击伤害
	_try_counter_damage()

func _try_counter_damage() -> void:
	if not is_target_alive() or not _bk:
		return
	var dist := get_distance_to_target()
	if dist > _bk.attack_range * 1.2:
		return
	var mgr := get_attack_manager()
	if not mgr or not "melee_damage" in mgr or not mgr.melee_damage:
		return
	var hurtbox: HurtBoxComponent = target_node.get_node_or_null("HurtBoxComponent")
	if hurtbox:
		var dmg := mgr.melee_damage.duplicate(true)
		dmg.amount *= 1.5  # 反击伤害加成
		dmg.min_amount *= 1.5
		dmg.max_amount *= 1.5
		dmg.randomize_damage()
		hurtbox.take_damage(dmg, _bk.global_position)

func _on_counter_finished() -> void:
	if _bk:
		_bk.attack_cooldown = get_attack_manager().get_cooldown() if get_attack_manager() else 1.5
	var next := evaluate_combat_transition()
	transitioned.emit(self, next)

func on_damaged(damage: Damage, attacker_position: Vector2 = Vector2.ZERO) -> void:
	if _defending:
		# 防御中：减半伤害（通过治疗弥补）
		if _bk and _bk.health_component:
			var heal_amount := damage.amount * 0.5
			_bk.health_component.heal(heal_amount)
		return
	# 非防御阶段被打仍可眩晕
	super.on_damaged(damage, attacker_position)

func exit() -> void:
	stop_timer()
	_defending = false
	if _bk and _bk.sprite and _bk.sprite.animation_finished.is_connected(_on_counter_finished):
		_bk.sprite.animation_finished.disconnect(_on_counter_finished)
```

- [ ] **Step 3: Create BKRoll.gd (roll dodge)**

```gdscript
extends BKBaseState

## BladeKeeper 翻滚闪避状态
## 向玩家侧方翻滚，拉开距离后转入 projectile 或 trap

@export var roll_speed := 250.0

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = false

func enter() -> void:
	if not _bk or not is_target_alive():
		transitioned.emit(self, "idle")
		return

	# 计算侧方方向（垂直于朝向玩家的方向）
	var to_player := get_direction_to_target()
	var side_dir := Vector2(-to_player.y, to_player.x)  # 左侧垂直
	if randf() > 0.5:
		side_dir = -side_dir  # 50% 概率翻到右侧

	_bk.velocity = side_dir * roll_speed
	update_sprite_facing(false)
	play_anim("roll")

	if _bk.sprite:
		if not _bk.sprite.animation_finished.is_connected(_on_roll_finished):
			_bk.sprite.animation_finished.connect(_on_roll_finished)

func physics_process_state(delta: float) -> void:
	if _bk:
		_bk.move_and_slide()
		# 减速
		_bk.velocity = _bk.velocity.lerp(Vector2.ZERO, 5.0 * delta)

func _on_roll_finished() -> void:
	if not _bk:
		transitioned.emit(self, "idle")
		return

	# 翻滚后转入远程攻击
	var mgr := get_attack_manager() as BladeKeeperAttackManager
	if mgr and _bk.current_phase != BossBase.Phase.PHASE_1:
		var choices := ["projectile", "trap"]
		transitioned.emit(self, choices.pick_random())
	else:
		var next := evaluate_combat_transition()
		transitioned.emit(self, next)

func on_damaged(_damage: Damage, _attacker_position: Vector2 = Vector2.ZERO) -> void:
	pass  # 翻滚中无敌

func exit() -> void:
	if _bk and _bk.sprite and _bk.sprite.animation_finished.is_connected(_on_roll_finished):
		_bk.sprite.animation_finished.disconnect(_on_roll_finished)
	if _bk:
		_bk.velocity = Vector2.ZERO
```

- [ ] **Step 4: Commit**

```bash
git add Scenes/Characters/Enemies/BladeKeeper/States/BKAttack.gd Scenes/Characters/Enemies/BladeKeeper/States/BKDefend.gd Scenes/Characters/Enemies/BladeKeeper/States/BKRoll.gd
git commit -m "feat(boss): add BladeKeeper attack, defend, and roll states"
```

---

## Task 6: BladeKeeper Ranged States (Projectile, Trap, Special)

**Files:**
- Create: `Scenes/Characters/Enemies/BladeKeeper/States/BKProjectile.gd`
- Create: `Scenes/Characters/Enemies/BladeKeeper/States/BKTrapState.gd`
- Create: `Scenes/Characters/Enemies/BladeKeeper/States/BKSpecial.gd`

- [ ] **Step 1: Create BKProjectile.gd**

```gdscript
extends BKBaseState

## BladeKeeper 飞剑投射状态

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true

func enter() -> void:
	if not _bk or not is_target_alive():
		transitioned.emit(self, "idle")
		return

	_bk.velocity = Vector2.ZERO
	update_sprite_facing(false)
	play_anim("projectile_cast")

	if _bk.sprite:
		if not _bk.sprite.animation_finished.is_connected(_on_cast_finished):
			_bk.sprite.animation_finished.connect(_on_cast_finished)

func _on_cast_finished() -> void:
	# 发射飞剑
	var mgr := get_attack_manager() as BladeKeeperAttackManager
	if mgr and is_target_alive():
		mgr.fire_sword_projectile(target_node.global_position)

	if _bk:
		_bk.attack_cooldown = mgr.get_cooldown() if mgr else 1.2
	var next := evaluate_combat_transition()
	transitioned.emit(self, next)

func exit() -> void:
	if _bk and _bk.sprite and _bk.sprite.animation_finished.is_connected(_on_cast_finished):
		_bk.sprite.animation_finished.disconnect(_on_cast_finished)
```

- [ ] **Step 2: Create BKTrapState.gd**

```gdscript
extends BKBaseState

## BladeKeeper 陷阱布置状态

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true

func enter() -> void:
	if not _bk or not is_target_alive():
		transitioned.emit(self, "idle")
		return

	_bk.velocity = Vector2.ZERO
	update_sprite_facing(false)
	play_anim("trap_cast")

	if _bk.sprite:
		if not _bk.sprite.animation_finished.is_connected(_on_cast_finished):
			_bk.sprite.animation_finished.connect(_on_cast_finished)

func _on_cast_finished() -> void:
	var mgr := get_attack_manager() as BladeKeeperAttackManager
	if mgr and is_target_alive():
		# 在玩家当前位置或附近放置陷阱
		var trap_pos: Vector2 = target_node.global_position
		# 添加少量随机偏移
		trap_pos += Vector2(randf_range(-30, 30), randf_range(-20, 20))
		mgr.place_trap(trap_pos)

	if _bk:
		_bk.attack_cooldown = mgr.get_cooldown() if mgr else 1.2
	var next := evaluate_combat_transition()
	transitioned.emit(self, next)

func exit() -> void:
	if _bk and _bk.sprite and _bk.sprite.animation_finished.is_connected(_on_cast_finished):
		_bk.sprite.animation_finished.disconnect(_on_cast_finished)
```

- [ ] **Step 3: Create BKSpecial.gd (Phase 3 only)**

```gdscript
extends BKBaseState

## BladeKeeper Phase 3 专属特殊攻击
## 播放 sp_atk 动画，大范围剑气攻击

@export var special_damage_multiplier := 2.0
@export var special_range := 300.0

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = false

func enter() -> void:
	if not _bk:
		transitioned.emit(self, "idle")
		return

	_bk.velocity = Vector2.ZERO
	update_sprite_facing(false)
	play_anim("sp_atk")

	if _bk.sprite:
		if not _bk.sprite.animation_finished.is_connected(_on_special_finished):
			_bk.sprite.animation_finished.connect(_on_special_finished)

func _on_special_finished() -> void:
	# 大范围伤害判定
	_apply_special_damage()

	if _bk:
		var mgr := get_attack_manager() as BladeKeeperAttackManager
		_bk.attack_cooldown = mgr.get_cooldown() if mgr else 1.0
	var next := evaluate_combat_transition()
	transitioned.emit(self, next)

func _apply_special_damage() -> void:
	if not is_target_alive() or not _bk:
		return
	var dist := get_distance_to_target()
	if dist > special_range:
		return
	var mgr := get_attack_manager() as BladeKeeperAttackManager
	if not mgr or not mgr.melee_damage:
		return
	var hurtbox: HurtBoxComponent = target_node.get_node_or_null("HurtBoxComponent")
	if hurtbox:
		var dmg := mgr.melee_damage.duplicate(true)
		dmg.amount *= special_damage_multiplier
		dmg.min_amount *= special_damage_multiplier
		dmg.max_amount *= special_damage_multiplier
		var kb := KnockBackEffect.new()
		kb.knockback_force = 300.0
		dmg.effects.append(kb)
		dmg.randomize_damage()
		hurtbox.take_damage(dmg, _bk.global_position)

func on_damaged(_damage: Damage, _attacker_position: Vector2 = Vector2.ZERO) -> void:
	pass  # 特殊攻击中无敌

func exit() -> void:
	if _bk and _bk.sprite and _bk.sprite.animation_finished.is_connected(_on_special_finished):
		_bk.sprite.animation_finished.disconnect(_on_special_finished)
```

- [ ] **Step 4: Commit**

```bash
git add Scenes/Characters/Enemies/BladeKeeper/States/BKProjectile.gd Scenes/Characters/Enemies/BladeKeeper/States/BKTrapState.gd Scenes/Characters/Enemies/BladeKeeper/States/BKSpecial.gd
git commit -m "feat(boss): add BladeKeeper projectile, trap, and special states"
```

---

## Task 7: BladeKeeper Attack Entities (Sword Projectile + Trap)

**Files:**
- Create: `Scenes/Characters/Enemies/BladeKeeper/Attacks/BKSwordProjectile.gd`
- Create: `Scenes/Characters/Enemies/BladeKeeper/Attacks/BKSwordProjectile.tscn`
- Create: `Scenes/Characters/Enemies/BladeKeeper/Attacks/BKTrap.gd`
- Create: `Scenes/Characters/Enemies/BladeKeeper/Attacks/BKTrap.tscn`

- [ ] **Step 1: Create BKSwordProjectile.gd**

Follows the same pattern as `BossProjectile.gd`: Area2D with HitBoxComponent child, speed-based movement, lifetime auto-destroy.

```gdscript
extends Area2D
class_name BKSwordProjectile

## BladeKeeper 飞剑投射物
## 直线飞行，碰到玩家/墙壁消失

@export var speed := 400.0
@export var lifetime := 4.0
@export var damage_config: Damage

var direction := Vector2.RIGHT

@onready var hitbox: HitBoxComponent = $HitBoxComponent
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)

	if damage_config and hitbox:
		hitbox.damage = damage_config

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()
	rotation = direction.angle()

func _on_hitbox_hit() -> void:
	queue_free()
```

- [ ] **Step 2: Create BKSwordProjectile.tscn**

Scene structure mirrors `BossProjectile.tscn`:
- Root: Area2D (collision_layer=0, collision_mask=0)
  - Sprite2D (use `res://Assets/Art/BLADE_KEEPER/PNG animations/projectile_and_trap/projectile_throw/projectile_throw_1.png`)
  - HitBoxComponent (Area2D, collision_layer=16, collision_mask=2)
    - CollisionShape2D (CircleShape2D, radius=10)

Build using `mcp__godot__create_scene` + `mcp__godot__add_node` + `mcp__godot__save_scene`, or write the .tscn file directly:

```ini
[gd_scene format=3]

[ext_resource type="Script" path="res://Scenes/Characters/Enemies/BladeKeeper/Attacks/BKSwordProjectile.gd" id="1_script"]
[ext_resource type="Script" uid="uid://cu68vwy5tvkr4" path="res://Core/Components/HitBoxComponent.gd" id="2_hitbox"]
[ext_resource type="Texture2D" path="res://Assets/Art/BLADE_KEEPER/PNG animations/projectile_and_trap/projectile_throw/projectile_throw_1.png" id="3_texture"]

[sub_resource type="CircleShape2D" id="CircleShape2D_proj"]
radius = 10.0

[node name="BKSwordProjectile" type="Area2D"]
collision_layer = 0
collision_mask = 0
script = ExtResource("1_script")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("3_texture")
scale = Vector2(1.5, 1.5)

[node name="HitBoxComponent" type="Area2D" parent="."]
collision_layer = 16
collision_mask = 2
script = ExtResource("2_hitbox")

[node name="CollisionShape2D" type="CollisionShape2D" parent="HitBoxComponent"]
shape = SubResource("CircleShape2D_proj")

[connection signal="area_entered" from="HitBoxComponent" to="." method="_on_hitbox_hit"]
```

- [ ] **Step 3: Create BKTrap.gd**

```gdscript
extends Area2D
class_name BKTrap

## BladeKeeper 地面陷阱
## 放置后半透明，玩家踩到触发爆炸伤害 + ForceStunEffect

@export var trap_lifetime := 8.0
@export var damage_config: Damage
@export var stun_duration := 0.5

var _triggered := false

@onready var hitbox: Area2D = $DetectionArea
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# 半透明
	modulate = Color(1, 1, 1, 0.3)

	# 生命周期
	var timer := get_tree().create_timer(trap_lifetime)
	timer.timeout.connect(_expire)

	# 检测玩家踩踏
	hitbox.area_entered.connect(_on_player_entered)

	# 落地动画
	_play_land_anim()

func _play_land_anim() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.3, 0.2).from(0.8)

func _on_player_entered(area: Area2D) -> void:
	if _triggered:
		return
	if area is HurtBoxComponent:
		_triggered = true
		_detonate(area as HurtBoxComponent)

func _detonate(hurtbox: HurtBoxComponent) -> void:
	# 显示陷阱
	modulate = Color(1, 1, 1, 1.0)

	# 造成伤害
	var dmg: Damage
	if damage_config:
		dmg = damage_config.duplicate(true)
		dmg.randomize_damage()
	else:
		dmg = Damage.new()
		dmg.amount = 15.0
		dmg.min_amount = 10.0
		dmg.max_amount = 20.0
		dmg.randomize_damage()

	# 添加短暂定身效果
	var stun_effect := ForceStunEffect.new()
	stun_effect.stun_duration = stun_duration
	dmg.effects.append(stun_effect)

	hurtbox.take_damage(dmg, global_position)

	# 爆炸粒子
	VfxHelper.spawn_burst(get_parent(), global_position,
		"res://Assets/Art/FX/Particle/Spark.png", 8, Color(1.5, 0.8, 0.2), 80.0)

	# 爆炸动画后销毁
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)

func _expire() -> void:
	if _triggered:
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
```

- [ ] **Step 4: Create BKTrap.tscn**

```ini
[gd_scene format=3]

[ext_resource type="Script" path="res://Scenes/Characters/Enemies/BladeKeeper/Attacks/BKTrap.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://Assets/Art/BLADE_KEEPER/PNG animations/projectile_and_trap/trap_throw/trap_throw_1.png" id="2_texture"]

[sub_resource type="CircleShape2D" id="CircleShape2D_detect"]
radius = 15.0

[node name="BKTrap" type="Area2D"]
collision_layer = 0
collision_mask = 0
script = ExtResource("1_script")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2_texture")
scale = Vector2(1.5, 1.5)

[node name="DetectionArea" type="Area2D" parent="."]
collision_layer = 16
collision_mask = 2

[node name="CollisionShape2D" type="CollisionShape2D" parent="DetectionArea"]
shape = SubResource("CircleShape2D_detect")
```

- [ ] **Step 5: Commit**

```bash
git add Scenes/Characters/Enemies/BladeKeeper/Attacks/
git commit -m "feat(boss): add BladeKeeper sword projectile and trap attack entities"
```

---

## Task 8: BladeKeeper Boss Scene (.tscn)

**Files:**
- Create: `Scenes/Characters/Enemies/BladeKeeper/BladeKeeperBoss.tscn`

- [ ] **Step 1: Create the scene**

The BladeKeeper scene does NOT inherit from BossBase.tscn because it uses AnimatedSprite2D instead of Sprite2D + AnimationTree. Build it from scratch as a CharacterBody2D with all required components.

Node hierarchy:
```
BladeKeeperBoss (CharacterBody2D, group="enemy")
├── AnimatedSprite2D (SpriteFrames with all BK animations)
├── CollisionShape2D (RectangleShape2D 40x56)
├── DamageNumbersAnchor (Node2D, y=-40)
├── HurtBoxComponent (Area2D, collision_layer=8, mask=0)
│   └── CollisionShape2D (RectangleShape2D 40x52)
├── HitBoxComponent (Area2D, collision_layer=16, mask=2)
│   └── CollisionShape2D (RectangleShape2D 36x48, disabled by default)
├── HealthComponent (Node, max_health=1000, health=1000)
├── HealthBar (ProgressBar, same inline script as BossBase.tscn)
├── BladeKeeperAttackManager (Node)
└── StateMachine (BKStateMachine, init_state=Idle)
    ├── Idle (BKIdle)
    ├── Chase (BKChase)
    ├── Attack (BKAttack)
    ├── Defend (BKDefend)
    ├── Roll (BKRoll)
    ├── Projectile (BKProjectile)
    ├── Trap (BKTrapState)
    ├── Special (BKSpecial)
    └── Stun (BKStun)
```

Key properties:
- `collision_layer = 8` (enemy), `collision_mask = 128` (walls)
- Script: `BladeKeeperBoss.gd`
- `max_health = 1000`, `health = 1000`
- `detection_radius = 800`, `attack_range = 200`, `min_distance = 100`
- `base_move_speed = 180`

The SpriteFrames resource must be created with all animations loaded from `res://Assets/Art/BLADE_KEEPER/PNG animations/` directories. Each animation loads its frames in filename order.

Use MCP tools (`mcp__godot__create_scene`, `mcp__godot__add_node`, `mcp__godot__save_scene`) to build the scene, OR write the .tscn file directly. The .tscn approach is more reliable for complex scenes.

The HitBoxComponent is for melee attacks — it should be disabled by default and enabled during attack animations via animation signals or state code.

- [ ] **Step 2: Verify the scene loads**

```bash
# Validate scene can be opened without errors
godot --headless --path . --quit 2>&1 | head -20
```

- [ ] **Step 3: Commit**

```bash
git add Scenes/Characters/Enemies/BladeKeeper/BladeKeeperBoss.tscn
git commit -m "feat(boss): add BladeKeeper boss scene with AnimatedSprite2D"
```

---

## Task 9: DemonSlime Boss Script

**Files:**
- Create: `Scenes/Characters/Enemies/DemonSlime/DemonSlimeBoss.gd`

- [ ] **Step 1: Create DemonSlimeBoss.gd**

```gdscript
extends BossBase
class_name DemonSlimeBoss

## DemonSlime Boss - 力量型恶魔史莱姆
## 慢速重击，劈砍冲击波 + 阶段分裂小史莱姆

# ============ 配置参数 ============
@export_group("Movement")
@export var base_move_speed := 80.0

# 阶段速度倍率
const PHASE_SPEED := {
	BossBase.Phase.PHASE_1: 1.0,
	BossBase.Phase.PHASE_2: 1.3,
	BossBase.Phase.PHASE_3: 1.5,
}

var move_speed: float:
	get:
		return base_move_speed * PHASE_SPEED.get(current_phase, 1.0)

@export_group("Minions")
@export var mini_slime_scene: PackedScene
@export var phase_2_spawn_count := 2
@export var phase_3_spawn_count := 3
@export var spawn_radius := 80.0

# ============ 节点引用 ============
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# ============ 运行时 ============
var _mini_slimes: Array[Node] = []

# ============ Boss 初始化 ============
func _on_boss_ready() -> void:
	if sprite:
		sprite.play("idle")

# ============ 朝向更新 ============
func _update_facing() -> void:
	if not sprite:
		return
	if velocity.length() < 10:
		return
	sprite.flip_h = velocity.x < 0

# ============ 阶段转换 ============
func _on_phase_transition() -> void:
	match current_phase:
		Phase.PHASE_2:
			_spawn_mini_slimes(phase_2_spawn_count)
		Phase.PHASE_3:
			_spawn_mini_slimes(phase_3_spawn_count)

# ============ 小史莱姆生成 ============
func _spawn_mini_slimes(count: int) -> void:
	if not mini_slime_scene:
		return
	_cleanup_dead_slimes()

	for i in count:
		var mini := mini_slime_scene.instantiate()
		var angle := randf() * TAU
		var offset := Vector2(cos(angle), sin(angle)) * spawn_radius
		mini.global_position = global_position + offset
		get_parent().add_child(mini)
		_mini_slimes.append(mini)

		# 生成动画：从0缩放到1
		mini.scale = Vector2.ZERO
		var tween := mini.create_tween()
		tween.tween_property(mini, "scale", Vector2(0.4, 0.4), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _cleanup_dead_slimes() -> void:
	_mini_slimes = _mini_slimes.filter(func(s): return is_instance_valid(s))

# ============ 死亡处理 ============
func _handle_death() -> void:
	# 清除所有小史莱姆
	for mini in _mini_slimes:
		if is_instance_valid(mini):
			var tween := mini.create_tween()
			tween.tween_property(mini, "modulate:a", 0.0, 0.3)
			tween.tween_callback(mini.queue_free)
	_mini_slimes.clear()

	# 调用父类死亡
	super._handle_death()
```

- [ ] **Step 2: Commit**

```bash
git add Scenes/Characters/Enemies/DemonSlime/DemonSlimeBoss.gd
git commit -m "feat(boss): add DemonSlimeBoss script with phase-based slime spawning"
```

---

## Task 10: DemonSlime State Base + State Machine

**Files:**
- Create: `Scenes/Characters/Enemies/DemonSlime/States/DSBaseState.gd`
- Create: `Scenes/Characters/Enemies/DemonSlime/States/DSStateMachine.gd`

- [ ] **Step 1: Create DSBaseState.gd**

```gdscript
extends BaseState
class_name DSBaseState

## DemonSlime 状态基类

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true

# ============ 缓存引用 ============
var _ds_cache: DemonSlimeBoss

var _ds: DemonSlimeBoss:
	get:
		if not _ds_cache and owner_node is DemonSlimeBoss:
			_ds_cache = owner_node as DemonSlimeBoss
		return _ds_cache

var _attack_mgr_cache: Node

func get_attack_manager() -> Node:
	if is_instance_valid(_attack_mgr_cache):
		return _attack_mgr_cache
	if owner_node:
		_attack_mgr_cache = owner_node.get_node_or_null("DemonSlimeAttackManager")
	return _attack_mgr_cache

# ============ 动画控制 ============

func play_anim(anim_name: String) -> void:
	if _ds and _ds.sprite and _ds.sprite.sprite_frames:
		if _ds.sprite.sprite_frames.has_animation(anim_name):
			_ds.sprite.play(anim_name)

func get_anim_name() -> String:
	if _ds and _ds.sprite:
		return _ds.sprite.animation
	return ""

func is_anim_playing() -> bool:
	if _ds and _ds.sprite:
		return _ds.sprite.is_playing()
	return false

# ============ 距离决策 ============

func evaluate_combat_transition(include_attack: bool = true) -> String:
	if not _ds:
		return "idle"
	if not is_target_alive():
		return "idle"

	var distance := get_distance_to_target()
	if distance > _ds.detection_radius:
		return "idle"
	if distance <= _ds.attack_range:
		if include_attack and _ds.attack_cooldown <= 0:
			return "attack"
		return "idle"
	return "chase"

# ============ 攻击选择（返回具体攻击状态名） ============

func pick_attack_state() -> String:
	var mgr := get_attack_manager() as DemonSlimeAttackManager
	if mgr:
		return mgr.pick_attack_state()
	return "cleave"

# ============ 受伤响应 ============

func on_damaged(_damage: Damage, _attacker_position: Vector2 = Vector2.ZERO) -> void:
	if not _ds:
		return
	if _ds.current_phase == BossBase.Phase.PHASE_3:
		return
	if _ds.stun_immunity > 0:
		return
	transitioned.emit(self, "stun")
```

- [ ] **Step 2: Create DSStateMachine.gd**

```gdscript
extends BaseStateMachine
class_name DSStateMachine

## DemonSlime 状态机

var is_transitioning_phase: bool = false

func _setup_signals() -> void:
	super._setup_signals()
	if owner_node and owner_node.has_signal("phase_changed"):
		owner_node.phase_changed.connect(_on_phase_changed)

func _on_owner_damaged(damage: Damage, attacker_position: Vector2) -> void:
	if is_transitioning_phase:
		return
	super._on_owner_damaged(damage, attacker_position)

func _on_phase_changed(new_phase: int) -> void:
	is_transitioning_phase = true

	match new_phase:
		BossBase.Phase.PHASE_2:
			force_transition("chase")
		BossBase.Phase.PHASE_3:
			force_transition("cleave")

	await owner_node.get_tree().create_timer(0.1).timeout
	is_transitioning_phase = false
```

- [ ] **Step 3: Commit**

```bash
git add Scenes/Characters/Enemies/DemonSlime/States/DSBaseState.gd Scenes/Characters/Enemies/DemonSlime/States/DSStateMachine.gd
git commit -m "feat(boss): add DemonSlime state base and state machine"
```

---

## Task 11: DemonSlime Core States (Idle, Chase, Stun)

**Files:**
- Create: `Scenes/Characters/Enemies/DemonSlime/States/DSIdle.gd`
- Create: `Scenes/Characters/Enemies/DemonSlime/States/DSChase.gd`
- Create: `Scenes/Characters/Enemies/DemonSlime/States/DSStun.gd`

- [ ] **Step 1: Create DSIdle.gd**

```gdscript
extends DSBaseState

## DemonSlime 待机状态

var idle_time := 2.0

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true

func enter() -> void:
	if _ds:
		_ds.velocity = Vector2.ZERO
	play_anim("idle")
	start_timer(idle_time, _on_idle_timeout)

func process_state(_delta: float) -> void:
	if not _ds:
		return
	if is_target_alive():
		var dist := get_distance_to_target()
		if dist <= _ds.attack_range and _ds.attack_cooldown <= 0:
			var attack_state := pick_attack_state()
			transitioned.emit(self, attack_state)
			return
		if dist <= _ds.detection_radius:
			transitioned.emit(self, "chase")
			return

func _on_idle_timeout() -> void:
	if is_target_alive() and get_distance_to_target() <= _ds.detection_radius:
		transitioned.emit(self, "chase")

func exit() -> void:
	stop_timer()
```

- [ ] **Step 2: Create DSChase.gd**

```gdscript
extends DSBaseState

## DemonSlime 追击状态

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true

func enter() -> void:
	play_anim("walk")

func physics_process_state(_delta: float) -> void:
	if not _ds:
		return

	if not is_target_alive():
		transitioned.emit(self, "idle")
		return

	var distance := get_distance_to_target()

	if distance > _ds.detection_radius:
		transitioned.emit(self, "idle")
		return

	# 进入攻击范围
	if distance <= _ds.attack_range and _ds.attack_cooldown <= 0:
		var attack_state := pick_attack_state()
		transitioned.emit(self, attack_state)
		return

	# 追击
	var direction := get_direction_to_target()
	_ds.velocity = direction * _ds.move_speed
	_ds.move_and_slide()

	update_sprite_facing(false)
	if get_anim_name() != "walk":
		play_anim("walk")

func exit() -> void:
	if _ds:
		_ds.velocity = Vector2.ZERO
```

- [ ] **Step 3: Create DSStun.gd**

```gdscript
extends DSBaseState

## DemonSlime 眩晕状态

@export var stun_duration := 1.5

func _init():
	priority = StatePriority.CONTROL
	can_be_interrupted = false

func enter() -> void:
	if _ds:
		_ds.stunned = true
		_ds.velocity = Vector2.ZERO
	play_anim("take_hit")
	start_timer(stun_duration, _on_stun_timeout)

func _on_stun_timeout() -> void:
	if _ds:
		_ds.stunned = false
		_ds.stun_immunity = 1.5
	var next := evaluate_combat_transition()
	transitioned.emit(self, next)

func on_damaged(damage: Damage, _attacker_position: Vector2 = Vector2.ZERO) -> void:
	if damage.has_effect(StunEffect):
		start_timer(stun_duration, _on_stun_timeout)

func exit() -> void:
	stop_timer()
	if _ds:
		_ds.stunned = false
```

- [ ] **Step 4: Commit**

```bash
git add Scenes/Characters/Enemies/DemonSlime/States/DSIdle.gd Scenes/Characters/Enemies/DemonSlime/States/DSChase.gd Scenes/Characters/Enemies/DemonSlime/States/DSStun.gd
git commit -m "feat(boss): add DemonSlime idle, chase, and stun states"
```

---

## Task 12: DemonSlime Attack Manager

**Files:**
- Create: `Scenes/Characters/Enemies/DemonSlime/DemonSlimeAttackManager.gd`

- [ ] **Step 1: Create DemonSlimeAttackManager.gd**

```gdscript
extends Node
class_name DemonSlimeAttackManager

## DemonSlime 攻击管理器

@export var shockwave_scene: PackedScene
@export var cleave_damage: Damage
@export var slam_damage: Damage

var boss: DemonSlimeBoss

# 攻击池（按阶段）
var _attack_pools: Dictionary = {
	BossBase.Phase.PHASE_1: [
		{ "state": "cleave", "weight": 100 },
	],
	BossBase.Phase.PHASE_2: [
		{ "state": "cleave", "weight": 70 },
		{ "state": "slam", "weight": 30 },
	],
	BossBase.Phase.PHASE_3: [
		{ "state": "cleave", "weight": 50 },
		{ "state": "slam", "weight": 50 },
	],
}

# 冷却（按阶段）
var _cooldowns: Dictionary = {
	BossBase.Phase.PHASE_1: 2.5,
	BossBase.Phase.PHASE_2: 2.0,
	BossBase.Phase.PHASE_3: 1.5,
}

func _ready() -> void:
	boss = get_parent() as DemonSlimeBoss

func pick_attack_state() -> String:
	if not boss:
		return "cleave"
	var pool: Array = _attack_pools.get(boss.current_phase, _attack_pools[BossBase.Phase.PHASE_1])
	return _weighted_pick(pool)

func get_cooldown() -> float:
	if not boss:
		return 2.5
	return _cooldowns.get(boss.current_phase, 2.5)

## 生成扇形冲击波（Cleave 用）
func spawn_fan_shockwave(origin: Vector2, facing_dir: Vector2) -> void:
	if not shockwave_scene:
		return
	var sw := shockwave_scene.instantiate()
	sw.global_position = origin
	sw.setup_fan(facing_dir, 120.0, _get_cleave_radius())
	if cleave_damage:
		sw.damage_config = cleave_damage
	boss.get_parent().add_child(sw)

## 生成环形冲击波（Slam 用）
func spawn_ring_shockwave(origin: Vector2) -> void:
	if not shockwave_scene:
		return
	var sw := shockwave_scene.instantiate()
	sw.global_position = origin
	sw.setup_ring(250.0)
	if slam_damage:
		sw.damage_config = slam_damage
	boss.get_parent().add_child(sw)

## Phase 3 时 Cleave 半径增大 30%
func _get_cleave_radius() -> float:
	if boss and boss.current_phase == BossBase.Phase.PHASE_3:
		return 260.0
	return 200.0

func _weighted_pick(pool: Array) -> String:
	var total_weight := 0
	for entry in pool:
		total_weight += entry["weight"]
	var roll := randi() % total_weight
	var cumulative := 0
	for entry in pool:
		cumulative += entry["weight"]
		if roll < cumulative:
			return entry["state"]
	return pool[0]["state"]
```

- [ ] **Step 2: Commit**

```bash
git add Scenes/Characters/Enemies/DemonSlime/DemonSlimeAttackManager.gd
git commit -m "feat(boss): add DemonSlime attack manager with shockwave spawning"
```

---

## Task 13: DemonSlime Attack States (Cleave, Slam)

**Files:**
- Create: `Scenes/Characters/Enemies/DemonSlime/States/DSCleave.gd`
- Create: `Scenes/Characters/Enemies/DemonSlime/States/DSSlam.gd`

- [ ] **Step 1: Create DSCleave.gd**

```gdscript
extends DSBaseState

## DemonSlime 劈砍状态
## 播放 cleave 动画，中段生成前方 120° 扇形冲击波

var _shockwave_spawned := false

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = true

func enter() -> void:
	_shockwave_spawned = false
	if _ds:
		_ds.velocity = Vector2.ZERO
		update_sprite_facing(false)
	play_anim("cleave")

	if _ds and _ds.sprite:
		if not _ds.sprite.animation_finished.is_connected(_on_cleave_finished):
			_ds.sprite.animation_finished.connect(_on_cleave_finished)

func process_state(_delta: float) -> void:
	if not _ds or not _ds.sprite:
		return
	# 在动画中段（约第7-8帧/15帧）生成冲击波
	if not _shockwave_spawned and _ds.sprite.frame >= 7:
		_shockwave_spawned = true
		_spawn_shockwave()

func _spawn_shockwave() -> void:
	var mgr := get_attack_manager() as DemonSlimeAttackManager
	if not mgr or not _ds:
		return
	var facing := Vector2.LEFT if (_ds.sprite and _ds.sprite.flip_h) else Vector2.RIGHT
	mgr.spawn_fan_shockwave(_ds.global_position, facing)

func _on_cleave_finished() -> void:
	if _ds:
		var mgr := get_attack_manager() as DemonSlimeAttackManager
		_ds.attack_cooldown = mgr.get_cooldown() if mgr else 2.5
	var next := evaluate_combat_transition()
	transitioned.emit(self, next)

func exit() -> void:
	if _ds and _ds.sprite and _ds.sprite.animation_finished.is_connected(_on_cleave_finished):
		_ds.sprite.animation_finished.disconnect(_on_cleave_finished)
```

- [ ] **Step 2: Create DSSlam.gd**

```gdscript
extends DSBaseState

## DemonSlime 跳跃砸地状态
## 跳向玩家位置，落地生成 360° 环形冲击波
## 复用 cleave 动画（加速播放）

@export var jump_height := 80.0
@export var jump_duration := 0.6

var _target_pos := Vector2.ZERO

func _init():
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = false

func enter() -> void:
	if not _ds or not is_target_alive():
		transitioned.emit(self, "idle")
		return

	_target_pos = target_node.global_position
	_ds.velocity = Vector2.ZERO
	update_sprite_facing(false)

	# 跳跃动画
	_perform_jump()

func _perform_jump() -> void:
	if not _ds:
		return

	var start_pos := _ds.global_position
	var tween := _ds.create_tween()

	# 水平移动到目标
	tween.tween_property(_ds, "global_position", _target_pos, jump_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 垂直抛物线（视觉层）
	if _ds.sprite:
		tween.parallel().tween_method(
			func(t: float) -> void:
				if is_instance_valid(_ds) and _ds.sprite:
					_ds.sprite.offset.y = -jump_height * sin(t * PI),
			0.0, 1.0, jump_duration
		)

	# 播放 cleave 动画加速
	play_anim("cleave")
	if _ds.sprite:
		_ds.sprite.speed_scale = 1.5

	tween.tween_callback(_on_land)

func _on_land() -> void:
	if not is_instance_valid(_ds):
		return

	# 重置 sprite offset 和速度
	if _ds.sprite:
		_ds.sprite.offset.y = 0
		_ds.sprite.speed_scale = 1.0

	# 生成环形冲击波
	var mgr := get_attack_manager() as DemonSlimeAttackManager
	if mgr:
		mgr.spawn_ring_shockwave(_ds.global_position)

	# 屏幕震动效果（如果有 camera）
	VfxHelper.spawn_burst(_ds.get_parent(), _ds.global_position,
		"res://Assets/Art/FX/Particle/Rock.png", 12, Color(0.7, 0.5, 0.9), 120.0)

	# 设置冷却
	_ds.attack_cooldown = mgr.get_cooldown() if mgr else 2.0

	# 短暂停顿后恢复
	start_timer(0.3, func():
		var next := evaluate_combat_transition()
		transitioned.emit(self, next)
	)

func exit() -> void:
	stop_timer()
	if _ds and _ds.sprite:
		_ds.sprite.speed_scale = 1.0
		_ds.sprite.offset.y = 0
```

- [ ] **Step 3: Commit**

```bash
git add Scenes/Characters/Enemies/DemonSlime/States/DSCleave.gd Scenes/Characters/Enemies/DemonSlime/States/DSSlam.gd
git commit -m "feat(boss): add DemonSlime cleave and slam attack states"
```

---

## Task 14: DemonSlime Shockwave Entity

**Files:**
- Create: `Scenes/Characters/Enemies/DemonSlime/Attacks/DSShockwave.gd`
- Create: `Scenes/Characters/Enemies/DemonSlime/Attacks/DSShockwave.tscn`

- [ ] **Step 1: Create DSShockwave.gd**

Based on `BossAOE.gd` pattern but with fan/ring modes.

```gdscript
extends Node2D
class_name DSShockwave

## DemonSlime 冲击波
## 支持扇形（Cleave）和环形（Slam）两种模式

@export var expand_time := 0.4
@export var hold_time := 0.3
@export var damage_config: Damage

var max_radius := 200.0
var fan_angle := 120.0  # 扇形角度（度）
var fan_direction := Vector2.RIGHT
var is_ring := false  # true=环形, false=扇形

var current_radius := 0.0
var damaged_targets: Array = []

@onready var area: Area2D = $Area2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var visual: Polygon2D = $Visual

## 配置为扇形冲击波
func setup_fan(direction: Vector2, angle_deg: float, radius: float) -> void:
	fan_direction = direction.normalized()
	fan_angle = angle_deg
	max_radius = radius
	is_ring = false

## 配置为环形冲击波
func setup_ring(radius: float) -> void:
	max_radius = radius
	is_ring = true

func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = 0
	collision_shape.shape = shape

	# 生成视觉多边形
	_build_visual()

	area.area_entered.connect(_on_area_entered)
	_start_expansion()

func _build_visual() -> void:
	if not visual:
		return
	var points: PackedVector2Array = []
	if is_ring:
		var segments := 32
		for i in range(segments):
			var angle := i * TAU / segments
			points.append(Vector2(cos(angle), sin(angle)) * 50.0)
		visual.color = Color(0.6, 0.3, 0.9, 0.4)
	else:
		# 扇形
		var segments := 16
		var half_angle := deg_to_rad(fan_angle / 2.0)
		var base_angle := fan_direction.angle()
		points.append(Vector2.ZERO)
		for i in range(segments + 1):
			var t := float(i) / segments
			var angle := base_angle - half_angle + t * 2.0 * half_angle
			points.append(Vector2(cos(angle), sin(angle)) * 50.0)
		visual.color = Color(0.8, 0.2, 0.6, 0.4)
	visual.polygon = points
	visual.scale = Vector2.ZERO

func _start_expansion() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "current_radius", max_radius, expand_time)
	if visual:
		var target_scale := Vector2.ONE * (max_radius / 50.0)
		tween.tween_property(visual, "scale", target_scale, expand_time)
	await tween.finished

	await get_tree().create_timer(hold_time).timeout

	var fade_tween := create_tween()
	if visual:
		fade_tween.tween_property(visual, "modulate:a", 0.0, 0.2)
	await fade_tween.finished
	queue_free()

func _exit_tree() -> void:
	if collision_shape:
		collision_shape.shape = null

func _process(_delta: float) -> void:
	var shape := collision_shape.shape as CircleShape2D
	if shape:
		shape.radius = current_radius

func _on_area_entered(entered_area: Area2D) -> void:
	if entered_area is HurtBoxComponent and entered_area not in damaged_targets:
		# 扇形模式：检查角度
		if not is_ring:
			var to_target := (entered_area.global_position - global_position)
			var angle_diff := abs(fan_direction.angle_to(to_target.normalized()))
			if angle_diff > deg_to_rad(fan_angle / 2.0):
				return

		damaged_targets.append(entered_area)

		var dmg: Damage
		if damage_config:
			dmg = damage_config.duplicate(true)
			dmg.randomize_damage()
		else:
			dmg = Damage.new()
			dmg.amount = 20.0
			dmg.min_amount = 15.0
			dmg.max_amount = 25.0
			dmg.randomize_damage()

		# 添加击退
		var kb := KnockBackEffect.new()
		kb.knockback_force = 250.0
		dmg.effects.append(kb)

		entered_area.take_damage(dmg, global_position)
```

- [ ] **Step 2: Create DSShockwave.tscn**

```ini
[gd_scene format=3]

[ext_resource type="Script" path="res://Scenes/Characters/Enemies/DemonSlime/Attacks/DSShockwave.gd" id="1_script"]

[sub_resource type="CircleShape2D" id="CircleShape2D_sw"]
radius = 0.0

[node name="DSShockwave" type="Node2D"]
script = ExtResource("1_script")

[node name="Visual" type="Polygon2D" parent="."]

[node name="Area2D" type="Area2D" parent="."]
collision_layer = 16
collision_mask = 2

[node name="CollisionShape2D" type="CollisionShape2D" parent="Area2D"]
shape = SubResource("CircleShape2D_sw")
```

- [ ] **Step 3: Commit**

```bash
git add Scenes/Characters/Enemies/DemonSlime/Attacks/
git commit -m "feat(boss): add DemonSlime shockwave entity with fan/ring modes"
```

---

## Task 15: DemonSlime MiniSlime

**Files:**
- Create: `Scenes/Characters/Enemies/DemonSlime/MiniSlime/MiniSlime.gd`
- Create: `Scenes/Characters/Enemies/DemonSlime/MiniSlime/MiniSlime.tscn`

- [ ] **Step 1: Create MiniSlime.gd**

Simple enemy using EnemyBase + EnemyStateMachine (BASIC type). Reuses DemonSlime animations at 0.4 scale.

```gdscript
extends EnemyBase
class_name MiniSlime

## DemonSlime 分裂出的小史莱姆
## 简单AI：idle → chase → attack（近身 cleave，无冲击波）

func _on_enemy_ready() -> void:
	add_to_group("mini_slime")
```

- [ ] **Step 2: Create MiniSlime.tscn**

Scene structure based on existing enemy pattern (like Slime.tscn):

```
MiniSlime (CharacterBody2D, group="enemy", group="mini_slime")
├── AnimatedSprite2D (reuse DemonSlime SpriteFrames, scale 0.4)
├── CollisionShape2D (CircleShape2D, radius=6)
├── DamageNumbersAnchor (Node2D, y=-20)
├── HurtBoxComponent (Area2D, collision_layer=8, mask=0)
│   └── CollisionShape2D (CircleShape2D, radius=8)
├── HitBoxComponent (Area2D, collision_layer=16, mask=2)
│   └── CollisionShape2D (CircleShape2D, radius=6)
├── HealthComponent (Node)
├── StateMachine (EnemyStateMachine, preset=BASIC)
│   ├── IdleState
│   ├── WanderState
│   ├── ChaseState
│   ├── AttackState
│   ├── HitState
│   ├── KnockbackState
│   └── StunState
```

Key properties:
- `max_health = 150` (15% of 1000)
- `chase_speed = 50`
- `detection_radius = 120`
- `follow_radius = 30`
- `scale = Vector2(0.4, 0.4)` (set by parent DemonSlimeBoss via tween)

The SpriteFrames can reference the same DemonSlime animations with these mapped names for EnemyStateMachine compatibility:
- idle → demon_idle (or create "idle" animation from demon_idle frames)
- attack → demon_cleave
- hit → demon_take_hit
- death → demon_death

- [ ] **Step 3: Commit**

```bash
git add Scenes/Characters/Enemies/DemonSlime/MiniSlime/
git commit -m "feat(boss): add MiniSlime enemy for DemonSlime spawning"
```

---

## Task 16: DemonSlime Boss Scene (.tscn)

**Files:**
- Create: `Scenes/Characters/Enemies/DemonSlime/DemonSlimeBoss.tscn`

- [ ] **Step 1: Create the scene**

Node hierarchy:
```
DemonSlimeBoss (CharacterBody2D, group="enemy")
├── AnimatedSprite2D (SpriteFrames: idle, walk, cleave, take_hit, death)
├── CollisionShape2D (RectangleShape2D 48x56)
├── DamageNumbersAnchor (Node2D, y=-40)
├── HurtBoxComponent (Area2D, collision_layer=8, mask=0)
│   └── CollisionShape2D (RectangleShape2D 44x52)
├── HealthComponent (Node, max_health=1500, health=1500)
├── HealthBar (ProgressBar, same inline script as BossBase.tscn)
├── DemonSlimeAttackManager (Node)
└── StateMachine (DSStateMachine, init_state=Idle)
    ├── Idle (DSIdle)
    ├── Chase (DSChase)
    ├── Cleave (DSCleave)
    ├── Slam (DSSlam)
    └── Stun (DSStun)
```

Key properties:
- `collision_layer = 8`, `collision_mask = 128`
- Script: `DemonSlimeBoss.gd`
- `max_health = 1500`, `health = 1500` (1.5x of existing boss)
- `detection_radius = 600`, `attack_range = 250`, `min_distance = 80`
- `base_move_speed = 80`
- `mini_slime_scene`: reference to `MiniSlime.tscn`

SpriteFrames animations loaded from `res://Assets/Art/BOSS_SLIME/individual sprites/`:

| Animation | Directory | Frames | FPS | Loop |
|-----------|-----------|--------|-----|------|
| idle | 01_demon_idle | 6 | 8 | yes |
| walk | 02_demon_walk | 12 | 10 | yes |
| cleave | 03_demon_cleave | 15 | 12 | no |
| take_hit | 04_demon_take_hit | 5 | 10 | no |
| death | 05_demon_death | 22 | 10 | no |

- [ ] **Step 2: Verify scene loads**

```bash
godot --headless --path . --quit 2>&1 | head -20
```

- [ ] **Step 3: Commit**

```bash
git add Scenes/Characters/Enemies/DemonSlime/DemonSlimeBoss.tscn
git commit -m "feat(boss): add DemonSlime boss scene with AnimatedSprite2D"
```

---

## Task 17: Level 4 (BladeKeeper)

**Files:**
- Create: `Scenes/Levels/Level4_BladeKeeper/Level4.gd`
- Create: `Scenes/Levels/Level4_BladeKeeper/Level4.tscn`

- [ ] **Step 1: Create Level4.gd**

```gdscript
extends Node2D

## 关卡4: BladeKeeper Boss战 - 剑道场

@onready var player_spawn: Node2D = $PlayerSpawn
@onready var level_hud: LevelHUD = $LevelHUD
@onready var boss: Node2D = $BladeKeeperBoss
@onready var portal: Portal = $Portal

func _ready() -> void:
	LevelManager.current_level = 3
	LevelManager.is_level_active = true
	LevelManager._reset_level_stats()
	LevelManager.level_started.emit(3)

	_setup_boss()
	print("Level4: BladeKeeper Battle started!")

func _setup_boss() -> void:
	if boss and boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_boss_defeated)

func _on_boss_defeated() -> void:
	print("Level4: BladeKeeper defeated!")
	LevelManager.on_boss_defeated()
	UIManager.show_toast("BladeKeeper Defeated!", 3.0, "success")

	# 金币爆散
	var coin_burst_scene := preload("res://Effects/CoinBurst.tscn")
	var coin_burst := coin_burst_scene.instantiate()
	coin_burst.coin_amount = 10
	coin_burst.global_position = boss.global_position + Vector2(0, -16)
	add_child(coin_burst)
```

- [ ] **Step 2: Create Level4.tscn**

Scene structure following Level3 pattern:
```
Level4 (Node2D)
├── ParallaxBackground
│   └── ParallaxLayer (motion_scale 0.2, 0.2)
│       └── Background Sprite
├── TileMapLayer (ground + walls)
├── Camera2D (zoom 2x, limits)
├── PlayerSpawn (Marker2D at ~(80, 328))
├── BladeKeeperBoss (instance of BladeKeeperBoss.tscn, at center)
├── PatrolPoints (Node2D)
│   ├── Marker2D (4 patrol markers)
├── LevelHUD (instance)
└── Portal (instance, initially locked)
```

The arena should be a medium-sized enclosed space. Use existing tileset from Level3 for the basic layout.

- [ ] **Step 3: Commit**

```bash
git add Scenes/Levels/Level4_BladeKeeper/
git commit -m "feat(level): add Level 4 BladeKeeper boss arena"
```

---

## Task 18: Level 5 (DemonSlime)

**Files:**
- Create: `Scenes/Levels/Level5_DemonSlime/Level5.gd`
- Create: `Scenes/Levels/Level5_DemonSlime/Level5.tscn`

- [ ] **Step 1: Create Level5.gd**

```gdscript
extends Node2D

## 关卡5: DemonSlime Boss战 - 恶魔洞穴

@onready var player_spawn: Node2D = $PlayerSpawn
@onready var level_hud: LevelHUD = $LevelHUD
@onready var boss: Node2D = $DemonSlimeBoss
@onready var portal: Portal = $Portal

func _ready() -> void:
	LevelManager.current_level = 4
	LevelManager.is_level_active = true
	LevelManager._reset_level_stats()
	LevelManager.level_started.emit(4)

	_setup_boss()
	print("Level5: DemonSlime Battle started!")

func _setup_boss() -> void:
	if boss and boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_boss_defeated)

func _on_boss_defeated() -> void:
	print("Level5: DemonSlime defeated!")

	# 清除所有残留的小史莱姆
	for mini in get_tree().get_nodes_in_group("mini_slime"):
		var tween := mini.create_tween()
		tween.tween_property(mini, "modulate:a", 0.0, 0.5)
		tween.tween_callback(mini.queue_free)

	LevelManager.on_boss_defeated()
	UIManager.show_toast("DemonSlime Defeated!", 3.0, "success")

	# 金币爆散
	var coin_burst_scene := preload("res://Effects/CoinBurst.tscn")
	var coin_burst := coin_burst_scene.instantiate()
	coin_burst.coin_amount = 12
	coin_burst.global_position = boss.global_position + Vector2(0, -16)
	add_child(coin_burst)
```

- [ ] **Step 2: Create Level5.tscn**

Similar to Level4 but larger arena:
```
Level5 (Node2D)
├── ParallaxBackground
├── TileMapLayer (larger arena)
├── Camera2D (zoom 2x, wider limits)
├── PlayerSpawn (Marker2D)
├── DemonSlimeBoss (instance of DemonSlimeBoss.tscn, at center)
├── PatrolPoints (2-3 markers, short patrol)
├── LevelHUD (instance)
└── Portal (instance)
```

- [ ] **Step 3: Commit**

```bash
git add Scenes/Levels/Level5_DemonSlime/
git commit -m "feat(level): add Level 5 DemonSlime boss arena"
```

---

## Task 19: Register Levels in LevelManager

**Files:**
- Modify: `Core/Autoloads/LevelManager.gd:20-31`

- [ ] **Step 1: Update LEVEL_SCENES array**

In `Core/Autoloads/LevelManager.gd`, add Level 4 and Level 5:

```gdscript
# BEFORE (lines 20-24):
const LEVEL_SCENES: Array[String] = [
	"res://Scenes/Levels/Level1_Adventure/Level1.tscn",
	"res://Scenes/Levels/Level2_Maze/Level2.tscn",
	"res://Scenes/Levels/Level3_Boss/Level3.tscn"
]

# AFTER:
const LEVEL_SCENES: Array[String] = [
	"res://Scenes/Levels/Level1_Adventure/Level1.tscn",
	"res://Scenes/Levels/Level2_Maze/Level2.tscn",
	"res://Scenes/Levels/Level3_Boss/Level3.tscn",
	"res://Scenes/Levels/Level4_BladeKeeper/Level4.tscn",
	"res://Scenes/Levels/Level5_DemonSlime/Level5.tscn",
]
```

- [ ] **Step 2: Update LEVEL_OBJECTIVES**

```gdscript
# BEFORE (lines 27-31):
const LEVEL_OBJECTIVES: Dictionary = {
	0: {"treasures": 5},
	1: {"keys": 5},
	2: {"boss": true}
}

# AFTER:
const LEVEL_OBJECTIVES: Dictionary = {
	0: {"treasures": 5},
	1: {"keys": 5},
	2: {"boss": true},
	3: {"boss": true},
	4: {"boss": true},
}
```

- [ ] **Step 3: Update get_current_level_name()**

Add names for levels 3 and 4:

```gdscript
# Add to match statement:
		3:
			return "BladeKeeper's Hall"
		4:
			return "DemonSlime's Lair"
```

- [ ] **Step 4: Update get_objective_text()**

```gdscript
# Add to match statement:
		3:
			return "Defeat the BladeKeeper!"
		4:
			return "Defeat the DemonSlime!"
```

- [ ] **Step 5: Update can_complete_level()**

```gdscript
# Add to match statement:
		3:
			return is_boss_defeated
		4:
			return is_boss_defeated
```

- [ ] **Step 6: Commit**

```bash
git add Core/Autoloads/LevelManager.gd
git commit -m "feat(level): register Level 4 and Level 5 in LevelManager"
```

---

## Task 20: Integration Test + Final Verification

- [ ] **Step 1: Verify all scripts parse without errors**

```bash
godot --headless --path . --check-only --script res://Scenes/Characters/Enemies/BladeKeeper/BladeKeeperBoss.gd 2>&1
godot --headless --path . --check-only --script res://Scenes/Characters/Enemies/DemonSlime/DemonSlimeBoss.gd 2>&1
```

- [ ] **Step 2: Launch game and check for runtime errors**

Use `mcp__godot__run_project` to launch, then `mcp__godot__get_debug_output` to check for errors.

- [ ] **Step 3: Fix any issues found**

Address GDScript parse errors, missing references, scene loading issues.

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat(boss): complete BladeKeeper and DemonSlime boss implementation"
```
