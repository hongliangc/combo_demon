# TileMap Implementation Reference (Godot 4.4)

## Architecture Overview

In Godot 4.3+, the monolithic `TileMap` node was replaced by individual `TileMapLayer` nodes. This is the production pattern:

```
TileMapLayer_Background   (z_index = -2, no collision)
TileMapLayer_Backdrop     (z_index = -1, no collision, parallax)
TileMapLayer_Terrain      (z_index = 0,  COLLISION ENABLED, navigation)
TileMapLayer_Details      (z_index = 1,  no collision, decorative)
TileMapLayer_Foreground   (z_index = 3,  no collision, occlusion)
```

**Never put collision physics on more than one TileMapLayer** unless you have a deliberate reason (e.g., separate one-way platform layer).

---

## TileSet Configuration

### Terrain Sets

A TileSet can have multiple terrain sets. Typical 2D platformer setup:

```
TileSet
├── Terrain Set 0: "Ground"
│   ├── Terrain 0: Stone Floor
│   ├── Terrain 1: Dirt Path
│   └── Terrain 2: Ice Platform
├── Terrain Set 1: "Walls"
│   ├── Terrain 0: Stone Wall
│   └── Terrain 1: Brick Wall
└── Terrain Set 2: "Ceiling"
    └── Terrain 0: Stalactite
```

### Bitmask Mode

Use **16-tile (Minimal)** for most cases — simpler, faster to configure.
Use **47-tile (Full)** only when you need all edge/corner transitions (high-fidelity tilesets).

**Terrain matching rule**: Connect mode `CONNECT_MODE_CONNECT_WITH_ANY` for ground tiles,
`CONNECT_MODE_CONNECT_WITH_MATCHING_TERRAIN` for walls that should not connect to floors.

---

## TileMapLayer API Reference (Godot 4.4)

### Core Painting Methods

```gdscript
# Paint a single cell with a specific atlas tile
layer.set_cell(
    coords: Vector2i,
    source_id: int,      # TileSet source index
    atlas_coords: Vector2i,  # Position in atlas (column, row)
    alternative_tile: int = 0  # for rotations/mirrors
)

# Erase a cell
layer.erase_cell(coords: Vector2i)

# Get what's at a cell
var tile_data: TileData = layer.get_cell_tile_data(coords: Vector2i)
var atlas_pos: Vector2i = layer.get_cell_atlas_coords(coords: Vector2i)
var source_id: int = layer.get_cell_source_id(coords: Vector2i)

# Fill a region with terrain (auto-bitmask)
layer.set_cells_terrain_connect(
    cells: Array[Vector2i],
    terrain_set: int,
    terrain: int,
    ignore_empty_terrains: bool = true
)

# Fill a region without affecting neighbors (manual bitmask)
layer.set_cells_terrain_path(
    cells: Array[Vector2i],
    terrain_set: int,
    terrain: int,
    ignore_empty_terrains: bool = true
)

# Get all used cell positions
var all_cells: Array[Vector2i] = layer.get_used_cells()
var cells_of_type: Array[Vector2i] = layer.get_used_cells_by_id(source_id, atlas_coords)
```

### Coordinate Conversion

```gdscript
# World position → tile coords
var tile_pos: Vector2i = layer.local_to_map(local_pos: Vector2)

# Tile coords → world position (returns cell center)
var world_pos: Vector2 = layer.map_to_local(map_pos: Vector2i)

# Global to tile
var tile: Vector2i = layer.local_to_map(layer.to_local(global_pos))
```

**UV / Atlas note:** Atlas coordinates are (column, row) in tile units, origin is top-left of the atlas image.

---

## Procedural Level Generation Patterns

### Chunk-Based Room Generator

