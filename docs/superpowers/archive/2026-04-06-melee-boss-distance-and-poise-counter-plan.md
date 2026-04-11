# Melee Boss Distance Model & Poise Counter System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix melee boss distance handling (remove retreat for melee) and add a poise-based counter-attack system that triggers when the boss is hit repeatedly.

**Architecture:** Two changes share the BossBase/BossBaseState layer. (1) `is_melee` flag gates the `min_distance → retreat` branch in `evaluate_combat_transition`. (2) Poise system lives in BossBase (data) + BossBaseState (trigger) + new BossCounterState (behavior). Counter VFX reuses the GhostExpandEffect pattern with a red color.

**Tech Stack:** GDScript (Godot 4.4.1), existing shader/VFX infrastructure

**Spec:** `docs/superpowers/specs/2026-04-06-melee-boss-distance-and-poise-counter.md`

---

### Task 1: Add `is_melee` flag to BossBase and update distance logic

**Files:**
- Modify: `Core/Characters/BossBase.gd:32-35` (Detection exports)
- Modify: `Scenes/Characters/Bosses/Shared/BossBaseState.gd:57-81` (evaluate_combat_transition)

- [ ] **Step 1: Add `is_melee` export to BossBase**

In `Core/Characters/BossBase.gd`, add after the existing Detection exports (after line 35):

```gdscript
@export var is_melee := false       ## 近战 Boss 不使用 min_distance 撤退机制
```

The Detection group becomes:
```gdscript
@export_group("Detection")
@export var detection_radius := 800.0
@export var attack_range := 300.0
@export var min_distance := 150.0
@export var is_melee := false       ## 近战 Boss 不使用 min_distance 撤退机制
```

- [ ] **Step 2: Update evaluate_combat_transition to skip min_distance for melee**

In `Scenes/Characters/Bosses/Shared/BossBaseState.gd`, change lines 70-72 from:

```gdscript
	# 太近 → 撤退
	if distance < _boss.min_distance:
		return _resolve_state("retreat", "chase")
```

to:

```gdscript
	# 太近 → 撤退（仅远程 Boss）
	if not _boss.is_melee and distance < _boss.min_distance:
		return _resolve_state("retreat", "chase")
```

- [ ] **Step 3: Verify in-editor** 

