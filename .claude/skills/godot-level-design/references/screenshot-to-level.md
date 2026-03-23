# Screenshot-to-Level Reference

## Overview

This module converts a level screenshot (or reference image) into a runnable Godot 4 scene using the project's **existing assets**. The output is production-ready GDScript + a `.tscn`-compatible scene structure.

---

## Full Pipeline

```
[Screenshot]
     │
     ▼
Step 1: VISUAL ANALYSIS         — Decompose image into zones, tiles, entities
     │
     ▼
Step 2: ASSET INVENTORY         — Scan project to find matching resources
     │
     ▼
Step 3: COORDINATE MAPPING      — Map pixel regions → tile coords
     │
     ▼
Step 4: GENERATION              — Emit GDScript + scene tree
     │
     ▼
Step 5: VALIDATION              — Check playability, collision coverage, nav
```

---

## Step 1 — Visual Analysis

When a screenshot is provided, analyze it in this exact order:

### 1a. Grid Detection

First establish the tile size. Look for:
- Repeating grid patterns in the terrain
- UI grid overlay if visible
- Known tile sizes: **16px**, **32px**, **48px**, **64px**

State the detected (or assumed) tile size explicitly:
```
Detected tile size: 32×32 px
Level dimensions: ~40 tiles wide × 18 tiles tall
```

If tile size is ambiguous, ask the user before proceeding.

### 1b. Layer Decomposition

Identify which visual elements belong to which TileMapLayer:

| Visual Element | Layer Assignment |
|---|---|
| Sky, clouds, distant mountains | `TileMapLayer_Background` |
| Mid-distance props, ruins | `TileMapLayer_Backdrop` |
| Walkable ground, walls, platforms | `TileMapLayer_Terrain` ← physics |
| Small props, flowers, cracks | `TileMapLayer_Details` |
| Columns, arches in front of player | `TileMapLayer_Foreground` |

### 1c. Entity Identification

Catalog all non-tile objects visible in the screenshot:

```
TERRAIN TILES:
  - Ground tiles: [describe pattern, color, style]
  - Wall tiles: [...]
  - Platform tiles: [...]
  - Decorative tiles: [...]

ENTITIES:
  - Player spawn: [position estimate]
  - Enemies: [type + position for each]
  - Checkpoints / bonfires: [position]
  - Chests / collectibles: [position]
  - Hazards: [type + position]
  - Doors / exits: [position]

STRUCTURAL:
  - One-way platforms: [positions]
  - Ladders / ropes: [positions]
  - Moving platforms: [positions + direction]
```

### 1d. ASCII Grid Reconstruction

Produce a full ASCII map of the detected layout before any code:

```
Tile size: 32px | Grid: 40×18 | Origin: top-left

     0         1         2         3
     0123456789012345678901234567890123456789
Y00: ########################################
Y01: #......................................#
Y02: #....P.................................#
Y03: #.......E.....###......................#
Y04: ###########....###.....................#
Y05: ..........#..E..#...C.................#
Y06: ..........######.....##########.......#
Y07: ....................................K..#
Y08: .......^^^^^............................
...

Legend: # terrain  . empty  P player-spawn  E enemy
        C chest    K checkpoint  ^ spike  ~ water
        = one-way platform  | ladder
```

---

## Step 2 — Asset Inventory

### 2a. Scan Project Assets

Ask the user to provide their asset paths, OR scan the project if file access is available:

```python
# Run this in the project root to inventory assets
import os, json

def scan_assets(root: str) -> dict:
    assets = {"tilesets": [], "scenes": [], "textures": [], "scripts": []}
    for dirpath, _, files in os.walk(root):
        for f in files:
            rel = os.path.relpath(os.path.join(dirpath, f), root)
            if f.endswith(".tres") or f.endswith(".res"):
                assets["tilesets"].append(rel)
            elif f.endswith(".tscn"):
                assets["scenes"].append(rel)
            elif f.endswith((".png", ".webp", ".svg")):
                assets["textures"].append(rel)
            elif f.endswith(".gd"):
                assets["scripts"].append(rel)
    return assets

result = scan_assets(".")
print(json.dumps(result, indent=2))
```

