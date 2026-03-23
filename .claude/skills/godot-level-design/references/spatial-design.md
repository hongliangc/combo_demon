# Spatial Design Reference

## Macro Layout Theory

### Flow Classification

Levels are classified by their dominant flow type:

**Type A — Directed Flow**
- Player always knows where to go
- Used in: tutorial, boss lead-up, story moments
- Key tools: lighting gradient, architecture framing, enemy line-of-sight funnel

**Type B — Legible Branching**
- Multiple visible paths, player chooses
- Used in: mid-game exploration, secret hunting
- Key rule: all branch starts must be visible from the central hub
- Max 3 branches per hub to avoid decision paralysis

**Type C — Obfuscated Discovery**
- Hidden paths, false walls, off-screen secrets
- Used in: metroidvania post-ability-unlock revisit, high-skill reward
- Key rule: always leave a visual hint (crack in wall, different tile pattern, drip of light)

---

## Elevation Design System

### The Three-Tier Model

```
TIER 3 (Sky / High)     — Reward routes, ranged enemy positions, secrets
         [===]  [=]  [======]

TIER 2 (Mid)            — Shortcut gates, ambush platforms, mid-boss arenas
    [=======]  [===]    [==]

TIER 1 (Ground)         — Main path, patrol enemies, interactables
[==========================================]
```

**Rules:**
- Main story beat always passes through Tier 1 or 2, never Tier 3 exclusively
- Tier 3 is always OPTIONAL unless it's the only post-boss unlock route
- Vertical distance Tier 1→3: 6–12 tiles recommended (16px tiles)
- Every Tier 3 platform must have a visible fall-back route to Tier 1

### Elevation Purpose Taxonomy

| Height Change | Design Intent | Example |
|---|---|---|
| +2 tiles | Obstacle, easy hop | Low fence, small ledge |
| +4–6 tiles | Route split, view upgrade | Sniper ledge, fork |
| +8–12 tiles | Tier transition, stamina test | Climbing section |
| +16+ tiles | Vertical dungeon floor, elevator | Tower level |
| -2 tiles | Descend into danger | Pit entry |
| -8+ tiles | Commitment drop, no easy return | Descent zone |

---

## Jump Physics Constraints

These limits are derived from platformer physics and must be respected for every gap and height transition. Recalculate if your project changes gravity, jump velocity, or run speed.

Reference formula:
```
t_peak  = abs(jump_velocity) / gravity       # time to apex
t_land  = 2 * t_peak                         # total air time (flat landing)
max_h_px = run_speed * t_land                # max horizontal distance in px
max_v_px = jump_velocity² / (2 * gravity)   # max height gain in px
```

**Hard limits (default: gravity=980, jump_vel=-350, run=130, tile=16px):**

| Constraint | Tiles | px | Notes |
|---|:---:|:---:|---|
| Max horizontal gap | **5** | 80 | Full jump at run speed |
| Max vertical rise | **3** | 48 | Standing jump height |
| Min platform width | **2** | 32 | Narrower = unfair landing |
| Comfortable landing zone | **3+** | 48+ | After a hard jump |
| Max safe fall (no fall damage) | **8** | 128 | Only relevant if fall damage enabled |
| Coyote gap tolerance | +1 | 16 | Player runs off edge, coyote time still fires |

**Validation rule — apply to every gap and height change:**
```
PASS when ALL conditions met:
  gap_tiles    <= 5
  height_rise  <= 3    (target platform is higher)
  height_drop  <= 8    (target platform is lower)
  landing_width >= 2
FAIL → apply Fail-Safe rules in tilemap-implementation.md
```

Increase difficulty by changing **one variable at a time** — wider gap OR greater height, never both in the same segment.

---

### Sight Lines

Every dangerous vertical drop should satisfy one of:
1. Player can see the floor from above (transparent foreground tile or gap)
2. An enemy is visible at the bottom before the fall (warning)
3. A shadow/particle effect communicates depth

---

## Room Sizing Guidelines

| Room Type | Min Size (tiles) | Max Size | Notes |
|---|---|---|---|
| Tutorial room | 20×10 | 40×12 | Keep ceiling low |
| Combat room | 16×8 | 50×20 | Width drives pacing |
| Corridor | 6×4 | 100×6 | For tension/speed |
| Arena | 30×14 | 80×30 | Boss room: 40×20 min |
| Secret room | 8×6 | 20×10 | Always off-critical-path |
| Checkpoint alcove | 6×5 | 12×8 | Must feel "safe" |

---

## Camera Design

