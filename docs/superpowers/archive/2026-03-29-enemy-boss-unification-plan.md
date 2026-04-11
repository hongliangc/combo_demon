# EnemyBase / BossBase 架构统一优化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify EnemyBase/BossBase architecture by standardizing sprite types, state machine inheritance, and boss state reuse of CommonStates.

**Architecture:** Three independent improvements applied sequentially: (1) EnemyBase sprite standardization, (2) BossStateMachine inherits EnemyStateMachine, (3) CommonStates gain virtual hooks and boss states extend them instead of duplicating.

**Tech Stack:** Godot 4.4.1+ GDScript, AnimationTree BlendTree, BaseStateMachine priority system

---

### Task 1: EnemyBase Sprite2D → AnimatedSprite2D

**Files:**
- Modify: `Core/Characters/EnemyBase.gd:138-148` (`_update_sprite_facing()`)
- Modify: `Scenes/Characters/Templates/EnemyBase.tscn` (node type + RESET animation track paths)

- [ ] **Step 1: Simplify `_update_sprite_facing()` in EnemyBase.gd**

Replace the dual-branch sprite facing logic with a unified version:

```gdscript
## 根据移动方向翻转精灵（子类可重写）
func _update_sprite_facing() -> void:
	if not sprite or not alive or velocity.x == 0:
		return
	if "flip_h" in sprite:
		sprite.flip_h = velocity.x < 0
```

This replaces lines 138-148, removing the `Sprite2D`/`AnimatedSprite2D` type checks.

- [ ] **Step 2: Update EnemyBase.tscn node type**

Change the Sprite2D node to AnimatedSprite2D:

```
[node name="Sprite2D" type="Sprite2D" parent="." unique_id=992887352]
```
→
```
[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="." unique_id=992887352]
```

- [ ] **Step 3: Update RESET animation track paths in EnemyBase.tscn**

Change all 4 track paths from `Sprite2D:*` to `AnimatedSprite2D:*`:

- `tracks/0/path = NodePath("Sprite2D:frame")` → `NodePath("AnimatedSprite2D:frame")`
- `tracks/1/path = NodePath("Sprite2D:modulate")` → `NodePath("AnimatedSprite2D:modulate")`
- `tracks/2/path = NodePath("Sprite2D:rotation")` → `NodePath("AnimatedSprite2D:rotation")`
- `tracks/3/path = NodePath("Sprite2D:position")` → `NodePath("AnimatedSprite2D:position")`

- [ ] **Step 4: Verify — run full project**

Run: `mcp__godot__run_project` with full project
Expected: 0 errors. Enemies spawn and animate normally. State machine transitions (Idle → Wander → Chase → Attack) appear in debug output.

---

### Task 2: BossStateMachine extends EnemyStateMachine

**Files:**
- Modify: `Scenes/Characters/Bosses/Shared/BossStateMachine.gd:1` (change extends)

- [ ] **Step 1: Change BossStateMachine inheritance**

Replace line 1:

```gdscript
extends BaseStateMachine
```
→
```gdscript
extends EnemyStateMachine
```

No other changes needed. BossStateMachine's `_setup_signals()` already calls `super._setup_signals()` which chains correctly. EnemyStateMachine's `_ready()` auto-create guard (`get_child_count() == 0`) prevents creating preset states since all boss scenes already have manually configured state children.

- [ ] **Step 2: Verify — run all 3 boss scenes**

Run `mcp__godot__run_project` for each:
- `res://Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn`
- `res://Scenes/Characters/Bosses/DemonSlime/DemonSlime.tscn`
- `res://Scenes/Characters/Bosses/Cyclops/Cyclops.tscn`

Expected: 0 errors each. State machine transitions appear normally in debug output.

---

### Task 3: Add virtual hooks to IdleState

**Files:**
- Modify: `Core/StateMachine/CommonStates/IdleState.gd:69-77` (`process_state()`)

- [ ] **Step 1: Extract `_evaluate_idle_transition()` virtual method**

Add the virtual method and refactor `process_state()` to call it. Replace lines 69-77:

```gdscript
func process_state(_delta: float) -> void:
	# 检测玩家
	if enable_player_detection:
		_evaluate_idle_transition()


## 评估 Idle 状态中的转换（子类可重写）
## 默认行为：检查攻击范围 → 检查追击范围
func _evaluate_idle_transition() -> void:
	# 优先检查攻击范围：在攻击范围内直接进入攻击，跳过追击
	if try_attack():
		return
	if try_chase():
		return
```

- [ ] **Step 2: Verify — run full project**

Run: `mcp__godot__run_project` with full project
Expected: 0 errors. All enemies still detect player and transition from Idle → Chase/Attack.

---

### Task 4: Add virtual hooks to ChaseState

