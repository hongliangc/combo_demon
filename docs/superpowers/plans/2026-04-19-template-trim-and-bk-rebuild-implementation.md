# Template Trim + BladeKeeper Rebuild — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trim `AgentAIBase.tscn` to a pure structural skeleton (Sub-project A), then rebuild `BladeKeeper.tscn` from that trimmed template, deleting all legacy step-machine state scripts (Sub-project B).

**Architecture:** Two sequenced sub-projects, each one commit. Sub-project A removes content leakage (Sprite2D placeholder, default shapes, RESET tracks referencing concrete child nodes) from the template. Sub-project B rewrites BK as a clean inheritance instance and deletes 9 legacy `.gd` files. The new BK uses stock states (`Idle/Chase/Hit/Death/Dispatcher/GenericAttack/Combo/Approach`) plus 11 Skill `.tres` resources; BossAttackManager and the custom step-state scripts go away.

**Tech Stack:** Godot 4.4.1, GDScript, GUT 9.6.0 testing, Godot MCP tools (`mcp__godot__launch_editor`, `mcp__godot__get_debug_output`, `mcp__godot__save_scene`).

**Branch:** `feat/bk-migration` (already checked out; tasks 1–7 from the prior plan are committed there).

**Source spec:** `docs/superpowers/specs/2026-04-19-template-trim-and-bk-rebuild-design.md`

---

## Sub-project A: Trim `AgentAIBase.tscn`

### Task A1: Delete `Sprite2D` node, RESET tracks referencing it, and default-shape SubResources

**Files:**
- Modify: `Scenes/Characters/Templates/AgentAIBase.tscn`

**Context:** The template is 194 lines. Current ranges to edit:
- Lines 16–53: `[sub_resource type="Animation" id="Animation_RESET"]` — tracks 0/1/2 reference `NodePath("Sprite2D:modulate")` / `Sprite2D:position` / `Sprite2D:rotation`. Tracks 3 (`HealthBar:modulate`) and 4 (`HurtBoxComponent/CollisionShape2D:disabled`) are skeleton-level — keep them.
- Lines 84–92: `RectangleShape2D_body` (size 81×80), `RectangleShape2D_hurt` (80×78), `RectangleShape2D_hit` (79×78). All three are content-level defaults — delete.
- Line 114: `[node name="Sprite2D" type="Sprite2D" parent="." unique_id=364152549]` — delete.
- Lines 119–120: `[node name="CollisionShape2D" ...] shape = SubResource("RectangleShape2D_body")` — keep node, remove `shape =` line.
- Lines 127–128: `[node name="CollisionShape2D" parent="HurtBoxComponent" ...] shape = SubResource("RectangleShape2D_hurt")` — keep node, remove `shape =` line.
- Lines 135–136: `[node name="CollisionShape2D" parent="HitBoxComponent" ...] shape = SubResource("RectangleShape2D_hit")` — keep node, remove `shape =` line.

- [ ] **Step 1: Read the current template to confirm exact line content**

Read `Scenes/Characters/Templates/AgentAIBase.tscn`. Verify the ranges above match (Godot may have re-numbered after a save).

- [ ] **Step 2: Delete the three `RectangleShape2D` SubResources**

Edit `Scenes/Characters/Templates/AgentAIBase.tscn`. Delete the block:

```
[sub_resource type="RectangleShape2D" id="RectangleShape2D_body"]
size = Vector2(81, 80)

[sub_resource type="RectangleShape2D" id="RectangleShape2D_hurt"]
size = Vector2(80, 78)

[sub_resource type="RectangleShape2D" id="RectangleShape2D_hit"]
size = Vector2(79, 78)

```

- [ ] **Step 3: Delete the `Sprite2D` node**

Delete the line:

```
[node name="Sprite2D" type="Sprite2D" parent="." unique_id=364152549]
```

(Plus the blank line after it, if any.)

- [ ] **Step 4: Remove `shape = SubResource(...)` assignments from the three CollisionShape2D nodes**

For each of these three nodes — root `CollisionShape2D`, `HurtBoxComponent/CollisionShape2D`, `HitBoxComponent/CollisionShape2D` — delete the `shape = SubResource("...")` line directly underneath the node header. The node header itself stays.

After this edit, the three node blocks read:

```
[node name="CollisionShape2D" type="CollisionShape2D" parent="." unique_id=884594291]

[node name="CollisionShape2D" type="CollisionShape2D" parent="HurtBoxComponent" unique_id=975434091]

[node name="CollisionShape2D" type="CollisionShape2D" parent="HitBoxComponent" unique_id=1873200456]
```

- [ ] **Step 5: Delete RESET animation tracks 0, 1, 2 (Sprite2D references)**