```gdscript
# LevelGenerator.gd
class_name LevelGenerator
extends Node

@export var terrain_layer: TileMapLayer
@export var tile_source_id: int = 0
@export var terrain_set_floor: int = 0
@export var terrain_id_stone: int = 0

func generate_room(rect: Rect2i) -> void:
    # Floor
    _fill_terrain_row(rect.position.y + rect.size.y - 1,
                      rect.position.x, rect.end.x,
                      terrain_set_floor, terrain_id_stone)
    # Walls
    _fill_terrain_col(rect.position.x, rect.position.y, rect.end.y,
                      terrain_set_floor, terrain_id_stone)
    _fill_terrain_col(rect.end.x - 1, rect.position.y, rect.end.y,
                      terrain_set_floor, terrain_id_stone)
    # Ceiling
    _fill_terrain_row(rect.position.y,
                      rect.position.x, rect.end.x,
                      terrain_set_floor, terrain_id_stone)

func _fill_terrain_row(y: int, x_start: int, x_end: int, tset: int, tid: int) -> void:
    var cells: Array[Vector2i] = []
    for x in range(x_start, x_end):
        cells.append(Vector2i(x, y))
    terrain_layer.set_cells_terrain_connect(cells, tset, tid)

func _fill_terrain_col(x: int, y_start: int, y_end: int, tset: int, tid: int) -> void:
    var cells: Array[Vector2i] = []
    for y in range(y_start, y_end):
        cells.append(Vector2i(x, y))
    terrain_layer.set_cells_terrain_connect(cells, tset, tid)

func carve_opening(wall_x: int, y_start: int, height: int = 3) -> void:
    for y in range(y_start, y_start + height):
        terrain_layer.erase_cell(Vector2i(wall_x, y))
```

### Platform Spawner

```gdscript
# PlatformSpawner.gd
func spawn_platforms(
    layer: TileMapLayer,
    region: Rect2i,
    count: int,
    min_width: int = 3,
    max_width: int = 8,
    terrain_set: int = 0,
    terrain_id: int = 0
) -> Array[Rect2i]:
    var placed: Array[Rect2i] = []
    var attempts := 0
    var rng := RandomNumberGenerator.new()
    rng.randomize()

    while placed.size() < count and attempts < count * 10:
        attempts += 1
        var w := rng.randi_range(min_width, max_width)
        var x := rng.randi_range(region.position.x, region.end.x - w)
        var y := rng.randi_range(region.position.y + 2, region.end.y - 3)
        var platform := Rect2i(x, y, w, 1)

        # Check no overlap with existing platforms (minimum 2 tile gap)
        var valid := true
        for existing in placed:
            if platform.grow(2).intersects(existing.grow(2)):
                valid = false
                break
        if not valid:
            continue

        var cells: Array[Vector2i] = []
        for px in range(x, x + w):
            cells.append(Vector2i(px, y))
        layer.set_cells_terrain_connect(cells, terrain_set, terrain_id)
        placed.append(platform)

    return placed
```

---

## Navigation (Enemy Pathfinding)

### Setup in Scene

```
NavigationRegion2D
└── (bake the polygon to cover walkable terrain area)

Enemy
└── NavigationAgent2D
```

### Baking Navigation from Script

```gdscript
# Call after generating or modifying tilemap
func _rebake_navigation() -> void:
    var nav_region := $NavigationRegion2D as NavigationRegion2D
    # In editor: call bake_navigation_polygon()
    # At runtime: navigation is static unless you call:
    nav_region.bake_navigation_polygon()
    # Wait one frame before using paths
    await get_tree().process_frame
```

**Important:** TileMapLayer with navigation polygons painted in the TileSet will auto-contribute to NavigationRegion2D bake if the layer's `use_kinematic_bodies` is off and navigation polygon is enabled per tile.

---

## One-Way Platforms

```gdscript
# In TileSet: set collision layer to one-way (enable "one way" in TileData collision properties)
# In physics: player CharacterBody2D needs this in movement:

func _handle_drop_through() -> void:
    if Input.is_action_pressed("move_down") and Input.is_action_just_pressed("jump"):
        # Disable one-way collision for 0.3s
        $CollisionShape2D.disabled = true
        await get_tree().create_timer(0.3).timeout
        $CollisionShape2D.disabled = false
```

---

## Performance Tips

- **Chunk culling**: Set `TileMapLayer.enabled = false` for rooms the player can't reach (disable per-room via trigger)
- **Static bodies**: For large flat terrain sections (10+ tile rows), consider using a single `StaticBody2D` with a `CollisionPolygon2D` instead of per-tile physics
- **Occlusion**: Enable `TileMapLayer` occlusion only on Foreground layer, not Terrain (performance hit)
- **Cell batch updates**: Collect all `set_cell` calls into arrays, use `set_cells_terrain_connect` in one call vs. per-cell individual calls
- **Tile atlas size**: Keep single atlas source under 2048×2048 px for mobile targets; split into multiple sources if needed

---

## Tile Semantic Dictionary Pattern

**NEVER use raw atlas coordinates directly in generation code.** Always define a semantic dictionary and reference it by name. This prevents breakage when the tileset atlas is reorganized.

