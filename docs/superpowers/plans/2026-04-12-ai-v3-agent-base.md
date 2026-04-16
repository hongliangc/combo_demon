# AI v3 — AgentAIBase + Stock States Rewrite

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace BossBase/EnemyBase dependency with unified `AgentAIBase.gd`; rewrite Stock States to use AnimationPlayer directly (no AnimationTree); add data-driven `_register_rules`; fix DS2 to extend AgentAIBase.

**Architecture:** `AgentAIBase.gd` owns gravity + `move_and_slide()` + facing. States only set `velocity`, never call `move_and_slide()`. Animation via `owner_node.anim_player.play()`. Transition rules defined as arrays and registered via `_register_rules()` which auto-skips missing states.

**Tech Stack:** Godot 4.4.1+, GDScript, GUT

**Spec:** `docs/superpowers/specs/2026-04-12-ai-v3-agent-base-design.md`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `Core/AI/AgentAIBase.gd` | **Create** | Unified base: gravity, move_and_slide, facing, _register_rules, signal wiring |
| `Core/AI/Stock/IdleState.gd` | **Rewrite** | velocity=0, anim_player.play("idle") |
| `Core/AI/Stock/ChaseState.gd` | **Rewrite** | velocity=dir*speed, anim_player.play("walk"), no move_and_slide |
| `Core/AI/Stock/WanderState.gd` | **Rewrite** | random dir, timer, anim_player.play("walk"), no move_and_slide |
| `Core/AI/Stock/HitState.gd` | **Rewrite** | apply effects, anim_player.play("hit"), timer→dispatch |
| `Core/AI/Stock/StunState.gd` | **Rewrite** | anim_player.play("stunned"), timer→dispatch |
| `Core/AI/Stock/DeathState.gd` | **Rewrite** | anim_player.play("death"), disable collision |
| `Scenes/Characters/Templates/AgentAIBase.tscn` | **Modify** | Root script→AgentAIBase.gd, remove AnimationTree node |
| `Scenes/Characters/Bosses/DemonSlime2/DemonSlime2.gd` | **Rewrite** | extends AgentAIBase, data-driven rules, guard methods |
| `Scenes/Characters/Bosses/DemonSlime2/States/DS2Cleave.gd` | **Modify** | Use anim_player instead of AnimationTree |
| `Scenes/Characters/Bosses/DemonSlime2/States/DS2Slam.gd` | **Modify** | Use anim_player instead of AnimationTree |
| `Scenes/Characters/Bosses/DemonSlime2/States/DS2Counter.gd` | **Modify** | Use anim_player |
| `Scenes/Characters/Bosses/DemonSlime2/States/DS2Defend.gd` | **Modify** | Use anim_player |
| `Scenes/Characters/Bosses/DemonSlime2/States/DS2Roll.gd` | **No change** | Already uses velocity + timer, no AnimationTree |
| `test/unit/test_ai_controller.gd` | **Modify** | Add test for _register_rules |
| `test/integration/test_ds2.gd` | **Modify** | Use AgentAIBase instead of manual setup |

---

### Task 1: Create AgentAIBase.gd

**Files:**
- Create: `Core/AI/AgentAIBase.gd`

- [ ] **Step 1: Create AgentAIBase.gd**

```gdscript
class_name AgentAIBase extends CharacterBody2D

## AI 角色统一基类
## 职责：gravity + move_and_slide + facing + AI 信号接线 + _register_rules

@export var has_gravity: bool = false
@export var gravity_force: float = 800.0

@onready var ai: AIController = $AIController
@onready var health_comp: HealthComponent = $HealthComponent
@onready var anim_player: AnimationPlayer = $AnimationPlayer
var sprite: Node2D

func _ready() -> void:
	_auto_find_sprite()
	_setup_blackboard()
	_setup_transitions()
	_setup_signals()

func _physics_process(delta: float) -> void:
	if has_gravity:
		if not is_on_floor():
			velocity.y += gravity_force * delta
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
	pass

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
## rules 格式: [[from, to, event, guard_method, priority], ...]
## from="*" 表示 ANYSTATE; guard_method="" 表示无条件
## 自动跳过 StateMachine 中不存在的状态
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

- [ ] **Step 2: Verify no parse errors**

Run: `"D:/devtool/godot/Godot_v4.6-stable_win64.exe/Godot_v4.6-stable_win64_console.exe" --path "E:/workspace/4.godot/combo_demon" --check-only --headless 2>&1 | grep -i "AgentAIBase\|error" | head -10`

Expected: No errors for AgentAIBase.gd

---

### Task 2: Rewrite 6 Stock States

**Files:**
- Modify: `Core/AI/Stock/IdleState.gd`
- Modify: `Core/AI/Stock/ChaseState.gd`
- Modify: `Core/AI/Stock/WanderState.gd`
- Modify: `Core/AI/Stock/HitState.gd`
- Modify: `Core/AI/Stock/StunState.gd`
- Modify: `Core/AI/Stock/DeathState.gd`

- [ ] **Step 1: Rewrite IdleState.gd**

```gdscript
extends AIState

