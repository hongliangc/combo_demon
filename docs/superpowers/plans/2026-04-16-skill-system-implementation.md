# Skill System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `last_action` hack with data-driven Skill Resources, SkillSet selector, and universal attack states.

**Architecture:** Skill/ComboSkill Resources declare metadata + params. SkillSet filters/picks/manages cooldowns. Guards call pick/pick_tagged to pre-select skills. AttackDispatcher routes to GenericAttackState or ComboState. DS2 migrated as proof of concept.

**Tech Stack:** Godot 4.4.1, GDScript, GUT test framework

**Spec:** `docs/superpowers/specs/2026-04-16-skill-system-design.md`

---

## File Map

### New Files

| File | Responsibility |
|---|---|
| `Core/AI/Skill.gd` | Skill Resource — selection + control + execution params |
| `Core/AI/ComboSkill.gd` | ComboSkill Resource — extends Skill with sequence + gap |
| `Core/AI/SkillSet.gd` | Filter + weighted pick + cooldown management |
| `Core/AI/Stock/BaseAttackState.gd` | 公共基类:`_resolve_direction()` + `_finish()` |
| `Core/AI/Stock/AttackDispatcher.gd` | Route pending_skill to target state |
| `Core/AI/Stock/GenericAttackState.gd` | Universal attack/dodge executor (extends BaseAttackState) |
| `Core/AI/Stock/ComboState.gd` | Sequential multi-step combo executor (extends BaseAttackState) |
| `Scenes/Characters/Bosses/DemonSlime2/Skills/ds2_cleave.tres` | Cleave skill config |
| `Scenes/Characters/Bosses/DemonSlime2/Skills/ds2_slam.tres` | Slam skill config |
| `Scenes/Characters/Bosses/DemonSlime2/Skills/ds2_combo_2hit.tres` | Combo 验证(两次 cleave) |
| `test/unit/test_skill_set.gd` | SkillSet unit tests |
| `test/unit/test_skill_resource.gd` | Skill/ComboSkill resource tests |
| `test/integration/test_ds2_skills.gd` | DS2 skill system integration tests |

### Modified Files

| File | Changes |
|---|---|
| `Core/AI/AIController.gd` | Add `current_skill`, `goto()`, interrupt check in `dispatch()`, **删除 `attack_cooldown` 和 `global_cooldown` 的 tick** |
| `Core/AI/AgentAIBase.gd` | Add `skill_set`, `_setup_skill_set()`, `damage_recent`, `global_cooldown` tick, `_hit_clear_timer` |
| `Scenes/Characters/Templates/AgentAIBase.tscn` | Add AttackDispatcher, GenericAttackState, ComboState nodes |
| `Scenes/Characters/Bosses/DemonSlime2/DemonSlime2.gd` | Rewrite to SkillSet-driven |

### Deleted Files

| File | Reason |
|---|---|
| `Scenes/Characters/Bosses/DemonSlime2/States/DS2Cleave.gd` | GenericAttackState replaces |
| `Scenes/Characters/Bosses/DemonSlime2/States/DS2Slam.gd` | GenericAttackState replaces |
| `test/integration/test_ds2.gd` | 旧 attack_cooldown/last_action 测试,被 test_ds2_skills.gd 取代 |

---

## Task 1: Skill and ComboSkill Resources

**Files:**
- Create: `Core/AI/Skill.gd`
- Create: `Core/AI/ComboSkill.gd`
- Test: `test/unit/test_skill_resource.gd`

- [ ] **Step 1: Create Skill.gd**

```gdscript
# Core/AI/Skill.gd
class_name Skill extends Resource

## 技能声明 Resource — 选择条件 + 控制标志 + 执行参数

# ==== 选择层（SkillSet 读取）====
## 唯一标识，用于 cd key 和日志
@export var id: StringName = &""
## 目标状态节点名（StateMachine 中的 AIState.name，小写）
@export var state_name: StringName = &""
## 本技能专属冷却（秒）
@export var cooldown: float = 1.5
## 加权随机权重（0 = 不进入普通池，仅 pick_tagged 可选）
@export var weight: int = 1
## 阶段解锁（含端点）
@export var min_phase: int = 0
## -1 = 不限上限
@export var max_phase: int = -1
## 距离门槛（0 = 不限）
@export var min_range: float = 0.0
@export var max_range: float = 0.0
## 分类标签
@export var tags: Array[StringName] = []
## Boss 脚本中的前置条件方法名（空 = 无条件）
@export var precondition_method: StringName = &""

# ==== 控制层（AIController 读取）====
## false = 执行期间只有 EV_DIED / EV_ATTACK_FINISHED 可打断
@export var interruptible: bool = true

# ==== 执行层（State 读取）====
## 状态专属参数字典
@export var params: Dictionary = {}
```

- [ ] **Step 2: Create ComboSkill.gd**

```gdscript
# Core/AI/ComboSkill.gd
class_name ComboSkill extends Skill

## 组合技 Resource — 按序执行子技能的动画 + 参数

## 子技能列表（ComboState 读取每项的 params）
@export var sequence: Array[Skill] = []
## 每步之间的间隔（秒）
@export var gap: float = 0.1

func _init() -> void:
	interruptible = false
	state_name = &"combo"
```

- [ ] **Step 3: Write test for Skill resource field access**

```gdscript
# test/unit/test_skill_resource.gd
extends GutTest

## Skill / ComboSkill Resource 单元测试

func test_skill_default_values() -> void:
	var s := Skill.new()
	assert_eq(s.id, &"")
	assert_eq(s.state_name, &"")
	assert_eq(s.cooldown, 1.5)
	assert_eq(s.weight, 1)
	assert_eq(s.min_phase, 0)
	assert_eq(s.max_phase, -1)
	assert_eq(s.min_range, 0.0)
	assert_eq(s.max_range, 0.0)
	assert_eq(s.tags.size(), 0)
	assert_eq(s.precondition_method, &"")
	assert_true(s.interruptible)
	assert_eq(s.params.size(), 0)

func test_skill_field_assignment() -> void:
	var s := Skill.new()
	s.id = &"cleave"
	s.state_name = &"generic_attack"
	s.cooldown = 2.0
	s.weight = 5
	s.min_phase = 1
	s.max_phase = 2
	s.min_range = 50.0
	s.max_range = 250.0
	s.tags = [&"melee", &"heavy"]
	s.precondition_method = &"_precond_test"
	s.interruptible = false
	s.params = { &"animation": &"cleave", &"speed": 100.0 }

	assert_eq(s.id, &"cleave")
	assert_eq(s.state_name, &"generic_attack")
	assert_eq(s.cooldown, 2.0)
	assert_eq(s.weight, 5)
	assert_eq(s.min_phase, 1)
	assert_eq(s.max_phase, 2)
	assert_eq(s.min_range, 50.0)
	assert_eq(s.max_range, 250.0)
	assert_eq(s.tags.size(), 2)
	assert_true(&"melee" in s.tags)
	assert_false(s.interruptible)
	assert_eq(s.params[&"animation"], &"cleave")

func test_combo_skill_defaults() -> void:
	var cs := ComboSkill.new()
	assert_false(cs.interruptible, "combo defaults to non-interruptible")
	assert_eq(cs.state_name, &"combo")
	assert_eq(cs.gap, 0.1)
	assert_eq(cs.sequence.size(), 0)

func test_combo_skill_sequence() -> void:
	var s1 := Skill.new()
	s1.id = &"slash1"
	s1.params = { &"animation": &"slash1" }

	var s2 := Skill.new()
	s2.id = &"slash2"
	s2.params = { &"animation": &"slash2" }

	var cs := ComboSkill.new()
	cs.id = &"combo2"
	cs.sequence = [s1, s2]
	cs.gap = 0.2

	assert_eq(cs.sequence.size(), 2)
	assert_eq(cs.sequence[0].id, &"slash1")
	assert_eq(cs.sequence[1].params[&"animation"], &"slash2")
	assert_eq(cs.gap, 0.2)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd e:/workspace/4.godot/combo_demon && bash test/run_tests.sh test/unit/test_skill_resource.gd`
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Core/AI/Skill.gd Core/AI/ComboSkill.gd test/unit/test_skill_resource.gd
git commit -m "feat: add Skill and ComboSkill Resource classes with tests"
```

---

## Task 2: SkillSet Selector + Cooldown Manager

**Files:**
- Create: `Core/AI/SkillSet.gd`
- Test: `test/unit/test_skill_set.gd`

- [ ] **Step 1: Create SkillSet.gd**

```gdscript
# Core/AI/SkillSet.gd
class_name SkillSet extends RefCounted