### 2b. Asset Matching Protocol

Match each visual element to a project asset using this priority order:

1. **Exact name match** — filename contains the visual element's description
   - e.g., `stone_ground.png` → ground tiles
2. **Directory match** — file is in a directory matching the zone theme
   - e.g., `assets/tilesets/dungeon/` → dungeon level
3. **User confirmation** — if ambiguous, show options and ask
4. **Placeholder** — if no match found, use `res://` path placeholder with `# TODO` comment

### 2c. Asset Mapping Table

Produce this table before generating code. User must confirm before proceeding to Step 3:

```
ASSET MAPPING (confirm before code generation)
══════════════════════════════════════════════
Visual Element          → Project Asset Path
──────────────────────────────────────────────
Ground tile (stone)     → res://assets/tilesets/ruins/tileset_ruins.tres  [source_id=0, terrain_set=0, terrain=0]
Wall tile (brick)       → res://assets/tilesets/ruins/tileset_ruins.tres  [source_id=0, terrain_set=1, terrain=0]
One-way platform        → res://assets/tilesets/ruins/tileset_ruins.tres  [source_id=0, atlas=(3,0)]
Enemy - Skeleton        → res://scenes/enemies/Skeleton.tscn
Enemy - Archer          → res://scenes/enemies/Archer.tscn
Checkpoint / Bonfire    → res://scenes/interactables/Checkpoint.tscn
Chest                   → res://scenes/interactables/Chest.tscn
Spike hazard            → res://scenes/hazards/SpikePit.tscn
Player spawn            → res://scenes/player/PlayerSpawnMarker.tscn
──────────────────────────────────────────────
⚠ Unmatched: Moving platform → NO ASSET FOUND (will use placeholder)
```

---

## Step 3 — Coordinate Mapping

### Pixel to Tile Conversion

```python
def pixel_to_tile(px: int, py: int, tile_size: int, origin_x: int = 0, origin_y: int = 0) -> tuple:
    """Convert screenshot pixel position to tile coordinates."""
    tile_x = (px - origin_x) // tile_size
    tile_y = (py - origin_y) // tile_size
    return (tile_x, tile_y)

def tile_to_godot_world(tx: int, ty: int, tile_size: int) -> tuple:
    """Convert tile coordinates to Godot world position (center of tile)."""
    world_x = tx * tile_size + tile_size // 2
    world_y = ty * tile_size + tile_size // 2
    return (world_x, world_y)
```

### Terrain Region Extraction

Group contiguous terrain tiles into rectangular regions for efficient `set_cells_terrain_connect` calls:

```python
def extract_terrain_regions(ascii_grid: list[str], tile_char: str) -> list[tuple]:
    """
    Returns list of (x, y, width, height) rects of contiguous tile_char regions.
    Uses greedy horizontal-first grouping.
    """
    grid = [list(row) for row in ascii_grid]
    regions = []
    for y, row in enumerate(grid):
        x = 0
        while x < len(row):
            if row[y][x] == tile_char:
                # Find width of run
                w = 0
                while x + w < len(row) and row[y][x + w] == tile_char:
                    w += 1
                regions.append((x, y, w, 1))
                # Mark as consumed
                for i in range(w):
                    grid[y][x + i] = ' '
                x += w
            else:
                x += 1
    return regions
```

---

## Step 4 — Code Generation

### 4a. Scene Tree Output Format

Always emit the scene tree as a comment header before the GDScript:

```gdscript
# ═══════════════════════════════════════════════════
# GENERATED SCENE: Level_Z01_E01_Screenshot.tscn
# Source: [screenshot filename or description]
# Tile size: 32px | Grid: 40×18
# Generated by: godot-level-design skill (screenshot-to-level)
# ═══════════════════════════════════════════════════
#
# SCENE TREE:
# Level_Z01_E01_Screenshot (Node2D) ← LevelController.gd
# ├── World (Node2D)
# │   ├── TileMapLayer_Background
# │   ├── TileMapLayer_Terrain  ← physics, navigation
# │   └── TileMapLayer_Details
# ├── Encounters (Node2D)
# │   └── Room_E01 (Node2D)
# ├── Interactables (Node2D)
# │   ├── Checkpoint_01
# │   └── Chest_01
# ├── Hazards (Node2D)
# └── Camera (Camera2D)
```

### 4b. Level Generator Script

```gdscript
# LevelFromScreenshot_Z01_E01.gd
# Run this script once as an EditorScript to build the level scene,
# OR call build_level() from LevelController._ready() at runtime.

@tool
extends EditorScript  # Change to 'Node' for runtime use

const TILE_SIZE := 32
const TILESET_PATH := "res://assets/tilesets/ruins/tileset_ruins.tres"
const TERRAIN_SET_GROUND := 0
const TERRAIN_ID_STONE := 0
const TERRAIN_ID_DIRT := 1

# ── Asset paths (edit these to match your project) ──────────────────
const ENEMY_SKELETON := "res://scenes/enemies/Skeleton.tscn"
const ENEMY_ARCHER   := "res://scenes/enemies/Archer.tscn"
const CHECKPOINT     := "res://scenes/interactables/Checkpoint.tscn"
const CHEST          := "res://scenes/interactables/Chest.tscn"
const SPIKE_PIT      := "res://scenes/hazards/SpikePit.tscn"

func _run() -> void:  # Called by EditorScript. Use _ready() for runtime.
    build_level()

func build_level() -> void:
    # ── Get or create TileMapLayer nodes ────────────────────────────
    var terrain_layer := _get_or_create_layer("TileMapLayer_Terrain")
    var detail_layer  := _get_or_create_layer("TileMapLayer_Details")

    var tileset := load(TILESET_PATH) as TileSet
    terrain_layer.tile_set = tileset
    detail_layer.tile_set  = tileset

    # ── Paint terrain from screenshot analysis ───────────────────────
    _paint_ground(terrain_layer)
    _paint_platforms(terrain_layer)
    _paint_details(detail_layer)

    # ── Spawn entities ───────────────────────────────────────────────
    _spawn_entities()

    print("[LevelBuilder] Level built successfully.")

# ── Terrain painting ─────────────────────────────────────────────────

func _paint_ground(layer: TileMapLayer) -> void:
    # Ground floor rows — extracted from screenshot analysis
    # Each entry: [x_start, y, width]
    var ground_segments := [
        [0, 17, 40],   # Bottom floor, full width
        [0, 16, 10],   # Left wall base
        [30, 16, 10],  # Right wall base
        # ... add all segments from ASCII map
    ]
    for seg in ground_segments:
        var cells: Array[Vector2i] = []
        for x in range(seg[0], seg[0] + seg[2]):
            cells.append(Vector2i(x, seg[1]))
        layer.set_cells_terrain_connect(cells, TERRAIN_SET_GROUND, TERRAIN_ID_STONE)

func _paint_platforms(layer: TileMapLayer) -> void:
    # One-way platforms — use specific atlas tile, not terrain connect
    var platforms := [
        # [x, y, width, atlas_col, atlas_row]
        [5, 12, 5, 3, 0],
        [15, 10, 4, 3, 0],
        [25, 8, 6, 3, 0],
    ]
    for p in platforms:
        for x in range(p[0], p[0] + p[2]):
            layer.set_cell(Vector2i(x, p[1]), 0, Vector2i(p[3], p[4]))

func _paint_details(layer: TileMapLayer) -> void:
    # Decorative tiles (no physics) — use atlas coords directly
    var details := [
        # [x, y, atlas_col, atlas_row]
        [3, 16, 5, 2],   # Crack decal
        [10, 16, 6, 2],  # Moss
    ]
    for d in details:
        layer.set_cell(Vector2i(d[0], d[1]), 0, Vector2i(d[2], d[3]))

# ── Entity spawning ───────────────────────────────────────────────────

func _spawn_entities() -> void:
    # Player spawn
    _place_marker("PlayerSpawn", Vector2(5, 15) * TILE_SIZE)

    # Enemies — positions from screenshot analysis
    _spawn_scene(ENEMY_SKELETON, Vector2(12, 16), "Skeleton_01")
    _spawn_scene(ENEMY_SKELETON, Vector2(20, 16), "Skeleton_02")
    _spawn_scene(ENEMY_ARCHER,   Vector2(30, 10), "Archer_01")  # On platform

    # Interactables
    _spawn_scene(CHECKPOINT, Vector2(35, 15), "Checkpoint_01")
    _spawn_scene(CHEST,      Vector2(30, 9),  "Chest_Hidden_01")  # On upper platform

    # Hazards
    _spawn_scene(SPIKE_PIT, Vector2(22, 17), "SpikePit_01")

func _spawn_scene(path: String, tile_pos: Vector2, node_name: String) -> Node2D:
    if not ResourceLoader.exists(path):
        push_warning("[LevelBuilder] Asset not found: %s — skipping %s" % [path, node_name])
        return null
    var scene := load(path) as PackedScene
    var instance := scene.instantiate() as Node2D
    instance.name = node_name
    instance.position = tile_pos * TILE_SIZE
    # Find correct parent group
    var parent_name := _get_parent_for_scene(path)
    var parent := get_tree().get_root().find_child(parent_name, true, false)
    if parent:
        parent.add_child(instance)
        instance.owner = get_tree().get_edited_scene_root()
    else:
        push_warning("[LevelBuilder] Parent node '%s' not found" % parent_name)
    return instance

func _get_parent_for_scene(path: String) -> String:
    if "enemies" in path:    return "Encounters"
    if "hazards" in path:    return "Hazards"
    if "interactables" in path: return "Interactables"
    return "World"

func _get_or_create_layer(layer_name: String) -> TileMapLayer:
    var root := get_scene()
    var world := root.find_child("World", false, false)
    if not world:
        world = Node2D.new()
        world.name = "World"
        root.add_child(world)
        world.owner = root
    var layer := world.find_child(layer_name, false, false) as TileMapLayer
    if not layer:
        layer = TileMapLayer.new()
        layer.name = layer_name
        world.add_child(layer)
        layer.owner = root
    return layer

func _place_marker(marker_name: String, world_pos: Vector2) -> void:
    var m := Marker2D.new()
    m.name = marker_name
    m.position = world_pos
    var root := get_scene()
    root.add_child(m)
    m.owner = root
```