In the `[sub_resource type="Animation" id="Animation_RESET"]` block, delete:

```
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("Sprite2D:modulate")
tracks/0/interp = 1
tracks/0/loop_wrap = true
tracks/0/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"update": 0,
"values": [Color(1, 1, 1, 1)]
}
tracks/1/type = "value"
tracks/1/imported = false
tracks/1/enabled = true
tracks/1/path = NodePath("Sprite2D:position")
tracks/1/interp = 1
tracks/1/loop_wrap = true
tracks/1/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"update": 0,
"values": [Vector2(0, 0)]
}
tracks/2/type = "value"
tracks/2/imported = false
tracks/2/enabled = true
tracks/2/path = NodePath("Sprite2D:rotation")
tracks/2/interp = 1
tracks/2/loop_wrap = true
tracks/2/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"update": 0,
"values": [0.0]
}
```

Then **renumber** the remaining tracks 3 → 0 and 4 → 1. After renumbering, the block contains only:

```
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("HealthBar:modulate")
tracks/0/interp = 1
tracks/0/loop_wrap = true
tracks/0/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"update": 0,
"values": [Color(1, 1, 1, 1)]
}
tracks/1/type = "value"
tracks/1/imported = false
tracks/1/enabled = true
tracks/1/path = NodePath("HurtBoxComponent/CollisionShape2D:disabled")
tracks/1/interp = 1
tracks/1/loop_wrap = true
tracks/1/keys = {
"times": PackedFloat32Array(0),
"transitions": PackedFloat32Array(1),
"update": 1,
"values": [false]
}
```

---

### Task A2: Validate template loads + DS2 still works

**Files:**
- Read-only: `Scenes/Characters/Templates/AgentAIBase.tscn`, `Scenes/Characters/Bosses/DemonSlime2/DemonSlime2.tscn`

- [ ] **Step 1: Open the template in Godot editor to confirm no parse errors**

Run `mcp__godot__launch_editor` (project path `e:/workspace/4.godot/combo_demon`).

Then open `Scenes/Characters/Templates/AgentAIBase.tscn` via the editor (or directly load via `mcp__godot__get_debug_output`).

Expected: no error messages about missing SubResources, missing nodes, or invalid NodePaths in the Output panel.

- [ ] **Step 2: Open DS2 in the editor to confirm inheritance still works**

Open `Scenes/Characters/Bosses/DemonSlime2/DemonSlime2.tscn`. Read the editor output via `mcp__godot__get_debug_output`.

Expected: no errors. DS2 already adds `AnimatedSprite2D` as a sibling (line 447 of DS2.tscn) and overrides shapes (lines 454–472), so the trimmed template should leave DS2 functional.

If errors appear (e.g. `Failed to load NodePath: 'Sprite2D'`), report them and STOP — Sub-project A must not break DS2.

---

### Task A3: Run unit tests

**Files:**
- Read-only

- [ ] **Step 1: Run the full GUT test suite**

Run:
```bash
cd e:/workspace/4.godot/combo_demon && godot --headless -d -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit
```