## 技能池管理器：过滤 → 加权选择 → 冷却管理

var _skills: Array[Skill] = []
var _cooldowns: Dictionary = {}   # { skill.id: float }

## 初始化技能池
func setup(skills: Array[Skill]) -> void:
	_skills = skills
	for s in skills:
		_cooldowns[s.id] = 0.0

## 从可用技能中加权随机选一个（weight=0 的技能被排除）
func pick(boss_ref: Node, bb: AIBlackboard) -> Skill:
	var pool := _filter(boss_ref, bb, false)
	if pool.is_empty():
		return null
	return _weighted_pick(pool)

## 按 tag 过滤后选（含 weight=0 的技能）
func pick_tagged(tag: StringName, boss_ref: Node, bb: AIBlackboard) -> Skill:
	var pool := _filter(boss_ref, bb, true).filter(
		func(s: Skill) -> bool: return tag in s.tags
	)
	if pool.is_empty():
		return null
	return _weighted_pick(pool)

## 查询是否有任何技能可用
func has_available(boss_ref: Node, bb: AIBlackboard) -> bool:
	return not _filter(boss_ref, bb, false).is_empty()

## 触发某技能的冷却
func start_cooldown(skill_id: StringName) -> void:
	var s := _find_skill(skill_id)
	if s:
		_cooldowns[s.id] = s.cooldown

## 每帧扣减冷却（由 AgentAIBase._physics_process 调用）
func tick(delta: float) -> void:
	for id in _cooldowns:
		if _cooldowns[id] > 0:
			_cooldowns[id] = maxf(_cooldowns[id] - delta, 0.0)

## 读取某技能当前剩余冷却
func get_cooldown(skill_id: StringName) -> float:
	return _cooldowns.get(skill_id, 0.0)

# ---- 内部 ----

func _filter(boss_ref: Node, bb: AIBlackboard, include_zero_weight: bool) -> Array[Skill]:
	var phase: int = bb.get_var(&"current_phase", 0)
	var dist: float = bb.get_var(&"distance", INF)
	var result: Array[Skill] = []
	for s in _skills:
		if _cooldowns.get(s.id, 0.0) > 0:
			continue
		if phase < s.min_phase:
			continue
		if s.max_phase >= 0 and phase > s.max_phase:
			continue
		if s.max_range > 0 and dist > s.max_range:
			continue
		if s.min_range > 0 and dist < s.min_range:
			continue
		if not include_zero_weight and s.weight <= 0:
			continue
		if s.precondition_method != &"" and boss_ref.has_method(s.precondition_method):
			if not boss_ref.call(s.precondition_method):
				continue
		result.append(s)
	return result

func _weighted_pick(pool: Array[Skill]) -> Skill:
	var total := 0
	for s in pool:
		total += maxi(s.weight, 1)
	var roll := randi() % total
	var acc := 0
	for s in pool:
		acc += maxi(s.weight, 1)
		if roll < acc:
			return s
	return pool.back()

func _find_skill(id: StringName) -> Skill:
	for s in _skills:
		if s.id == id:
			return s
	return null
```

- [ ] **Step 2: Write SkillSet unit tests**

```gdscript
# test/unit/test_skill_set.gd
extends GutTest

## SkillSet 单元测试

var _boss: Node
var _bb: AIBlackboard
var _ss: SkillSet

# ---- helpers ----

func _make_skill(id: StringName, overrides: Dictionary = {}) -> Skill:
	var s := Skill.new()
	s.id = id
	s.state_name = overrides.get("state_name", &"generic_attack")
	s.cooldown = overrides.get("cooldown", 1.5)
	s.weight = overrides.get("weight", 1)
	s.min_phase = overrides.get("min_phase", 0)
	s.max_phase = overrides.get("max_phase", -1)
	s.min_range = overrides.get("min_range", 0.0)
	s.max_range = overrides.get("max_range", 0.0)
	s.tags = overrides.get("tags", [])
	s.precondition_method = overrides.get("precondition_method", &"")
	s.interruptible = overrides.get("interruptible", true)
	return s

func before_each() -> void:
	_boss = Node.new()
	add_child_autofree(_boss)
	_bb = AIBlackboard.new()
	_bb.set_var(&"current_phase", 0)
	_bb.set_var(&"distance", 100.0)
	_ss = SkillSet.new()

# ============ setup ============

func test_setup_initializes_cooldowns() -> void:
	var cleave := _make_skill(&"cleave")
	var slam := _make_skill(&"slam")
	_ss.setup([cleave, slam])
	assert_eq(_ss.get_cooldown(&"cleave"), 0.0)
	assert_eq(_ss.get_cooldown(&"slam"), 0.0)

# ============ pick: phase filter ============

func test_pick_filters_by_phase() -> void:
	var cleave := _make_skill(&"cleave", { "min_phase": 0 })
	var slam := _make_skill(&"slam", { "min_phase": 1 })
	_ss.setup([cleave, slam])
	_bb.set_var(&"current_phase", 0)
	# phase 0: only cleave available
	var picked := _ss.pick(_boss, _bb)
	assert_eq(picked.id, &"cleave", "phase 0 should only pick cleave")

func test_pick_phase_unlocks() -> void:
	var cleave := _make_skill(&"cleave", { "min_phase": 0 })
	var slam := _make_skill(&"slam", { "min_phase": 1, "weight": 100 })
	_ss.setup([cleave, slam])
	_bb.set_var(&"current_phase", 1)
	# phase 1: both available, slam has weight 100 so almost always picked
	var slam_count := 0
	for i in 50:
		var p := _ss.pick(_boss, _bb)
		if p.id == &"slam":
			slam_count += 1
	assert_gt(slam_count, 40, "slam (weight=100) should dominate")

