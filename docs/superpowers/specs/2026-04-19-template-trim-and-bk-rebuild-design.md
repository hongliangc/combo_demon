# Template Trim + BladeKeeper Rebuild — Design

**Date**: 2026-04-19
**Status**: Approved for plan-writing
**Supersedes**: `docs/superpowers/specs/2026-04-18-bladekeeper-migration-design.md` (Task 8 onwards)

## Background

The 2026-04-18 BladeKeeper migration spec drove tasks 1–7 to completion (skill `.tres` resources + `BladeKeeper.gd` rewrite). When tackling Task 8 (rewrite `BladeKeeper.tscn`'s state-machine subtree), two architectural problems surfaced:

1. The plan assumed BK's scene already had `AIController/StateMachine` — it didn't. BK still inherits `BossBase.tscn` (legacy step-machine), so Task 8 was a full re-template, not an incremental edit.
2. The current `AgentAIBase.tscn` template carries content leakage (placeholder `Sprite2D` node, default shapes, `RESET` animation referencing specific child nodes), forcing every inheriting boss to "ignore inherited node + add sibling replacement" — a pattern DS2 has already fallen into.

Both problems share a root cause: the line between **template** (骨架) and **instance content** is blurred. Fixing it requires two sequenced sub-projects.

## Principle (now codified)

**模板做骨架，不做内容**. Captured in `.claude/skills/godot-coding-standards/SKILL.md` ("场景模板原则 — 骨架 vs 内容"). All future template edits follow this rule.

## Sub-project A: Trim `AgentAIBase.tscn`

### Goal

Remove content leakage from the template so BladeKeeper (and future bosses) inherit a true skeleton.

### Changes

| Element | Action |
|---|---|
| `Sprite2D` node (template line 114) | **Delete** |
| `RESET` animation tracks targeting `Sprite2D:modulate` / `:position` / `:rotation` | **Delete** (keep `HealthBar:modulate` and `HurtBoxComponent/CollisionShape2D:disabled` tracks — these reference skeleton nodes valid for all bosses) |
| `RectangleShape2D_body` / `_hurt` / `_hit` SubResources (default 81×80 etc.) | **Delete** |
| `CollisionShape2D` / `HurtBoxComponent/CollisionShape2D` / `HitBoxComponent/CollisionShape2D` `shape =` assignment | **Remove** (node persists, `shape` field empty — instance must fill) |
| All component nodes (HurtBox/HitBox/HealthComponent/HealthBar/AnimationPlayer/AIController/StateMachine + 7 stock states) | **Keep unchanged** |
| `DamageNumbersAnchor` / `FloorCast L/R` / `WallCast L/R` (with default offsets sized for ~80px sprites) | **Keep unchanged** (reasonable defaults for common case; large-sprite bosses override) |

### Validation

1. Open `DemonSlime2.tscn` in editor → no parse errors → DS2 still loads.
2. Run `Level_DemonSlime2` (or BK level with DS2 selected) → boss spawns, runs full idle/chase/attack/death loop.
3. Run unit test suite → all green.

### Risk

DS2's `_auto_find_sprite()` flow already prefers `AnimatedSprite2D` over `Sprite2D` (DS2 line 447 adds `AnimatedSprite2D` as sibling). Removing the template `Sprite2D` should be transparent. **Verify explicitly** post-trim.

### Commit

One commit: `refactor(template): trim AgentAIBase to pure skeleton`.

---

## Sub-project B: Rebuild `BladeKeeper.tscn`

### Goal

Replace `BladeKeeper.tscn` with a clean inheritance from the trimmed `AgentAIBase.tscn`. No backwards compatibility, no preserved legacy nodes.

### Constraints

- **Preserve UID** `uid://bics1mnpd7xx4` — `EnemySpawn.gd:6` preloads this path; changing UID breaks the test level spawn.
- **Inherit from** `AgentAIBase.tscn` (UID `uid://rllitgnkf211`).
- BK scene **completely废弃**, only the asset SubResources (sprite frames, animation library, BK-specific shapes) and external scenes (`BKSwordProjectile.tscn`, `BKTrapEntity.tscn`) carry over.

### Node structure (post-rebuild)

```
BladeKeeper (CharacterBody2D, instance=AgentAIBase.tscn, script=BladeKeeper.gd)
├── [inherited] HurtBoxComponent → CollisionShape2D (shape override)
├── [inherited] HitBoxComponent → CollisionShape2D (shape override + disabled=true)
├── [inherited] CollisionShape2D (shape override)
├── [inherited] HealthComponent (max_health/health override)
├── [inherited] HealthBar (position/value override)
├── [inherited] DamageNumbersAnchor / FloorCast L/R / WallCast L/R
├── [inherited] AnimationPlayer (libraries/ override → BK's AnimationLibrary)
├── [inherited] AIController/StateMachine + 7 stock states (Idle/Chase/Hit/Death/Dispatcher/GenericAttack/Combo)
│   └── [added] Approach (script=res://Core/AI/Stock/ApproachState.gd)
└── [added] AnimatedSprite2D (sprite_frames=preserved SpriteFrames, animation=&"idle")
```

**Not added**: `AnimationTree`. New stock states drive animation directly via `anim_player.play(anim_name)`; the legacy BlendTree (locomotion blend) provides no value.

### Resources kept (from old BK.tscn)

- All `Texture2D` ext_resources (sprite frame assets)
- `SpriteFrames` SubResource (sprite atlas regions)
- `AnimationLibrary` SubResource — verified via grep to contain all required animations: `atk_1`, `atk_2`, `atk_3`, `sp_atk`, `idle`, `walk`, `roll`, `projectile_cast`, `trap_cast`, `defend`, `death`, `hit`, `air_atk`, `jump_up`, `jump_down`
- BK-specific `RectangleShape2D` SubResources (body / hurt / hit shapes — sized for BK)
- `BKSwordProjectile.tscn` ext_resource (referenced by `bk_throw_sword.tres`)
- `BKTrapEntity.tscn` ext_resource (referenced by `bk_place_trap.tres`)

### Resources removed

- `BossBase.tscn` ext_resource → replaced by `AgentAIBase.tscn`
- `BKAttackManager.gd` / `BKStateMachine.gd` ext_resources
- `BKChase` / `BKAttack` / `BKDefend` / `BKRoll` / `BKProjectile` / `BKTrap` `.gd` ext_resources
- `BossCounterState.gd` ext_resource (BK-only legacy; DS2 uses its own `DS2Counter.gd`)
- `CommonStates/IdleState.gd` and `CommonStates/HitState.gd` ext_resources (template provides Stock variants)
- `AnimationNodeBlendTree_root` and all `AnimationNode*` SubResources (AnimationTree is gone)

### Root node fields

**Keep**:
- `script = ExtResource("<bk_script>")` (BladeKeeper.gd)
- `base_move_speed = 180.0`
- `pressure_threshold = 35.0`
- `collision_mask = 129`

**Remove** (BossBase-only fields, not present on AgentAIBase.gd):
- `attack_range`, `is_melee`, `has_gravity`, `evasion_enabled`, `poise_enabled`, `max_health`, `health`

**Add**:
- `skill_resources = Array[Skill]([ExtResource(...) × 11])` — static inline references to all 11 skill `.tres` files in `skills/` directory

### Animation method tracks (critical step)

Add Call Method Tracks to BK's `AnimationLibrary`, target node path `AIController/StateMachine/GenericAttack`:

| Animation | Method | Approximate frame |
|---|---|---|
| `projectile_cast` | `spawn_projectile` | sword-release frame |
| `trap_cast` | `spawn_entity` | drop frame |
| `defend` | `call_skill_method` | apply frame |

**Implementation rule**: must be done through Godot editor (via MCP tools `launch_editor` + manual track edit + `save_scene`). **Forbidden**: hand-editing the track JSON in `.tscn` text. If the MCP route fails, implementer reports `BLOCKED` — does not fall back to text edit.

### Legacy file deletion (bundled into Sub-project B commit)

Delete `.gd` + `.gd.uid` pairs:
- `Scenes/Characters/Bosses/BladeKeeper/BKAttackManager.gd(.uid)`
- `Scenes/Characters/Bosses/BladeKeeper/BKStateMachine.gd(.uid)`
- `Scenes/Characters/Bosses/BladeKeeper/States/BKAttack.gd(.uid)`
- `Scenes/Characters/Bosses/BladeKeeper/States/BKChase.gd(.uid)`
- `Scenes/Characters/Bosses/BladeKeeper/States/BKDefend.gd(.uid)`
- `Scenes/Characters/Bosses/BladeKeeper/States/BKRoll.gd(.uid)`
- `Scenes/Characters/Bosses/BladeKeeper/States/BKProjectile.gd(.uid)`
- `Scenes/Characters/Bosses/BladeKeeper/States/BKTrap.gd(.uid)`
- `Scenes/Characters/Bosses/BladeKeeper/States/BKIdle.gd(.uid)` (if exists)
- `Scenes/Characters/Bosses/Shared/BossCounterState.gd(.uid)` (BK-only legacy; verified DS2 does NOT use it)

### Bundled hotfix

Include the in-flight `BladeKeeper.gd` change `&"dead"` → `&"death"` (line 39). Template's death node is `Death` → `AIController._collect_states()` lowercases to `&"death"`.

### Skill array storage decision

**Static inline** Array (chosen). Wrapping into a `BKSkillSet.tres` Resource is YAGNI — only valuable when 2+ bosses share the same skill set. Defer until that need appears.

### Validation

1. Open `BladeKeeper.tscn` in editor → no parse errors.
2. Run `Level_BladeKeeper` (boss_name = "BladeKeeper") → BK spawns, runs full idle/chase/attack/death loop.
3. Verify all 3 method tracks fire: `projectile_cast` spawns sword projectile, `trap_cast` spawns trap entity, `defend` triggers buff/heal method.
4. Run unit test suite — all 11 BK skill resource tests + everything else green.

### Commit

One commit: `feat(bk): rebuild BladeKeeper from AgentAIBase + delete legacy step-machine`.

---

## Sequencing

1. **Sub-project A** (template trim) — single commit, validate DS2.
2. **Sub-project B** (BK rebuild) — single commit, validate Level_BladeKeeper.

A must complete + validate before B starts. If A breaks DS2, fix A before B.

## Out of Scope

- BuffEntity framework (referenced in BK.gd `apply_defense_buff` comment) — separate future work.
- Promoting `Approach` state to template — only BK uses it; revisit when 2nd boss needs gap-close.
- `SkillSetData.gd` Resource wrapper — revisit when shared skill sets emerge.
- Other bosses' migration — DS2 is already on AgentAIBase; future bosses follow the same pattern documented here.

## References

- Skill: `.claude/skills/godot-coding-standards/SKILL.md` ("场景模板原则 — 骨架 vs 内容")
- Reference migration: `Scenes/Characters/Bosses/DemonSlime2/DemonSlime2.tscn` (note: still has the AnimatedSprite2D-as-sibling pattern; sub-project A makes that pattern unnecessary going forward)
- Original spec: `docs/superpowers/specs/2026-04-18-bladekeeper-migration-design.md`
- In-progress plan: `docs/superpowers/plans/2026-04-18-bladekeeper-migration-implementation.md` (tasks 1–7 done; tasks 8–12 to be replaced by the plan written from this spec)
