# Screenshot-to-Level Reference

## Pipeline

```
[Screenshot] → Step 1: VISUAL ANALYSIS → Step 2: ASSET INVENTORY
            → Step 3: COORDINATE MAPPING → Step 4: GENERATION → Step 5: VALIDATION
```

---

## Step 1 — Visual Analysis

**1a. Grid Detection** — Detect tile size (16/32/48/64px). State explicitly before proceeding. If ambiguous, ask user.

**1b. Layer Decomposition**

| Visual Element | Layer |
|---|---|
| Sky, clouds, distant mountains | `TileMapLayer_Background` |
| Mid-distance props, ruins | `TileMapLayer_Backdrop` |
| Walkable ground, walls, platforms | `TileMapLayer_Terrain` (physics) |
| Small props, flowers, cracks | `TileMapLayer_Details` |
| Columns, arches in front of player | `TileMapLayer_Foreground` |

**1c. Entity Identification** — Catalog: ground/wall/platform tiles, player spawn, enemies (type+pos), checkpoints, chests, hazards, doors, one-way platforms, ladders, moving platforms.

**1d. ASCII Grid** — Produce full ASCII map before any code:
```
Tile size: 32px | Grid: 40×18 | Origin: top-left
     0123456789...
Y00: ########...
Legend: # terrain  . empty  P player-spawn  E enemy
        C chest  K checkpoint  ^ spike  = one-way  | ladder
```

---

## Step 2 — Asset Inventory

**2a. Scan** — Ask user for asset paths, or scan project for `.tres/.res`, `.tscn`, `.png/.webp`, `.gd` files.

**2b. Matching Priority**
1. Exact name match (filename contains visual description)
2. Directory match (dir matches zone theme)
3. User confirmation if ambiguous
4. Placeholder `res://` path with `# TODO` comment

**2c. Asset Mapping Table** — Confirm with user before Step 3:
```
Visual Element          → Project Asset Path                                    [params]
Ground tile (stone)     → res://assets/tilesets/ruins/tileset_ruins.tres       [source_id=0, terrain_set=0, terrain=0]
Wall tile (brick)       → res://assets/tilesets/ruins/tileset_ruins.tres       [terrain_set=1, terrain=0]
One-way platform        → res://assets/tilesets/ruins/tileset_ruins.tres       [atlas=(3,0)]
Enemy - Skeleton        → res://scenes/enemies/Skeleton.tscn
Checkpoint              → res://scenes/interactables/Checkpoint.tscn
⚠ Moving platform       → NO ASSET FOUND (placeholder)
```

---

## Step 3 — Coordinate Mapping

Key formulas:
- `tile_x = (px - origin_x) // tile_size` , `tile_y = (py - origin_y) // tile_size`
- `world_x = tile_x * tile_size + tile_size // 2` (center of tile)

Group contiguous terrain into rectangular segments `[x, y, width]` for `set_cells_terrain_connect` calls.

---

## Step 4 — Code Generation

**4a. Scene Tree Header** — Always emit as comment before GDScript:
```gdscript
# GENERATED SCENE: Level_Z01_E01_Screenshot.tscn
# Tile size: 32px | Grid: 40×18
# SCENE TREE:
# Level_Z01_E01 (Node2D) ← LevelController.gd
# ├── World/TileMapLayer_Background, _Terrain, _Details
# ├── Encounters/Room_E01
# ├── Interactables/Checkpoint_01, Chest_01
# ├── Hazards
# └── Camera (Camera2D)
```

**4b. Key API Patterns**

```gdscript
# Constants
const TILE_SIZE := 32
const TILESET_PATH := "res://assets/tilesets/ruins/tileset_ruins.tres"
const TERRAIN_SET_GROUND := 0

# Paint terrain (connect mode)
var cells: Array[Vector2i] = []
for x in range(x_start, x_start + width):
    cells.append(Vector2i(x, y))
layer.set_cells_terrain_connect(cells, TERRAIN_SET_GROUND, TERRAIN_ID_STONE)

# Paint one-way platform (direct atlas)
layer.set_cell(Vector2i(x, y), 0, Vector2i(atlas_col, atlas_row))

# Spawn entity
func _spawn_scene(path: String, tile_pos: Vector2, node_name: String) -> Node2D:
    if not ResourceLoader.exists(path): push_warning("Missing: %s" % path); return null
    var inst := (load(path) as PackedScene).instantiate() as Node2D
    inst.name = node_name
    inst.position = tile_pos * TILE_SIZE
    _get_parent_for(path).add_child(inst)
    return inst

# Route entity to correct parent
func _get_parent_for_scene(path: String) -> String:
    if "enemies" in path: return "Encounters"
    if "hazards" in path: return "Hazards"
    if "interactables" in path: return "Interactables"
    return "World"

# Get or create TileMapLayer
func _get_or_create_layer(name: String) -> TileMapLayer:
    var world := root.find_child("World", false, false)
    var layer := world.find_child(name, false, false) as TileMapLayer
    if not layer: layer = TileMapLayer.new(); layer.name = name; world.add_child(layer)
    return layer

# Runtime loader data format
# { "tile_size":32, "tileset":"res://...", "terrain_set":0,
#   "ground":[[x,y,w],...], "platforms":[[x,y,w,ac,ar],...],
#   "entities":[{"type":"Skeleton","tile_x":12,"tile_y":16},...] }
```

---

## Step 5 — Validation Checklist

```
PLAYABILITY
  [ ] Player spawn exists on solid ground
  [ ] All platforms reachable from spawn
  [ ] All exits reachable

COLLISION
  [ ] TileMapLayer_Terrain has collision layer set in TileSet physics
  [ ] One-way platforms use one-way collision
  [ ] Hazard areas are Area2D, not StaticBody2D

NAVIGATION
  [ ] NavigationRegion2D bake covers all ground enemy patrol areas

ASSETS
  [ ] All asset paths exist (no missing resource warnings)
  [ ] TileSet source_id=0, terrain_set/terrain IDs match actual config
  [ ] All # TODO placeholders flagged to user

CAMERA
  [ ] Camera limits set to level bounds
```

---

## Ambiguity Resolution

| Ambiguity | Resolution |
|---|---|
| Tile size unclear | Ask: "Is tile size 16, 32, or 48px?" |
| Asset not found | Emit `# TODO: replace with actual asset path` |
| Entity type unclear | Describe and ask which scene to use |
| Screenshot is partial | Generate visible area, add `# TODO: extend level` |
| UI overlay visible | Ignore UI, focus on world geometry |

---

## Output Format

```
## Level Analysis: [description]
**Detected:** Tile size 32px | 40×18 grid | ~3 layers
**Asset Mapping:** [confirmed table]
**ASCII Layout:** [full grid]
**Generated:** LevelFromScreenshot_Z01_E01.gd (EditorScript builder)
**TODOs:** [list unmatched/unconfirmed assets]
**Next Steps:** 1. Confirm asset mapping  2. Run EditorScript  3. Rebake NavigationRegion2D  4. Set Camera2D limits
```