Run: `mcp__godot__run_project` and confirm BladeKeeper still chases and attacks without errors. No behavior change yet (BladeKeeper doesn't set `is_melee` yet).

- [ ] **Step 4: Commit**

```bash
git add Core/Characters/BossBase.gd Scenes/Characters/Bosses/Shared/BossBaseState.gd
git commit -m "feat: add is_melee flag to BossBase, skip min_distance retreat for melee bosses"
```

---

### Task 2: Configure BladeKeeper as melee boss

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd:20-23` (_on_boss_ready)

- [ ] **Step 1: Set is_melee and remove min_distance assignment**

In `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd`, change `_on_boss_ready()` from:

```gdscript
func _on_boss_ready() -> void:
	detection_radius = 800.0
	attack_range = 200.0
	min_distance = 100.0
```

to:

```gdscript
func _on_boss_ready() -> void:
	detection_radius = 800.0
	attack_range = 200.0
	is_melee = true
```

- [ ] **Step 2: Verify** 

Run the project, confirm BladeKeeper chases into attack range and attacks without retreating.

- [ ] **Step 3: Commit**

```bash
git add Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd
git commit -m "feat: configure BladeKeeper as melee boss (is_melee=true)"
```

---

### Task 3: Add poise data layer to BossBase

**Files:**
- Modify: `Core/Characters/BossBase.gd`

- [ ] **Step 1: Add poise exports and runtime vars**

In `Core/Characters/BossBase.gd`, add a new export group after the Phase Settings group (after line 43):

```gdscript
@export_group("Poise / Counter")
@export var poise_enabled := false          ## 是否启用韧性反击系统
@export var max_poise := 5                  ## 默认韧性值
@export var poise_per_phase: Dictionary = {} ## 可选：{Phase.PHASE_2: 4, Phase.PHASE_3: 3}
@export var poise_immunity_time := 1.5      ## 反击后免疫窗口
```

Add runtime vars after the existing `stun_immunity` var (after line 53):

```gdscript
# 韧性（Poise）
var current_poise: int = 0
var poise_immunity: float = 0.0
```

- [ ] **Step 2: Initialize poise in _on_character_ready**

In `_on_character_ready()`, add after the behavior_config block (after line 69):

```gdscript
	# 初始化韧性
	if poise_enabled:
		current_poise = max_poise
```

- [ ] **Step 3: Update _physics_process to decrement poise_immunity**

In `_physics_process()`, add after the `stun_immunity` decrement (after line 90):

```gdscript
	if poise_immunity > 0:
		poise_immunity -= delta
```

- [ ] **Step 4: Add take_poise_hit and reset_poise methods**

Add before the death handling section (before `func _handle_death()`):

```gdscript
# ============ 韧性系统 ============

## 扣减韧性，返回是否触发反击
func take_poise_hit() -> bool:
	if not poise_enabled or poise_immunity > 0:
		return false
	current_poise -= 1
	return current_poise <= 0

## 反击后重置韧性
func reset_poise() -> void:
	var phase_poise: int = poise_per_phase.get(current_phase, max_poise)
	current_poise = phase_poise
	poise_immunity = poise_immunity_time
```

- [ ] **Step 5: Update _on_phase_transition to reset poise**

Change `_on_phase_transition()` from:

```gdscript
func _on_phase_transition() -> void:
	pass  # 子类可覆盖
```

to:

```gdscript
func _on_phase_transition() -> void:
	# 阶段切换时更新韧性
	if poise_enabled:
		var phase_poise: int = poise_per_phase.get(current_phase, max_poise)
		current_poise = phase_poise
```

- [ ] **Step 6: Commit**

```bash
git add Core/Characters/BossBase.gd
git commit -m "feat: add poise data layer to BossBase (exports, runtime vars, methods)"
```

---

### Task 4: Add pick_counter_attack to BossPhaseConfig

**Files:**
- Modify: `Scenes/Characters/Bosses/Shared/BossPhaseConfig.gd`

- [ ] **Step 1: Add pick_counter_attack method**

In `Scenes/Characters/Bosses/Shared/BossPhaseConfig.gd`, add after `pick_retreat_attack()` (after line 73):

```gdscript

## 从攻击池中选取反击招式（筛选 counter=true，空则回退到主攻击池）
func pick_counter_attack() -> Dictionary:
	var pool := attacks.filter(func(e): return e.get("counter", false))
	if pool.is_empty():
		pool = attacks  # fallback：任意招式
	return _pick_from_pool(pool)
```

- [ ] **Step 2: Commit**

```bash
git add Scenes/Characters/Bosses/Shared/BossPhaseConfig.gd
git commit -m "feat: add pick_counter_attack() to BossPhaseConfig"
```

---

### Task 5: Update BossBaseState.on_damaged to trigger counter

**Files:**
- Modify: `Scenes/Characters/Bosses/Shared/BossBaseState.gd:123-132` (on_damaged)

- [ ] **Step 1: Rewrite on_damaged with poise check**

In `Scenes/Characters/Bosses/Shared/BossBaseState.gd`, replace the entire `on_damaged` method (lines 124-132):

```gdscript
## Boss 特有的 on_damaged 实现
## 优先级：poise 反击 > Phase 3 免疫 > stun
func on_damaged(_damage: Damage, _attacker_position: Vector2 = Vector2.ZERO) -> void:
	var boss := get_boss()
	if not boss:
		return
	if boss.stun_immunity > 0:
		return

	# Poise 检查（优先于 stun）
	if boss.poise_enabled and boss.take_poise_hit():
		transitioned.emit(self, "counter")
		return

	# Phase 3 眩晕免疫
	if boss.current_phase == BossBase.Phase.PHASE_3:
		return

	transitioned.emit(self, "stun")
```

- [ ] **Step 2: Commit**

```bash
git add Scenes/Characters/Bosses/Shared/BossBaseState.gd
git commit -m "feat: update BossBaseState.on_damaged with poise counter trigger"
```

---

### Task 6: Create CounterFlashEffect VFX

**Files:**
- Create: `Core/Effects/CounterFlashEffect.gd`

- [ ] **Step 1: Create CounterFlashEffect**

Create `Core/Effects/CounterFlashEffect.gd`. This follows the same pattern as `GhostExpandEffect` — applies a shader material to the source sprite, runs a tween animation, then cleans up. Uses the existing `golden_outline_flash.gdshader` with a red color.

```gdscript
extends Node2D
class_name CounterFlashEffect

## 反击蓄力闪光效果 — 红色描边脉冲 + 微缩放
## 复用 golden_outline_flash.gdshader，红色调

signal effect_finished()

@export var duration: float = 0.4
@export var thickness: float = 1.5
@export var flash_color: Color = Color(1.0, 0.2, 0.1, 1.0)  ## 红橙色

var _source_sprite: Node2D = null
var _original_material: Material = null
var _shader_material: ShaderMaterial = null
var _original_scale: Vector2 = Vector2.ONE

static var _shader: Shader = null

## 对目标精灵应用反击闪光效果
func create_from_sprite(source_sprite: Node2D, _spawn_position: Vector2) -> void:
	_source_sprite = source_sprite
	_original_scale = source_sprite.scale

	if _shader == null:
		_shader = load("res://Assets/Shaders/golden_outline_flash.gdshader")

	_original_material = source_sprite.material

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = _shader
	_shader_material.set_shader_parameter("outline_color", flash_color)
	_shader_material.set_shader_parameter("thickness", 0.0)
	source_sprite.material = _shader_material

	_play_counter_flash()

func _play_counter_flash() -> void:
	var tween = create_tween()
	var peak := thickness

	# 快速亮起红色描边
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_method(_set_thickness, 0.0, peak, duration * 0.2)

	# 缩放脉冲 (1.0 → 1.1 → 1.0)
	tween.parallel().tween_property(_source_sprite, "scale", _original_scale * 1.1, duration * 0.2)

	# 保持高亮
	tween.tween_interval(duration * 0.4)

	# 渐隐 + 恢复缩放
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_method(_set_thickness, peak, 0.0, duration * 0.4)
	tween.parallel().tween_property(_source_sprite, "scale", _original_scale, duration * 0.4)

	tween.tween_callback(_cleanup)

func _set_thickness(value: float) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("thickness", value)

func _cleanup() -> void:
	if is_instance_valid(_source_sprite):
		_source_sprite.material = _original_material
		_source_sprite.scale = _original_scale
	_source_sprite = null
	_original_material = null
	if _shader_material:
		_shader_material.shader = null
	_shader_material = null
	effect_finished.emit()
	queue_free()

func _exit_tree() -> void:
	if is_instance_valid(_source_sprite) and _source_sprite.material == _shader_material:
		_source_sprite.material = _original_material
		_source_sprite.scale = _original_scale
	if _shader_material:
		_shader_material.shader = null
	_shader_material = null

# ============ 静态工厂方法 ============
static func create(source_sprite: Node2D, spawn_position: Vector2, parent: Node) -> CounterFlashEffect:
	var effect = CounterFlashEffect.new()
	effect._pending_source_sprite = source_sprite
	effect._pending_spawn_position = spawn_position
	parent.call_deferred("add_child", effect)
	return effect

var _pending_source_sprite: Node2D = null
var _pending_spawn_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	if _pending_source_sprite:
		create_from_sprite(_pending_source_sprite, _pending_spawn_position)
		_pending_source_sprite = null
```

- [ ] **Step 2: Commit**

```bash
git add Core/Effects/CounterFlashEffect.gd
git commit -m "feat: add CounterFlashEffect VFX (red outline flash + scale pulse)"
```

---

### Task 7: Create BossCounterState

**Files:**
- Create: `Scenes/Characters/Bosses/Shared/BossCounterState.gd`

- [ ] **Step 1: Create BossCounterState**

Create `Scenes/Characters/Bosses/Shared/BossCounterState.gd`:

```gdscript
extends BossState
class_name BossCounterState

## Boss 反击状态 — poise 归零后触发
## 流程：震退(stagger) + VFX → 选反击招式 → 执行攻击 → 重置 poise → 转出
##
## 优先级 REACTION + stun_immunity 保护，防止反击被眩晕打断

enum Phase { STAGGER, COUNTER_ATTACK }

@export var stagger_duration := 0.4  ## 震退阶段时长

var _phase: Phase = Phase.STAGGER
var _stagger_timer: SceneTreeTimer
var _counter_entry: Dictionary = {}

func _init() -> void:
	priority = StatePriority.REACTION
	can_be_interrupted = false

func enter() -> void:
	var boss := get_boss()
	if not boss:
		transitioned.emit(self, "idle")
		return

	_phase = Phase.STAGGER

	# 设置 stun_immunity 防止被打断
	boss.stun_immunity = stagger_duration + 2.0  # 留足反击动画时间
	boss.velocity = Vector2.ZERO
	boss.can_move = false

	# 播放 hit 动画作为震退
	enter_control_state("hit")

	# 触发红色闪光 VFX
	_spawn_counter_vfx(boss)

	# 震退计时器
	_stagger_timer = get_tree().create_timer(stagger_duration)
	_stagger_timer.timeout.connect(_on_stagger_finished)

	DebugConfig.debug("[BossCounter] 进入震退阶段", "", "combat")

func _spawn_counter_vfx(boss: BossBase) -> void:
	var sprite := boss.get_node_or_null("AnimatedSprite2D") as Node2D
	if not sprite:
		return
	CounterFlashEffect.create(sprite, boss.global_position, boss)

func _on_stagger_finished() -> void:
	_phase = Phase.COUNTER_ATTACK

	# 从攻击池选反击招式
	var mgr := get_attack_manager()
	if not mgr:
		_finish_counter()
		return

	var config := _get_phase_config()
	if not config:
		_finish_counter()
		return

	_counter_entry = config.pick_counter_attack()
	var mode: String = _counter_entry.get("mode", "attack")

	DebugConfig.debug("[BossCounter] 反击招式: %s" % mode, "", "combat")

	# 反击选定后立即重置 poise（攻击状态结束后不会回到 counter）
	var boss := get_boss()
	if boss:
		boss.reset_poise()
		boss.can_move = true

	# 面朝玩家
	_face_player()

	# 缓存到 last_picked_entry 供攻击状态读取
	mgr.last_picked_entry = _counter_entry

	# 转到攻击状态执行反击
	exit_control_state()
	transitioned.emit(self, _resolve_counter_state(mode))

func _resolve_counter_state(mode: String) -> String:
	match mode:
		"defend":
			return _resolve_state("defend", "attack")
		"projectile":
			return _resolve_state("projectile", "attack")
		"trap":
			return _resolve_state("trap", "attack")
		"roll":
			return _resolve_state("roll", "attack")
		_:
			# attack, combo, special, jump → 统一由 attack 状态处理
			return _resolve_state("attack", "idle")

func _finish_counter() -> void:
	var boss := get_boss()
	if boss:
		boss.reset_poise()
		boss.can_move = true
	exit_control_state()
	var next := evaluate_combat_transition(false)
	transitioned.emit(self, next)

func _face_player() -> void:
	var boss := get_boss()
	if not boss or not target_node:
		return
	var sprite := boss.get_node_or_null("AnimatedSprite2D") as Node2D
	if sprite and "flip_h" in sprite:
		sprite.flip_h = boss.global_position.x > target_node.global_position.x

func exit() -> void:
	exit_control_state()
	_phase = Phase.STAGGER

	if _stagger_timer and _stagger_timer.timeout.is_connected(_on_stagger_finished):
		_stagger_timer.timeout.disconnect(_on_stagger_finished)

	var boss := get_boss()
	if boss:
		boss.can_move = true

func on_damaged(_damage: Damage, _attacker_position: Vector2 = Vector2.ZERO) -> void:
	# 反击中不响应伤害（stun_immunity 已保护）
	pass
```

- [ ] **Step 2: Commit**

```bash
git add Scenes/Characters/Bosses/Shared/BossCounterState.gd
git commit -m "feat: add BossCounterState (stagger + VFX + counter-attack dispatch)"
```

---

### Task 8: Configure BladeKeeper poise and counter attacks

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd:20-23`
- Modify: `Scenes/Characters/Bosses/BladeKeeper/BKAttackManager.gd:99-141`

- [ ] **Step 1: Enable poise in BladeKeeper**

In `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd`, update `_on_boss_ready()` to:

```gdscript
func _on_boss_ready() -> void:
	detection_radius = 800.0
	attack_range = 200.0
	is_melee = true
	# Poise 反击系统
	poise_enabled = true
	max_poise = 5
	poise_per_phase = {Phase.PHASE_2: 4, Phase.PHASE_3: 3}
```

- [ ] **Step 2: Mark counter attacks in BKAttackManager phase configs**

In `Scenes/Characters/Bosses/BladeKeeper/BKAttackManager.gd`, add `"counter": true` to specific entries in `_setup_default_phases()`.

Phase 1 — mark the combo entry:
```gdscript
	p1.attacks = [
		{"mode": "combo", "weight": 2, "counter": true},
		{"mode": "projectile", "weight": 1},
	]
```

Phase 2 — mark special:
```gdscript
	p2.attacks = [
		{"mode": "combo", "weight": 3},
		{"mode": "jump", "weight": 2},
		{"mode": "defend", "weight": 2},
		{"mode": "roll", "weight": 2},
		{"mode": "projectile", "weight": 2},
		{"mode": "trap", "weight": 2},
		{"mode": "special", "weight": 1, "counter": true},
	]
```

Phase 3 — mark combo:
```gdscript
	p3.attacks = [
		{"mode": "combo", "weight": 3, "counter": true},
		{"mode": "jump", "weight": 3},
		{"mode": "defend", "weight": 1},
		{"mode": "roll", "weight": 2},
		{"mode": "projectile", "weight": 2},
		{"mode": "trap", "weight": 2},
		{"mode": "special", "weight": 2},
	]
```

- [ ] **Step 3: Commit**

```bash
git add Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd Scenes/Characters/Bosses/BladeKeeper/BKAttackManager.gd
git commit -m "feat: configure BladeKeeper poise (5/4/3) and mark counter attacks"
```

---

### Task 9: Add Counter state node to BladeKeeper scene

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn`

- [ ] **Step 1: Add Counter node via MCP or manual edit**

Add a Counter state node to the BladeKeeper StateMachine. Use `mcp__godot__add_node` to add a Node named "Counter" under the StateMachine, with script `res://Scenes/Characters/Bosses/Shared/BossCounterState.gd`.

Alternatively, add this block to `BladeKeeper.tscn` after the Trap node (after the last state node):

```
[node name="Counter" type="Node" parent="StateMachine" index="8"]
script = ExtResource("BossCounterState_script")
```

This requires adding an `ext_resource` entry for the BossCounterState script at the top of the `.tscn` file. The MCP approach is simpler.

- [ ] **Step 2: Verify the scene loads**

Run: `mcp__godot__run_project`
Expected: No errors about missing "counter" state. BladeKeeper loads and operates.

- [ ] **Step 3: Commit**

```bash
git add Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn
git commit -m "feat: add Counter state node to BladeKeeper scene"
```

---

### Task 10: Integration test — play and verify counter mechanic

- [ ] **Step 1: Run the project and test**

Run: `mcp__godot__run_project`

Test sequence:
1. Approach BladeKeeper → verify it chases into attack range (no retreat behavior)
2. Attack BladeKeeper 5 times quickly → verify counter triggers (red flash + stagger + counter-attack)
3. After counter, verify boss resumes normal behavior
4. Reduce boss to Phase 2 → verify poise threshold drops to 4
5. Reduce boss to Phase 3 → verify poise threshold drops to 3

- [ ] **Step 2: Check debug output**

Run: `mcp__godot__get_debug_output`

Expected log lines:
- `[BossCounter] 进入震退阶段`
- `[BossCounter] 反击招式: combo` (or special, depending on phase)
- No errors or warnings related to counter/poise

- [ ] **Step 3: Final commit (if any fixes needed)**

```bash
git add -A
git commit -m "fix: integration fixes for poise counter system"
```

---

## Task Dependency Summary

```
Task 1 (is_melee flag) → Task 2 (BladeKeeper melee config)
Task 3 (poise data) → Task 4 (pick_counter_attack) → Task 5 (on_damaged trigger)
Task 6 (VFX) ─┐
Task 5 ────────┼→ Task 7 (BossCounterState) → Task 8 (BK config) → Task 9 (scene) → Task 10 (test)
Task 4 ────────┘
```

Tasks 1-2 and Tasks 3-6 can be done in parallel.
