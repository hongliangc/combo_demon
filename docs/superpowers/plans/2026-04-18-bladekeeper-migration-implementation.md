# BladeKeeper Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate BladeKeeper from BossBase + BKAttackManager step-machine architecture to AgentAIBase + SkillSet data-driven architecture, while preserving BossBase for Cyclops.

**Architecture:** Replace 327-line `BKAttack.gd` step machine with ~12 Skill / ComboSkill .tres resources selected by SkillSet. Add shared `ApproachState` for high-speed gap-closing. Extend `GenericAttackState` with `call_skill_method` to bridge animation method tracks to boss buff/heal methods (interim solution before full BuffEntity framework).

**Tech Stack:** Godot 4.4.1, GDScript, GUT test framework. Skill system primitives (Skill, ComboSkill, SkillSet, AttackDispatcher, GenericAttackState, ComboState) already in place.

**Reference spec:** `docs/superpowers/specs/2026-04-18-bladekeeper-migration-design.md`

---

## File Structure

### New shared infrastructure (Core)
- `Core/AI/Stock/ApproachState.gd` — gap-closing executor (new)
- `Core/AI/Stock/GenericAttackState.gd` — extend with `call_skill_method` (modify)

### New tests
- `test/unit/test_approach_state.gd` — unit test for ApproachState
- `test/unit/test_generic_attack_method_call.gd` — unit test for `call_skill_method`

### New BK skill resources (`Scenes/Characters/Bosses/BladeKeeper/skills/`)
Single Skills: `bk_atk_basic.tres`, `bk_atk_heavy.tres`, `bk_dash_approach.tres`, `bk_throw_sword.tres`, `bk_place_trap.tres`, `bk_dodge_back.tres`, `bk_defend_buff.tres`, `bk_heal_self.tres`
ComboSkills: `bk_combo_basic.tres`, `bk_combo_finisher_p2.tres`, `bk_combo_finisher_p3.tres`
(Defer `bk_combo_dodge_seq` to Phase 2 — see spec §8.)

### Modified BK files
- `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd` — full rewrite, extends `AgentAIBase`
- `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn` — replace StateMachine children

### Deleted files
- `BKAttackManager.gd` (+ .uid)
- `BKStateMachine.gd` (+ .uid)
- `States/BKAttack.gd` (+ .uid)
- `States/BKChase.gd` (+ .uid)
- `States/BKDefend.gd` (+ .uid)
- `States/BKRoll.gd` (+ .uid)
- `States/BKProjectile.gd` (+ .uid)
- `States/BKTrap.gd` (+ .uid)
- `States/BKIdle.gd` (+ .uid)  — replaced by Stock/IdleState
- `test/unit/test_bk_attack.gd` (+ .uid)

---

## Task 1: Add `call_skill_method` to GenericAttackState (TDD)

**Files:**
- Test: `test/unit/test_generic_attack_method_call.gd` (create)
- Modify: `Core/AI/Stock/GenericAttackState.gd`

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_generic_attack_method_call.gd`:

```gdscript
extends GutTest

## Stub owner that records method calls
class _StubOwner:
    extends Node
    var calls: Array = []
    func apply_buff(duration: float) -> void:
        calls.append([&"apply_buff", duration])
    func heal_self() -> void:
        calls.append([&"heal_self", null])

## Stub AI exposing current_skill
class _StubAI:
    extends Node
    var current_skill: Skill

func _make_state(owner_node: Node, skill: Skill) -> Node:
    var state = load("res://Core/AI/Stock/GenericAttackState.gd").new()
    state.name = "GenericAttack"
    var ai := _StubAI.new()
    ai.current_skill = skill
    state.ai = ai
    state.owner_node = owner_node
    return state

func test_call_skill_method_invokes_owner_method_with_arg() -> void:
    var owner := _StubOwner.new()
    add_child_autofree(owner)
    var skill := Skill.new()
    skill.params = { &"method": &"apply_buff", &"method_arg": 3.0 }
    var state = _make_state(owner, skill)
    state.call_skill_method()
    assert_eq(owner.calls.size(), 1)
    assert_eq(owner.calls[0][0], &"apply_buff")
    assert_eq(owner.calls[0][1], 3.0)

func test_call_skill_method_no_arg_calls_method_without_args() -> void:
    var owner := _StubOwner.new()
    add_child_autofree(owner)
    var skill := Skill.new()
    skill.params = { &"method": &"heal_self" }
    var state = _make_state(owner, skill)
    state.call_skill_method()
    assert_eq(owner.calls.size(), 1)
    assert_eq(owner.calls[0][0], &"heal_self")

func test_call_skill_method_missing_method_silently_skips() -> void:
    var owner := _StubOwner.new()
    add_child_autofree(owner)
    var skill := Skill.new()
    skill.params = { &"method": &"nonexistent_method" }
    var state = _make_state(owner, skill)
    state.call_skill_method()  # should not crash
    assert_eq(owner.calls.size(), 0)

func test_call_skill_method_no_method_param_silently_skips() -> void:
    var owner := _StubOwner.new()
    add_child_autofree(owner)
    var skill := Skill.new()
    skill.params = {}
    var state = _make_state(owner, skill)
    state.call_skill_method()
    assert_eq(owner.calls.size(), 0)

func test_call_skill_method_no_current_skill_silently_skips() -> void:
    var owner := _StubOwner.new()
    add_child_autofree(owner)
    var state = _make_state(owner, null)
    state.call_skill_method()
    assert_eq(owner.calls.size(), 0)
```

- [ ] **Step 2: Run test, verify it fails**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_generic_attack_method_call.gd -gexit`
Expected: FAIL with "Invalid call. Nonexistent function 'call_skill_method'"

- [ ] **Step 3: Add `call_skill_method` to GenericAttackState**

Edit `Core/AI/Stock/GenericAttackState.gd`, append at end of file:

```gdscript

## 动画 method call track 调用：调用 owner_node 上的方法
## 用于 BuffEntity 框架到位前的过渡方案
func call_skill_method() -> void:
    var skill: Skill = ai.current_skill
    if not skill:
        return
    var method_name: StringName = skill.params.get(&"method", &"")
    if method_name == &"" or not owner_node.has_method(method_name):
        return
    var arg = skill.params.get(&"method_arg", null)
    if arg == null:
        owner_node.call(method_name)
    else:
        owner_node.call(method_name, arg)
```

- [ ] **Step 4: Run test, verify all 5 cases pass**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_generic_attack_method_call.gd -gexit`
Expected: 5 PASS, 0 FAIL.

- [ ] **Step 5: Commit**

```bash
git add Core/AI/Stock/GenericAttackState.gd test/unit/test_generic_attack_method_call.gd test/unit/test_generic_attack_method_call.gd.uid
git commit -m "feat: GenericAttackState supports animation method call to owner"
```

---

## Task 2: Create ApproachState (TDD)

**Files:**
- Test: `test/unit/test_approach_state.gd` (create)
- Create: `Core/AI/Stock/ApproachState.gd`

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_approach_state.gd`:

```gdscript
extends GutTest

## Minimal CharacterBody2D stub
class _StubBody:
    extends CharacterBody2D
    var anim_player = null
    var sprite = null

class _StubAI:
    extends Node
    var current_skill: Skill = null
    var current_skill_finished: bool = false
    func goto(_n: StringName) -> void:
        pass

func _make_state(body: CharacterBody2D, skill: Skill, distance: float) -> Node:
    var state = load("res://Core/AI/Stock/ApproachState.gd").new()
    state.name = "Approach"
    var ai := _StubAI.new()
    ai.current_skill = skill
    state.ai = ai
    state.owner_node = body
    state.bb = AIBlackboard.new()
    state.bb.set_var(&"distance", distance)
    return state

func test_physics_update_sets_velocity_toward_target() -> void:
    var body := _StubBody.new()
    add_child_autofree(body)
    var skill := Skill.new()
    skill.params = { &"speed": 350.0, &"direction": &"toward_target", &"stop_distance": 100.0 }
    var state = _make_state(body, skill, 500.0)
    state.bb.set_var(&"target_position", Vector2(800, 0))
    body.global_position = Vector2(0, 0)
    state.physics_update(0.016)
    assert_eq(body.velocity.x, 350.0)

func test_physics_update_finishes_when_within_stop_distance() -> void:
    var body := _StubBody.new()
    add_child_autofree(body)
    var skill := Skill.new()
    skill.params = { &"speed": 350.0, &"direction": &"toward_target", &"stop_distance": 100.0 }
    var state = _make_state(body, skill, 80.0)  # already inside stop_distance
    state.bb.set_var(&"target_position", Vector2(80, 0))
    body.global_position = Vector2(0, 0)
    state.physics_update(0.016)
    # _finish() in BaseAttackState clears ai.current_skill; use that as proxy for "finished"
    assert_null(state.ai.current_skill, "current_skill should be cleared by _finish")

func test_physics_update_no_skill_does_nothing() -> void:
    var body := _StubBody.new()
    add_child_autofree(body)
    var state = _make_state(body, null, 500.0)
    state.physics_update(0.016)
    assert_eq(body.velocity.x, 0.0)
```

- [ ] **Step 2: Run test, verify it fails**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_approach_state.gd -gexit`
Expected: FAIL with "could not load script Core/AI/Stock/ApproachState.gd".

- [ ] **Step 3: Implement ApproachState**

Create `Core/AI/Stock/ApproachState.gd`:

```gdscript
# Core/AI/Stock/ApproachState.gd
extends BaseAttackState

## 突进执行器：高速接近目标，到达 stop_distance 或动画结束即退出
## params:
##   animation: StringName     播放动画名（可选）
##   speed: float              冲刺速度
##   direction: StringName     方向键（默认 toward_target）
##   stop_distance: float      距目标 ≤ 此值时提前结束（0 = 不提前结束）

func enter() -> void:
    var skill: Skill = ai.current_skill
    if not skill:
        _finish()
        return
    var anim_name = skill.params.get(&"animation", &"")
    if anim_name and "anim_player" in owner_node and owner_node.anim_player:
        owner_node.anim_player.play(anim_name)
        owner_node.anim_player.animation_finished.connect(_on_anim_done, CONNECT_ONE_SHOT)

func physics_update(_delta: float) -> void:
    var skill: Skill = ai.current_skill
    if not skill or not (owner_node is CharacterBody2D):
        return
    var spd: float = skill.params.get(&"speed", 0.0)
    var dir_key: StringName = skill.params.get(&"direction", &"toward_target")
    (owner_node as CharacterBody2D).velocity.x = _resolve_direction(dir_key) * spd
    var stop_dist: float = skill.params.get(&"stop_distance", 0.0)
    if stop_dist > 0 and bb.get_var(&"distance", INF) <= stop_dist:
        _finish()

func exit() -> void:
    if "anim_player" in owner_node and owner_node.anim_player:
        if owner_node.anim_player.animation_finished.is_connected(_on_anim_done):
            owner_node.anim_player.animation_finished.disconnect(_on_anim_done)

func _on_anim_done(_anim_name: StringName) -> void:
    _finish()
```

- [ ] **Step 4: Run test, verify all 3 cases pass**

Run: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_approach_state.gd -gexit`
Expected: 3 PASS, 0 FAIL.

- [ ] **Step 5: Commit**

```bash
git add Core/AI/Stock/ApproachState.gd Core/AI/Stock/ApproachState.gd.uid test/unit/test_approach_state.gd test/unit/test_approach_state.gd.uid
git commit -m "feat: add ApproachState for high-speed gap-closing skills"
```

---

## Task 3: Create skills directory + first single Skill resources

**Files:**
- Create: `Scenes/Characters/Bosses/BladeKeeper/skills/bk_atk_basic.tres`
- Create: `Scenes/Characters/Bosses/BladeKeeper/skills/bk_atk_heavy.tres`

