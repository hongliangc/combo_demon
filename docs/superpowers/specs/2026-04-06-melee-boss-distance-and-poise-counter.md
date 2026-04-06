# Melee Boss Distance Model & Poise Counter System

## Summary

Two related improvements to the Boss combat framework:

1. **Melee distance model**: Remove `min_distance → retreat` logic for melee bosses. Melee bosses use a two-segment model: `[0, attack_range] → attack`, `[attack_range, detection_radius] → chase`.
2. **Poise counter system**: Bosses can have a poise (韧性) value. Continuous player attacks deplete poise; when poise reaches zero, the boss performs a stagger + counter-attack sequence.

## Design

### 1. Melee Distance Model

**Problem**: `evaluate_combat_transition()` in `BossBaseState` treats all bosses identically with a three-segment distance model: `[0, min_distance] → retreat`, `[min_distance, attack_range] → attack`, `[attack_range, detection] → chase`. For melee bosses like BladeKeeper, the retreat zone is nonsensical — they should stay close and attack.

**Solution**: Add `is_melee` flag to `BossBase`. When `is_melee == true`, `evaluate_combat_transition` skips the `min_distance` check entirely.

**Changes**:

- `BossBase.gd`: Add `@export var is_melee := false` in Detection group
- `BossBaseState.gd`: In `evaluate_combat_transition()`, wrap the `min_distance` block with `if not _boss.is_melee:`
- `BladeKeeper.gd`: Set `is_melee = true` in `_on_boss_ready()`, remove `min_distance = 100` assignment

**Resulting behavior for melee bosses**:
```
[0, attack_range]          → attack (if cooldown ready) / circle / chase
[attack_range, detection]  → chase
[> detection]              → patrol / idle
```

### 2. Poise Counter System

#### 2.1 Data Layer (BossBase.gd)

New exports in a "Poise / Counter" group:

```
@export var poise_enabled := false
@export var max_poise := 5
@export var poise_per_phase: Dictionary = {}   # e.g. {Phase.PHASE_2: 4, Phase.PHASE_3: 3}
@export var poise_immunity_time := 1.5
```

Runtime vars:

```
var current_poise: int = 0
var poise_immunity: float = 0.0
```

Lifecycle:
- `_on_boss_ready()`: `current_poise = max_poise`
- `_physics_process()`: decrement `poise_immunity` (alongside existing `attack_cooldown` / `stun_immunity`)
- `_on_phase_transition()`: update `max_poise` from `poise_per_phase` if key exists, reset `current_poise`

Methods:

```gdscript
func take_poise_hit() -> bool:
    if not poise_enabled or poise_immunity > 0:
        return false
    current_poise -= 1
    return current_poise <= 0

func reset_poise() -> void:
    var phase_poise = poise_per_phase.get(current_phase, max_poise)
    current_poise = phase_poise
    poise_immunity = poise_immunity_time
```

#### 2.2 Trigger (BossBaseState.gd)

Modify `on_damaged()`:

```gdscript
func on_damaged(_damage, _attacker_position) -> void:
    var boss := get_boss()
    if not boss: return
    if boss.stun_immunity > 0: return

    # Poise check (priority over stun)
    if boss.poise_enabled and boss.take_poise_hit():
        transitioned.emit(self, "counter")
        return

    # Phase 3 stun immunity (existing behavior)
    if boss.current_phase == BossBase.Phase.PHASE_3:
        return

    transitioned.emit(self, "stun")
```

Key: poise check happens before phase-3 stun immunity check. This means even in Phase 3, poise depletion triggers a counter-attack (intentional — Phase 3 boss is aggressive, not passive).

#### 2.3 Counter State (new file)

**File**: `Scenes/Characters/Bosses/Shared/BossCounterState.gd`
**Extends**: `BossState`
**Priority**: `REACTION`
**Interrupt protection**: Sets `stun_immunity = counter_duration` on enter (reuses existing immunity mechanism, prevents Stun from interrupting)

**Flow**:
1. `enter()`: Stop movement → set `stun_immunity` → trigger counter flash VFX → play `hit` animation as stagger (~0.3-0.5s timer). If `hit` anim is unavailable, use a plain timer with VFX only.
2. Stagger timer ends → pick counter attack from pool (filter `"counter": true` entries from current PhaseConfig, fallback to highest-weight entry)
3. Execute counter attack via `_dispatch_attack()`
4. Attack animation finishes → `boss.reset_poise()` → `evaluate_combat_transition()` to decide next state

#### 2.4 Counter Flash VFX

**File**: `Core/Effects/CounterFlashEffect.gd`

Based on `berserk.gdshader` visual style (scale + brighten), adapted for a short burst effect:
- Red/orange flash tint on the boss sprite
- Quick scale pulse (1.0 → 1.1 → 1.0 over ~0.3s)
- Shader uniform `progress` driven by a Tween from 0 → 1 → 0
- Signals completion so Counter state knows stagger phase is done

#### 2.5 Attack Pool Marking (BossPhaseConfig)

Attack entry dictionaries gain an optional `"counter": true` field:

```gdscript
# Example: BladeKeeper PhaseConfig
{"mode": "special", "weight": 1, "counter": true}
{"mode": "combo", "weight": 3}  # normal, not used for counter
```

`BossPhaseConfig` gets a helper method:

```gdscript
func pick_counter_attack() -> Dictionary:
    var pool = attacks.filter(func(e): return e.get("counter", false))
    if pool.is_empty():
        pool = attacks  # fallback: any attack
    return pool[randi() % pool.size()]
```

### 3. BladeKeeper Configuration

In `BladeKeeper.gd` `_on_boss_ready()`:

```gdscript
is_melee = true
poise_enabled = true
max_poise = 5
poise_per_phase = {Phase.PHASE_2: 4, Phase.PHASE_3: 3}
```

In `BKAttackManager` phase configs, mark counter-eligible attacks:
- Phase 1: `{"mode": "special", "weight": 1, "counter": true}`
- Phase 2: `{"mode": "combo", "weight": 2, "counter": true}`
- Phase 3: `{"mode": "combo", "weight": 3, "counter": true}`

BladeKeeper's state machine needs a `Counter` node using `BossCounterState`.

## Files Changed

| File | Change |
|---|---|
| `Core/Characters/BossBase.gd` | Add `is_melee`, poise exports/vars/methods |
| `Scenes/Characters/Bosses/Shared/BossBaseState.gd` | Modify `evaluate_combat_transition` + `on_damaged` |
| `Scenes/Characters/Bosses/Shared/BossCounterState.gd` | **New** — counter state |
| `Scenes/Characters/Bosses/Shared/BossPhaseConfig.gd` | Add `pick_counter_attack()` |
| `Core/Effects/CounterFlashEffect.gd` | **New** — VFX |
| `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd` | Set `is_melee`, poise config |
| `Scenes/Characters/Bosses/BladeKeeper/BKAttackManager.gd` | Mark counter attacks in phase configs |
| `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn` | Add Counter state node |

## Out of Scope

- Cyclops/DemonSlime poise configuration (can be added later by setting `poise_enabled = true`)
- New counter-specific animations (reuses existing hit/stun anims + VFX)
- Poise UI indicator (could add later as boss health bar decoration)