Expected: all tests PASS. Specifically the `test_bk_skill_resources_load.gd` 11 tests must still pass (they don't depend on the template).

If `godot --headless` is not on PATH, ask the user for the correct invocation OR fall back to opening the editor and running GUT manually.

If tests fail, report which test, paste the failure output, and STOP.

---

### Task A4: Manual scene-play validation (DS2)

**Files:**
- Read-only (test fixture): `Scenes/Levels/Level_BladeKeeper/LevelBladeKeeper.tscn`, `Scenes/Levels/Level_BladeKeeper/EnemySpawn.gd`

- [ ] **Step 1: Edit `EnemySpawn.gd` to spawn DS2 by default for this validation**

Edit `Scenes/Levels/Level_BladeKeeper/EnemySpawn.gd`. Change line 11:

From:
```gdscript
@export_enum("BladeKeeper", "DemonSlime2") var boss_name: String = "DemonSlime2"
```

(It is likely already `"DemonSlime2"`. Verify.)

Also temporarily set line 15:
```gdscript
@export var use_game_manager: bool = false
```

(Forces the default `boss_name` path so the test doesn't depend on GameManager state.)

- [ ] **Step 2: Run the level**

Run `mcp__godot__run_project` with main scene `res://Scenes/Levels/Level_BladeKeeper/LevelBladeKeeper.tscn`.

- [ ] **Step 3: Capture debug output and confirm DS2 spawns + completes idle/chase/attack loop**

Run `mcp__godot__get_debug_output`. Expected: `bossSpawn: Spawned default character - DemonSlime2` line. No `ERROR` or `Failed to load` lines related to DS2 or AgentAIBase.

If DS2 fails to spawn, report and STOP.

- [ ] **Step 4: Stop the project**

Run `mcp__godot__stop_project`.

- [ ] **Step 5: Revert the temporary changes to `EnemySpawn.gd`**

Restore `boss_name` and `use_game_manager` to their original values from git:
```bash
git checkout -- Scenes/Levels/Level_BladeKeeper/EnemySpawn.gd
```

(Note: `EnemySpawn.gd` is currently untracked per git status. If `git checkout` fails because the file is untracked, manually revert the two lines edited in Step 1.)

---

### Task A5: Commit Sub-project A

**Files:**
- Modify: `Scenes/Characters/Templates/AgentAIBase.tscn`

- [ ] **Step 1: Stage and commit**

```bash
cd e:/workspace/4.godot/combo_demon
git add Scenes/Characters/Templates/AgentAIBase.tscn
git commit -m "refactor(template): trim AgentAIBase to pure skeleton

- remove placeholder Sprite2D node (instances add their own visual)
- remove RESET tracks referencing Sprite2D (instances define their own)
- remove default RectangleShape2D for body/hurt/hit (instances assign shapes)
- keep all component nodes + 7 stock states + AIController + StateMachine

Codified in .claude/skills/godot-coding-standards/SKILL.md (场景模板原则)."
```

- [ ] **Step 2: Verify clean working tree (except for known untracked files)**

```bash
git status
```

Expected: `AgentAIBase.tscn` no longer in modified list. `BladeKeeper.gd` may still appear modified (the `&"dead"` → `&"death"` hotfix in working tree — that's bundled into Sub-project B).

---

## Sub-project B: Rebuild `BladeKeeper.tscn`

### Task B1: Inventory current BK.tscn — identify resources to keep vs drop

**Files:**
- Read-only: `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn`

**Context:** Current BK.tscn is 1506 lines. It inherits BossBase.tscn and contains a mix of (a) sprite/animation assets we keep, (b) BK-specific shapes we keep, (c) AnimationTree blend-tree apparatus we drop, (d) legacy step-machine ext_resources we drop.

Verified resource locations from earlier exploration:

| Section | Lines | Action |
|---|---|---|
| `[gd_scene]` header | 1 | Replace |
| Texture2D ext_resources | scattered 3–145 | **Keep all** |
| Script ext_resources (BossBase, BK*, BossAttackManager, BKStateMachine, IdleState, HitState, BossCounterState) | scattered 3–145 | **Drop all** (replaced by AgentAIBase + new entries) |
| `BKSwordProjectile.tscn` ext_resource (id="14_projscene") | line 40 | **Keep** (referenced by skill .tres) |
| `BKTrapEntity.tscn` ext_resource (id="15_trapscene") | line 42 | **Keep** (referenced by skill .tres) |
| `SpriteFrames_nw0us` SubResource | 146–604 | **Keep** |
| `RectangleShape2D_bk_collision` SubResource | 605 (~3 lines) | **Keep** |
| `Animation_*` SubResources × 16 | 608–1256 | **Keep all** |
| `AnimationLibrary_52y2t` SubResource | 1257–1276 | **Keep** |
| `AnimationNodeBlend2`, `AnimationNodeAnimation_*`, `AnimationNodeStateMachineTransition_*`, `AnimationNodeStateMachine_*`, `AnimationNodeBlendTree_root` SubResources | 1277–1421 | **Drop all** (AnimationTree gone) |
| `RectangleShape2D_4qryw` SubResource | 1422–1423 | **Keep** (BK hit shape) |
| `[node name="BladeKeeper" instance=ExtResource("1_base")] ...` and all child node blocks | 1425–1506 | **Replace entirely** |

- [ ] **Step 1: Verify the line ranges by reading the file**

Read `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn`. Confirm SubResource boundaries match. If Godot has re-saved the file since the plan was written, line numbers may shift — work from SubResource IDs (e.g. `SpriteFrames_nw0us`, `AnimationLibrary_52y2t`), not from absolute line numbers.

- [ ] **Step 2: Confirm UID `uid://bics1mnpd7xx4`**

Read line 1: `[gd_scene format=3 uid="uid://bics1mnpd7xx4"]`. This UID **must be preserved** — `EnemySpawn.gd:6` preloads this path, and Godot caches the UID-to-path mapping.

---

### Task B2: Compose new ext_resource header and node block

**Files:**
- Modify (write): `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn`

**Context:** This is the central scene-rewrite task. We compose a new `.tscn` content by:
1. Keeping the `[gd_scene]` header (preserve UID).
2. Keeping all Texture2D + 2 PackedScene ext_resources (drop only the script ones we don't need).
3. Adding new ext_resources: AgentAIBase.tscn, BladeKeeper.gd, ApproachState.gd, all 11 skill .tres files.
4. Keeping all needed SubResources (SpriteFrames, all 16 Animation, AnimationLibrary, BK shapes).
5. Dropping AnimationTree-related SubResources.
6. Writing a new root node block + child node overrides + 1 added Approach state + 1 added AnimatedSprite2D.

**Skill .tres UIDs (all 11):**

| File | UID |
|---|---|
| `bk_atk_basic.tres` | `uid://srwwv9ytwx7e6` |
| `bk_atk_heavy.tres` | `uid://ql8mn9m799bhl` |
| `bk_dash_approach.tres` | `uid://4a6qktdpxruya` |
| `bk_throw_sword.tres` | `uid://f4mflfdu5fdyi` |
| `bk_place_trap.tres` | `uid://fb2mvmd0580mp` |
| `bk_dodge_back.tres` | `uid://a5u7atibngcal` |
| `bk_defend_buff.tres` | `uid://9axjwnl4u8c9c` |
| `bk_heal_self.tres` | `uid://sx9ziqliv6jxf` |
| `bk_combo_basic.tres` | `uid://drq1bgk8avw57` |
| `bk_combo_finisher_p2.tres` | `uid://2b21xo61hqgs7` |
| `bk_combo_finisher_p3.tres` | `uid://51cbbhcb9g8io` |

**Other UIDs:**
- `AgentAIBase.tscn`: `uid://rllitgnkf211`
- `BladeKeeper.gd`: `uid://cxftsuikhh8cy` (verify by reading `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd.uid`)
- `ApproachState.gd`: **no `.uid` file exists**. Use path-only ext_resource (no `uid=` attribute).

**Template's StateMachine `unique_id`:** `193203180` (from AgentAIBase.tscn line 173). Used in `parent_id_path=PackedInt32Array(193203180)` for the added Approach state.

- [ ] **Step 1: Re-read the current BK.tscn header and SubResource block, take careful note of every Texture2D ext_resource id and path**

Read lines 1–145 of `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn`. Each Texture2D line looks like:
```
[ext_resource type="Texture2D" uid="uid://c3p8ryejbadlq" path="res://Assets/Art/BLADE_KEEPER/PNG animations/07_1_atk/07_1_atk_1.png" id="3_5jd21"]
```
Keep all of these verbatim.

- [ ] **Step 2: Build the new ext_resource header**

The new header replaces lines 1–145. It must contain:

1. The `[gd_scene]` line **with preserved UID**:
```
[gd_scene format=3 uid="uid://bics1mnpd7xx4" load_steps=N]
```
where `N` is the total number of ext_resources + sub_resources (Godot will recompute on save; for the manual edit, set a placeholder like `load_steps=100` and let Godot fix it on first save).

2. The new template ext_resource (replace `BossBase.tscn` line):
```
[ext_resource type="PackedScene" uid="uid://rllitgnkf211" path="res://Scenes/Characters/Templates/AgentAIBase.tscn" id="1_base"]
```

3. The BK script ext_resource (carry over from old line 4):
```
[ext_resource type="Script" uid="uid://cxftsuikhh8cy" path="res://Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd" id="2_bk"]
```

4. The ApproachState script ext_resource (path-only, no UID):
```
[ext_resource type="Script" path="res://Core/AI/Stock/ApproachState.gd" id="3_approach"]
```

5. **All Texture2D ext_resources** copied verbatim from the old file (renumber ids to be sequential starting from 4, OR keep original ids — Godot accepts either as long as ids are unique within the file).

6. The two PackedScene ext_resources for projectile/trap (carry over):
```
[ext_resource type="PackedScene" uid="uid://cecnqhyi5nu00" path="res://Scenes/Characters/Bosses/BladeKeeper/Attacks/BKSwordProjectile.tscn" id="<N1>_projscene"]
[ext_resource type="PackedScene" uid="uid://dqjprnns73oqg" path="res://Scenes/Characters/Bosses/BladeKeeper/Attacks/BKTrapEntity.tscn" id="<N2>_trapscene"]
```

7. **All 11 skill .tres ext_resources** (new additions):
```
[ext_resource type="Resource" uid="uid://srwwv9ytwx7e6" path="res://Scenes/Characters/Bosses/BladeKeeper/skills/bk_atk_basic.tres" id="skill_basic"]
[ext_resource type="Resource" uid="uid://ql8mn9m799bhl" path="res://Scenes/Characters/Bosses/BladeKeeper/skills/bk_atk_heavy.tres" id="skill_heavy"]
[ext_resource type="Resource" uid="uid://4a6qktdpxruya" path="res://Scenes/Characters/Bosses/BladeKeeper/skills/bk_dash_approach.tres" id="skill_dash"]
[ext_resource type="Resource" uid="uid://f4mflfdu5fdyi" path="res://Scenes/Characters/Bosses/BladeKeeper/skills/bk_throw_sword.tres" id="skill_throw"]
[ext_resource type="Resource" uid="uid://fb2mvmd0580mp" path="res://Scenes/Characters/Bosses/BladeKeeper/skills/bk_place_trap.tres" id="skill_trap"]
[ext_resource type="Resource" uid="uid://a5u7atibngcal" path="res://Scenes/Characters/Bosses/BladeKeeper/skills/bk_dodge_back.tres" id="skill_dodge"]
[ext_resource type="Resource" uid="uid://9axjwnl4u8c9c" path="res://Scenes/Characters/Bosses/BladeKeeper/skills/bk_defend_buff.tres" id="skill_defend"]
[ext_resource type="Resource" uid="uid://sx9ziqliv6jxf" path="res://Scenes/Characters/Bosses/BladeKeeper/skills/bk_heal_self.tres" id="skill_heal"]
[ext_resource type="Resource" uid="uid://drq1bgk8avw57" path="res://Scenes/Characters/Bosses/BladeKeeper/skills/bk_combo_basic.tres" id="skill_combo_basic"]
[ext_resource type="Resource" uid="uid://2b21xo61hqgs7" path="res://Scenes/Characters/Bosses/BladeKeeper/skills/bk_combo_finisher_p2.tres" id="skill_combo_p2"]
[ext_resource type="Resource" uid="uid://51cbbhcb9g8io" path="res://Scenes/Characters/Bosses/BladeKeeper/skills/bk_combo_finisher_p3.tres" id="skill_combo_p3"]
```

**Drop these legacy script ext_resources entirely** (do not include in new file):
- `BossBase.tscn` (id `1_base` is being reassigned to AgentAIBase.tscn)
- `BKAttackManager.gd` (was id `4_atkmgr`)
- `BKStateMachine.gd` (was id `5_sm`)
- `IdleState.gd` from CommonStates (was id `6_idle`)
- `BKChase.gd` (was `7_chase`)
- `BKAttack.gd` (was `8_attack`)
- `BKDefend.gd` (was `9_defend`)
- `BKRoll.gd` (was `10_roll`)
- `BKProjectile.gd` (was `11_proj`)
- `BKTrap.gd` (was `12_trap`)
- `BossCounterState.gd` (was `13_counter`)
- `HitState.gd` from CommonStates (was `13_hit`)

- [ ] **Step 3: Keep the SubResource block (lines 146–1276 + 1422–1423), drop the AnimationTree block (lines 1277–1421)**

Specifically:
- Keep `SpriteFrames_nw0us` (line 146, ~459 lines)
- Keep `RectangleShape2D_bk_collision` (line 605, ~3 lines)
- Keep all 16 `Animation_*` SubResources (lines 608–1256)
- Keep `AnimationLibrary_52y2t` (lines 1257–1276)
- **Drop everything between** `AnimationNodeBlend2_control` and the line just before `RectangleShape2D_4qryw` (lines ~1277–1421). This includes:
  - `AnimationNodeBlend2_control`
  - All 13 `AnimationNodeAnimation_*` SubResources
  - All 10 `AnimationNodeStateMachineTransition_*` SubResources
  - `AnimationNodeStateMachine_control`
  - `AnimationNodeBlendTree_root` (or however the root tree is named — the `[node name="AnimationTree"]` block references it via `tree_root = SubResource("AnimationNodeBlendTree_root")`)
- Keep `RectangleShape2D_4qryw` (lines 1422–1423)

- [ ] **Step 4: Write the new node block**

Replace the original root + children block (lines 1425–1506) with this new content:

```
[node name="BladeKeeper" instance=ExtResource("1_base")]
collision_mask = 129
script = ExtResource("2_bk")
base_move_speed = 180.0
pressure_threshold = 35.0
skill_resources = Array[Skill]([ExtResource("skill_basic"), ExtResource("skill_heavy"), ExtResource("skill_dash"), ExtResource("skill_throw"), ExtResource("skill_trap"), ExtResource("skill_dodge"), ExtResource("skill_defend"), ExtResource("skill_heal"), ExtResource("skill_combo_basic"), ExtResource("skill_combo_p2"), ExtResource("skill_combo_p3")])

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
position = Vector2(0, -42)
sprite_frames = SubResource("SpriteFrames_nw0us")
animation = &"idle"

[node name="AnimationPlayer" parent="."]
libraries/ = SubResource("AnimationLibrary_52y2t")
autoplay = &"walk"

[node name="CollisionShape2D" parent="."]
position = Vector2(0, -1)
shape = SubResource("RectangleShape2D_bk_collision")

[node name="CollisionShape2D" parent="HurtBoxComponent"]
position = Vector2(0, -1)
shape = SubResource("RectangleShape2D_bk_collision")

[node name="CollisionShape2D" parent="HitBoxComponent"]
shape = SubResource("RectangleShape2D_4qryw")
disabled = true

[node name="HealthComponent" parent="."]
max_health = 100000.0
health = 100000.0

[node name="HealthBar" parent="."]
value = 0.3

[node name="Approach" type="Node" parent="AIController/StateMachine" parent_id_path=PackedInt32Array(193203180)]
script = ExtResource("3_approach")
```

**Notes on the node block:**
- `[node name="BladeKeeper" instance=ExtResource("1_base")]` — no `unique_id` is needed for the inheriting root; Godot generates one. `collision_mask=129` mirrors the legacy file. `script` re-points at BladeKeeper.gd.
- `[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]` — added node (template no longer has `Sprite2D`). `_auto_find_sprite()` in AgentAIBase will pick this up.
- `[node name="AnimationPlayer" parent="."]` — overrides the inherited template AnimationPlayer's `libraries/` field. The template's RESET stays present in addition to BK's library; this is harmless.
- The three `CollisionShape2D` overrides assign BK shapes (re-using `RectangleShape2D_bk_collision` for both body and hurt is the legacy behavior — BK uses one shape for both hitboxes).
- `[node name="HealthComponent" parent="."]` — overrides max_health/health on the inherited HealthComponent.
- `[node name="Approach" parent="AIController/StateMachine" parent_id_path=PackedInt32Array(193203180)]` — adds a new state node under the inherited StateMachine. The `193203180` is AgentAIBase's StateMachine `unique_id`.

**Notes on what's deliberately NOT included:**
- No `[node name="AnimationTree"]` block — AnimationTree is gone.
- No `BossAttackManager` node.
- No standalone `StateMachine` node (the inherited one under AIController is the only state machine).
- No BossBase-only fields (`attack_range`, `is_melee`, `has_gravity`, `evasion_enabled`, `poise_enabled`, `max_health`, `health` on the root — `max_health`/`health` go on HealthComponent instead).

- [ ] **Step 5: Write the new file**

Use the Write tool to replace `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn` with the composed content (header + ext_resources + SubResources + new node block). The file should be roughly 1100–1200 lines after dropping AnimationTree (~145 lines removed) and replacing the 80-line node block with a 35-line one.

**Critical**: do NOT use Edit for piece-meal changes — too easy to corrupt the file structure. Compose the full file content first, verify against the steps above, then Write.

---

### Task B3: Verify scene loads without errors

**Files:**
- Read-only

- [ ] **Step 1: Open BK.tscn in Godot editor**

Run `mcp__godot__launch_editor` (project at `e:/workspace/4.godot/combo_demon`).

Open `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn` in the editor.

- [ ] **Step 2: Capture editor output**

Run `mcp__godot__get_debug_output`.

Expected: no errors. Acceptable warnings: deprecation warnings about `RESET` animations or NodePath quirks. NOT acceptable: `Failed to load resource`, `Invalid node path`, `Script does not extend...`, parse errors.

If any unacceptable error appears, report it and STOP — do not proceed to Task B4.

- [ ] **Step 3: Save the scene through the editor**

Run `mcp__godot__save_scene` for `BladeKeeper.tscn`. This lets Godot normalize `load_steps` and re-format the file. The file diff after this save should be cosmetic only (load_steps recount, possibly reordered SubResource IDs).

---

### Task B4: Add animation Call Method Tracks

**Files:**
- Modify (via Godot editor only): `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn` (specifically, the inline `Animation_fap8e` / `Animation_r7lhx` / `Animation_k5270` SubResources for `projectile_cast` / `trap_cast` / `defend`)

**Context:** `GenericAttackState.gd` exposes three methods that animations need to call at specific frames:
- `spawn_projectile()` — used by `bk_throw_sword.tres` (animation `projectile_cast`)
- `spawn_entity()` — used by `bk_place_trap.tres` (animation `trap_cast`)
- `call_skill_method()` — used by `bk_defend_buff.tres` and `bk_heal_self.tres` (animation `defend`, dispatches to `apply_defense_buff` / `heal_self` based on skill params)

These methods must be invoked from Call Method Tracks on the AnimationPlayer. Target node path: `AIController/StateMachine/GenericAttack`.

**Implementation rule:** Edit through Godot editor only. Hand-editing track JSON in `.tscn` text is forbidden — the format is fragile and a malformed track corrupts the entire scene.

- [ ] **Step 1: Open BK.tscn in Godot editor**

If not already open from Task B3.

- [ ] **Step 2: Inspect the `projectile_cast` animation; if it lacks a Call Method Track for `spawn_projectile`, add one**

In the editor:
1. Select the AnimationPlayer node.
2. In the Animation panel, switch to the `projectile_cast` animation.
3. Look for an existing Call Method Track on path `AIController/StateMachine/GenericAttack`. If present and pointing at `spawn_projectile`, skip to Step 3.
4. If absent: add a new "Call Method Track" → set node path to `AIController/StateMachine/GenericAttack` → add a key at the sword-release frame (~40% into the animation; visually identify the frame where the sword leaves BK's hand) → set method to `spawn_projectile`.

- [ ] **Step 3: Inspect the `trap_cast` animation; if it lacks a Call Method Track for `spawn_entity`, add one**

Same procedure. Key time: ~50% into the animation (visually identify the frame where the trap drops).

- [ ] **Step 4: Inspect the `defend` animation; if it lacks a Call Method Track for `call_skill_method`, add one**

Same procedure. Key time: ~30% into the animation (visually identify the frame where the defensive stance becomes active).

- [ ] **Step 5: Save the scene**

Run `mcp__godot__save_scene` for `BladeKeeper.tscn`.

- [ ] **Step 6: Verify the tracks were saved**

Read the modified `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn`. Search for `"method"` in the `Animation_fap8e` / `Animation_r7lhx` / `Animation_k5270` SubResources. Each should now contain a track of type `"method"` with `path = NodePath("AIController/StateMachine/GenericAttack")` and `values` referencing `spawn_projectile` / `spawn_entity` / `call_skill_method` respectively.

If verification fails, report and STOP. **Do not** attempt to manually inject the track JSON — re-do the editor steps.

---

### Task B5: Delete legacy `.gd` files

**Files:**
- Delete: 9 `.gd` + `.gd.uid` pairs in `Scenes/Characters/Bosses/BladeKeeper/` and `Scenes/Characters/Bosses/Shared/`

- [ ] **Step 1: Confirm no remaining references in the codebase**

Run grep checks:
```bash
cd e:/workspace/4.godot/combo_demon
```

Then check each:
- `BKAttackManager`: `grep -r "BKAttackManager" Scenes/ Core/ test/` — expect zero hits (BK.tscn after Task B2 should have no reference)
- `BKStateMachine`: `grep -r "BKStateMachine" Scenes/ Core/ test/` — expect zero hits
- `BKAttack`, `BKChase`, `BKDefend`, `BKRoll`, `BKProjectile`, `BKTrap`: `grep -r "BK[A-Z][a-z]*\.gd" Scenes/ Core/ test/` — expect zero hits
- `BossCounterState`: `grep -r "BossCounterState" Scenes/ Core/ test/` — expect zero hits (DS2 uses `DS2Counter.gd`, not this one)

If any grep returns hits, report and STOP — there's a hidden dependency.

- [ ] **Step 2: Delete the legacy `.gd` files**

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
rm Scenes/Characters/Bosses/Shared/BossCounterState.gd
rm Scenes/Characters/Bosses/Shared/BossCounterState.gd.uid
```

If `BKIdle.gd` exists in `Scenes/Characters/Bosses/BladeKeeper/States/`, delete it too:
```bash
ls Scenes/Characters/Bosses/BladeKeeper/States/ | grep -i bkidle
# if any line returned:
rm Scenes/Characters/Bosses/BladeKeeper/States/BKIdle.gd
rm Scenes/Characters/Bosses/BladeKeeper/States/BKIdle.gd.uid
```

- [ ] **Step 3: Verify the empty `States/` directory**

```bash
ls Scenes/Characters/Bosses/BladeKeeper/States/
```

If empty, remove the directory:
```bash
rmdir Scenes/Characters/Bosses/BladeKeeper/States/
```

If non-empty (some other file lives there), leave the directory and note what's still in it.

---

### Task B6: Run unit tests

**Files:**
- Read-only

- [ ] **Step 1: Run full GUT test suite**

```bash
cd e:/workspace/4.godot/combo_demon && godot --headless -d -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit
```

Expected: all tests PASS. The 11 BK skill resource tests + everything else green.

If any test fails, report which test, paste failure output, and STOP.

---

### Task B7: Manual scene-play validation (BK)

**Files:**
- Modify temporarily: `Scenes/Levels/Level_BladeKeeper/EnemySpawn.gd`

- [ ] **Step 1: Set EnemySpawn to spawn BK by default**

Edit `Scenes/Levels/Level_BladeKeeper/EnemySpawn.gd` line 11:
```gdscript
@export_enum("BladeKeeper", "DemonSlime2") var boss_name: String = "BladeKeeper"
```

And line 15:
```gdscript
@export var use_game_manager: bool = false
```

- [ ] **Step 2: Run the level**

Run `mcp__godot__run_project` with main scene `res://Scenes/Levels/Level_BladeKeeper/LevelBladeKeeper.tscn`.

- [ ] **Step 3: Capture debug output**

Run `mcp__godot__get_debug_output`.

Expected lines (substring match):
- `bossSpawn: Spawned default character - BladeKeeper`
- No `ERROR`, no `Failed to load`, no `Script does not extend`, no `Invalid call to method`

Watch BK for ~10 seconds: it should idle → chase player → execute skills (including `spawn_projectile` from `projectile_cast` animation, and `spawn_entity` from `trap_cast` animation if trap skill triggers).

- [ ] **Step 4: Stop the project**

Run `mcp__godot__stop_project`.

- [ ] **Step 5: Revert EnemySpawn.gd**

```bash
git checkout -- Scenes/Levels/Level_BladeKeeper/EnemySpawn.gd
```

If `git checkout` fails (file untracked), manually revert lines 11 and 15 to their pre-edit values.

---

### Task B8: Commit Sub-project B

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn`, `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd`
- Delete: 9 (or 10) legacy `.gd` + `.gd.uid` pairs

- [ ] **Step 1: Verify staged changes look right**

```bash
cd e:/workspace/4.godot/combo_demon
git status
```

Expected:
- Modified: `BladeKeeper.tscn` (full rewrite)
- Modified: `BladeKeeper.gd` (the `&"dead"` → `&"death"` hotfix carried over from working tree)
- Deleted: `BKAttackManager.gd`, `BKAttackManager.gd.uid`, `BKStateMachine.gd`, `BKStateMachine.gd.uid`, `BKAttack.gd(.uid)`, `BKChase.gd(.uid)`, `BKDefend.gd(.uid)`, `BKRoll.gd(.uid)`, `BKProjectile.gd(.uid)`, `BKTrap.gd(.uid)`, `BossCounterState.gd(.uid)`
- Possibly deleted directory: `Scenes/Characters/Bosses/BladeKeeper/States/`

- [ ] **Step 2: Stage and commit**

```bash
cd e:/workspace/4.godot/combo_demon
git add Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn
git add Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd
git add -u Scenes/Characters/Bosses/BladeKeeper/
git add -u Scenes/Characters/Bosses/Shared/
git commit -m "feat(bk): rebuild BladeKeeper from AgentAIBase + delete legacy step-machine

- BladeKeeper.tscn: full rewrite, inherits trimmed AgentAIBase.tscn
- replaces BossBase + BKAttackManager + BKStateMachine architecture
- adds AnimatedSprite2D (template no longer has placeholder Sprite2D)
- drops AnimationTree (new stock states use AnimationPlayer.play directly)
- Approach state added under AIController/StateMachine
- skill_resources Array statically populated with all 11 .tres references
- animation method tracks added: projectile_cast/trap_cast/defend
- BladeKeeper.gd hotfix: get_state(&\"dead\") -> &\"death\" (template node is Death)
- delete legacy: BKAttackManager, BKStateMachine, BKAttack/Chase/Defend/Roll/Projectile/Trap, BossCounterState
"
```

(`git add -u` re-stages deletions; works only on tracked deletions.)

- [ ] **Step 3: Verify clean working tree**

```bash
git status
```

Expected: nothing to commit (working tree clean), or only untracked/unrelated files (`.claude/scheduled_tasks.lock`, `bash.exe.stackdump`, `EnemySpawn.gd` if still untracked, the design + plan docs).

- [ ] **Step 4: Final smoke test**

```bash
cd e:/workspace/4.godot/combo_demon && godot --headless -d -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit
```

Expected: all tests PASS post-commit.

---

## Done Criteria

- [ ] Sub-project A commit pushed with trimmed `AgentAIBase.tscn`
- [ ] DS2 still loads + spawns + plays through full state cycle
- [ ] Sub-project B commit pushed with rebuilt `BladeKeeper.tscn` + legacy deletions
- [ ] BK loads + spawns + executes basic/heavy/dash/throw/trap/defend/heal/combo skills
- [ ] All unit tests pass
- [ ] Working tree clean (modulo unrelated untracked files)
