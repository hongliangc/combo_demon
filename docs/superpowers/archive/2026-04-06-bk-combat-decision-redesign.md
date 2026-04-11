# BladeKeeper Combat Decision Redesign

## Summary

Redesign BladeKeeper's combat decision flow to fix Attack/Chase oscillation, DODGE sequence, and move defend/roll/jump out of the attack pool into reactive triggers.

## Problems

1. `.tscn` `attack_range=30` is correct (melee = close range), but `_finish_attack()` uses `evaluate_combat_transition()` which immediately transitions to chase if distance > 30 — causing Attack/Chase oscillation
2. Chase in attack_range but on cooldown: `_on_reached_attack_range()` returns `""`, ChaseState returns without moving — boss freezes
3. DODGE is a plain backwards hop — should include projectile throw + trap placement
4. defend/roll/jump are in the attack pool but should be reactive behaviors
5. combo/jump animations get interrupted by rapid state switching

## Design

### 1. Attack Pool Cleanup

Remove from attack pool: `defend`, `roll`, `jump`.

Final attack pools:

**Phase 1:**
```
{"mode": "attack", "weight": 5}
{"mode": "combo", "weight": 2, "counter": true}
{"mode": "projectile", "weight": 1}
```

**Phase 2:**
```
{"mode": "combo", "weight": 3}
{"mode": "projectile", "weight": 2}
{"mode": "trap", "weight": 2}
{"mode": "special", "weight": 1, "counter": true}
```

**Phase 3:**
```
{"mode": "combo", "weight": 3, "counter": true}
{"mode": "projectile", "weight": 2}
{"mode": "trap", "weight": 2}
{"mode": "special", "weight": 2}
```

### 2. BKAttack Internal Self-Loop

Replace `_finish_attack()` logic. Instead of calling `evaluate_combat_transition()`, do distance check internally:

```
distance <= attack_range → re-pick attack, stay in BKAttack
distance > attack_range  → transition to chase
```

This eliminates Attack/Chase oscillation for non-combo modes.

**attack mode** (Phase 1):
```
ATK(single hit) → _finish_attack() → distance check
```

**combo mode** (all phases, main attack):
```
ATK(random atk_1/2/3)
  → probability check
    → YES: SP_ATK → DODGE sequence → chase
    → NO:  DODGE sequence → chase
```

Combo always ends with DODGE sequence, always returns to chase. No distance check needed — DODGE pulls away.

**special mode** (Phase 2+):
```
SP_ATK → _finish_attack() → distance check
```

### 3. DODGE Sequence Rework (3 phases)

Current: single backwards hop with `roll` animation.

New: three sequential sub-steps using `trap_cast` animation:

```
DODGE_START  → back-flip launch (trap_cast anim) + place trap at launch position
DODGE_AIR    → mid-air: fire sword projectile toward player
DODGE_LAND   → landing → unconditional transition("chase")
```

Implementation:
- `DODGE_START`: set velocity away from player, call `attack_manager.place_trap(boss.global_position)`, play `trap_cast` animation
- `DODGE_AIR`: call `attack_manager.fire_sword_projectile(target_pos)` at the mid-point of the animation (use a timer at ~dodge_duration * 0.5)
- `DODGE_LAND`: on animation/timer finish, stop velocity, transition to chase

Reuse existing `BKAttackManager.fire_sword_projectile()` and `BKAttackManager.place_trap()` methods.

### 4. on_damaged Priority Chain

Modify `BossBaseState.on_damaged` (and/or override in BK-specific states):

```
1. stun_immunity > 0         → ignore
2. poise depleted             → counter
3. evasion chance (per phase) → random pick: defend OR roll
4. Phase 3 stun immunity      → ignore
5. default                    → stun
```

**BossBase new exports:**

```gdscript
@export_group("Evasion")
@export var evasion_enabled := false
@export var evasion_chance_per_phase: Dictionary = {}  # {Phase: float}
```

**BladeKeeper config:**
```gdscript
evasion_enabled = true
evasion_chance_per_phase = {Phase.PHASE_1: 0.15, Phase.PHASE_2: 0.25, Phase.PHASE_3: 0.35}
```

When evasion triggers: `["defend", "roll"].pick_random()` → transition to that state.

### 5. Chase Fixes

**Cooldown freeze fix**: In `ChaseState.physics_process_state()`, when `_on_reached_attack_range()` returns `""`, do NOT return. Fall through to movement code so boss keeps following the player while waiting for cooldown.

**Jump tracking**: In `BKChase.physics_process_state()`, before the attack range check, detect if player is airborne:
```
if target is in air (target.is_on_floor() == false):
    if state_machine has "jump" state:
        transition to jump → approach in air → air_atk if in range
```

### 6. BKChase Route Cleanup

Remove defend from the mode match in `_on_reached_attack_range()`:

```gdscript
match mode:
    "roll":
        return "roll"       # remove — roll is now reactive only
    "projectile":
        return "projectile"
    "trap":
        return "trap"
    _:
        return "attack"     # combo, special, attack all go to BKAttack
```

Actually, since roll is removed from attack pool, the match simplifies to:

```gdscript
match mode:
    "projectile":
        return "projectile"
    "trap":
        return "trap"
    _:
        return "attack"
```

## Files Changed

| File | Change |
|---|---|
| `Scenes/Characters/Bosses/BladeKeeper/States/BKAttack.gd` | Rework DODGE to 3-phase sequence; replace `_finish_attack()` with distance check + self-loop; update Step enum |
| `Scenes/Characters/Bosses/BladeKeeper/States/BKChase.gd` | Remove defend/roll from route match; add jump tracking for airborne player |
| `Scenes/Characters/Bosses/BladeKeeper/BKAttackManager.gd` | Clean attack pools (remove defend/roll/jump); restore attack mode in Phase 1 |
| `Core/Characters/BossBase.gd` | Add evasion exports (`evasion_enabled`, `evasion_chance_per_phase`) |
| `Scenes/Characters/Bosses/Shared/BossBaseState.gd` | Add evasion check in `on_damaged` chain |
| `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd` | Configure evasion params |
| `Core/StateMachine/CommonStates/ChaseState.gd` | Fix cooldown freeze (don't return on empty target_state) |

## Out of Scope

- BKDefend internal logic changes (already works as parry)
- BKRoll internal logic changes (already does backwards roll)
- New animations (reuse existing trap_cast for DODGE)
- Other bosses (Cyclops, DemonSlime) — unaffected