## Stock Idle — 停止移动，播放 idle 动画

func enter() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	if "anim_player" in owner_node and owner_node.anim_player:
		if owner_node.anim_player.has_animation(&"idle"):
			owner_node.anim_player.play(&"idle")
```

- [ ] **Step 2: Rewrite ChaseState.gd**

```gdscript
extends AIState

## Stock Chase — 向目标移动，播放 walk 动画

@export var default_speed: float = 80.0

func enter() -> void:
	if "anim_player" in owner_node and owner_node.anim_player:
		if owner_node.anim_player.has_animation(&"walk"):
			owner_node.anim_player.play(&"walk")

func physics_update(_delta: float) -> void:
	if owner_node is not CharacterBody2D:
		return
	var body := owner_node as CharacterBody2D
	var target_pos: Vector2 = bb.get_var(&"target_position", body.global_position) as Vector2
	var speed := float(bb.get_var(&"chase_speed", default_speed))
	var dir: Vector2 = (target_pos - body.global_position).normalized()
	body.velocity = dir * speed

func exit() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
```

- [ ] **Step 3: Rewrite WanderState.gd**

```gdscript
extends AIState

## Stock Wander — 随机方向移动，定时结束

@export var default_speed: float = 50.0
@export var min_time: float = 2.0
@export var max_time: float = 5.0

var _direction: Vector2
var _timer: Timer

func enter() -> void:
	_direction = Vector2.RIGHT.rotated(randf_range(0, TAU))
	if "anim_player" in owner_node and owner_node.anim_player:
		if owner_node.anim_player.has_animation(&"walk"):
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
	if _timer:
		_timer.stop()
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO

func _ensure_timer() -> void:
	if not _timer:
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.timeout.connect(func(): dispatch(AIEvents.EV_ATTACK_FINISHED))
		add_child(_timer)
```

- [ ] **Step 4: Rewrite HitState.gd**

```gdscript
extends AIState

## Stock Hit — 受击反应：应用 effects，播 hit 动画，timer → dispatch hit_recovered

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
		if owner_node.anim_player.has_animation(&"hit"):
			owner_node.anim_player.play(&"hit")
	_ensure_timer()
	_timer.wait_time = default_duration
	_timer.start()

func physics_update(delta: float) -> void:
	if owner_node is CharacterBody2D:
		var body := owner_node as CharacterBody2D
		body.velocity = body.velocity.lerp(Vector2.ZERO, 8.0 * delta)

func exit() -> void:
	if _timer:
		_timer.stop()
	bb.set_var(&"recently_hit", false)

func _ensure_timer() -> void:
	if not _timer:
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.timeout.connect(func(): dispatch(AIEvents.EV_HIT_RECOVERED))
		add_child(_timer)
```

- [ ] **Step 5: Rewrite StunState.gd**

```gdscript
extends AIState

## Stock Stun — 眩晕动画 + timer → dispatch stun_recovered

@export var default_duration: float = 1.5

var _timer: Timer

func enter() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	if "anim_player" in owner_node and owner_node.anim_player:
		if owner_node.anim_player.has_animation(&"stunned"):
			owner_node.anim_player.play(&"stunned")
	_ensure_timer()
	_timer.wait_time = default_duration
	_timer.start()

func exit() -> void:
	if _timer:
		_timer.stop()

func _ensure_timer() -> void:
	if not _timer:
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.timeout.connect(func(): dispatch(AIEvents.EV_STUN_RECOVERED))
		add_child(_timer)
```

- [ ] **Step 6: Rewrite DeathState.gd**

```gdscript
extends AIState

## Stock Death — 播放死亡动画，禁用 owner

func enter() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	if "anim_player" in owner_node and owner_node.anim_player:
		if owner_node.anim_player.has_animation(&"death"):
			owner_node.anim_player.play(&"death")
	if owner_node:
		owner_node.set_physics_process(false)
		var col: CollisionShape2D = owner_node.get_node_or_null(^"CollisionShape2D")
		if col:
			col.set_deferred(&"disabled", true)