func test_pick_max_phase_locks() -> void:
	var early := _make_skill(&"early", { "min_phase": 0, "max_phase": 0 })
	var late := _make_skill(&"late", { "min_phase": 1 })
	_ss.setup([early, late])
	_bb.set_var(&"current_phase", 1)
	var picked := _ss.pick(_boss, _bb)
	assert_eq(picked.id, &"late", "early skill locked out at phase 1")

# ============ pick: distance filter ============

func test_pick_filters_by_max_range() -> void:
	var cleave := _make_skill(&"cleave", { "max_range": 250.0 })
	_ss.setup([cleave])
	_bb.set_var(&"distance", 300.0)
	assert_null(_ss.pick(_boss, _bb), "too far for cleave")
	_bb.set_var(&"distance", 200.0)
	assert_not_null(_ss.pick(_boss, _bb), "in range")

func test_pick_filters_by_min_range() -> void:
	var proj := _make_skill(&"proj", { "min_range": 200.0 })
	_ss.setup([proj])
	_bb.set_var(&"distance", 100.0)
	assert_null(_ss.pick(_boss, _bb), "too close for projectile")
	_bb.set_var(&"distance", 300.0)
	assert_not_null(_ss.pick(_boss, _bb), "far enough")

# ============ pick: cooldown filter ============

func test_cooldown_blocks_pick() -> void:
	var cleave := _make_skill(&"cleave", { "cooldown": 2.0 })
	_ss.setup([cleave])
	_ss.start_cooldown(&"cleave")
	assert_null(_ss.pick(_boss, _bb), "skill on cooldown")

func test_cooldown_tick_restores() -> void:
	var cleave := _make_skill(&"cleave", { "cooldown": 1.0 })
	_ss.setup([cleave])
	_ss.start_cooldown(&"cleave")
	assert_null(_ss.pick(_boss, _bb), "on cooldown")
	_ss.tick(0.5)
	assert_null(_ss.pick(_boss, _bb), "still on cooldown at 0.5s")
	_ss.tick(0.6)
	assert_not_null(_ss.pick(_boss, _bb), "cooldown expired at 1.1s")

# ============ pick: weight=0 excluded ============

func test_weight_zero_excluded_from_pick() -> void:
	var retreat := _make_skill(&"retreat", { "weight": 0, "tags": [&"defensive"] })
	_ss.setup([retreat])
	assert_null(_ss.pick(_boss, _bb), "weight=0 excluded from normal pick")

# ============ pick_tagged ============

func test_pick_tagged_finds_zero_weight() -> void:
	var retreat := _make_skill(&"retreat", { "weight": 0, "tags": [&"defensive"] })
	_ss.setup([retreat])
	var picked := _ss.pick_tagged(&"defensive", _boss, _bb)
	assert_not_null(picked, "pick_tagged should find weight=0 skill")
	assert_eq(picked.id, &"retreat")

func test_pick_tagged_wrong_tag_returns_null() -> void:
	var retreat := _make_skill(&"retreat", { "weight": 0, "tags": [&"defensive"] })
	_ss.setup([retreat])
	assert_null(_ss.pick_tagged(&"ranged", _boss, _bb), "wrong tag")

func test_pick_tagged_respects_cooldown() -> void:
	var retreat := _make_skill(&"retreat", { "weight": 0, "cooldown": 3.0, "tags": [&"defensive"] })
	_ss.setup([retreat])
	_ss.start_cooldown(&"retreat")
	assert_null(_ss.pick_tagged(&"defensive", _boss, _bb), "on cooldown")

# ============ precondition_method ============

func test_precondition_blocks_pick() -> void:
	var retreat := _make_skill(&"retreat", {
		"weight": 0, "tags": [&"defensive"],
		"precondition_method": &"_precond_heavy_damage"
	})
	_ss.setup([retreat])
	# boss has no _precond_heavy_damage method → skill filtered (method missing)
	assert_null(_ss.pick_tagged(&"defensive", _boss, _bb))

func test_precondition_passes() -> void:
	# Add a method to boss that returns true
	var script := GDScript.new()
	script.source_code = "extends Node\nfunc _precond_heavy_damage() -> bool:\n\treturn true\n"
	script.reload()
	var boss := Node.new()
	boss.set_script(script)
	add_child_autofree(boss)

	var retreat := _make_skill(&"retreat", {
		"weight": 0, "tags": [&"defensive"],
		"precondition_method": &"_precond_heavy_damage"
	})
	_ss.setup([retreat])
	var picked := _ss.pick_tagged(&"defensive", boss, _bb)
	assert_not_null(picked, "precondition returns true → skill available")

# ============ has_available ============

func test_has_available() -> void:
	var cleave := _make_skill(&"cleave")
	_ss.setup([cleave])
	assert_true(_ss.has_available(_boss, _bb))
	_ss.start_cooldown(&"cleave")
	assert_false(_ss.has_available(_boss, _bb))

# ============ tick ============

func test_tick_does_not_go_negative() -> void:
	var cleave := _make_skill(&"cleave", { "cooldown": 0.5 })
	_ss.setup([cleave])
	_ss.start_cooldown(&"cleave")
	_ss.tick(10.0)
	assert_eq(_ss.get_cooldown(&"cleave"), 0.0, "should not go negative")
```

- [ ] **Step 3: Run tests**

Run: `cd e:/workspace/4.godot/combo_demon && bash test/run_tests.sh test/unit/test_skill_set.gd`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add Core/AI/SkillSet.gd test/unit/test_skill_set.gd
git commit -m "feat: add SkillSet selector with filter, weighted pick, and cooldown management"
```

---

## Task 3: AIController Extensions

**Files:**
- Modify: `Core/AI/AIController.gd`
- Test: `test/unit/test_ai_controller.gd` (append new tests)

- [ ] **Step 1: Add current_skill field and goto() method to AIController**

Add after line 15 (`ANYSTATE` declaration) in `Core/AI/AIController.gd`:

```gdscript
## 当前正在执行的技能（由 AttackDispatcher 设置，攻击结束时清除）
var current_skill: Skill = null
```

Add after `get_state()` method (end of file) in `Core/AI/AIController.gd`:

```gdscript
## 路由状态专用：直接跳转到指定状态，绕过转换表
func goto(state_name: StringName) -> void:
	var target := get_state(state_name)
	if target:
		_change_state(target)
```

- [ ] **Step 2: Add interrupt check to dispatch()**

Replace the existing `dispatch()` method in `Core/AI/AIController.gd` (lines 106-117):

```gdscript
func dispatch(event: StringName) -> void:
	if current_state == null or event == &"":
		return
	# 不可打断技能执行中，只允许白名单事件
	if current_skill and not current_skill.interruptible:
		if event != AIEvents.EV_DIED and event != AIEvents.EV_ATTACK_FINISHED:
			return
	for t in _transitions:
		if t.event != event:
			continue
		if t.from_state != null and t.from_state != current_state:
			continue
		if t.guard.is_valid() and not t.guard.call():
			continue
		_change_state(t.to_state)
		return
```

- [ ] **Step 3: Remove attack_cooldown AND global_cooldown ticks from _update_blackboard()**

In `Core/AI/AIController.gd`, remove lines 98-103 (both ticks):