```gdscript
# Define once per project — update only this dict if atlas changes
const TILE := {
    # Ground / Terrain
    "GROUND_CENTER": Vector2i(1, 0),  # all 4 sides solid
    "GROUND_TOP":    Vector2i(2, 0),  # top exposed
    "GROUND_LEFT":   Vector2i(0, 0),  # left exposed
    "GROUND_RIGHT":  Vector2i(3, 0),  # right exposed

    # Corners (outer)
    "CORNER_TL": Vector2i(0, 1),
    "CORNER_TR": Vector2i(3, 1),
    "CORNER_BL": Vector2i(0, 2),
    "CORNER_BR": Vector2i(3, 2),

    # Inner (concave) corners
    "INNER_TL": Vector2i(1, 1),
    "INNER_TR": Vector2i(2, 1),

    # Slopes
    "SLOPE_LEFT":  Vector2i(4, 0),
    "SLOPE_RIGHT": Vector2i(5, 0),

    # One-way platform
    "ONEWAY": Vector2i(8, 1),

    # Hazards
    "SPIKE_UP":   Vector2i(7, 2),
    "SPIKE_DOWN": Vector2i(7, 3),

    # Decoration (no collision)
    "GRASS_A":    Vector2i(5, 3),
    "GRASS_B":    Vector2i(6, 3),
    "GRASS_C":    Vector2i(7, 3),
    "BACKROCK_A": Vector2i(2, 4),
    "BACKROCK_B": Vector2i(3, 4),
}
```

Usage: `layer.set_cell(Vector2i(x, y), ATLAS_ID, TILE["GROUND_TOP"])`

### Auto-Tiling Adjacency Lookup

When setting tiles procedurally (without `set_cells_terrain_connect`), select the correct key from adjacency:

```
Condition                          → TILE key
──────────────────────────────────────────────
All 4 sides solid                  → GROUND_CENTER
Top exposed only                   → GROUND_TOP
Left exposed only                  → GROUND_LEFT
Right exposed only                 → GROUND_RIGHT
Top + left exposed (outer corner)  → CORNER_TL
Top + right exposed (outer corner) → CORNER_TR
Concave top-left (inner corner)    → INNER_TL
Concave top-right (inner corner)   → INNER_TR
```

```gdscript
# Auto-tile a solid region after painting
func auto_tile_region(layer: TileMapLayer, cells: Array[Vector2i]) -> void:
    var solid := {}
    for c in cells:
        solid[c] = true

    for c in cells:
        var top   := solid.has(Vector2i(c.x,   c.y-1))
        var bot   := solid.has(Vector2i(c.x,   c.y+1))
        var left  := solid.has(Vector2i(c.x-1, c.y))
        var right := solid.has(Vector2i(c.x+1, c.y))

        var key: String
        if top and bot and left and right:
            key = "GROUND_CENTER"
        elif not top and bot and left and right:
            key = "GROUND_TOP"
        elif top and bot and not left and right:
            key = "GROUND_LEFT"
        elif top and bot and left and not right:
            key = "GROUND_RIGHT"
        elif not top and bot and not left and right:
            key = "CORNER_TL"
        elif not top and bot and left and not right:
            key = "CORNER_TR"
        else:
            key = "GROUND_CENTER"  # fallback

        layer.set_cell(c, 0, TILE[key])
```

> **Note:** If you use `set_cells_terrain_connect()` with a properly configured TileSet, Godot handles adjacency automatically. Use manual auto-tiling only when bypassing the terrain system (e.g., for procedural generators that need fine control).

---

## Fail-Safe: Auto-Repair Rules

When a generated segment fails jump validation (see `spatial-design.md`), apply the first matching repair:

| Failure | Auto-Repair |
|---|---|
| Gap > 5 tiles wide | Reduce gap by 1; insert stepping-stone platform at mid-gap, y = lower platform y − 1 |
| Height rise > 3 tiles | Insert intermediate staircase step at midpoint |
| Landing width < 2 | Extend target platform 2 tiles in direction of travel |
| Unavoidable hazard on critical path | Shift spike 1 tile inward; if still unavoidable, remove |
| Flat run > 8 tiles | Insert 1-tile height bump at midpoint |
| No line-of-sight to hazard | Add foreground gap or remove blocking tile 3 tiles before hazard |

**Always log auto-repairs** — include them in the Validation Report output.