```

---

### Task 3: Update AgentAIBase.tscn

**Files:**
- Modify: `Scenes/Characters/Templates/AgentAIBase.tscn`

- [ ] **Step 1: Update template**

Changes to make:
1. Root node script: change from `EnemyBase.gd` to `AgentAIBase.gd`
2. Remove `AnimationTree` node entirely
3. Remove all AnimationTree sub_resources (BlendTree, BlendSpace2D, StateMachine, TimeScale, Blend2, all AnimationNodeAnimation)
4. Keep: Sprite2D, AnimationPlayer (with RESET), CollisionShape2D, HurtBox, HitBox, HealthComponent, HealthBar, DamageNumbersAnchor, AIController/StateMachine/Idle/Chase/Hit/Death

Root node `script` line changes from:
```
script = ExtResource("1_enemy_base")
```
to reference `AgentAIBase.gd`.

Remove the `[ext_resource ... EnemyBase.gd]` line and add `[ext_resource ... AgentAIBase.gd]`.

Delete the `[node name="AnimationTree" ...]` line.

Delete all AnimationTree-related sub_resources.

---

### Task 4: Rewrite DemonSlime2.gd

**Files:**
- Modify: `Scenes/Characters/Bosses/DemonSlime2/DemonSlime2.gd`

- [ ] **Step 1: Rewrite DemonSlime2.gd**

```gdscript
class_name DemonSlime2 extends AgentAIBase

## DemonSlime2 — 新 AI 架构试点 Boss

# ---- Boss 特化字段 ----
@export var base_move_speed: float = 80.0
@export var detection_radius: float = 600.0
@export var attack_range: float = 250.0
@export var phase_2_hp_pct: float = 0.66
@export var phase_3_hp_pct: float = 0.33

var current_phase: int = 0

const PHASE_SPEED := { 0: 1.0, 1: 1.3, 2: 1.5 }

var move_speed: float:
	get: return base_move_speed * PHASE_SPEED.get(current_phase, 1.0)

func _ready() -> void:
	sprite = $AnimatedSprite2D
	super._ready()
	if health_comp:
		health_comp.health_changed.connect(_on_health_changed)

func _setup_blackboard() -> void:
	super._setup_blackboard()
	var bb := ai.blackboard
	bb.bind_var(&"current_phase", self, &"current_phase")
	bb.set_var(&"detection_radius", detection_radius)
	bb.set_var(&"attack_range", attack_range)
	bb.set_var(&"attack_cooldown", 0.0)
	bb.set_var(&"global_cooldown", 0.0)
	bb.set_var(&"last_action", &"")
	bb.set_var(&"recently_hit", false)
	bb.set_var(&"chase_speed", base_move_speed)

func _setup_transitions() -> void:
	_register_rules([
		# [from,    to,       event,                       guard,               priority]
		["idle",    "chase",  "",                          "_guard_detected",    10],
		["wander",  "chase",  "",                          "_guard_detected",    10],
		["chase",   "idle",   "",                          "_guard_target_lost", 0],
		["chase",   "slam",   "",                          "_guard_can_slam",    20],
		["chase",   "cleave", "",                          "_guard_can_cleave",  10],
		["cleave",  "chase",  AIEvents.EV_ATTACK_FINISHED, "",                   0],
		["slam",    "chase",  AIEvents.EV_ATTACK_FINISHED, "",                   0],
		["*",       "death",  AIEvents.EV_DIED,            "",                   100],
		["*",       "hit",    AIEvents.EV_DAMAGED,         "",                   10],
		["hit",     "chase",  AIEvents.EV_HIT_RECOVERED,   "_guard_target_alive", 10],
		["hit",     "idle",   AIEvents.EV_HIT_RECOVERED,   "",                   0],
	])

# ---- Guard methods ----
func _guard_detected() -> bool:
	var bb := ai.blackboard
	return bb.get_var(&"target_alive", false) and bb.get_var(&"distance", INF) < detection_radius

func _guard_target_lost() -> bool:
	var bb := ai.blackboard
	return not bb.get_var(&"target_alive", false) or bb.get_var(&"distance", INF) > 700.0

func _guard_target_alive() -> bool:
	return ai.blackboard.get_var(&"target_alive", false)