```gdscript
	var atk_cd: float = blackboard.get_var(&"attack_cooldown", 0.0)
	if atk_cd > 0:
		blackboard.set_var(&"attack_cooldown", maxf(0.0, atk_cd - delta))
	var gcd: float = blackboard.get_var(&"global_cooldown", 0.0)
	if gcd > 0:
		blackboard.set_var(&"global_cooldown", maxf(0.0, gcd - delta))
```

`attack_cooldown` is replaced by per-skill cooldowns. `global_cooldown` ownership moves to `AgentAIBase._tick_global_cooldown()` (Task 5) — keeping both would double-tick the GCD.

- [ ] **Step 4: Write tests for new AIController features**

Append to `test/unit/test_ai_controller.gd`:

```gdscript
# ============ goto ============

func test_goto_changes_state() -> void:
	_ai.goto(&"chase")
	assert_eq(_ai.get_current_state_name(), &"chase")

func test_goto_invalid_state_does_nothing() -> void:
	_ai.goto(&"nonexistent")
	assert_eq(_ai.get_current_state_name(), &"idle")

# ============ current_skill interrupt ============

func test_non_interruptible_skill_blocks_dispatch() -> void:
	var skill := Skill.new()
	skill.interruptible = false
	_ai.current_skill = skill
	_ai.add_transition(_ai.ANYSTATE, _hit, AIEvents.EV_DAMAGED)
	_ai.dispatch(AIEvents.EV_DAMAGED)
	assert_eq(_ai.get_current_state_name(), &"idle", "non-interruptible blocks EV_DAMAGED")

func test_non_interruptible_allows_died() -> void:
	var skill := Skill.new()
	skill.interruptible = false
	_ai.current_skill = skill
	_ai.add_transition(_ai.ANYSTATE, _death, AIEvents.EV_DIED)
	_ai.dispatch(AIEvents.EV_DIED)
	assert_eq(_ai.get_current_state_name(), &"death", "EV_DIED always penetrates")

func test_non_interruptible_allows_attack_finished() -> void:
	_ai.add_transition(_idle, _chase, &"go")
	_ai.dispatch(&"go")
	var skill := Skill.new()
	skill.interruptible = false
	_ai.current_skill = skill
	_ai.add_transition(_chase, _idle, AIEvents.EV_ATTACK_FINISHED)
	_ai.dispatch(AIEvents.EV_ATTACK_FINISHED)
	assert_eq(_ai.get_current_state_name(), &"idle", "EV_ATTACK_FINISHED always penetrates")

func test_interruptible_skill_allows_dispatch() -> void:
	var skill := Skill.new()
	skill.interruptible = true
	_ai.current_skill = skill
	_ai.add_transition(_ai.ANYSTATE, _hit, AIEvents.EV_DAMAGED)
	_ai.dispatch(AIEvents.EV_DAMAGED)
	assert_eq(_ai.get_current_state_name(), &"hit", "interruptible allows EV_DAMAGED")

func test_no_skill_allows_dispatch() -> void:
	_ai.current_skill = null
	_ai.add_transition(_ai.ANYSTATE, _hit, AIEvents.EV_DAMAGED)
	_ai.dispatch(AIEvents.EV_DAMAGED)
	assert_eq(_ai.get_current_state_name(), &"hit", "no skill = interruptible")
```

- [ ] **Step 5: Run all AIController tests**

Run: `cd e:/workspace/4.godot/combo_demon && bash test/run_tests.sh test/unit/test_ai_controller.gd`
Expected: All tests PASS (old + new)

- [ ] **Step 6: Commit**

```bash
git add Core/AI/AIController.gd test/unit/test_ai_controller.gd
git commit -m "feat: extend AIController with current_skill, goto(), and interrupt check"
```

---

## Task 4: Generic Attack States

**Files:**
- Create: `Core/AI/Stock/BaseAttackState.gd`
- Create: `Core/AI/Stock/AttackDispatcher.gd`
- Create: `Core/AI/Stock/GenericAttackState.gd`
- Create: `Core/AI/Stock/ComboState.gd`

- [ ] **Step 0: Create BaseAttackState.gd (公共基类)**

```gdscript
# Core/AI/Stock/BaseAttackState.gd
extends AIState
class_name BaseAttackState

## 攻击/组合状态公共基类:方向解析 + 收尾流程

func _finish() -> void:
	var gcd: float = 0.3
	if ai.current_skill:
		gcd = ai.current_skill.params.get(&"global_cooldown", 0.3)
	bb.set_var(&"global_cooldown", gcd)
	ai.current_skill = null
	dispatch(AIEvents.EV_ATTACK_FINISHED)

func _resolve_direction(dir_key: StringName) -> float:
	if not owner_node is Node2D:
		return 0.0
	match dir_key:
		&"forward":
			if "sprite" in owner_node and owner_node.sprite and "flip_h" in owner_node.sprite:
				return -1.0 if owner_node.sprite.flip_h else 1.0
			return 1.0
		&"backward":
			if "sprite" in owner_node and owner_node.sprite and "flip_h" in owner_node.sprite:
				return 1.0 if owner_node.sprite.flip_h else -1.0
			return -1.0
		&"toward_target":
			var tp: Vector2 = bb.get_var(&"target_position", (owner_node as Node2D).global_position)
			return sign(tp.x - (owner_node as Node2D).global_position.x)
		&"away_from_target":
			var tp: Vector2 = bb.get_var(&"target_position", (owner_node as Node2D).global_position)
			return -sign(tp.x - (owner_node as Node2D).global_position.x)
	return 0.0
```

- [ ] **Step 1: Create AttackDispatcher.gd**

```gdscript
# Core/AI/Stock/AttackDispatcher.gd
extends AIState

## 路由状态：读取 pending_skill → 设 current_skill → 跳转目标状态
## 生命周期极短（1帧内跳走）

func enter() -> void:
	var skill: Skill = bb.get_var(&"pending_skill")
	if not skill:
		dispatch(AIEvents.EV_ATTACK_FINISHED)
		return
	ai.current_skill = skill
	if owner_node.has_method(&"_on_skill_start"):
		owner_node._on_skill_start(skill)
	if owner_node.get(&"skill_set"):
		owner_node.skill_set.start_cooldown(skill.id)
	ai.goto(skill.state_name)
```

- [ ] **Step 2: Create GenericAttackState.gd (extends BaseAttackState)**