**Files:**
- Modify: `Core/StateMachine/CommonStates/ChaseState.gd:63-65`

- [ ] **Step 1: Extract `_on_reached_attack_range()` virtual method**

Replace the hardcoded attack range transition (lines 63-65):

```gdscript
		# 进入攻击范围
		if distance <= attack_range:
			transition_to(attack_state_name)
			return
```
→
```gdscript
		# 进入攻击范围
		if distance <= attack_range:
			var target_state := _on_reached_attack_range()
			if target_state != "":
				transition_to(target_state)
			return
```

Add the virtual method at the end of the file (after `_update_animation_locomotion()`):

```gdscript
## 到达攻击范围时的状态选择（子类可重写）
## 默认返回 attack_state_name（通常是 "attack"）
func _on_reached_attack_range() -> String:
	return attack_state_name
```

- [ ] **Step 2: Verify — run full project**

Run: `mcp__godot__run_project` with full project
Expected: 0 errors. Enemies still transition from Chase → Attack when in range.

---

### Task 5: Add virtual hooks to StunState

**Files:**
- Modify: `Core/StateMachine/CommonStates/StunState.gd:73-86` (`exit()`) and add `_on_stun_exit()`

- [ ] **Step 1: Add `_on_stun_exit()` hook and update `exit()`**

Replace `exit()` (lines 73-86):

```gdscript
func exit() -> void:
	stop_timer()

	# 退出控制状态，返回到正常行为
	exit_control_state()

	# 恢复动画播放速度
	set_control_time_scale(1.0)

	# 清除眩晕标记
	if "stunned" in owner_node:
		owner_node.stunned = false

	# 子类钩子（如设置眩晕免疫）
	_on_stun_exit()

	DebugConfig.debug("眩晕: %s 结束" % owner_node.name, "", "state_machine")


## 眩晕退出钩子（子类可重写）
## 用于设置眩晕免疫等 Boss 特有逻辑
func _on_stun_exit() -> void:
	pass
```

- [ ] **Step 2: Update `_on_timer_timeout()` to call `decide_next_state()`**

The current `_on_timer_timeout()` is inherited from BaseState and calls `decide_next_state()`. StunState does NOT override `_on_timer_timeout()`, so this already works correctly — BaseState's default `_on_timer_timeout()` calls `decide_next_state()` which uses distance-based logic.

Verify by reading `BaseState.gd` lines 223-226 — `_on_timer_timeout()` already calls `decide_next_state()`. No change needed here.

- [ ] **Step 3: Verify — run full project**

Run: `mcp__godot__run_project` with full project
Expected: 0 errors. Enemies recover from stun normally.

---

### Task 6: BKIdle extends IdleState

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/States/BKIdle.gd` (full rewrite)

- [ ] **Step 1: Rewrite BKIdle to extend IdleState**

Replace entire file:

```gdscript
extends "res://Core/StateMachine/CommonStates/IdleState.gd"

## BladeKeeper Idle 状态 — 继承通用 IdleState
## 重写转换逻辑使用 Boss 距离决策

func _init():
	super._init()
	use_fixed_time = true
	stop_immediately = true

func _ready():
	min_idle_time = 2.0
	next_state_on_timeout = "chase"

## 重写：使用 Boss 距离决策代替通用 try_attack/try_chase
func _evaluate_idle_transition() -> void:
	var boss := owner_node as BossBase
	if not boss:
		super._evaluate_idle_transition()
		return

	if not is_target_alive():
		return

	var distance := get_distance_to_target()
	if distance <= boss.attack_range and boss.attack_cooldown <= 0:
		transitioned.emit(self, "attack")
	elif distance <= boss.detection_radius:
		transitioned.emit(self, "chase")
```

- [ ] **Step 2: Verify — run BladeKeeper scene**

Run: `mcp__godot__run_project` with `res://Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn`
Expected: 0 errors. Idle → Chase → Attack transitions appear in debug output.

---

### Task 7: DSIdle extends IdleState

**Files:**
- Modify: `Scenes/Characters/Bosses/DemonSlime/States/DSIdle.gd` (full rewrite)

- [ ] **Step 1: Rewrite DSIdle to extend IdleState**

Replace entire file:

```gdscript
extends "res://Core/StateMachine/CommonStates/IdleState.gd"

## DemonSlime Idle 状态 — 继承通用 IdleState
## 重写转换逻辑使用 Boss 距离决策

func _init():
	super._init()
	use_fixed_time = true
	stop_immediately = true

func _ready():
	min_idle_time = 2.0
	next_state_on_timeout = "chase"

## 重写：使用 Boss 距离决策代替通用 try_attack/try_chase
func _evaluate_idle_transition() -> void:
	var boss := owner_node as BossBase
	if not boss:
		super._evaluate_idle_transition()
		return

	if not is_target_alive():
		return

	var distance := get_distance_to_target()
	if distance <= boss.attack_range and boss.attack_cooldown <= 0:
		transitioned.emit(self, "attack")
	elif distance <= boss.detection_radius:
		transitioned.emit(self, "chase")
```