func _guard_can_cleave() -> bool:
	var bb := ai.blackboard
	if bb.get_var(&"attack_cooldown", 1.0) > 0: return false
	if bb.get_var(&"global_cooldown", 1.0) > 0: return false
	if bb.get_var(&"distance", INF) > attack_range: return false
	if bb.get_var(&"last_action") == &"cleave": return false
	return true

func _guard_can_slam() -> bool:
	var bb := ai.blackboard
	if bb.get_var(&"attack_cooldown", 1.0) > 0: return false
	if bb.get_var(&"global_cooldown", 1.0) > 0: return false
	if bb.get_var(&"distance", INF) > 180.0: return false
	if bb.get_var(&"current_phase", 0) < 1: return false
	return true

# ---- Phase system ----
func _on_health_changed(current: float, maximum: float) -> void:
	var pct := current / maxf(maximum, 1.0)
	var new_phase := current_phase
	if pct <= phase_3_hp_pct:
		new_phase = 2
	elif pct <= phase_2_hp_pct:
		new_phase = 1
	if new_phase != current_phase:
		current_phase = new_phase
		ai.blackboard.set_var(&"chase_speed", move_speed)
		ai.dispatch(AIEvents.EV_PHASE_CHANGED)
```

---

### Task 5: Rewrite DS2 Attack States (AnimationPlayer)

**Files:**
- Modify: `Scenes/Characters/Bosses/DemonSlime2/States/DS2Cleave.gd`
- Modify: `Scenes/Characters/Bosses/DemonSlime2/States/DS2Slam.gd`
- Modify: `Scenes/Characters/Bosses/DemonSlime2/States/DS2Counter.gd`
- Modify: `Scenes/Characters/Bosses/DemonSlime2/States/DS2Defend.gd`

- [ ] **Step 1: Rewrite DS2Cleave.gd**

```gdscript
extends AIState

## DS2 Cleave — 扇形冲击波攻击

@export var cleave_cooldown: float = 2.5

func enter() -> void:
	bb.set_var(&"attack_cooldown", cleave_cooldown)
	bb.set_var(&"global_cooldown", 0.3)
	bb.set_var(&"last_action", &"cleave")
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	if "anim_player" in owner_node and owner_node.anim_player:
		owner_node.anim_player.animation_finished.connect(_on_anim_finished, CONNECT_ONE_SHOT)
		owner_node.anim_player.play(&"cleave")

func _on_anim_finished(_name: StringName) -> void:
	dispatch(AIEvents.EV_ATTACK_FINISHED)

func exit() -> void:
	if "anim_player" in owner_node and owner_node.anim_player:
		if owner_node.anim_player.animation_finished.is_connected(_on_anim_finished):
			owner_node.anim_player.animation_finished.disconnect(_on_anim_finished)
```

- [ ] **Step 2: Rewrite DS2Slam.gd**

```gdscript
extends AIState

## DS2 Slam — 近身地面冲击

@export var slam_cooldown: float = 3.0
@export var slam_anim: StringName = &"cleave"

func enter() -> void:
	bb.set_var(&"attack_cooldown", slam_cooldown)
	bb.set_var(&"global_cooldown", 0.5)
	bb.set_var(&"last_action", &"slam")
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	if "anim_player" in owner_node and owner_node.anim_player:
		owner_node.anim_player.animation_finished.connect(_on_anim_finished, CONNECT_ONE_SHOT)
		owner_node.anim_player.play(slam_anim)

func _on_anim_finished(_name: StringName) -> void:
	dispatch(AIEvents.EV_ATTACK_FINISHED)

func exit() -> void:
	if "anim_player" in owner_node and owner_node.anim_player:
		if owner_node.anim_player.animation_finished.is_connected(_on_anim_finished):
			owner_node.anim_player.animation_finished.disconnect(_on_anim_finished)
```

- [ ] **Step 3: Rewrite DS2Counter.gd**

```gdscript
extends AIState

## DS2 Counter — Poise 破防后的反击动作

func enter() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	if "anim_player" in owner_node and owner_node.anim_player:
		owner_node.anim_player.animation_finished.connect(_on_anim_finished, CONNECT_ONE_SHOT)
		owner_node.anim_player.play(&"hit")

func _on_anim_finished(_name: StringName) -> void:
	dispatch(AIEvents.EV_REACTION_DONE)

func exit() -> void:
	if "anim_player" in owner_node and owner_node.anim_player:
		if owner_node.anim_player.animation_finished.is_connected(_on_anim_finished):
			owner_node.anim_player.animation_finished.disconnect(_on_anim_finished)