```gdscript
# Core/AI/Stock/GenericAttackState.gd
extends BaseAttackState

## 通用攻击执行器：播动画 + 可选位移 + 动画结束退出
## 覆盖：普通攻击、后撤、闪避等简单技能

func enter() -> void:
	var skill := ai.current_skill
	if not skill:
		_finish()
		return
	# 停止当前移动
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	# 播放动画
	var anim_name = skill.params.get(&"animation", &"")
	if anim_name and "anim_player" in owner_node and owner_node.anim_player:
		owner_node.anim_player.play(anim_name)
		owner_node.anim_player.animation_finished.connect(_on_anim_done, CONNECT_ONE_SHOT)
	else:
		# 无动画时立即完成
		_finish()
		return
	# 可选位移
	var spd: float = skill.params.get(&"speed", 0.0)
	if spd > 0 and owner_node is CharacterBody2D:
		var dir_key: StringName = skill.params.get(&"direction", &"forward")
		(owner_node as CharacterBody2D).velocity.x = _resolve_direction(dir_key) * spd

func exit() -> void:
	if "anim_player" in owner_node and owner_node.anim_player:
		if owner_node.anim_player.animation_finished.is_connected(_on_anim_done):
			owner_node.anim_player.animation_finished.disconnect(_on_anim_done)

func _on_anim_done(_anim_name: StringName) -> void:
	_finish()

## 动画 method call track 调用：生成投射物
func spawn_projectile() -> void:
	var skill := ai.current_skill
	if not skill:
		return
	var scene: PackedScene = skill.params.get(&"projectile_scene")
	if not scene:
		return
	var proj := scene.instantiate()
	owner_node.get_tree().root.add_child(proj)
	proj.global_position = (owner_node as Node2D).global_position + skill.params.get(&"spawn_offset", Vector2.ZERO)
	var target_pos: Vector2 = bb.get_var(&"target_position", (owner_node as Node2D).global_position)
	if proj.has_method(&"set_direction"):
		proj.set_direction((target_pos - proj.global_position).normalized())

## 动画 method call track 调用：生成实体（陷阱、特效等）
func spawn_entity() -> void:
	var skill := ai.current_skill
	if not skill:
		return
	var scene: PackedScene = skill.params.get(&"spawn_scene")
	if not scene:
		return
	var entity := scene.instantiate()
	owner_node.get_tree().root.add_child(entity)
	entity.global_position = (owner_node as Node2D).global_position + skill.params.get(&"spawn_offset", Vector2.ZERO)
```

- [ ] **Step 3: Create ComboState.gd (extends BaseAttackState)**

```gdscript
# Core/AI/Stock/ComboState.gd
extends BaseAttackState

## 组合技执行器：按序播放子技能的动画 + 参数

var _combo: ComboSkill
var _step: int = 0
var _waiting_gap: bool = false
var _gap_timer: float = 0.0

func enter() -> void:
	_combo = ai.current_skill as ComboSkill
	if not _combo or _combo.sequence.is_empty():
		_finish()
		return
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	_step = 0
	_waiting_gap = false
	_play_step()

func physics_update(delta: float) -> void:
	if _waiting_gap:
		_gap_timer -= delta
		if _gap_timer <= 0:
			_waiting_gap = false
			_play_step()

func exit() -> void:
	if "anim_player" in owner_node and owner_node.anim_player:
		if owner_node.anim_player.animation_finished.is_connected(_on_sub_anim_done):
			owner_node.anim_player.animation_finished.disconnect(_on_sub_anim_done)

func _play_step() -> void:
	if _step >= _combo.sequence.size():
		_finish()
		return
	var sub_skill: Skill = _combo.sequence[_step]
	var anim_name = sub_skill.params.get(&"animation", &"")
	if anim_name and "anim_player" in owner_node and owner_node.anim_player:
		owner_node.anim_player.play(anim_name)
		if not owner_node.anim_player.animation_finished.is_connected(_on_sub_anim_done):
			owner_node.anim_player.animation_finished.connect(_on_sub_anim_done)
	# 可选位移
	var spd: float = sub_skill.params.get(&"speed", 0.0)
	if spd > 0 and owner_node is CharacterBody2D:
		var dir_key: StringName = sub_skill.params.get(&"direction", &"forward")
		(owner_node as CharacterBody2D).velocity.x = _resolve_direction(dir_key) * spd

func _on_sub_anim_done(_anim_name: StringName) -> void:
	_step += 1
	if _step >= _combo.sequence.size():
		# disconnect before finish
		if "anim_player" in owner_node and owner_node.anim_player:
			if owner_node.anim_player.animation_finished.is_connected(_on_sub_anim_done):
				owner_node.anim_player.animation_finished.disconnect(_on_sub_anim_done)
		_finish()
		return
	if _combo.gap > 0:
		_waiting_gap = true
		_gap_timer = _combo.gap
	else:
		_play_step()
```

注：`_finish()` 和 `_resolve_direction()` 继承自 `BaseAttackState`,不重复定义。

- [ ] **Step 4: Commit**

```bash
git add Core/AI/Stock/BaseAttackState.gd Core/AI/Stock/AttackDispatcher.gd Core/AI/Stock/GenericAttackState.gd Core/AI/Stock/ComboState.gd
git commit -m "feat: add BaseAttackState, AttackDispatcher, GenericAttackState, ComboState"
```

---

## Task 5: AgentAIBase Extensions

**Files:**
- Modify: `Core/AI/AgentAIBase.gd`

- [ ] **Step 1: Add skill_set, damage tracking, and sensor to AgentAIBase**

Replace the full content of `Core/AI/AgentAIBase.gd` with:

```gdscript
class_name AgentAIBase extends CharacterBody2D

## AI 角色统一基类
## 职责：gravity + move_and_slide + facing + skill_set + sensor + AI 信号接线

@export var has_gravity: bool = false
@export var gravity_force: float = 800.0
## 美术原图默认朝向：true=朝右，false=朝左
@export var sprite_faces_right: bool = false

@onready var ai: AIController = $AIController
@onready var health_comp: HealthComponent = $HealthComponent
@onready var anim_player: AnimationPlayer = $AnimationPlayer
var sprite: Node2D

var skill_set: SkillSet

# ---- 伤害统计 ----
var _damage_log: Array[Array] = []   # [[timestamp, amount], ...]
const DAMAGE_WINDOW: float = 3.0
var _hit_clear_timer: float = 0.0
const HIT_CLEAR_DELAY: float = 0.5

@onready var _floor_cast_l: RayCast2D = get_node_or_null(^"FloorCastL")
@onready var _floor_cast_r: RayCast2D = get_node_or_null(^"FloorCastR")
@onready var _wall_cast_l: RayCast2D = get_node_or_null(^"WallCastL")
@onready var _wall_cast_r: RayCast2D = get_node_or_null(^"WallCastR")

func _ready() -> void:
	_auto_find_sprite()
	_setup_skill_set()
	_setup_blackboard()
	_setup_transitions()
	_setup_signals()

func _physics_process(delta: float) -> void:
	if has_gravity:
		if not is_on_floor():
			velocity.y += gravity_force * delta
		elif velocity.y > 0:
			velocity.y = 0
	move_and_slide()
	if skill_set:
		skill_set.tick(delta)
	_tick_global_cooldown(delta)
	_tick_hit_clear(delta)
	_update_facing()

func _update_facing() -> void:
	if sprite and "flip_h" in sprite and abs(velocity.x) > 0.1:
		var moving_right := velocity.x > 0
		sprite.flip_h = moving_right != sprite_faces_right

func _auto_find_sprite() -> void:
	sprite = get_node_or_null(^"AnimatedSprite2D")
	if not sprite:
		sprite = get_node_or_null(^"Sprite2D")

# ---- 平台移动助手 ----
func can_move_dir(dir: int) -> bool:
	if dir == 0:
		return true
	if dir > 0:
		var has_floor := _floor_cast_r == null or _floor_cast_r.is_colliding()
		var hit_wall := _wall_cast_r != null and _wall_cast_r.is_colliding()
		return has_floor and not hit_wall
	else:
		var has_floor := _floor_cast_l == null or _floor_cast_l.is_colliding()
		var hit_wall := _wall_cast_l != null and _wall_cast_l.is_colliding()
		return has_floor and not hit_wall

# ---- 子类重写 ----
func _setup_skill_set() -> void:
	skill_set = SkillSet.new()

func _setup_blackboard() -> void:
	var bb := ai.blackboard
	bb.bind_var(&"health", health_comp, &"health")
	bb.bind_var(&"max_health", health_comp, &"max_health")
	bb.set_var(&"global_cooldown", 0.0)
	bb.set_var(&"recently_hit", false)
	bb.set_var(&"damage_recent", 0.0)

func _setup_transitions() -> void:
	pass

func _setup_signals() -> void:
	if health_comp:
		health_comp.damaged.connect(_on_agent_damaged)
		health_comp.died.connect(_on_agent_died)

# ---- 事件处理 ----
func _on_agent_damaged(damage: Damage, attacker_pos: Vector2) -> void:
	var bb := ai.blackboard
	bb.set_var(&"last_damage", damage)
	bb.set_var(&"last_attacker_pos", attacker_pos)
	bb.set_var(&"recently_hit", true)
	_hit_clear_timer = HIT_CLEAR_DELAY
	# 累计伤害
	var now := Time.get_ticks_msec() / 1000.0
	_damage_log.append([now, damage.amount])
	_update_damage_recent()
	ai.dispatch(AIEvents.EV_DAMAGED)

func _on_agent_died() -> void:
	ai.dispatch(AIEvents.EV_DIED)

# ---- 伤害统计 ----
func _update_damage_recent() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var cutoff := now - DAMAGE_WINDOW
	while not _damage_log.is_empty() and _damage_log[0][0] < cutoff:
		_damage_log.pop_front()
	var total := 0.0
	for entry in _damage_log:
		total += entry[1]
	ai.blackboard.set_var(&"damage_recent", total)

func _tick_hit_clear(delta: float) -> void:
	if _hit_clear_timer > 0:
		_hit_clear_timer -= delta
		if _hit_clear_timer <= 0:
			ai.blackboard.set_var(&"recently_hit", false)

func _tick_global_cooldown(delta: float) -> void:
	var gcd: float = ai.blackboard.get_var(&"global_cooldown", 0.0)
	if gcd > 0:
		ai.blackboard.set_var(&"global_cooldown", maxf(gcd - delta, 0.0))

# ---- 数据驱动转换表注册 ----
func _register_rules(rules: Array) -> void:
	for r in rules:
		var from: AIState = null if r[0] == "*" else ai.get_state(StringName(r[0]))
		var to: AIState = ai.get_state(StringName(r[1]))
		if r[0] != "*" and from == null:
			continue
		if to == null:
			continue
		var guard := Callable(self, r[3]) if r[3] != "" else Callable()
		ai.add_transition(from, to, StringName(r[2]), guard, r[4])
```

- [ ] **Step 2: Commit**

```bash
git add Core/AI/AgentAIBase.gd
git commit -m "feat: extend AgentAIBase with skill_set, damage tracking, and global cooldown"
```

---

## Task 6: Update Template Scene

**Files:**
- Modify: `Scenes/Characters/Templates/AgentAIBase.tscn`

- [ ] **Step 1: Add AttackDispatcher, GenericAttackState, ComboState nodes to template**

Use MCP to add the three new State nodes to the template scene's StateMachine. Alternatively, edit the .tscn file directly to add these nodes under `AIController/StateMachine`:

Add ext_resources for the new scripts, then add nodes:

```
[ext_resource type="Script" path="res://Core/AI/Stock/AttackDispatcher.gd" id="11_dispatcher"]
[ext_resource type="Script" path="res://Core/AI/Stock/GenericAttackState.gd" id="12_generic_attack"]
[ext_resource type="Script" path="res://Core/AI/Stock/ComboState.gd" id="13_combo"]
```

Add nodes after Death node:

```
[node name="Dispatcher" type="Node" parent="AIController/StateMachine"]
script = ExtResource("11_dispatcher")

[node name="GenericAttack" type="Node" parent="AIController/StateMachine"]
script = ExtResource("12_generic_attack")

[node name="Combo" type="Node" parent="AIController/StateMachine"]
script = ExtResource("13_combo")
```

- [ ] **Step 2: Verify scene loads**

Run: `mcp__godot__run_project` briefly to confirm no parse errors, then `mcp__godot__stop_project`.

- [ ] **Step 3: Commit**

```bash
git add Scenes/Characters/Templates/AgentAIBase.tscn
git commit -m "feat: add Dispatcher, GenericAttack, Combo nodes to AgentAIBase template"
```

---

## Task 7: DS2 Skill Resources

**Files:**
- Create: `Scenes/Characters/Bosses/DemonSlime2/Skills/ds2_cleave.tres`
- Create: `Scenes/Characters/Bosses/DemonSlime2/Skills/ds2_slam.tres`
- Create: `Scenes/Characters/Bosses/DemonSlime2/Skills/ds2_retreat.tres`

- [ ] **Step 1: Create Skills directory**

```bash
mkdir -p "e:/workspace/4.godot/combo_demon/Scenes/Characters/Bosses/DemonSlime2/Skills"
```

- [ ] **Step 2: Create ds2_cleave.tres**

```
[gd_resource type="Resource" script_class="Skill" load_steps=2 format=3]

[ext_resource type="Script" path="res://Core/AI/Skill.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"cleave"
state_name = &"genericattack"
cooldown = 1.5
weight = 5
min_phase = 0
max_phase = -1
min_range = 0.0
max_range = 250.0
tags = Array[StringName]([&"melee"])
precondition_method = &""
interruptible = true
params = {
&"animation": &"cleave",
&"global_cooldown": 0.3
}
```

- [ ] **Step 3: Create ds2_slam.tres**

```
[gd_resource type="Resource" script_class="Skill" load_steps=2 format=3]

[ext_resource type="Script" path="res://Core/AI/Skill.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"slam"
state_name = &"genericattack"
cooldown = 3.0
weight = 3
min_phase = 1
max_phase = -1
min_range = 0.0
max_range = 180.0
tags = Array[StringName]([&"melee", &"heavy"])
precondition_method = &""
interruptible = true
params = {
&"animation": &"cleave",
&"global_cooldown": 0.5
}
```

Note: `animation` uses `"cleave"` because DS2Slam currently uses `slam_anim = &"cleave"` (same animation). Update to `&"slam"` if a separate slam animation exists.

- [ ] **Step 4: Create ds2_combo_2hit.tres (验证 ComboState)**

ComboSkill 引用两个内置子 Skill。Godot tres 内联子资源:

```
[gd_resource type="Resource" script_class="ComboSkill" load_steps=4 format=3]

[ext_resource type="Script" path="res://Core/AI/ComboSkill.gd" id="1"]
[ext_resource type="Script" path="res://Core/AI/Skill.gd" id="2"]

[sub_resource type="Resource" id="sub_1"]
script = ExtResource("2")
id = &"combo_step1"
params = { &"animation": &"cleave" }

[sub_resource type="Resource" id="sub_2"]
script = ExtResource("2")
id = &"combo_step2"
params = { &"animation": &"cleave" }

[resource]
script = ExtResource("1")
id = &"combo_2hit"
state_name = &"combo"
cooldown = 5.0
weight = 2
min_phase = 1
max_phase = -1
max_range = 200.0
tags = Array[StringName]([&"melee", &"combo"])
interruptible = false
sequence = Array[Resource]([SubResource("sub_1"), SubResource("sub_2")])
gap = 0.15
params = { &"global_cooldown": 0.5 }
```

