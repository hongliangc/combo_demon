---
name: godot-level-design
description: "Production-grade Godot 4 level design skill for 2D Platformer games. Use this skill whenever the user asks to design, generate, document, or review a game level in Godot 4 — including tilemap layout, enemy placement, encounter design, pacing, checkpoint logic, collectible placement, and narrative beat integration. Also trigger for souls-like or metroidvania vertical design, shortcut systems, elevation-based structures, terrain brush workflows, or any request involving TileMapLayer, TileSet, or level scene organization in Godot 4. CRITICALLY trigger when the user uploads a screenshot or reference image and wants to recreate or generate a level from it using their existing project assets — even if they just say 'make this level' or 'reproduce this screenshot'. Even if the user only says 'help me design a level' or 'layout ideas for my next area', use this skill."
---

# Godot 4 — 2D Platformer Level Design Skill

This skill guides production-quality level design for 2D platformers in Godot 4.4+. It covers both the **design philosophy layer** (spatial structure, pacing, encounters) and the **technical implementation layer** (TileMapLayer, scene composition, GDScript hooks) — including **screenshot-to-level reconstruction** using existing project assets.

---

## Workflow Overview

### Mode A — Design from Scratch
When designing a new level from requirements:

```
1. Clarify Context    → Understand genre tone, current zone, player abilities
2. Spatial Layout     → Define the macro structure (shape, flow, elevation)
3. Encounter Design   → Enemy/hazard placement & rhythm
4. Technical Spec     → Godot scene tree, TileMapLayer setup, node structure
5. Deliverable        → Output the requested format (doc / code / tilemap script)
```

### Mode B — Screenshot to Level  ⬅ NEW
When a screenshot or reference image is provided:

```
1. Visual Analysis    → Detect tile size, decompose layers, catalog entities
2. Asset Inventory    → Scan / ask for project assets, build mapping table
3. Coordinate Mapping → Convert pixel regions to tile coordinates
4. Code Generation    → Emit EditorScript builder + optional runtime data
5. Validation         → Check playability, collision, navigation, asset paths
```

**→ Read `references/screenshot-to-level.md` immediately when a screenshot is present.**

---

## Reference Files

Read the relevant file(s) **before** generating output:

- `references/screenshot-to-level.md` — **Full pipeline: image analysis → asset mapping → GDScript generation** *(read first when screenshot provided)*
- `references/spatial-design.md` — Macro layout, elevation, flow theory
- `references/encounter-design.md` — Enemy placement, pacing, combat rooms
- `references/tilemap-implementation.md` — TileMapLayer API, terrain, autotile
- `references/scene-architecture.md` — Scene tree, node naming, export variables
- `references/souls-platformer-patterns.md` — Shortcuts, bonfire logic, vertical loops *(souls-like / metroidvania)*

---

## Phase 1 — Clarify Context

Before designing, resolve these parameters (ask if not provided):

| Parameter | Options / Notes |
|---|---|
| **Level Goal** | Tutorial / Combat gauntlet / Exploration / Boss approach / Shortcut unlock |
| **Player Abilities** | Which movement abilities are unlocked (dash, double jump, wall jump, etc.) |
| **Zone Theme** | Castle / Cave / Forest / Industrial / Void / etc. |
| **Vertical Style** | Horizontal scroll / Vertical climb / Open arena / Corridor |
| **Difficulty Position** | Early / Mid / Late game |
| **Key Design Beat** | The ONE memorable moment this level must have |

---

## Phase 2 — Spatial Layout

### Skeleton First — Then Tile

**Always output the level skeleton before writing any tile coordinates or GDScript.** This catches structural problems (unreachable platforms, bad pacing) before they become code.

Skeleton format:
```yaml
# Level skeleton — confirm before proceeding to tile generation
segments:
  - type: flat       # REST — player arrives
    x: 0, length: 6, y: 14
  - type: gap        # CHALLENGE
    x: 6, width: 3
  - type: platform   # REWARD
    x: 9, y: 11, width: 4, one_way: false
  - type: slope_up   # TRANSITION
    x: 13, length: 3, delta_y: -2
  - type: hazard_pit # CHALLENGE
    x: 16, width: 2, spike: true
  - type: flat       # REST + REWARD
    x: 18, length: 5, y: 9, collectibles: true

rhythm_groups:
  - "[flat@0]     REST"
  - "[gap@6]      CHALLENGE"
  - "[platform@9] REWARD"
  - "[slope@13]   TRANSITION"
  - "[pit@16]     CHALLENGE"
  - "[flat@18]    REST+REWARD"
```

Validate the skeleton against jump physics constraints (see `references/spatial-design.md`) **before** converting to tiles.

### Macro Structure Patterns

Choose one macro shape and state it explicitly in your output:

| Pattern | Use When |
|---|---|
| **Linear Gauntlet** | Controlled pacing, tutorial, boss lead-up |
| **Loop w/ Shortcut** | Souls-like revisit, unlockable bypass |
| **Vertical Tower** | Escalation tension, elevator boss, stamina drain |
| **Branching Hub** | Exploration, multiple route discovery |
| **Arena + Escape** | Ambush climax, timed sequence |
| **Spiral Descent** | Mystery/horror tone, resource attrition |

### Elevation Principles

- **Every height difference must have a purpose**: sniper line, hidden path, shortcut gate, narrative reveal
- Use **3 elevation tiers** minimum for non-linear levels: ground floor, mid ledge, upper route
- Enemies on higher ground = ranged/projectile. Ground level = melee/patrol
- Shortcut gates live at **mid tier**, opening downward to tier 1

### Room Grammar

Each "room" or distinct space should follow:
```
[Entry Beat] → [Readable Threat] → [Engagement] → [Resolution + Reward] → [Exit Signal]
```
- Entry beat: 1–2 second visual read before danger
- Readable threat: enemy placement telegraphed by environment shadow/silhouette
- Resolution: small platform to catch breath, health drop, or save point
- Exit signal: distinct door, light source, or vertical gap

---

## Phase 3 — Encounter Design & Rhythm

See `references/encounter-design.md` for full enemy pattern library.

### Rhythm Groups

A level is a sequence of **rhythm groups** — small segments that form the pacing heartbeat. Every generated or designed level must label its segments by group type:

| Type | Description | Duration |
|---|---|---|
| **REST** | Flat ground, no hazards, breathing room | 4–6 tiles |
| **CHALLENGE** | Gap / spike / precision jump | 1–4 tiles |
| **REWARD** | Collectible cluster, power-up, visual beat | 2–4 tiles |
| **TRANSITION** | Slope or step connecting elevations | 2–4 tiles |

**Sequence rule:** `REST → CHALLENGE → REWARD → REST → CHALLENGE (harder) → REWARD`
- After 3+ consecutive CHALLENGEs: mandatory REST ≥ 4 tiles
- Never place two identical rhythm group sequences back-to-back
- Increase CHALLENGE difficulty by ONE variable at a time (gap width OR height, not both)

### Quick Encounter Rules

1. **Introduce before combining**: show a new enemy solo before pairing with others
2. **3-beat encounter rhythm**: Opener (1 enemy) → Escalation (2–3) → Climax (mixed + hazard)
3. **Mandatory recovery space** after every climax (flat ground, light source, or health drop)
4. **Hazard density cap**: max 3 active hazard types per room
5. **Elite/mini-boss placement**: dead-end or locked room only, never on critical path without bypass

### Encounter Notation

```
[Room ID: E03]
  Enemies:   Skeleton×2 (patrol), Archer×1 (upper ledge)
  Hazards:   Spike pit (center), Swinging blade (exit)
  Rhythm:    CHALLENGE → CHALLENGE → REWARD
  Reward:    Chest (upper ledge, requires clearing archer)
  Shortcut:  Ladder opens on clear → connects to E01
```

---

## Phase 4 — Technical Specification (Godot 4)

### Scene Tree Structure

```
Level_ZoneName_XX.tscn
├── World                          (Node2D)
│   ├── TileMapLayer_Background    (TileMapLayer, z_index=-1)
│   ├── TileMapLayer_Terrain       (TileMapLayer, z_index=0, physics enabled)
│   ├── TileMapLayer_Foreground    (TileMapLayer, z_index=2)
│   ├── Encounters                 (Node2D)
│   │   ├── Room_E01               (Node2D)
│   │   │   ├── EnemySpawner       (Node2D + script)
│   │   │   └── TriggerZone        (Area2D)
│   ├── Interactables              (Node2D)
│   │   ├── Checkpoint_01          (Area2D)
│   │   └── Chest_Hidden_01        (StaticBody2D)
│   ├── Hazards                    (Node2D)
│   └── Navigation                 (NavigationRegion2D)
├── LevelEvents                    (Node, autoload signal bus)
└── Camera                        (Camera2D, limits set per level)
```

### TileMapLayer Setup

```gdscript
# Terrain painting via script (production pattern)
func paint_terrain_rect(layer: TileMapLayer, rect: Rect2i, terrain_set: int, terrain_id: int) -> void:
    var cells: Array[Vector2i] = []
    for x in range(rect.position.x, rect.end.x):
        for y in range(rect.position.y, rect.end.y):
            cells.append(Vector2i(x, y))
    layer.set_cells_terrain_connect(cells, terrain_set, terrain_id)

# Clear a region
func clear_rect(layer: TileMapLayer, rect: Rect2i) -> void:
    for x in range(rect.position.x, rect.end.x):
        for y in range(rect.position.y, rect.end.y):
            layer.erase_cell(Vector2i(x, y))
```