```

- [ ] **Step 4: Rewrite DS2Defend.gd**

```gdscript
extends AIState

## DS2 Defend — 格挡动作

func enter() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	if "anim_player" in owner_node and owner_node.anim_player:
		owner_node.anim_player.animation_finished.connect(_on_anim_finished, CONNECT_ONE_SHOT)
		owner_node.anim_player.play(&"hit")

func _on_anim_finished(_name: StringName) -> void:
	dispatch(AIEvents.EV_REACTION_DONE)

func exit() -> void:
	if "anim_player" in owner_node and owner_node.anim_player:
		if owner_node.anim_player.animation_finished.is_connected(_on_anim_finished):
			owner_node.anim_player.animation_finished.disconnect(_on_anim_finished)
```

Note: DS2Roll.gd needs no change — it already uses velocity + timer, no AnimationTree.

---

### Task 6: Update DemonSlime2.tscn

**Files:**
- Modify: `Scenes/Characters/Bosses/DemonSlime2/DemonSlime2.tscn` (in Godot editor)

- [ ] **Step 1: Verify inherited scene still works**

The .tscn inherits from AgentAIBase.tscn. After AgentAIBase.tscn changes (Task 3), the inherited scene may need adjustments:
- Root script is already overridden to DemonSlime2.gd ✓
- AnimationTree node removed from base → any DS2 overrides to AnimationTree become orphan properties (Godot handles this gracefully — they're just ignored)

Run LevelBladeKeeper to verify:
```bash
"D:/devtool/godot/Godot_v4.6-stable_win64.exe/Godot_v4.6-stable_win64_console.exe" --path "E:/workspace/4.godot/combo_demon" "res://Scenes/Levels/Level_BladeKeeper/LevelBladeKeeper.tscn"
```

Expected: No errors, DS2 visible, AI transitions logged as `[AI] → idle`, `[AI] → chase`, etc.

---

### Task 7: Update Integration Tests

**Files:**
- Modify: `test/integration/test_ds2.gd`

- [ ] **Step 1: Simplify test setup — use AgentAIBase pattern**

The integration tests should verify `_register_rules` works and that the full DS2 rule set produces correct transitions. Since the tests create nodes manually (not from .tscn), they don't need to change much — the AIController + AIState setup is the same. The main change: verify `_register_rules` auto-skip works.

Add this test to `test/unit/test_ai_controller.gd`:

```gdscript
func test_register_rules_skips_missing_states() -> void:
	# Only idle, chase, hit, death exist — "wander" and "attack" do not
	var mock_owner = _owner
	# Create a temporary AgentAIBase-like object to test _register_rules
	# Since _register_rules is on AgentAIBase, we test the logic directly:
	var rules := [
		["idle", "chase", "", "", 0],       # both exist → should register
		["idle", "wander", "", "", 0],      # wander missing → should skip
		["idle", "attack", "", "", 0],      # attack missing → should skip
		["*", "death", "died", "", 100],    # ANYSTATE → should register
	]
	# Manually do what _register_rules does
	var count_before := _ai._transitions.size()
	for r in rules:
		var from: AIState = null if r[0] == "*" else _ai.get_state(StringName(r[0]))
		var to: AIState = _ai.get_state(StringName(r[1]))
		if r[0] != "*" and from == null: continue
		if to == null: continue
		_ai.add_transition(from, to, StringName(r[2]), Callable(), r[4])
	var count_after := _ai._transitions.size()
	# Only 2 rules should have been added (idle→chase + *→death)
	assert_eq(count_after - count_before, 2, "should skip rules with missing states")
```

---

### Task 8: Runtime Verification

- [ ] **Step 1: Launch LevelBladeKeeper**

```bash
"D:/devtool/godot/Godot_v4.6-stable_win64.exe/Godot_v4.6-stable_win64_console.exe" --path "E:/workspace/4.godot/combo_demon" "res://Scenes/Levels/Level_BladeKeeper/LevelBladeKeeper.tscn"
```

Expected: Zero errors, DS2 spawns, AI logs `[AI] → idle` then `[AI] → chase` when player approaches.

- [ ] **Step 2: Verify walk animation plays during chase**

Walk up to DemonSlime2 — it should play "walk" animation and move toward player.

- [ ] **Step 3: Verify attack transition**

Get within attack_range (250) with cooldown=0 — DS2 should transition to cleave, play cleave animation, then return to chase.

- [ ] **Step 4: Fix any runtime issues**

Iterate on issues found during testing.
