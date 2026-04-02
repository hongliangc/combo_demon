# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Combo Demon** — 2D action game in Godot 4.4.1 (Mobile Renderer). Core gameplay: fluid combo combat, state machine AI, multi-phase boss fights, and attack effect system. ~81 scripts, 21 scenes.

## Development Commands

```bash
# Run project (headless, for testing)
godot --headless --path . &

# Run with editor
godot --editor --path .

# Export/validate scene
godot --headless --path . --export-debug
```

**MCP Tools available** (preferred over Bash for Godot operations):
- `mcp__godot__run_project` — launch game
- `mcp__godot__get_debug_output` — read engine logs
- `mcp__godot__create_scene` / `mcp__godot__add_node` / `mcp__godot__save_scene`
- `mcp__godot__get_uid` — resolve res:// UIDs for .tscn files

**Debugging**:
```gdscript
DebugConfig.debug("message", "", "channel")
# Channels: state_machine, animation, combat, movement
```

## Architecture (Quick Reference)

> **架构总索引** → `docs/ARCHITECTURE.md` | **详细架构** → 触发 `project-architecture` skill | **编码规范** → 触发 `godot-coding-standards` skill
> **类图** → `docs/class-diagrams.md` | **架构图** → `docs/architecture-diagrams.md`
> **重构/优化** → 触发 `feature-development` skill（已支持重构类型）

**State Machine** — 三层优先级: `CONTROL(2) > REACTION(1) > BEHAVIOR(0)`。BaseStateMachine + EnemyStateMachine(BASIC/RANGED/BOSS) + 7 CommonStates。

**AnimationTree** — 统一 BlendTree: `locomotion + control_sm → control_blend → output`。BaseState 提供 helper: `set_locomotion()`, `enter_control_state()`, `exit_control_state()`。

**Damage** — `Damage` Resource 含 `effects: Array[AttackEffect]`(Stun/KnockUp/KnockBack/Gather/ForceStun)。链路: HitBox → HurtBox → HealthComponent → damaged signal → StateMachine 状态切换。

**Player** — 5 组件: Movement, Combat, SkillManager, Health, Animation。

**Boss** — BossBase → Boss → BossStateMachine + BossAttackManager。3 阶段 + BossPhaseConfig Resource。

**Autoloads** — GameManager, UIManager, SoundManager, DamageNumbers, DebugConfig, TimeManager, LevelManager。

**Physics Layers** — 1:World 2:Player 3:PlayerProj 4:Enemy 5:EnemyProj 7:Object 8:Walls

**Input** — move_left/right/up/down(Arrow), dash/jump(Space), roll(R), interact(E), atk_sp(V), atk_1/2/3(X/W/E)

## Key Directories

| Layer | Path |
|---|---|
| Framework | `Core/StateMachine/`, `Core/Components/`, `Core/Resources/`, `Core/Effects/` |
| Services | `Core/Autoloads/` |
| Business | `Scenes/Characters/`, `Scenes/Levels/` |
| Presentation | `Assets/`, `Scenes/UI/` |

## Coding Conventions

`class_name PascalCase`, `var snake_case: Type`, `const UPPER_SNAKE`, `func snake_case() -> Type`。`@export` 配置化，懒缓存 `get_tree()` 查询。详见 `godot-coding-standards` skill。