### 4c. Runtime Loader Variant

For runtime level loading (not EditorScript), use this pattern:

```gdscript
# RuntimeLevelLoader.gd
# Attach to level root. Call load_from_data(level_data) after _ready().
extends Node2D

func load_from_data(data: Dictionary) -> void:
    # data format:
    # {
    #   "tile_size": 32,
    #   "tileset": "res://...",
    #   "terrain_set": 0,
    #   "ground": [[x, y, w], ...],
    #   "platforms": [[x, y, w, atlas_col, atlas_row], ...],
    #   "entities": [{"type": "Skeleton", "tile_x": 12, "tile_y": 16}, ...]
    # }

    var ts := int(data.get("tile_size", 32))
    var tileset := load(data["tileset"]) as TileSet
    var terrain_layer := $World/TileMapLayer_Terrain as TileMapLayer
    terrain_layer.tile_set = tileset

    # Paint ground
    for seg in data.get("ground", []):
        var cells: Array[Vector2i] = []
        for x in range(seg[0], seg[0] + seg[2]):
            cells.append(Vector2i(x, seg[1]))
        terrain_layer.set_cells_terrain_connect(
            cells, data.get("terrain_set", 0), data.get("terrain_id", 0))

    # Spawn entities
    for entity in data.get("entities", []):
        _spawn_entity(entity, ts)

func _spawn_entity(entity: Dictionary, tile_size: int) -> void:
    var ENTITY_PATHS := {
        "Skeleton":   "res://scenes/enemies/Skeleton.tscn",
        "Archer":     "res://scenes/enemies/Archer.tscn",
        "Checkpoint": "res://scenes/interactables/Checkpoint.tscn",
        "Chest":      "res://scenes/interactables/Chest.tscn",
        "SpikePit":   "res://scenes/hazards/SpikePit.tscn",
    }
    var type: String = entity.get("type", "")
    var path: String = ENTITY_PATHS.get(type, "")
    if path.is_empty() or not ResourceLoader.exists(path):
        push_warning("Unknown or missing entity type: %s" % type)
        return
    var instance := (load(path) as PackedScene).instantiate() as Node2D
    instance.position = Vector2(entity["tile_x"], entity["tile_y"]) * tile_size
    add_child(instance)
```

