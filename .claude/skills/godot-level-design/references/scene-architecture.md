# Scene Architecture Reference

## Level Scene Naming Convention

```
Level_[ZoneID]_[AreaNum]_[AreaName].tscn

Examples:
  Level_Z01_E01_RuinsEntry.tscn
  Level_Z01_E02_FloodedCorridor.tscn
  Level_Z02_B01_BellTower.tscn
  Level_Z02_Boss_BellWarden.tscn
```

Zone IDs: Z01 = Zone 1, etc.
Area types: E = Encounter, B = Boss Approach, Boss = Boss Chamber, Hub = Hub/Safe

---

## Full Scene Tree Template

```
Level_Z01_E01_RuinsEntry.tscn
│
├── LevelRoot (Node2D)              ← attach LevelController.gd
│   @export level_id: String
│   @export next_level: String
│   @export ambient_track: AudioStream
│
├── World (Node2D)
│   ├── TileMapLayer_Background     z_index=-2, no physics
│   ├── TileMapLayer_Backdrop       z_index=-1, parallax scroll
│   ├── TileMapLayer_Terrain        z_index=0,  physics ON, navigation ON
│   ├── TileMapLayer_Details        z_index=1,  no physics (decorative tiles)
│   └── TileMapLayer_Foreground     z_index=3,  no physics, occlusion layer
│
├── Encounters (Node2D)
│   ├── Room_E01 (Node2D)           ← EncounterRoom.gd
│   │   ├── TriggerZone (Area2D)
│   │   ├── EnemySpawner (Node2D)
│   │   │   ├── Spawn_Grunt_01 (Marker2D)
│   │   │   └── Spawn_Archer_01 (Marker2D)
│   │   ├── ExitGate (AnimatableBody2D)   ← optional
│   │   └── RewardSpawner (Node2D)
│   └── Room_E02 (Node2D)
│
├── Interactables (Node2D)
│   ├── Checkpoint_01 (Area2D)      ← Checkpoint.gd
│   ├── Chest_01 (StaticBody2D)     ← Chest.gd
│   ├── Lever_Shortcut_01 (Area2D)  ← Lever.gd
│   └── NPC_Merchant_01 (CharacterBody2D)
│
├── Hazards (Node2D)
│   ├── SpikePit_01 (Area2D)
│   ├── SwingingBlade_01 (AnimatableBody2D)
│   └── FireJet_01 (Node2D)
│
├── Shortcuts (Node2D)
│   ├── Elevator_ToEntrance (Node2D)  ← ElevatorShortcut.gd
│   └── Door_Locked_01 (Node2D)       ← AbilityGate.gd
│
├── Navigation (Node2D)
│   └── NavigationRegion2D
│
├── Environment (Node2D)
│   ├── LightingController (Node2D)  ← LevelLighting.gd
│   ├── ParallaxBackground
│   │   ├── ParallaxLayer (bg_far)
│   │   └── ParallaxLayer (bg_mid)
│   ├── Particles_Ambient (CPUParticles2D)
│   └── AudioStreamPlayer2D (ambient)
│
└── Camera (Camera2D)
    ├── CameraZone_01 (Area2D)
    └── CameraZone_02 (Area2D)
```

---

## LevelController.gd

```gdscript
# LevelController.gd
class_name LevelController
extends Node2D

@export var level_id: String = ""
@export var next_level_path: String = ""
@export var ambient_track: AudioStream
@export var respawn_marker: NodePath = "Interactables/Checkpoint_01"
@export var camera_zoom_default: Vector2 = Vector2(2.0, 2.0)
@export var level_bounds: Rect2 = Rect2(0, 0, 1280, 720)

@onready var camera: Camera2D = $Camera
@onready var nav_region: NavigationRegion2D = $Navigation/NavigationRegion2D

func _ready() -> void:
    _setup_camera()
    _setup_audio()
    _restore_level_state()
    await get_tree().process_frame
    nav_region.bake_navigation_polygon()

func _setup_camera() -> void:
    camera.zoom = camera_zoom_default
    camera.limit_left   = int(level_bounds.position.x)
    camera.limit_top    = int(level_bounds.position.y) - 200
    camera.limit_right  = int(level_bounds.end.x)
    camera.limit_bottom = int(level_bounds.end.y) + 64

func _setup_audio() -> void:
    if ambient_track:
        AudioManager.play_ambient(ambient_track)

func _restore_level_state() -> void:
    # Re-open doors/shortcuts that were unlocked in a previous visit
    for shortcut in get_tree().get_nodes_in_group("shortcuts"):
        if GameState.get_flag(shortcut.unlock_flag + "_shortcut_open"):
            shortcut.unlock()

    # Remove already-cleared encounter rooms
    for room in get_tree().get_nodes_in_group("encounter_rooms"):
        if GameState.get_flag(room.encounter_id + "_cleared"):
            room.set_cleared_state()

func transition_to_next_level() -> void:
    if next_level_path != "":
        TransitionManager.load_level(next_level_path)
```

---

## Autoload / Singleton Dependencies

These singletons should exist in the project for the level scripts to work:

```gdscript
# GameState (Autoload: res://autoload/GameState.gd)
# Methods used:
#   GameState.get_flag(key: String) -> bool
#   GameState.set_flag(key: String, value: bool) -> void
#   GameState.save_checkpoint(id: String, pos: Vector2) -> void
#   GameState.get_current_checkpoint() -> Dictionary
#   GameState.difficulty_modifier -> float

# AudioManager (Autoload: res://autoload/AudioManager.gd)
# Methods used:
#   AudioManager.play_ambient(stream: AudioStream) -> void
#   AudioManager.play_sfx(stream: AudioStream, pos: Vector2) -> void

# TransitionManager (Autoload: res://autoload/TransitionManager.gd)
# Methods used:
#   TransitionManager.load_level(path: String) -> void
#   TransitionManager.fade_and_move(player: Node2D, target: Vector2) -> void

# PlayerData (Autoload: res://autoload/PlayerData.gd)
# Methods used:
#   PlayerData.has_ability(ability_name: String) -> bool
```

---

## Group Tags Reference

All nodes should use these group tags for system-wide queries:

| Group | Used By |
|---|---|
| `"player"` | All player CharacterBody2D nodes |
| `"enemy"` | All enemy nodes |
| `"encounter_rooms"` | All EncounterRoom nodes |
| `"checkpoints"` | All Checkpoint nodes |
| `"shortcuts"` | All shortcut nodes (elevator, gate, lever) |
| `"hazards"` | All hazard nodes |
| `"interactables"` | All player-interactable nodes |
| `"collectibles"` | All pickup/collectible nodes |

---

## Resource Files

### LevelData Resource (optional, for data-driven design)

```gdscript
# LevelData.gd
class_name LevelData
extends Resource

@export var level_id: String
@export var display_name: String
@export var zone_id: String
@export var difficulty: int = 1  # 1-5
@export var recommended_level: int = 1
@export var unlock_requirements: Array[String] = []
@export var connects_to: Array[String] = []  # level_ids
@export var thumbnail: Texture2D
```

Store as `.tres` files: `res://data/levels/z01_e01.tres`

This enables the world map and fast-travel system to be fully data-driven.