注:子 Skill 暂复用 `cleave` 动画用于流程验证;真正区分动画时改 `&"animation"` 即可。

- [ ] **Step 5: Commit**

```bash
git add Scenes/Characters/Bosses/DemonSlime2/Skills/
git commit -m "feat: add DS2 skill resources (cleave, slam, combo_2hit)"
```

**Note**: retreat skill 暂未加,等 back_dash 动画就绪后再补(见决策 4B)。

---

## Task 8: DS2 Migration

**Files:**
- Modify: `Scenes/Characters/Bosses/DemonSlime2/DemonSlime2.gd`
- Delete: `Scenes/Characters/Bosses/DemonSlime2/States/DS2Cleave.gd`
- Delete: `Scenes/Characters/Bosses/DemonSlime2/States/DS2Slam.gd`

- [ ] **Step 1: Rewrite DemonSlime2.gd**

Replace full content of `Scenes/Characters/Bosses/DemonSlime2/DemonSlime2.gd`:

```gdscript
class_name DemonSlime2 extends AgentAIBase

## DemonSlime2 — Skill System 试点 Boss

# ---- Boss 特化字段 ----
@export var base_move_speed: float = 80.0
@export var detection_radius: float = 600.0
@export var attack_range: float = 250.0
@export var phase_2_hp_pct: float = 0.66
@export var phase_3_hp_pct: float = 0.33
var current_phase: int = 0

const PHASE_SPEED := { 0: 1.0, 1: 1.3, 2: 1.5 }

var move_speed: float:
	get: return base_move_speed * PHASE_SPEED.get(current_phase, 1.0)

func _ready() -> void:
	super._ready()
	if health_comp:
		health_comp.health_changed.connect(_on_health_changed)

# ---- 技能配置 ----
func _setup_skill_set() -> void:
	skill_set = SkillSet.new()
	skill_set.setup([
		preload("res://Scenes/Characters/Bosses/DemonSlime2/Skills/ds2_cleave.tres"),
		preload("res://Scenes/Characters/Bosses/DemonSlime2/Skills/ds2_slam.tres"),
		preload("res://Scenes/Characters/Bosses/DemonSlime2/Skills/ds2_combo_2hit.tres"),
	])

# ---- Blackboard ----
func _setup_blackboard() -> void:
	super._setup_blackboard()
	var bb := ai.blackboard
	bb.bind_var(&"current_phase", self, &"current_phase")
	bb.set_var(&"detection_radius", detection_radius)
	bb.set_var(&"chase_speed", base_move_speed)

# ---- 转换表 ----
func _setup_transitions() -> void:
	_register_rules([
		# 结构性转换
		["idle",    "chase",      "",                          "_guard_detected",      10],
		["wander",  "chase",      "",                          "_guard_detected",      10],
		["chase",   "idle",       "",                          "_guard_target_lost",    0],

		# 攻击场景（走 dispatcher）
		["chase",   "dispatcher", "",                          "_guard_can_attack",    10],

		# 攻击完成
		["*",       "chase",      AIEvents.EV_ATTACK_FINISHED, "_guard_target_alive",   0],
		["*",       "idle",       AIEvents.EV_ATTACK_FINISHED, "",                      0],

		# 受击 / 死亡
		["*",       "death",      AIEvents.EV_DIED,            "",                    100],
		["*",       "hit",        AIEvents.EV_DAMAGED,         "_guard_can_interrupt", 10],
		["hit",     "chase",      AIEvents.EV_HIT_RECOVERED,   "_guard_target_alive",  10],
		["hit",     "idle",       AIEvents.EV_HIT_RECOVERED,   "",                      0],
	])

# ---- Guard methods ----
func _guard_detected() -> bool:
	var bb := ai.blackboard
	return bb.get_var(&"target_alive", false) and bb.get_var(&"distance", INF) < detection_radius

func _guard_target_lost() -> bool:
	var bb := ai.blackboard
	return not bb.get_var(&"target_alive", false) or bb.get_var(&"distance", INF) > 700.0

func _guard_target_alive() -> bool:
	return ai.blackboard.get_var(&"target_alive", false)

## 普通攻击
func _guard_can_attack() -> bool:
	if ai.blackboard.get_var(&"global_cooldown", 0.0) > 0:
		return false
	var skill := skill_set.pick(self, ai.blackboard)
	if skill:
		ai.blackboard.set_var(&"pending_skill", skill)
		return true
	return false

## 当前技能是否可被打断
func _guard_can_interrupt() -> bool:
	return ai.current_skill == null or ai.current_skill.interruptible

# ---- Phase system ----
func _on_health_changed(current: float, maximum: float) -> void:
	var pct := current / maxf(maximum, 1.0)
	var new_phase := current_phase
	if pct <= phase_3_hp_pct:
		new_phase = 2
	elif pct <= phase_2_hp_pct:
		new_phase = 1
	if new_phase != current_phase:
		current_phase = new_phase
		ai.blackboard.set_var(&"chase_speed", move_speed)
		ai.dispatch(AIEvents.EV_PHASE_CHANGED)
```

- [ ] **Step 2: Delete DS2Cleave.gd, DS2Slam.gd, and obsolete integration test**

```bash
git rm "Scenes/Characters/Bosses/DemonSlime2/States/DS2Cleave.gd"
git rm "Scenes/Characters/Bosses/DemonSlime2/States/DS2Slam.gd"
git rm "test/integration/test_ds2.gd"
```

注:`test/integration/test_ds2.gd` 测试旧 `attack_cooldown`/`last_action` 转换表,被 Task 9 的 `test_ds2_skills.gd` 取代。

- [ ] **Step 3: Update DS2 scene tree**

Remove the Cleave and Slam nodes from `DemonSlime2.tscn` if they exist. Ensure the scene inherits from the updated AgentAIBase.tscn (which now includes Dispatcher, GenericAttack, Combo nodes). Check that no orphan references remain.

- [ ] **Step 4: Commit**

```bash
git add Scenes/Characters/Bosses/DemonSlime2/DemonSlime2.gd Scenes/Characters/Bosses/DemonSlime2/
git commit -m "feat: migrate DS2 to skill system, delete DS2Cleave and DS2Slam"
```

---

## Task 9: Integration Tests

**Files:**
- Create: `test/integration/test_ds2_skills.gd`

- [ ] **Step 1: Write DS2 skill system integration tests**