- [ ] **Step 1: Verify expected animation names exist on BK AnimationPlayer**

Open `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn` in Godot editor, inspect AnimationPlayer.
Required animations for these two skills: `attack_1`, `attack_2`. If names differ, record the mapping and use the actual names in the .tres `params.animation` fields.

- [ ] **Step 2: Create `bk_atk_basic.tres`**

Create file `Scenes/Characters/Bosses/BladeKeeper/skills/bk_atk_basic.tres`:

```
[gd_resource type="Resource" script_class="Skill" load_steps=2 format=3]

[ext_resource type="Script" path="res://Core/AI/Skill.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"bk_atk_basic"
state_name = &"generic_attack"
cooldown = 0.8
weight = 10
min_phase = 1
max_phase = -1
min_range = 0.0
max_range = 180.0
tags = [&"offensive", &"melee"]
precondition_method = &""
interruptible = true
params = {
    &"animation": &"attack_1"
}
```

- [ ] **Step 3: Create `bk_atk_heavy.tres`**

Create file `Scenes/Characters/Bosses/BladeKeeper/skills/bk_atk_heavy.tres`:

```
[gd_resource type="Resource" script_class="Skill" load_steps=2 format=3]

[ext_resource type="Script" path="res://Core/AI/Skill.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"bk_atk_heavy"
state_name = &"generic_attack"
cooldown = 1.5
weight = 6
min_phase = 2
max_phase = -1
min_range = 0.0
max_range = 200.0
tags = [&"offensive", &"melee"]
precondition_method = &""
interruptible = true
params = {
    &"animation": &"attack_2",
    &"speed": 80.0,
    &"direction": &"toward_target"
}
```

- [ ] **Step 4: Verify resources load**

Run Godot editor (`mcp__godot__launch_editor`), open both .tres files, confirm Inspector shows correct fields with no parse errors.

- [ ] **Step 5: Commit**

```bash
git add Scenes/Characters/Bosses/BladeKeeper/skills/bk_atk_basic.tres Scenes/Characters/Bosses/BladeKeeper/skills/bk_atk_heavy.tres
git commit -m "feat: add BK basic + heavy attack skill resources"
```

---

## Task 4: Create BK ranged + trap + dash skill resources

**Files:**
- Create: `skills/bk_dash_approach.tres`
- Create: `skills/bk_throw_sword.tres`
- Create: `skills/bk_place_trap.tres`

- [ ] **Step 1: Verify required animation names exist** (`dash`, `throw_sword`, `place_trap`)

Open BK AnimationPlayer in editor; if any names differ, record mapping.

- [ ] **Step 2: Create `bk_dash_approach.tres`**

```
[gd_resource type="Resource" script_class="Skill" load_steps=2 format=3]

[ext_resource type="Script" path="res://Core/AI/Skill.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"bk_dash_approach"
state_name = &"approach"
cooldown = 5.0
weight = 4
min_phase = 1
max_phase = -1
min_range = 200.0
max_range = 600.0
tags = [&"offensive", &"gap_close"]
precondition_method = &""
interruptible = true
params = {
    &"animation": &"dash",
    &"speed": 350.0,
    &"direction": &"toward_target",
    &"stop_distance": 180.0
}
```

- [ ] **Step 3: Create `bk_throw_sword.tres`**

```
[gd_resource type="Resource" script_class="Skill" load_steps=3 format=3]

[ext_resource type="Script" path="res://Core/AI/Skill.gd" id="1"]
[ext_resource type="PackedScene" path="res://Scenes/Characters/Bosses/BladeKeeper/Attacks/BKSwordProjectile.tscn" id="2"]

[resource]
script = ExtResource("1")
id = &"bk_throw_sword"
state_name = &"generic_attack"
cooldown = 4.0
weight = 3
min_phase = 1
max_phase = -1
min_range = 200.0
max_range = 800.0
tags = [&"offensive", &"projectile"]
precondition_method = &""
interruptible = true
params = {
    &"animation": &"throw_sword",
    &"projectile_scene": ExtResource("2"),
    &"spawn_offset": Vector2(40, -20)
}
```

- [ ] **Step 4: Create `bk_place_trap.tres`**

```
[gd_resource type="Resource" script_class="Skill" load_steps=3 format=3]

[ext_resource type="Script" path="res://Core/AI/Skill.gd" id="1"]
[ext_resource type="PackedScene" path="res://Scenes/Characters/Bosses/BladeKeeper/Attacks/BKTrapEntity.tscn" id="2"]

[resource]
script = ExtResource("1")
id = &"bk_place_trap"
state_name = &"generic_attack"
cooldown = 6.0
weight = 2
min_phase = 2
max_phase = -1
min_range = 0.0
max_range = 300.0
tags = [&"offensive", &"trap"]
precondition_method = &""
interruptible = true
params = {
    &"animation": &"place_trap",
    &"spawn_scene": ExtResource("2"),
    &"spawn_offset": Vector2(0, 0)
}
```

- [ ] **Step 5: Verify resources load (Godot editor) and commit**

```bash
git add Scenes/Characters/Bosses/BladeKeeper/skills/bk_dash_approach.tres Scenes/Characters/Bosses/BladeKeeper/skills/bk_throw_sword.tres Scenes/Characters/Bosses/BladeKeeper/skills/bk_place_trap.tres
git commit -m "feat: add BK dash, projectile, and trap skill resources"
```

---

## Task 5: Create BK reactive (defend/dodge/heal) skill resources

**Files:**
- Create: `skills/bk_dodge_back.tres`
- Create: `skills/bk_defend_buff.tres`
- Create: `skills/bk_heal_self.tres`

These three share `precondition_method = &"_precond_under_pressure"` and `tags` include `&"reactive"`.

- [ ] **Step 1: Verify animation names** (`dodge_back`, `buff_cast`)