### Godot 4 Camera Limit Setup

```gdscript
# Set in _ready() of Level root
func _setup_camera_limits(cam: Camera2D, level_rect: Rect2) -> void:
    cam.limit_left   = int(level_rect.position.x)
    cam.limit_top    = int(level_rect.position.y)
    cam.limit_right  = int(level_rect.end.x)
    cam.limit_bottom = int(level_rect.end.y)
    # Add headroom for jump arc
    cam.limit_top   -= 200
    cam.limit_bottom += 64
```

### Camera Zones

For levels with multiple distinct areas, use **camera trigger zones**:

```gdscript
# CameraZone.gd
class_name CameraZone
extends Area2D

@export var zoom_level: Vector2 = Vector2(1, 1)
@export var camera_offset: Vector2 = Vector2.ZERO
@export var smooth_transition: bool = true

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        var cam = get_viewport().get_camera_2d()
        if smooth_transition:
            var tween = create_tween()
            tween.tween_property(cam, "zoom", zoom_level, 0.4)
            tween.parallel().tween_property(cam, "offset", camera_offset, 0.4)
        else:
            cam.zoom = zoom_level
            cam.offset = camera_offset
```

---

## Pacing Rhythm

### The 5-Beat Level Arc

```
Beat 1 — ARRIVAL (10%)        Safe exploration, environmental storytelling
Beat 2 — FIRST CONTACT (20%)  First enemy, low stakes, teaches new mechanic
Beat 3 — ESCALATION (40%)     Combined threats, multi-enemy rooms, terrain hazards
Beat 4 — CLIMAX (20%)         Peak difficulty, elite enemy or mini-boss, max threat density
Beat 5 — RELEASE (10%)        Recovery, reward, shortcut unlock, narrative moment
```

Apply this arc at both **level scale** and **room scale** for fractal pacing.

### Threat Density Curve

Plot approximate threat density (0–10) across the level's horizontal span:

```
Density
  10 |              [CLIMAX]
   8 |           *--*      *-
   6 |        *--         
   4 |     *--             *--*
   2 |  *--                    *--
   0 |--                          --
     Start                        End
```

Never let density stay at 10 for more than 2 rooms. Always follow a peak with a valley.

---

## Decoration Density Rules

Decoration (grass, rocks, background props) should feel organic, not repetitive. Use these rules for any procedural or manual placement:

**Density function** — drive placement with noise, not uniform intervals:
```
density(x) = simplex_noise(x * 0.2)   # value in [0, 1]

Grass:     place if density(x) > 0.6  AND top of solid tile is exposed
BackRock:  place if density(x) < 0.3  AND no foreground tile at position
Trees:     fixed interval every 15–20 tiles, NOT noise-driven (too cluttered)
```

**Anti-repetition rules:**
- No identical tile variant within radius 3 tiles
- Cluster 2–3 tiles of the same type before switching variant
- Prefer edge positions (first/last tile of a platform run)
- Use ≥ 3 variants per decoration type with weighted random selection
- **Never place decoration on player landing zones** — 3 tiles after any gap edge

**GDScript weighted variant picker:**
```gdscript
func pick_variant(variants: Array[String], weights: Array[float]) -> String:
    var total := weights.reduce(func(a, b): return a + b, 0.0)
    var roll  := randf() * total
    var acc   := 0.0
    for i in variants.size():
        acc += weights[i]
        if roll <= acc:
            return variants[i]
    return variants[-1]

# Usage:
var key := pick_variant(["GRASS_A","GRASS_B","GRASS_C"], [0.5, 0.3, 0.2])
layer.set_cell(Vector2i(x, y), ATLAS_ID, TILE[key])
```

---

## Environmental Storytelling Techniques

### Before-After Contrast
Show the same room before and after an event (destroyed pillar, drained water, opened gate) via Level variant scenes loaded by save flag.

```gdscript
func _ready() -> void:
    if GameState.get_flag("zone01_flood_drained"):
        $TileMapLayer_Water.visible = false
        $TileMapLayer_WetFloor.visible = true
        $Enemy_WaterGuard.queue_free()
```

### Echo Objects
Plant visual callbacks: a broken sword on the ground earlier foreshadows the enemy who wields one. Use `Prop_BrokenSword.tscn` as a reusable scene.

### Lighting as Narrative
- Safe areas: warm orange/yellow point lights
- Danger areas: cold blue/green, pulsing
- Boss rooms: single harsh backlight, player in silhouette
- Secret rooms: faint magenta or cyan — color that "doesn't belong"