- [ ] **Step 2: Verify — run DemonSlime scene**

Run: `mcp__godot__run_project` with `res://Scenes/Characters/Bosses/DemonSlime/DemonSlime.tscn`
Expected: 0 errors. Idle → Chase transitions appear in debug output.

---

### Task 8: BKChase extends ChaseState

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/States/BKChase.gd` (full rewrite)

- [ ] **Step 1: Rewrite BKChase to extend ChaseState**

Replace entire file:

```gdscript
extends "res://Core/StateMachine/CommonStates/ChaseState.gd"

## BladeKeeper Chase 状态 — 继承通用 ChaseState
## 使用 Boss 参数覆盖通用设置，重写攻击范围决策

func _init():
	super._init()
	enable_sprite_flip = true

func _ready():
	# BladeKeeper 使用 BossBase 的参数，通过 owner 属性读取
	# ChaseState 默认从 owner 读取 chase_speed, attack_activation_radius 等
	# 但 BossBase 的属性名不同，需要覆盖默认值
	var boss := owner_node as BossBase
	if boss:
		default_chase_speed = (boss as BladeKeeper).move_speed if boss is BladeKeeper else 180.0
		default_attack_range = boss.attack_range
		default_give_up_range = boss.detection_radius
		give_up_state_name = "idle"

## 重写：检查攻击冷却
func _on_reached_attack_range() -> String:
	var boss := owner_node as BossBase
	if boss and boss.attack_cooldown > 0:
		return ""  # 冷却中，不转换（留在 chase）
	return "attack"
```

- [ ] **Step 2: Verify — run BladeKeeper scene**

Run: `mcp__godot__run_project` with `res://Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn`
Expected: 0 errors. Chase → Attack transitions appear when in range.

---

### Task 9: DSStun extends StunState

**Files:**
- Modify: `Scenes/Characters/Bosses/DemonSlime/States/DSStun.gd` (full rewrite)

- [ ] **Step 1: Rewrite DSStun to extend StunState**

Replace entire file:

```gdscript
extends "res://Core/StateMachine/CommonStates/StunState.gd"

## DemonSlime Stun 状态 — 继承通用 StunState
## 添加眩晕免疫 + Boss 距离决策恢复

func _init():
	super._init()
	stun_duration = 1.5
	reset_on_damage = true

## 重写：Phase 3 免疫眩晕
func on_damaged(damage: Damage, attacker_position: Vector2 = Vector2.ZERO) -> void:
	var boss := owner_node as BossBase
	if boss and boss.current_phase == BossBase.Phase.PHASE_3:
		return
	super.on_damaged(damage, attacker_position)

## 重写：设置眩晕免疫
func _on_stun_exit() -> void:
	var boss := owner_node as BossBase
	if boss:
		boss.stun_immunity = 1.5

## 重写：使用 Boss 距离决策选择恢复状态
func decide_next_state() -> void:
	var boss := owner_node as BossBase
	if not boss:
		super.decide_next_state()
		return

	if not is_target_alive():
		transition_to("idle")
		return

	var distance := get_distance_to_target()
	if distance > boss.detection_radius:
		transition_to("idle")
	elif distance <= boss.attack_range and boss.attack_cooldown <= 0:
		transition_to("attack")
	elif distance <= boss.detection_radius:
		transition_to("chase")
	else:
		transition_to("idle")
```

- [ ] **Step 2: Verify — run DemonSlime scene**

Run: `mcp__godot__run_project` with `res://Scenes/Characters/Bosses/DemonSlime/DemonSlime.tscn`
Expected: 0 errors. State machine transitions appear normally.

---

### Task 10: Final verification — all scenes

- [ ] **Step 1: Run all 3 boss scenes individually**

Run `mcp__godot__run_project` for each:
- `res://Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn` — 0 errors
- `res://Scenes/Characters/Bosses/DemonSlime/DemonSlime.tscn` — 0 errors
- `res://Scenes/Characters/Bosses/Cyclops/Cyclops.tscn` — 0 errors

- [ ] **Step 2: Run full project**

Run: `mcp__godot__run_project` with full project (default scene)
Expected: 0 errors. All enemies and bosses behave correctly. State machine transitions in debug output show normal patterns.

- [ ] **Step 3: Verify enemy scenes unaffected**

Confirm the debug output shows standard enemy state transitions (Idle → Wander → Chase → Attack → Hit etc.) with no errors or warnings related to sprite types or state machine inheritance.