- [ ] **Step 2: Create `bk_dodge_back.tres`**

```
[gd_resource type="Resource" script_class="Skill" load_steps=2 format=3]

[ext_resource type="Script" path="res://Core/AI/Skill.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"bk_dodge_back"
state_name = &"generic_attack"
cooldown = 3.0
weight = 0
min_phase = 1
max_phase = -1
min_range = 0.0
max_range = 200.0
tags = [&"reactive", &"evasive"]
precondition_method = &"_precond_under_pressure"
interruptible = true
params = {
    &"animation": &"dodge_back",
    &"speed": 300.0,
    &"direction": &"away_from_target"
}
```

- [ ] **Step 3: Create `bk_defend_buff.tres`**

```
[gd_resource type="Resource" script_class="Skill" load_steps=2 format=3]

[ext_resource type="Script" path="res://Core/AI/Skill.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"bk_defend_buff"
state_name = &"generic_attack"
cooldown = 8.0
weight = 0
min_phase = 1
max_phase = -1
min_range = 0.0
max_range = 1.0e10
tags = [&"reactive", &"defensive", &"buff"]
precondition_method = &"_precond_under_pressure"
interruptible = true
params = {
    &"animation": &"buff_cast",
    &"method": &"apply_defense_buff",
    &"method_arg": 3.0
}
```

- [ ] **Step 4: Create `bk_heal_self.tres`**

```
[gd_resource type="Resource" script_class="Skill" load_steps=2 format=3]

[ext_resource type="Script" path="res://Core/AI/Skill.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"bk_heal_self"
state_name = &"generic_attack"
cooldown = 12.0
weight = 0
min_phase = 2
max_phase = -1
min_range = 0.0
max_range = 1.0e10
tags = [&"reactive", &"defensive", &"buff"]
precondition_method = &"_precond_under_pressure"
interruptible = true
params = {
    &"animation": &"buff_cast",
    &"method": &"heal_self",
    &"method_arg": 20.0
}
```

- [ ] **Step 5: Commit**

```bash
git add Scenes/Characters/Bosses/BladeKeeper/skills/bk_dodge_back.tres Scenes/Characters/Bosses/BladeKeeper/skills/bk_defend_buff.tres Scenes/Characters/Bosses/BladeKeeper/skills/bk_heal_self.tres
git commit -m "feat: add BK reactive (dodge, defend buff, heal) skill resources"
```

---

## Task 6: Create BK ComboSkill resources (basic + per-phase finishers)

**Files:**
- Create: `skills/bk_combo_basic.tres`
- Create: `skills/bk_combo_finisher_p2.tres`
- Create: `skills/bk_combo_finisher_p3.tres`

ComboSkill stores its `sequence: Array[Skill]` as **embedded sub-resources** (not external .tres references — sub-skills here have no independent identity beyond the combo).

- [ ] **Step 1: Verify required animation names** (`attack_1`, `attack_2`, `attack_3`, `sp_atk`)

- [ ] **Step 2: Create `bk_combo_basic.tres` (3-step combo, all phases)**

```
[gd_resource type="Resource" script_class="ComboSkill" load_steps=5 format=3]

[ext_resource type="Script" path="res://Core/AI/ComboSkill.gd" id="1"]
[ext_resource type="Script" path="res://Core/AI/Skill.gd" id="2"]

[sub_resource type="Resource" id="sub1"]
script = ExtResource("2")
id = &"bk_combo_basic_step1"
params = { &"animation": &"attack_1" }

[sub_resource type="Resource" id="sub2"]
script = ExtResource("2")
id = &"bk_combo_basic_step2"
params = { &"animation": &"attack_2" }

[sub_resource type="Resource" id="sub3"]
script = ExtResource("2")
id = &"bk_combo_basic_step3"
params = { &"animation": &"attack_3" }

[resource]
script = ExtResource("1")
id = &"bk_combo_basic"
state_name = &"combo"
cooldown = 2.0
weight = 5
min_phase = 1
max_phase = -1
min_range = 0.0
max_range = 200.0
tags = [&"offensive", &"melee", &"combo"]
precondition_method = &""
interruptible = false
sequence = [SubResource("sub1"), SubResource("sub2"), SubResource("sub3")]
gap = 0.1
```

- [ ] **Step 3: Create `bk_combo_finisher_p2.tres` (P2 only, 4-step with sp_atk)**

Same structure as `bk_combo_basic.tres` but adds a 4th sub-resource with `animation = &"sp_atk"`, and resource fields:

```
id = &"bk_combo_finisher_p2"
weight = 3
min_phase = 2
max_phase = 2
cooldown = 4.0
```

Full 4-step sequence: attack_1 → attack_2 → attack_3 → sp_atk.

- [ ] **Step 4: Create `bk_combo_finisher_p3.tres` (P3+, weight 6)**

Same as `bk_combo_finisher_p2.tres` but:

```
id = &"bk_combo_finisher_p3"
weight = 6
min_phase = 3
max_phase = -1
cooldown = 3.5
```

- [ ] **Step 5: Verify all 3 .tres load in Godot editor + commit**

```bash
git add Scenes/Characters/Bosses/BladeKeeper/skills/bk_combo_basic.tres Scenes/Characters/Bosses/BladeKeeper/skills/bk_combo_finisher_p2.tres Scenes/Characters/Bosses/BladeKeeper/skills/bk_combo_finisher_p3.tres
git commit -m "feat: add BK basic + per-phase finisher combo resources"
```

---

## Task 7: Rewrite `BladeKeeper.gd` to extend AgentAIBase

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd`

This task replaces the entire file. The legacy script extended BossBase; the new script extends AgentAIBase, sets up SkillSet, registers transitions, and implements guards/preconditions/method-call placeholders.

- [ ] **Step 1: Replace `BladeKeeper.gd` content**

```gdscript
class_name BladeKeeper extends AgentAIBase

## BladeKeeper Boss — 快速技巧型剑士（迁移到 AgentAIBase + SkillSet 架构）

