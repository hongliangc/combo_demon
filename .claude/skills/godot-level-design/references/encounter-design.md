# Encounter Design Reference

## Core Philosophy

Every encounter should answer three questions:
1. **What does the player learn here?**
2. **What resource does the player spend?**
3. **What does the player gain?**

If an encounter doesn't answer all three, redesign it.

---

## Enemy Role Taxonomy

| Role | Behavior | Placement | Counter |
|---|---|---|---|
| **Grunt** | Patrol, melee range | Ground floor, predictable | Direct attack or bait |
| **Sentinel** | Stationary guard | Doorways, ledge edges | Requires approach angle |
| **Archer** | Ranged projectile | Elevated platforms | Dash or shield approach |
| **Rusher** | Fast charge, low HP | Corridors, ambush spots | Sidestep or parry window |
| **Tank** | High HP, slow, AoE | Room centers, boss rooms | Stamina/positioning game |
| **Tracker** | Follows player | Open arenas | Kite mechanics |
| **Support** | Buffs nearby enemies | Behind grunts | Priority kill target |
| **Ambusher** | Hides, triggers on player | Ceilings, blind corners | Sound cue telegraphs |

---

## Introduction Rules

### The Solo Introduction Rule
**Every new enemy type MUST appear alone on its first encounter.**
- Room before introduction: empty or known enemies only
- Introduction room: 1× new enemy, simple terrain, no hazards
- Combination room: new enemy + 1 known enemy type

Example sequence for introducing the Archer:
```
Room A: 2× Grunt (player already knows)
Room B: 1× Archer (solo introduction, flat ground for easy dodge)
Room C: 1× Archer + 2× Grunt (combination, archer on ledge)
Room D: 2× Archer + 1× Tank (advanced combination)
```

---

## Encounter Pattern Library

### Pattern 1 — The Gauntlet
```
[Entry] ──► [Grunt×2] ──► [Narrow corridor] ──► [Archer on ledge] ──► [Exit]
```
- Teach: ranged + melee split focus
- Spend: health or dash charge
- Gain: shortcut ladder or key item

### Pattern 2 — The Ambush Alcove
```
[Wide open room] ──► [Player crosses midpoint] ──► [Ambushers drop from ceiling×3]
                                                    [Exit gate locked until clear]
```
- Teach: room awareness, check ceilings
- Spend: panic resource (health burst)
- Gain: gate opens, chest appears

### Pattern 3 — The Sniper Gallery
```
[Ground path with cover objects]
[Archer×3 on upper ledge, staggered positions]
[Player must advance using cover, find stairs to ledge]
```
- Teach: cover usage, elevation change
- Spend: patience + positioning
- Gain: upper tier unlocked, faster route forward

### Pattern 4 — The Reverse Ambush (Player Has Advantage)
```
[Player sees enemies below from elevated approach]
[Drop attack or ranged initiation available]
[Enemies unaware]
```
- Teach: combat initiation options
- Spend: nothing if played well (reward exploration)
- Gain: resource bonus for clean clear

### Pattern 5 — The Escort Pressure
```
[Moving platform carrying player]
[Enemies spawn from walls during transit]
[Platform speed increases]
```
- Teach: positional combat, prioritization
- Spend: heavy health risk
- Gain: access to area otherwise unreachable

### Pattern 6 — The Elite Duel
```
[Dead-end room]
[1× Elite enemy (mini-boss tier)]
[Optional: pressure hazard activates at 50% HP]
[Shortcut opens on kill]
```
- Teach: patience, pattern reading
- Spend: most resources in level
- Gain: major shortcut, unique item, story beat

---

## Hazard Design

### Hazard Types

| Hazard | Activation | Design Rule |
|---|---|---|
| Spike pit | Always active | Must be visible before ledge |
| Swinging blade | Timed | Show full cycle before player reaches |
| Arrow trap | Pressure plate or timed | Telegraph with scratch marks or skull decal |
| Crumbling platform | On step | Color/crack distinction required |
| Fire jet | Timed | Particle preview before burst |
| Falling ceiling | Triggered | Shadow/rumble cue 1 second before |

### Hazard + Enemy Combinations (use sparingly)

| Combination | Difficulty Rating | Notes |
|---|---|---|
| Spike pit + Rusher | ★★★ | Fair if pit is visible |
| Arrow trap + Grunt | ★★ | Easy if timing readable |
| Swinging blade + Archer | ★★★★ | Only mid-late game |
| Crumbling platform + anything | ★★★★★ | Late game only |

**Never place an instant-kill hazard + enemy combination on the main path without a visible bypass.**

---

## GDScript: Encounter Trigger System

```gdscript
# EncounterRoom.gd
class_name EncounterRoom
extends Node2D

@export var encounter_id: String
@export var spawn_on_enter: bool = true
@export var lock_exit_until_clear: bool = false
@export var shortcut_node: NodePath = ""

@onready var trigger_zone: Area2D = $TriggerZone
@onready var enemy_spawner: Node2D = $EnemySpawner
@onready var exit_gate: Node = get_node_or_null($ExitGate)

var _encounter_started := false
var _enemies_alive: int = 0

func _ready() -> void:
    trigger_zone.body_entered.connect(_on_player_entered)

func _on_player_entered(body: Node2D) -> void:
    if not body.is_in_group("player") or _encounter_started:
        return
    _encounter_started = true
    _spawn_enemies()
    if lock_exit_until_clear and exit_gate:
        exit_gate.close()

func _spawn_enemies() -> void:
    for child in enemy_spawner.get_children():
        if child.has_method("activate"):
            child.activate()
            _enemies_alive += 1
            child.tree_exited.connect(_on_enemy_died)

func _on_enemy_died() -> void:
    _enemies_alive -= 1
    if _enemies_alive <= 0:
        _on_encounter_cleared()

func _on_encounter_cleared() -> void:
    if lock_exit_until_clear and exit_gate:
        exit_gate.open()
    if shortcut_node != "":
        get_node(shortcut_node).unlock()
    GameState.set_flag(encounter_id + "_cleared", true)
    # Spawn reward
    $RewardSpawner.spawn_if_present()
```

---

## Difficulty Scaling

### Per-Playthrough Modifiers

```gdscript
# Applied to enemy stats at spawn
func _apply_difficulty(enemy: Node, level_modifier: float) -> void:
    var global_diff = GameState.difficulty_modifier  # 0.5 / 1.0 / 1.5 / 2.0
    var combined = level_modifier * global_diff
    enemy.max_health = int(enemy.max_health * combined)
    enemy.damage_output = enemy.damage_output * combined
    enemy.move_speed = enemy.move_speed * clampf(combined, 0.8, 1.3)  # cap speed scaling
```

### New Game+ Enemy Mutations
- NG+1: +25% HP, add 1 projectile to ranged enemies
- NG+2: +50% HP, enemies have 1 additional attack pattern
- NG+3: full elite variants, tracking projectiles, stagger resistance

---

## Reward Placement Rules

1. **High-risk room** → mandatory health drop on kill
2. **Dead-end exploration** → unique cosmetic or ability upgrade shard
3. **Elite duel** → guaranteed equipment or major shortcut
4. **Secret discovery** → lore item + hidden checkpoint
5. **No-damage clear bonus** → visible bonus item (soul gem, echo shard) only if run tracker active

Never place the best reward where the player will find it on the critical path without effort.