```gdscript
# test/integration/test_ds2_skills.gd
extends GutTest

## DS2 Skill System 集成测试
## 验证 SkillSet + AIController + 转换表 协同工作

var _owner: CharacterBody2D
var _ai: AIController
var _ss: SkillSet
var _bb: AIBlackboard

func before_each() -> void:
	_owner = CharacterBody2D.new()
	_owner.name = "TestDS2"
	add_child_autofree(_owner)

	_ai = AIController.new()
	_ai.name = "AIController"
	_ai.initial_state_name = &"idle"
	_owner.add_child(_ai)
	_ai.set_owner(_owner)

	var sm := Node.new()
	sm.name = "StateMachine"
	_ai.add_child(sm)

	for sn in ["Idle", "Chase", "Hit", "Death", "Dispatcher", "GenericAttack", "Combo"]:
		var s := AIState.new()
		s.name = sn
		sm.add_child(s)

	await get_tree().process_frame
	await get_tree().process_frame

	_bb = _ai.blackboard
	_bb.set_var(&"current_phase", 0)
	_bb.set_var(&"distance", 150.0)
	_bb.set_var(&"target_alive", true)
	_bb.set_var(&"global_cooldown", 0.0)
	_bb.set_var(&"damage_recent", 0.0)

	# Setup skill set
	_ss = SkillSet.new()
	var cleave := Skill.new()
	cleave.id = &"cleave"
	cleave.state_name = &"genericattack"
	cleave.cooldown = 1.5
	cleave.weight = 5
	cleave.max_range = 250.0

	var slam := Skill.new()
	slam.id = &"slam"
	slam.state_name = &"genericattack"
	slam.cooldown = 3.0
	slam.weight = 3
	slam.min_phase = 1
	slam.max_range = 180.0

	var combo := ComboSkill.new()
	combo.id = &"combo_2hit"
	combo.cooldown = 5.0
	combo.weight = 2
	combo.min_phase = 1
	combo.max_range = 200.0
	var sub1 := Skill.new(); sub1.id = &"step1"; sub1.params = { &"animation": &"cleave" }
	var sub2 := Skill.new(); sub2.id = &"step2"; sub2.params = { &"animation": &"cleave" }
	combo.sequence = [sub1, sub2]

	_ss.setup([cleave, slam, combo])

# ============ Phase 0: only cleave ============

func test_phase0_picks_cleave() -> void:
	_bb.set_var(&"current_phase", 0)
	var picked := _ss.pick(_owner, _bb)
	assert_not_null(picked)
	assert_eq(picked.id, &"cleave")

func test_phase0_cleave_repeats_after_cooldown() -> void:
	_bb.set_var(&"current_phase", 0)
	var p1 := _ss.pick(_owner, _bb)
	assert_eq(p1.id, &"cleave")
	_ss.start_cooldown(&"cleave")
	assert_null(_ss.pick(_owner, _bb), "on cooldown")
	_ss.tick(2.0)
	var p2 := _ss.pick(_owner, _bb)
	assert_not_null(p2, "cooldown expired, can pick again")
	assert_eq(p2.id, &"cleave", "cleave repeats — no last_action bug")

# ============ Phase 1: cleave + slam ============

func test_phase1_unlocks_slam() -> void:
	_bb.set_var(&"current_phase", 1)
	_bb.set_var(&"distance", 150.0)
	var found_slam := false
	for i in 50:
		var p := _ss.pick(_owner, _bb)
		if p and p.id == &"slam":
			found_slam = true
			break
	assert_true(found_slam, "slam should appear at phase 1")

# ============ ComboSkill ============

func test_combo_unlocks_at_phase1() -> void:
	_bb.set_var(&"current_phase", 1)
	_bb.set_var(&"distance", 150.0)
	var found_combo := false
	for i in 80:
		var p := _ss.pick(_owner, _bb)
		if p and p.id == &"combo_2hit":
			found_combo = true
			assert_true(p is ComboSkill, "combo should be ComboSkill")
			assert_false(p.interruptible, "combo defaults to non-interruptible")
			assert_eq((p as ComboSkill).sequence.size(), 2)
			break
	assert_true(found_combo, "combo_2hit should appear at phase 1")

func test_combo_locked_at_phase0() -> void:
	_bb.set_var(&"current_phase", 0)
	_bb.set_var(&"distance", 150.0)
	for i in 30:
		var p := _ss.pick(_owner, _bb)
		assert_ne(p.id, &"combo_2hit", "combo should not appear at phase 0")

# ============ Interrupt check ============

func test_non_interruptible_blocks_damaged() -> void:
	var skill := Skill.new()
	skill.interruptible = false
	_ai.current_skill = skill

	var hit := _ai.get_state(&"hit")
	_ai.add_transition(null, hit, AIEvents.EV_DAMAGED)
	_ai.dispatch(AIEvents.EV_DAMAGED)
	assert_eq(_ai.get_current_state_name(), &"idle", "blocked by non-interruptible")

func test_non_interruptible_allows_died() -> void:
	var skill := Skill.new()
	skill.interruptible = false
	_ai.current_skill = skill

	var death := _ai.get_state(&"death")
	_ai.add_transition(null, death, AIEvents.EV_DIED)
	_ai.dispatch(AIEvents.EV_DIED)
	assert_eq(_ai.get_current_state_name(), &"death", "EV_DIED penetrates")

# ============ Distance filter ============

func test_out_of_range_no_attack() -> void:
	_bb.set_var(&"distance", 500.0)
	assert_null(_ss.pick(_owner, _bb), "too far for any attack")

# ============ Cooldown isolation ============

func test_per_skill_cooldown_isolation() -> void:
	_bb.set_var(&"current_phase", 1)
	_bb.set_var(&"distance", 150.0)
	_ss.start_cooldown(&"cleave")
	# cleave on cd, but slam should still be available
	var picked := _ss.pick(_owner, _bb)
	assert_not_null(picked)
	assert_eq(picked.id, &"slam", "slam available while cleave on cooldown")
```

- [ ] **Step 2: Run integration tests**

Run: `cd e:/workspace/4.godot/combo_demon && bash test/run_tests.sh test/integration/test_ds2_skills.gd`
Expected: All tests PASS

- [ ] **Step 3: Run all tests to check for regressions**

Run: `cd e:/workspace/4.godot/combo_demon && bash test/run_tests.sh`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add test/integration/test_ds2_skills.gd
git commit -m "test: add DS2 skill system integration tests"
```

---

## Task 10: Runtime Verification

**Files:** None (verification only)

- [ ] **Step 1: Launch game and test DS2 basic attack loop**

Run: `mcp__godot__run_project`
Verify: DS2 detects player → chases → dispatches → plays cleave animation → returns to chase

- [ ] **Step 2: Check debug output**

Run: `mcp__godot__get_debug_output`
Expected log lines:
```
[AI] → Chase
[AI] → Dispatcher
[AI] → GenericAttack
[AI] → Chase
```

- [ ] **Step 3: Test phase transitions**

Damage DS2 below 66% HP → verify slam appears in attack rotation.
Damage DS2 below 33% HP → verify phase 2 behavior.

- [ ] **Step 4: Test continuous attacks in phase 0**

Verify DS2 can cleave repeatedly without getting stuck (the original `last_action` bug).

- [ ] **Step 4.5: Test combo at phase 1+**

Damage DS2 to phase 1, observe boss occasionally fires `combo_2hit` (two consecutive cleave animations with 0.15s gap). Verify combo is non-interruptible.

- [ ] **Step 5: Stop project**

Run: `mcp__godot__stop_project`

- [ ] **Step 6: Final commit if any fixes needed**

If runtime testing revealed issues, fix and commit:

```bash
git add -A
git commit -m "fix: address runtime issues found during skill system verification"
```