# ---- Phase 系统（迁移期临时定义；后续 BuffEntity 引入时统一）----
enum Phase { PHASE_1 = 1, PHASE_2 = 2, PHASE_3 = 3 }
const PHASE_HP_THRESHOLD := { Phase.PHASE_2: 0.66, Phase.PHASE_3: 0.33 }
const PHASE_SPEED := {
    Phase.PHASE_1: 1.0,
    Phase.PHASE_2: 1.3,
    Phase.PHASE_3: 1.5,
}

@export var base_move_speed := 180.0
@export var pressure_threshold: float = 35.0

# 技能资源（在 Inspector 中拖拽 .tres 配置）
@export var skill_resources: Array[Skill] = []

var current_phase: int = Phase.PHASE_1
var _defense_multiplier: float = 1.0

var move_speed: float:
    get: return base_move_speed * PHASE_SPEED.get(current_phase, 1.0)

# ---- AgentAIBase 钩子 ----
func _setup_skill_set() -> void:
    skill_set = SkillSet.new()
    skill_set.setup(skill_resources)

func _setup_blackboard() -> void:
    super._setup_blackboard()
    ai.blackboard.set_var(&"current_phase", current_phase)

func _setup_transitions() -> void:
    var idle = ai.get_state(&"idle")
    var chase = ai.get_state(&"chase")
    var dispatcher = ai.get_state(&"dispatcher")
    var dead = ai.get_state(&"dead")

    # 全局：死亡（最高优先级）
    if dead:
        ai.add_transition(ai.ANYSTATE, dead, AIEvents.EV_DIED, Callable(), 100)
    # Idle → Chase（有目标且活着）
    if idle and chase:
        ai.add_transition(idle, chase, &"", _guard_target_alive, 10)
    # Chase → Dispatcher（进入攻击范围 + 有可用技能）
    if chase and dispatcher:
        ai.add_transition(chase, dispatcher, &"", _guard_can_attack, 20)
    # 攻击结束 → Chase（重新评估）
    if chase:
        ai.add_transition(ai.ANYSTATE, chase, AIEvents.EV_ATTACK_FINISHED, Callable(), 5)
    # 受压条件：Chase 中可被打断进入 Dispatcher（释放 reactive 技能）
    if chase and dispatcher:
        ai.add_transition(chase, dispatcher, &"", _guard_under_pressure, 30)

# ---- Guard 方法 ----
func _guard_target_alive() -> bool:
    return ai.blackboard.get_var(&"target_alive", false)

func _guard_can_attack() -> bool:
    if not ai.blackboard.get_var(&"target_alive", false):
        return false
    var skill: Skill = skill_set.pick(self, ai.blackboard)
    if skill == null:
        return false
    ai.blackboard.set_var(&"pending_skill", skill)
    return true

func _guard_under_pressure() -> bool:
    if ai.blackboard.get_var(&"damage_recent", 0.0) <= pressure_threshold:
        return false
    var skill: Skill = skill_set.pick_tagged(&"reactive", self, ai.blackboard)
    if skill == null:
        return false
    ai.blackboard.set_var(&"pending_skill", skill)
    return true

# ---- Skill precondition ----
func _precond_under_pressure() -> bool:
    return ai.blackboard.get_var(&"damage_recent", 0.0) > pressure_threshold

# ---- Method-call 占位（BuffEntity 框架到位前的过渡方案）----
## 注意：_defense_multiplier 仅记录状态。实际减伤需在 take_damage 路径上拦截 ——
## 当前 HealthComponent.take_damage 在 hurtbox 调用时已经应用了伤害，所以单纯
## 在 _on_agent_damaged 里改 damage.amount 已无效。落地方案二选一：
##   (1) 在 BK 上加 HurtBoxComponent 拦截器，take_damage 前乘以 _defense_multiplier；
##   (2) 暂不实现实际减伤，等 BuffEntity 框架到位时统一接 stat_modifiers。
## 本次迁移选 (2)：apply_defense_buff 只记录状态 + 等待 BuffEntity，不破坏现有伤害管线。
func apply_defense_buff(duration: float) -> void:
    _defense_multiplier = 0.5
    var t := get_tree().create_timer(duration)
    t.timeout.connect(func(): _defense_multiplier = 1.0)

func heal_self(amount: float) -> void:
    if health_comp:
        health_comp.heal(amount)

# ---- Phase 推进（依据 HP 比例）----
func _on_agent_damaged(damage: Damage, attacker_pos: Vector2) -> void:
    super._on_agent_damaged(damage, attacker_pos)
    _check_phase_advance()

func _check_phase_advance() -> void:
    if not health_comp:
        return
    var ratio: float = float(health_comp.health) / float(health_comp.max_health)
    var new_phase: int = current_phase
    if current_phase < Phase.PHASE_3 and ratio <= PHASE_HP_THRESHOLD[Phase.PHASE_3]:
        new_phase = Phase.PHASE_3
    elif current_phase < Phase.PHASE_2 and ratio <= PHASE_HP_THRESHOLD[Phase.PHASE_2]:
        new_phase = Phase.PHASE_2
    if new_phase != current_phase:
        current_phase = new_phase
        ai.blackboard.set_var(&"current_phase", current_phase)
        ai.dispatch(AIEvents.EV_PHASE_CHANGED)
```

- [ ] **Step 2: Verify file parses**

Open Godot editor, open `BladeKeeper.gd`. Expected: no parse errors. (`health_comp.heal(amount: float)` is confirmed to exist at `Core/Components/HealthComponent.gd:100`.)

- [ ] **Step 3: Commit**

```bash
git add Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd
git commit -m "feat: rewrite BladeKeeper.gd to extend AgentAIBase with SkillSet"
```

---

## Task 8: Re-template `BladeKeeper.tscn` from `BossBase.tscn` → `AgentAIBase.tscn`

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn`

