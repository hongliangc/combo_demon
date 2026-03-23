# Souls-Like & Metroidvania Platformer Patterns

## Core Philosophy

Souls-like level design is built on **controlled revelation**: the player discovers shortcuts, paths, and story by surviving the world — not by reading a map. Every shortcut is earned. Every death teaches.

---

## The Loop Principle

Every major area should form a **closed loop** back to a safe point (bonfire/checkpoint) with a shortcut that dramatically reduces travel time on repeat visits.

### Loop Structure

```
[Bonfire A] ──►──►──► [Mid Zone] ──►──►──► [Bonfire B]
     ▲                    │
     │                    ▼
     └────── [SHORTCUT: Ladder/Lever/Gate] ───────────┘
               (opened after clearing Mid Zone or Boss)
```

**Design rule:** The shortcut must:
1. Be **visible** from the main path but **unreachable** until triggered
2. Open toward the safe point (player always collapses inward to safety)
3. Save at least 60% of travel time
4. Never skip a mandatory story beat

---

## Shortcut Types

| Type | Trigger Condition | Visual Tell |
|---|---|---|
| **Drop Ladder** | Lever pulled after room clear | Ladder visible but retracted |
| **One-Way Fog Gate** | Boss defeated | Door crackling with energy |
| **Unlockable Door** | Key found in area | Locked door, key icon visible |
| **Collapse Bridge** | Player crosses once, can't return | Crumbling edge, different tile |
| **Elevator** | Mechanism activated on first pass | Elevator car visible at bottom |
| **Hidden Wall** | Item pickup reveals | Subtle crack/discoloration on wall |

---

## Vertical Level Design (Elevator/Tower Style)

### Floor Mapping

```
Floor 4 (Top): Boss Chamber         ← first time: long trek
Floor 3: Mid Checkpoint             ← shortcut elevator opens after boss
Floor 2: Main Combat Zone
Floor 1: Entry / Bonfire            ← starting safe point
```

### Vertical Loop Implementation

```gdscript
# ElevatorShortcut.gd
class_name ElevatorShortcut
extends Node2D

@export var destination_marker: NodePath
@export var unlock_flag: String = ""
@export var is_locked: bool = true

@onready var interaction_zone: Area2D = $InteractionZone
@onready var locked_visual: Node2D = $LockedVisual
@onready var unlocked_visual: Node2D = $UnlockedVisual

func _ready() -> void:
    if unlock_flag != "" and GameState.get_flag(unlock_flag):
        unlock()
    else:
        _update_visual(is_locked)

func unlock() -> void:
    is_locked = false
    _update_visual(false)
    GameState.set_flag(unlock_flag + "_shortcut_open", true)
    _play_unlock_effect()

func _update_visual(locked: bool) -> void:
    locked_visual.visible = locked
    unlocked_visual.visible = not locked

func use_elevator(player: Node2D) -> void:
    if is_locked:
        # Show "locked" feedback
        player.show_hint("Something seems to be blocking the mechanism...")
        return
    var dest: Node2D = get_node(destination_marker)
    player.teleport_to(dest.global_position)
    # Optional: fade transition
    TransitionManager.fade_and_move(player, dest.global_position)
```

---

## Metroidvania Ability Gates

### Ability Gate System

Sections of the level that require specific player abilities to access:

| Gate Type | Required Ability | Visual Language |
|---|---|---|
| High ledge (+8 tiles) | Double jump | Clearly too high to reach |
| Narrow vertical shaft | Wall jump | Tight shaft, wall marks |
| Blocked path | Dash | Pressure plate or timed door |
| Hidden wall | Ground slam | Floor with crack pattern |
| Underwater section | Swim / breath upgrade | Water barrier |

### Gate Foreshadowing Rule

**Always show the reward BEFORE teaching the ability:**
1. Player sees inaccessible chest/door in early area
2. Player acquires ability in mid-area
3. Player backtracks voluntarily to claim reward

This creates intrinsic motivation and makes backtracking feel triumphant.

```gdscript
# AbilityGate.gd
class_name AbilityGate
extends Node2D

@export var required_ability: String = "double_jump"
@export var locked_hint: String = "The ledge is too high to reach..."

@onready var blocker: Node2D = $Blocker  # visual/collision block

func _ready() -> void:
    if PlayerData.has_ability(required_ability):
        _unlock_silently()

func _unlock_silently() -> void:
    blocker.queue_free()

func show_locked_feedback(player: Node2D) -> void:
    player.show_hint(locked_hint)
```

---

## Death & Respawn Design

### Echo / Bloodstain Pattern (Souls-like)

Player drops a "soul echo" or "death mark" at their death location. Retrieving it restores lost progress.

```gdscript
# DeathEcho.gd
class_name DeathEcho
extends Area2D

@export var souls_value: int = 0
@export var death_position: Vector2

func _ready() -> void:
    global_position = death_position
    # Auto-destroy after time limit (optional)
    get_tree().create_timer(300.0).timeout.connect(queue_free)

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        body.recover_souls(souls_value)
        # Play recover effect
        $RecoverEffect.emitting = true
        await $RecoverEffect.finished
        queue_free()
```

### Respawn at Checkpoint Without Reset

On death:
1. Player respawns at last activated checkpoint
2. All enemies respawn (standard souls behavior)
3. World state (opened doors, pulled levers) PERSISTS
4. Death echo spawns at death location

```gdscript
# GameState.gd (relevant excerpt)
func respawn_player() -> void:
    var cp_data = get_current_checkpoint()
    player.global_position = cp_data.position
    player.restore_base_stats()
    # Respawn enemies
    get_tree().call_group("encounter_rooms", "reset_enemies")
    # Spawn death echo at last death location
    if last_death_position != Vector2.ZERO:
        _spawn_death_echo(last_death_position, lost_souls)
```

---

## Interconnected World Design

### Zone Connection Map

Use a **connection graph** to plan zone links before building:

```
[Zone 01: Ruins Entry]
      │  
      ├──► [Zone 02: Flooded Crypt]  (locked by: Rusty Key)
      │         │
      │         └──► [Zone 04: Underground Lake]  (ability gate: swim)
      │
      └──► [Zone 03: Rampart]  (open from start)
                │
                └──► [Zone 05: Bell Tower]  (shortcut elevator after boss)
                          │
                          └──► [Zone 06: Boss: The Bell Warden]
```

**Rule:** Every zone must have at least 2 connections (in + out/shortcut). Dead-end zones are only valid as boss chambers.

---

## Pacing for Souls-Like Levels

Unlike linear platformers, souls-like areas use **density variation** over a longer span:

```
[Entry: Sparse]  →  [Patrol Zone: Medium]  →  [Ambush: High]  →
→  [Checkpoint: None]  →  [Elite Room: Extreme]  →  [Boss Ante: Sparse dread]  →
→  [Boss Chamber]  →  [Post-Boss: Empty + Reward]  →  [Shortcut Home]
```

Key difference from standard platformer: **the checkpoint is NOT after the hardest part**. It's before, so the journey TO the boss is part of the challenge.
