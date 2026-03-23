# Enemy Special Skills Design

> 为10个新敌人各添加一个符合其特性的特殊技能

## Approach: Mixed (C)

- **攻击增强型 (A)**: 技能本质是攻击变体 → 扩展 AttackState，重写 `on_custom_attack()`
- **独立状态型 (B)**: 技能需要独立行为循环 → 新增 SpecialSkillState 基类 + 子类

## Architecture

### New Base Class: `SpecialSkillState`

**File**: `Core/StateMachine/CommonStates/SpecialSkillState.gd` extends `BaseState`

```gdscript
@export var skill_cooldown := 8.0
@export var skill_probability := 0.2
@export var recheck_delay := 1.0  # 概率失败后短冷却，避免每帧roll

var _cooldown_remaining := 0.0
var _recheck_remaining := 0.0
```

**Key methods**:
- `can_trigger(distance: float) -> bool` — cooldown + probability + subclass condition check
- `execute_skill() -> void` — abstract, subclass implements
- `finish_skill()` — reset cooldown, transition back to chase/attack
- `roll_probability() -> bool` — `randf() < skill_probability`, fail sets `_recheck_remaining = recheck_delay`

**Trigger integration**: Chase/Attack states call `SpecialSkillState.can_trigger()` in `physics_process_state()`. SpecialSkillState exposes a static-like check via the state machine's states dict.

### Trigger Flow

```
Chase/Attack.physics_process_state(delta):
  var ss = state_machine.states.get("special_skill")
  if ss and ss.can_trigger(distance_to_target):
      transition_to("special_skill")
      return

SpecialSkillState.can_trigger(distance):
  if _cooldown_remaining > 0: return false
  if _recheck_remaining > 0: return false
  if not _check_condition(distance): return false
  if not roll_probability():
      _recheck_remaining = recheck_delay
      return false
  return true
```

### Enemy Registration

Each enemy with a special skill state: set `EnemyStateMachine.auto_create_states = false` in .tscn, manually add states as child nodes (or extend `_create_basic_states()` + append special_skill state).

Simpler approach: keep `auto_create_states = true`, add special skill state as a scene child node. `BaseStateMachine._ready()` picks up all BaseState children.

For attack-enhanced enemies (A type): override the auto-created Attack state by adding a custom AttackState child with matching name "Attack" — `EnemyStateMachine` skips auto-creation when children already exist (`get_child_count() == 0` check).

---

## Group A: Attack-Enhanced (extend AttackState)

### 1. Bear — 震地重击 (Ground Slam)

**File**: `Scenes/Characters/Enemies/Bear/BearAttackState.gd`

- `skill_probability = 0.2`
- `on_custom_attack()`: roll probability
  - Success: spawn circular Area2D (radius ~80px), detect player, apply KnockBackEffect + 1.5x damage, screen shake tween on sprite, queue_free Area2D
  - Fail: call default `fire_attack()`

### 2. Cyclope — 蓄力猛击 (Charged Strike)

**File**: `Scenes/Characters/Enemies/Cyclope/CyclopeAttackState.gd`

- `skill_probability = 0.2`
- `enter()`: roll probability
  - Success: set `_is_charging = true`, start 1.0s charge timer, modulate sprite yellow flash (tween loop)
  - Timer complete: `fire_attack()` with 2x damage, stop tween
  - Fail: normal `enter()` flow
- Charge can be interrupted by hit/stun (exit stops tween + resets modulate)

### 3. Mouse — 连击冲刺 (Dash Combo)

**File**: `Scenes/Characters/Enemies/Mouse/MouseAttackState.gd`

- `skill_probability = 0.2`
- `on_custom_attack()`: roll probability
  - Success: 3-hit combo loop (tween: dash 30px toward player → fire_attack → wait 0.2s) × 3
  - Fail: normal single attack

### 4. Lizard — 毒液攻击 (Poison Strike)

**File**: `Scenes/Characters/Enemies/Lizard/LizardAttackState.gd`

- `skill_probability = 0.2`
- `on_custom_attack()`: roll probability
  - Success: normal attack + spawn poison Timer on player (3 ticks, 1s interval, small damage each), visual: player modulate green tint during poison
  - Fail: normal attack
- Poison does not stack (check for existing poison timer before adding)

### 5. Flam — 自爆 (Self-Destruct)

**File**: `Scenes/Characters/Enemies/Flam/FlamAttackState.gd`

- `skill_probability = 0.2`, but only when HP < 30%
- `on_custom_attack()`: check HP < 30% → roll probability
  - Success: tween scale up 1.5x over 1s + modulate red → spawn AOE Area2D (radius ~100px) → apply damage to player → `owner_node.health_component.die()`
  - Fail (or HP >= 30%): normal attack

---

## Group B: Independent State (extend SpecialSkillState)

### 6. Spirit — 幽灵瞬移 (Ghost Teleport)

**File**: `Scenes/Characters/Enemies/Spirit/SpiritTeleportState.gd`

- `skill_cooldown = 8.0`, `skill_probability = 0.2`
- **Condition**: distance to player > 100
- **Execute**:
  1. Tween modulate.a → 0 (0.3s fade out)
  2. Teleport to player position + offset behind player (opposite of player facing, ~40px)
  3. Tween modulate.a → 1 (0.3s fade in)
  4. `fire_attack()` immediately
  5. `finish_skill()` → transition to "attack"