**Context.** The current scene inherits from `BossBase.tscn` (legacy step-machine). It has a `BossAttackManager` child plus a `StateMachine` (using custom `BKStateMachine.gd`) with 9 BK-specific state children (BKChase, BKAttack, BKDefend, BKRoll, BKProjectile, BKTrap, plus shared Idle/Hit/Counter). Root inspector also sets BossBase-only fields (`attack_range`, `is_melee`, `evasion_enabled`, `poise_enabled`, `max_health`, `health`) that don't exist on `AgentAIBase.gd`.

**Goal.** Re-base BK on `AgentAIBase.tscn` (which already provides Sprite2D + AnimationPlayer + CollisionShape2D + HurtBox/HitBox + HealthComponent + HealthBar + DamageNumbersAnchor + FloorCast L/R + WallCast L/R + AIController + StateMachine + Idle/Chase/Hit/Death/Dispatcher/GenericAttack/Combo). Reference migration: `Scenes/Characters/Bosses/DemonSlime2/DemonSlime2.tscn`.

**Constraints established by user:** "BladeKeeper 现在是使用 skill system，不用兼容存量。都是用新架构" — no backwards compat, full clean slate. Drop BossAttackManager, BKStateMachine, all BK-specific state scripts, all BossBase-only inspector overrides. Keep only the asset blocks (textures, SpriteFrames, AnimationLibrary, AnimationTree).