**Key TileMapLayer rules (Godot 4.4):**
- Each logical layer (bg / terrain / fg) = **separate TileMapLayer node** (not layers within one node — that API was removed)
- Physics collision lives on **terrain layer only**
- `set_cells_terrain_connect()` requires terrain set index + terrain ID, not tile coords
- UV origin is **top-left** (not center) for atlas tile math

### Export Variables for Level Config

```gdscript
# Attach to Level root node
@export var level_id: String = "zone01_e03"
@export var unlock_shortcut_after_clear: bool = false
@export var shortcut_target_level: String = ""
@export var ambient_track: AudioStream
@export var respawn_point: NodePath
@export var difficulty_modifier: float = 1.0
```

### Checkpoint Pattern

```gdscript
# Checkpoint.gd
class_name Checkpoint
extends Area2D

signal checkpoint_activated(checkpoint_id: String)

@export var checkpoint_id: String
var _activated := false

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player") and not _activated:
        _activated = true
        checkpoint_activated.emit(checkpoint_id)
        GameState.save_checkpoint(checkpoint_id, global_position)
        _play_activate_animation()
```

---

## Phase 5 — Deliverables

Produce output in the format the user requests. Defaults by task type:

| Task | Default Output |
|---|---|
| "Design a level" | Spatial layout doc + encounter notation + scene tree spec |
| "Generate level GDScript" | Full .gd files + scene structure comments |
| "Review my level" | Critique by pacing / readability / encounter rhythm / technical issues |
| "Make a tilemap layout" | ASCII grid map + `paint_terrain_rect` GDScript calls |
| "Boss approach area" | Detailed single-path linear design with escalating dread pacing |
| **Screenshot / image provided** | **→ Run Mode B pipeline (see `references/screenshot-to-level.md`):** asset mapping table → ASCII reconstruction → EditorScript builder .gd |

### ASCII Layout Format

Use tile coordinates (each cell = 1 tile = 16px or 32px, state which):

```
Legend: # = terrain  . = empty  E = enemy  C = chest  K = checkpoint  ^ = spike  ~ = water

Y=0  ################################################
Y=1  #......................#........................#
Y=2  #...E......C.....E.....#......K.....E....E.....#
Y=3  ###########....#########.........##############
Y=4  ...........E...............^^^^^................
Y=5  ...........####.............####...............
```

---

## Quality Checklist & Validation Report

After completing any level design or generation, output a validation report with **actual numbers**, not just pass/fail:

```
Validation Report — [theme] [size] [difficulty]
================================================
Jump Physics:
  [PASS] All N gaps       <= 5 tiles     (max found: X at x=N)
  [PASS] All N rises      <= 3 tiles     (max found: X)
  [PASS] All platforms    >= 2 tiles wide (min found: X)

Rhythm & Pacing:
  [PASS] No flat run > 8 tiles           (max: X at x=N)
  [PASS] REST after every 3 CHALLENGEs   (checked N sequences)
  [WARN] Flat run at x:22–30 (8 tiles) — at limit, acceptable

Encounter Design:
  [PASS] No new mechanic paired with another new mechanic
  [PASS] Checkpoint before every elite/boss
  [PASS] All hazards visible 3+ tiles before player reaches

Tilemap Integrity:
  [PASS] No floating tiles               (0 violations)
  [PASS] All corners resolved by auto-tile (N corners OK)
  [PASS] Decoration clear of landing zones (3 tiles after gaps)

Auto-Repairs Applied: N
  - gap at x:14 reduced 6→5 tiles (exceeded max horizontal gap)
  - platform at x:22 extended +2 tiles (landing width was 1)
```

**Always include actual values.** A checklist without numbers is not a validation report.

Design quality checks (no numbers needed):
- [ ] Player can read first threat within 2 seconds of entering each room
- [ ] No dead-ends without reward or shortcut
- [ ] TileMapLayer nodes separated by role (bg / terrain / fg)
- [ ] Camera limits prevent player seeing outside level bounds
- [ ] NavigationRegion2D baked if any enemy uses NavigationAgent2D
- [ ] Level ID unique and follows naming convention

---

## Anti-Patterns to Avoid

| Anti-Pattern | Fix |
|---|---|
| Blind drop into spike pit | Always visible before the fall |
| Enemy spam in open room | Use terrain to create engagement angles |
| Shortcut that skips main reward | Shortcut bypasses grind, not story beat |
| 3+ terrain types in single TileMapLayer | Separate into individual TileMapLayer nodes |
| Camera that cuts off player jump arc | Set camera limits with extra 200px headroom |
| Checkpoint after boss (not before) | Always before; respect player time |
| NavigationRegion2D never rebaked | Add rebake call to level `_ready()` in editor |