- **Triggered from**: Chase state

### 7. Dragon — 火焰吐息 (Fire Breath)

**File**: `Scenes/Characters/Enemies/Dragon/DragonBreathState.gd`

- `skill_cooldown = 6.0`, `skill_probability = 0.3`
- **Condition**: distance to player < 150
- **Execute**:
  1. `stop_movement()`, face player
  2. Spawn 3 projectile scenes in fan spread (−20°, 0°, +20°) toward player
  3. Projectile: simple Area2D + Sprite2D + velocity, queue_free on hit or after 2s
  4. Wait 0.5s → `finish_skill()` → transition to "chase"
- **Projectile scene**: `Scenes/Characters/Enemies/Dragon/DragonFireball.tscn` (new, simple)
- **Triggered from**: Attack state (replaces a normal attack)

### 8. BlueBat — 俯冲突袭 (Dive Attack)

**File**: `Scenes/Characters/Enemies/BlueBat/BlueBatDiveState.gd`

- `skill_cooldown = 5.0`, `skill_probability = 0.25`
- **Condition**: 60 < distance < 120
- **Execute**:
  1. Brief pause (0.2s), modulate red flash
  2. Tween position toward player at 2x chase_speed
  3. On arrival (distance < 15): apply damage + KnockBackEffect to player
  4. Tween bounce back 60px in opposite direction (0.3s)
  5. `finish_skill()` → transition to "chase"
- **Triggered from**: Chase state

### 9. Slime — 分裂 (Split)

**File**: `Scenes/Characters/Enemies/Slime/SlimeSplitState.gd`

- `skill_cooldown = INF` (one-time), `skill_probability = 1.0`
- **Condition**: HP drops below 50% (checked via `on_damaged` override, not from Chase/Attack)
- **Execute**:
  1. Brief pause (0.3s), scale tween wobble
  2. Spawn 2 mini-Slime instances at offset positions (±30px)
  3. Mini-Slime: same scene, scale 0.6x, HP = parent.max_health * 0.3, speed *= 1.3, `_can_split = false` (prevent recursive split)
  4. Original Slime `queue_free()`
- **Triggered from**: `on_damaged()` in SlimeSplitState or via Slime.gd script checking HP threshold
- **Special**: needs custom `_on_enemy_ready()` to set `_can_split` flag, and override `on_damaged` to check threshold

### 10. SkullBlue — 冰冻光环 (Frost Aura)

**File**: `Scenes/Characters/Enemies/SkullBlue/SkullBlueFrostState.gd`

- `skill_cooldown = 10.0`, `skill_probability = 0.15`
- **Condition**: distance < 80
- **Execute**:
  1. `stop_movement()`, brief channel (0.5s), modulate blue glow
  2. Spawn circular Area2D (radius ~70px)
  3. If player in range: apply ForceStunEffect (1.5s) via damage system
  4. Visual: expanding ring effect (tween scale 0→1 on a CircleShape indicator)
  5. `finish_skill()` → transition to "chase"
- **Triggered from**: Chase state

---

## File Summary

### New files to create:
```
Core/StateMachine/CommonStates/SpecialSkillState.gd    # Base class (~60 lines)

# Group A (attack overrides)
Scenes/Characters/Enemies/Bear/BearAttackState.gd
Scenes/Characters/Enemies/Cyclope/CyclopeAttackState.gd
Scenes/Characters/Enemies/Mouse/MouseAttackState.gd
Scenes/Characters/Enemies/Lizard/LizardAttackState.gd
Scenes/Characters/Enemies/Flam/FlamAttackState.gd

# Group B (independent states)
Scenes/Characters/Enemies/Spirit/SpiritTeleportState.gd
Scenes/Characters/Enemies/Dragon/DragonBreathState.gd
Scenes/Characters/Enemies/Dragon/DragonFireball.tscn     # Projectile scene
Scenes/Characters/Enemies/Dragon/DragonFireball.gd
Scenes/Characters/Enemies/BlueBat/BlueBatDiveState.gd
Scenes/Characters/Enemies/Slime/SlimeSplitState.gd
Scenes/Characters/Enemies/SkullBlue/SkullBlueFrostState.gd
```

### Files to modify:
```
# Add special_skill state node or replace Attack state node
Scenes/Characters/Enemies/Bear/Bear.tscn
Scenes/Characters/Enemies/Cyclope/Cyclope.tscn
Scenes/Characters/Enemies/Mouse/Mouse.tscn
Scenes/Characters/Enemies/Lizard/Lizard.tscn
Scenes/Characters/Enemies/Flam/Flam.tscn
Scenes/Characters/Enemies/Spirit/Spirit.tscn
Scenes/Characters/Enemies/Dragon/Dragon.tscn
Scenes/Characters/Enemies/BlueBat/BlueBat.tscn
Scenes/Characters/Enemies/Slime/Slime.tscn
Scenes/Characters/Enemies/SkullBlue/SkullBlue.tscn

# Add trigger check in physics_process_state
Core/StateMachine/CommonStates/ChaseState.gd
Core/StateMachine/CommonStates/AttackState.gd
```

### Existing files NOT modified:
- `BaseState.gd` — no changes needed
- `EnemyStateMachine.gd` — no changes, states auto-discovered from children
- `EnemyBase.gd` — no changes needed