**Reference patterns from DS2.tscn migration:**
- Add `AnimatedSprite2D` as a NEW child node (Godot inherited scenes can't change inherited Sprite2D's *type*, so we add a sibling). `AgentAIBase._auto_find_sprite()` searches AnimatedSprite2D first → picks up the new node.
- Override inherited AnimationPlayer's `libraries/` to point at BK's AnimationLibrary sub-resource.
- Add new state children under `AIController/StateMachine` using:
  `[node name="Approach" type="Node" parent="AIController/StateMachine" parent_id_path=PackedInt32Array(193203180) ...]`
  (the magic number `193203180` is AgentAIBase's StateMachine `unique_id`).

**Animation method tracks needed (using current BK animation names — verified via existing AnimationLibrary):**
- `projectile_cast` → at sword-release frame, call `spawn_projectile()` on `AIController/StateMachine/GenericAttack`.
- `trap_cast` → at drop frame, call `spawn_entity()` on `AIController/StateMachine/GenericAttack`.
- `defend` → at apply frame, call `call_skill_method()` on `AIController/StateMachine/GenericAttack`.

The corresponding skill .tres files reference these animation names (`bk_throw_sword.tres` → `projectile_cast`, `bk_place_trap.tres` → `trap_cast`, `bk_defend_buff.tres` & `bk_heal_self.tres` → `defend`).

---

- [ ] **Step 1: Read current BK.tscn and inventory the asset blocks**

Read `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn`. Identify line ranges for:
- Texture ext_resources (preserve all)
- SpriteFrames sub-resource (preserve)
- AnimationLibrary sub-resource (preserve — and **inspect for animation names**)
- AnimationNodeBlendTree / AnimationNode* sub-resources (preserve — for AnimationTree)
- RectangleShape2D / CollisionShape sub-resources (note positions/sizes, will be re-applied as overrides)

Confirm via grep that animation names `projectile_cast`, `trap_cast`, `defend`, `roll`, `atk_1..atk_4`, `sp_atk`, `idle`, `walk`, `death` exist in the AnimationLibrary. If any are missing, surface immediately — fixing them is in scope but the implementer must report so the controller can decide whether to map to existing names or add empty placeholder animations.

- [ ] **Step 2: Build the new ext_resource block**

Replace the entire `[gd_scene ...]` + ext_resources header. Keep:
- All Texture2D ext_resources (untouched)
- BKSwordProjectile.tscn (keep, will be referenced by skill .tres at runtime — no longer wired into scene)
- BKTrapEntity.tscn (same)
- BladeKeeper.gd script ext_resource

Drop these ext_resources entirely:
- `BossBase.tscn` (replaced by AgentAIBase.tscn)
- `BKAttackManager.gd`
- `BKStateMachine.gd`
- `IdleState.gd` (the CommonStates one — provided by template)
- `HitState.gd` (CommonStates — provided by template)
- `BKChase.gd`, `BKAttack.gd`, `BKDefend.gd`, `BKRoll.gd`, `BKProjectile.gd`, `BKTrap.gd`
- `BossCounterState.gd`

Add this new ext_resource:
- `[ext_resource type="PackedScene" uid="uid://rllitgnkf211" path="res://Scenes/Characters/Templates/AgentAIBase.tscn" id="1_base"]`
- `[ext_resource type="Script" path="res://Core/AI/Stock/ApproachState.gd" id="N_approach"]` (use the next free id; ApproachState UID can be looked up from `Core/AI/Stock/ApproachState.gd.uid`)

For `skill_resources` Inspector array: the .tres files do NOT need ext_resource entries unless we write the array statically into the scene. **We will write them statically** (more deterministic than relying on Inspector drag). Add ext_resource entries for all 11 BK skill .tres files. Look up each UID from the corresponding `.tres` file's `uid="uid://..."` header (e.g. `bk_atk_basic.tres` → `uid://srwwv9ytwx7e6`).

- [ ] **Step 3: Replace the root node block**

Replace the existing `[node name="BladeKeeper" instance=ExtResource("1_base")]` block with:

```
[node name="BladeKeeper" instance=ExtResource("1_base")]
collision_mask = 129
script = ExtResource("2_bk")
base_move_speed = 180.0
pressure_threshold = 35.0
skill_resources = Array[Skill]([
    ExtResource("<bk_atk_basic_id>"),
    ExtResource("<bk_atk_heavy_id>"),
    ExtResource("<bk_dash_approach_id>"),
    ExtResource("<bk_throw_sword_id>"),
    ExtResource("<bk_place_trap_id>"),
    ExtResource("<bk_dodge_back_id>"),
    ExtResource("<bk_defend_buff_id>"),
    ExtResource("<bk_heal_self_id>"),
    ExtResource("<bk_combo_basic_id>"),
    ExtResource("<bk_combo_finisher_p2_id>"),
    ExtResource("<bk_combo_finisher_p3_id>"),
])
```

Removed properties (do NOT include): `attack_range`, `is_melee`, `has_gravity`, `evasion_enabled`, `poise_enabled`, `max_health`, `health`. Health max is now configured on the inherited `HealthComponent` child (see Step 6).

- [ ] **Step 4: Add AnimatedSprite2D as a new child (DS2 pattern)**

```
[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="." index="0"]
position = Vector2(0, -42)
sprite_frames = SubResource("SpriteFrames_nw0us")
animation = &"idle"
```

The inherited `Sprite2D` from the template stays in place but is unused — `_auto_find_sprite()` checks AnimatedSprite2D first.

- [ ] **Step 5: Override inherited AnimationPlayer + add AnimationTree**

```
[node name="AnimationPlayer" parent="." index="3"]
libraries/ = SubResource("AnimationLibrary_52y2t")
autoplay = &"walk"

[node name="AnimationTree" type="AnimationTree" parent="." index="4"]
tree_root = SubResource("AnimationNodeBlendTree_root")
parameters/locomotion/blend_position = Vector2(-0.039641917, 0.13506496)
```

(Indexes here are illustrative. Actual indexes depend on how Godot orders the inherited node tree after AnimatedSprite2D is inserted. The implementer should preserve relative ordering and let Godot re-index on first save.)

- [ ] **Step 6: Override inherited collision + box positions for BK's body size**

```
[node name="CollisionShape2D" parent="."]
position = Vector2(0, -1)
shape = SubResource("RectangleShape2D_bk_collision")

[node name="CollisionShape2D" parent="HurtBoxComponent"]
position = Vector2(0, -1)

[node name="CollisionShape2D" parent="HitBoxComponent"]
shape = SubResource("RectangleShape2D_4qryw")
disabled = true

[node name="HealthComponent" parent="."]
max_health = 100000.0
health = 100000.0

[node name="HealthBar" parent="."]
value = 0.3
```

Reuse the existing sub-resource shapes (`RectangleShape2D_bk_collision`, `RectangleShape2D_4qryw`, etc.) from the preserved sub-resource block.

- [ ] **Step 7: Add `Approach` state to inherited StateMachine**

```
[node name="Approach" type="Node" parent="AIController/StateMachine" parent_id_path=PackedInt32Array(193203180)]
script = ExtResource("N_approach")
```

(`193203180` is AgentAIBase's StateMachine `unique_id` — copy from AgentAIBase.tscn line 173.)

- [ ] **Step 8: Verify NO legacy nodes remain**

Confirm the file does NOT contain:
- `BossAttackManager` node
- `StateMachine` node (the standalone one — the new template's StateMachine lives under AIController)
- Any node with script pointing at `BKAttack.gd` / `BKChase.gd` / `BKDefend.gd` / `BKRoll.gd` / `BKProjectile.gd` / `BKTrap.gd` / `BKStateMachine.gd` / `BossCounterState.gd` / CommonStates `IdleState.gd` / CommonStates `HitState.gd`

- [ ] **Step 9: Wire animation Call Method Tracks**

Open the AnimationLibrary sub-resource. For each of these animations, add a CallMethodTrack on path `AIController/StateMachine/GenericAttack`:
- Animation `projectile_cast`: insert key at sword-release frame (≈40% into anim) calling `spawn_projectile`.
- Animation `trap_cast`: insert key at drop frame (≈50% into anim) calling `spawn_entity`.
- Animation `defend`: insert key at apply frame (≈30% into anim) calling `call_skill_method`.

Editing animation tracks via direct `.tscn` text edit is risky; preferred approach: use Godot editor (open scene, edit tracks, save). If editor route is taken, document the precise key time and method per anim in the commit message.

If any of these animations don't already have these method-call tracks AND the editor isn't available, leave a TODO comment in the scene file pointing to this step and surface to controller — do NOT fabricate sub-resource Animation track JSON by hand.

- [ ] **Step 10: Save + verify scene loads**

Save the scene. Then run:
```bash
godot --headless --quit --check-only --path . res://Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn
```
Or, if that flag isn't supported, launch the editor (`mcp__godot__launch_editor`) and confirm BK opens with no errors in the Output panel.

- [ ] **Step 11: Commit**

```bash
git add Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn
git commit -m "feat(bk): re-template BladeKeeper.tscn from BossBase to AgentAIBase + skill resources"
```

---

## Task 9: Delete legacy BK files

**Files:** delete all listed below.

- [ ] **Step 1: Delete legacy gd + uid files**

```bash
cd e:/workspace/4.godot/combo_demon
rm Scenes/Characters/Bosses/BladeKeeper/BKAttackManager.gd
rm Scenes/Characters/Bosses/BladeKeeper/BKAttackManager.gd.uid
rm Scenes/Characters/Bosses/BladeKeeper/BKStateMachine.gd
rm Scenes/Characters/Bosses/BladeKeeper/BKStateMachine.gd.uid
rm Scenes/Characters/Bosses/BladeKeeper/States/BKAttack.gd
rm Scenes/Characters/Bosses/BladeKeeper/States/BKAttack.gd.uid
rm Scenes/Characters/Bosses/BladeKeeper/States/BKChase.gd
rm Scenes/Characters/Bosses/BladeKeeper/States/BKChase.gd.uid
rm Scenes/Characters/Bosses/BladeKeeper/States/BKDefend.gd
rm Scenes/Characters/Bosses/BladeKeeper/States/BKDefend.gd.uid
rm Scenes/Characters/Bosses/BladeKeeper/States/BKRoll.gd
rm Scenes/Characters/Bosses/BladeKeeper/States/BKRoll.gd.uid
rm Scenes/Characters/Bosses/BladeKeeper/States/BKProjectile.gd
rm Scenes/Characters/Bosses/BladeKeeper/States/BKProjectile.gd.uid
rm Scenes/Characters/Bosses/BladeKeeper/States/BKTrap.gd
rm Scenes/Characters/Bosses/BladeKeeper/States/BKTrap.gd.uid
rm Scenes/Characters/Bosses/BladeKeeper/States/BKIdle.gd
rm Scenes/Characters/Bosses/BladeKeeper/States/BKIdle.gd.uid
rm Scenes/Characters/Bosses/BladeKeeper/States/BKStun.gd.uid
rm test/unit/test_bk_attack.gd
rm test/unit/test_bk_attack.gd.uid
```

- [ ] **Step 2: Verify no remaining references**

Run grep to ensure no other code references deleted classes:

```bash
grep -rn "BKAttackManager\|BKAttack\b\|BKChase\|BKDefend\|BKRoll\|BKProjectile\|BKTrap\|BKStateMachine\|BKIdle" \
  --include="*.gd" --include="*.tscn" .
```

Expected: zero matches. If any matches show up (e.g., other scenes or scripts referencing these), investigate and either remove the reference or stop and ask.

- [ ] **Step 3: Commit**

```bash
git add -A Scenes/Characters/Bosses/BladeKeeper/ test/unit/
git commit -m "chore: remove legacy BK step-machine + manager files"
```

---

## Task 10: Run full unit test suite

Validate that no existing test broke from the GenericAttackState modification or BK file removal.

- [ ] **Step 1: Run all unit tests**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit
```

Expected: all tests pass except `test_bk_attack.gd` which is now deleted.

- [ ] **Step 2: If any test fails**

- If failure is in `test_skill_set.gd` / `test_skill_resource.gd` / `test_attack_effects.gd`: investigate — likely unintended side effect from GenericAttackState change.
- If failure is in `test_ai_controller.gd`: check whether ai_diag log changes affected expected output.
- Fix the failing test or the production code, then re-run.

- [ ] **Step 3: Commit any fixes (if needed)**

```bash
git add <files>
git commit -m "fix: <description of fix>"
```

If no fixes needed, skip the commit.

---

## Task 11: Manual scene validation

Run the BK boss fight scene and verify each behavior path. This is **not automated** — it requires human observation of the running game.

- [ ] **Step 1: Launch BK scene**

Run via `mcp__godot__run_project` (the project's main scene must include BK, or open BK test scene if separate).

- [ ] **Step 2: Validate Idle → Chase transition**

Stand still as player. BK should detect (within 800px) and transition to Chase.
Check logs (`ai_diag` channel) for: `[AI] → chase`.

- [ ] **Step 3: Validate Chase → Dispatcher → GenericAttack loop (P1)**

Approach BK to within 200px. BK should:
- pick a skill (likely `bk_atk_basic` or `bk_combo_basic`)
- transition to dispatcher → generic_attack or combo
- play attack animation
- return to chase after EV_ATTACK_FINISHED

Logs should show: `[AI] cond chase → dispatcher (dist=...) skill_id=bk_atk_basic` (or similar).

- [ ] **Step 4: Validate dash approach skill**

Move player to 400-600px from BK. BK should periodically use `bk_dash_approach` to close the gap, terminating at ~180px (stop_distance).

- [ ] **Step 5: Validate phase transition (P1 → P2)**

Damage BK to ≤66% HP. Check logs for `EV_PHASE_CHANGED` dispatch and `current_phase = 2` blackboard update. Subsequent combo picks should occasionally include `bk_combo_finisher_p2` (4-step with sp_atk).

- [ ] **Step 6: Validate phase transition (P2 → P3)**

Damage BK to ≤33% HP. `current_phase = 3`. `bk_combo_finisher_p3` becomes most likely combo.

- [ ] **Step 7: Validate reactive trigger (under_pressure)**

Hit BK 3+ times rapidly so `damage_recent > 35`. BK should switch from offensive pattern to a `reactive` skill (`bk_dodge_back` / `bk_defend_buff` / `bk_heal_self` if P2+).
Verify `_defense_multiplier` halves incoming damage during defense window.

- [ ] **Step 8: Validate Cyclops still works**

Run Cyclops boss scene independently. Confirm no regression — Cyclops still uses BossBase and should be unaffected.

- [ ] **Step 9: Document issues**

If any step fails, capture log output + reproduction steps. Fix root cause, re-run failed steps, then proceed.

---

## Task 12: Final commit + summary

- [ ] **Step 1: Verify clean git state**

```bash
git status
```

Expected: working tree clean. If any stray files remain, investigate.

- [ ] **Step 2: Tag the migration milestone (optional)**

If user requests, tag the migration commit:
```bash
git tag -a bk-migration-complete -m "BladeKeeper migrated to AgentAIBase + SkillSet"
```

- [ ] **Step 3: Update CLAUDE.md or memory if any architecture facts changed**

Per user feedback memory: doc updates only after dev + test + CR all pass. Do **not** update docs at this step unless explicitly asked.

---

## Out of scope (deferred to future plans)

These items appear in the spec but are intentionally deferred:

1. **`bk_combo_dodge_seq` ComboSkill** — back-jump + trap + air projectile + land. Requires animation method tracks on combo sub-steps; defer until basic migration is validated. (Spec §4.2, §8 risk row.)
2. **BuffEntity framework** — `Core/Buffs/BuffEntity.gd` + `Core/Buffs/BuffComponent.gd`. Replaces method-call placeholders. Separate spec/plan. (Spec §6 Phase 2.)
3. **Migration of method-call buff skills to BuffEntity spawn_scene** — once BuffEntity exists, change `bk_defend_buff.tres` and `bk_heal_self.tres` to use `spawn_scene` instead of `method` params. (Spec §6 Phase 3.)
4. **BossBase removal** — delete BossBase / BossPhaseConfig / per-phase evasion legacy code. Blocked on Cyclops migration. Separate plan.