---

## Step 5 — Validation Checklist

After generating code, verify:

```
PLAYABILITY
  [ ] Player spawn exists and is on solid ground
  [ ] All platforms are reachable from spawn with current abilities
  [ ] No terrain regions completely enclose a solid area the player can't reach
  [ ] All exits are reachable

COLLISION
  [ ] TileMapLayer_Terrain has collision layer set in TileSet physics
  [ ] One-way platforms use one-way collision (not full body)
  [ ] Hazard areas are Area2D, not StaticBody2D

NAVIGATION
  [ ] NavigationRegion2D bake covers all ground enemy patrol areas
  [ ] Flying/ranged enemies don't require NavAgent (use direct pathfinding)

ASSETS
  [ ] All asset paths exist (no missing resource warnings in editor)
  [ ] TileSet source_id = 0 assumption is correct for this project
  [ ] Terrain set/terrain ID indices match the actual TileSet configuration
  [ ] Any "# TODO" placeholders are flagged to user

CAMERA
  [ ] Camera limits set to level bounds
  [ ] No unreachable area visible outside bounds
```

---

## Handling Ambiguous Screenshots

| Ambiguity | Resolution |
|---|---|
| Tile size unclear | Ask user: "Is your tile size 16, 32, or 48 pixels?" |
| Asset not found | Emit `# TODO: replace with actual asset path` comment |
| Entity type unclear | Describe what you see, ask which enemy scene to use |
| Parallax layers unclear | Default to single background layer, note ambiguity |
| Screenshot is partial | Generate what's visible, add `# TODO: extend level` markers |
| Screenshot has UI overlay | Ignore UI elements, focus on world geometry |
| Rotation/mirror unclear | Use default orientation, add comment |

---

## Example Output Summary Format

When delivering the final output, structure it as:

```
## Level Analysis: [screenshot description]

**Detected:** Tile size 32px | 40×18 grid | ~3 layers

**Asset Mapping:** [table — confirmed or flagged]

**ASCII Layout:**
[full grid]

**Generated Files:**
1. `LevelFromScreenshot_Z01_E01.gd` — EditorScript builder
2. `level_data_z01_e01.json` — Runtime data (optional)

**Known Gaps / TODOs:**
- Moving platform at (X=20, Y=8): no matching asset found
- Decorative tile at (X=5, Y=3): atlas coords unconfirmed

**Next Steps:**
1. Confirm asset mapping table above
2. Run `LevelFromScreenshot_Z01_E01.gd` as EditorScript in Godot
3. Rebake NavigationRegion2D
4. Set Camera2D limits to match level bounds
```
