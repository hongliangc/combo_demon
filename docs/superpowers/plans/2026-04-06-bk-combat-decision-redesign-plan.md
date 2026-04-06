# BladeKeeper Combat Decision Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix BladeKeeper's Attack/Chase oscillation, rework DODGE into a 3-phase sequence (backflip + projectile + trap), move defend/roll/jump out of the attack pool into reactive triggers, and fix Chase cooldown freeze.

**Architecture:** BKAttack becomes a self-contained combat loop with internal distance checks. DODGE sequence expanded to 3 sub-steps reusing existing `fire_sword_projectile()` and `place_trap()`. Evasion (defend/roll) triggered from `on_damaged` via new BossBase exports. Chase freeze fixed by removing early return on cooldown.

**Tech Stack:** GDScript (Godot 4.4.1), existing animation/VFX infrastructure

**Spec:** `docs/superpowers/specs/2026-04-06-bk-combat-decision-redesign.md`

---

### Task 1: Fix Chase cooldown freeze

**Files:**
- Modify: `Core/StateMachine/CommonStates/ChaseState.gd:71-76`

- [ ] **Step 1: Fix the early return**

In `Core/StateMachine/CommonStates/ChaseState.gd`, change lines 71-76 from:

```gdscript
	# 进入攻击范围
	if distance <= attack_range:
		var target_state := _on_reached_attack_range()
		if target_state != "":
			transition_to(target_state)
		return
```

to:

```gdscript
	# 进入攻击范围
	if distance <= attack_range:
		var target_state := _on_reached_attack_range()
		if target_state != "":
			transition_to(target_state)
			return
		# 冷却中：继续移动跟随，不卡死
```

The only change: move `return` inside the `if target_state != ""` block. When on cooldown (empty target_state), fall through to movement code below.

- [ ] **Step 2: Commit**

```bash
git add Core/StateMachine/CommonStates/ChaseState.gd
git commit -m "fix: Chase no longer freezes when in attack range but on cooldown"
```

---

### Task 2: Clean BKAttackManager attack pools

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/BKAttackManager.gd:98-141`

- [ ] **Step 1: Rewrite _setup_default_phases**

In `Scenes/Characters/Bosses/BladeKeeper/BKAttackManager.gd`, replace `_setup_default_phases()` (lines 99-141) with:

```gdscript
func _setup_default_phases() -> void:
	# Phase 1: 基础近战
	var p1 := BossPhaseConfig.new()
	p1.cooldown = 1.5
	p1.attacks = [
		{"mode": "attack", "weight": 5},
		{"mode": "combo", "weight": 2, "counter": true},
		{"mode": "projectile", "weight": 1},
	]
	phase_configs[BossBase.Phase.PHASE_1] = p1

	# Phase 2: 加入陷阱/特殊
	var p2 := BossPhaseConfig.new()
	p2.cooldown = 1.2
	p2.attacks = [
		{"mode": "combo", "weight": 3},
		{"mode": "projectile", "weight": 2},
		{"mode": "trap", "weight": 2},
		{"mode": "special", "weight": 1, "counter": true},
	]
	phase_configs[BossBase.Phase.PHASE_2] = p2

	# Phase 3: 全技能 + 更激进
	var p3 := BossPhaseConfig.new()
	p3.cooldown = 0.8
	p3.attacks = [
		{"mode": "combo", "weight": 3, "counter": true},
		{"mode": "projectile", "weight": 2},
		{"mode": "trap", "weight": 2},
		{"mode": "special", "weight": 2},
	]
	phase_configs[BossBase.Phase.PHASE_3] = p3

	DebugConfig.debug("[BKAttackManager] 默认阶段配置已加载 (3 phases)", "", "combat")
```

Changes vs current: removed `defend`, `roll`, `jump` from all phases. Restored `attack` in Phase 1.

- [ ] **Step 2: Commit**

```bash
git add Scenes/Characters/Bosses/BladeKeeper/BKAttackManager.gd
git commit -m "fix: remove defend/roll/jump from BK attack pools, restore attack in Phase 1"
```

---

### Task 3: Simplify BKChase route matching

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/States/BKChase.gd:40-51`

- [ ] **Step 1: Remove defend/roll from match**

In `Scenes/Characters/Bosses/BladeKeeper/States/BKChase.gd`, replace `_on_reached_attack_range()` match block (lines 40-51) with:

```gdscript
	match mode:
		"projectile":
			return "projectile"
		"trap":
			return "trap"
		_:
			# attack, combo, special 统一由 BKAttack 处理
			return "attack"
```

- [ ] **Step 2: Commit**

```bash
git add Scenes/Characters/Bosses/BladeKeeper/States/BKChase.gd
git commit -m "fix: simplify BKChase route — only projectile/trap have dedicated states"
```

---

### Task 4: Rework BKAttack — self-loop + DODGE 3-phase sequence

This is the largest task. It rewrites BKAttack's Step enum, DODGE logic, and `_finish_attack()`.

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/States/BKAttack.gd`

- [ ] **Step 1: Update Step enum**

Replace the Step enum (lines 28-36) with:

```gdscript
enum Step {
	NONE,
	ATK,           ## 普通攻击（随机 atk_1/2/3）
	SP_ATK,        ## 特殊攻击
	DODGE_START,   ## 后空翻起跳 + 放陷阱
	DODGE_AIR,     ## 空中投匕首
	DODGE_LAND,    ## 落地
	JUMP_UP,       ## 跳跃上升 + 靠近
	AIR_ATK,       ## 空中攻击
	JUMP_DOWN,     ## 下落
}
```

- [ ] **Step 2: Add DODGE parameters**

Replace existing dodge exports (lines 22-23) with:

```gdscript
## dodge 后空翻参数
@export var dodge_speed := 300.0
@export var dodge_duration := 0.5
@export var dodge_projectile_delay := 0.25  ## 空中投匕首时机（起跳后延迟）
```

- [ ] **Step 3: Rewrite _finish_attack with distance check**

Replace `_finish_attack()` (lines 249-252) with:

```gdscript
## 结束攻击 — 距离判断决定继续攻击还是 chase
func _finish_attack() -> void:
	exit_control_state()
	var boss := get_boss()
	if not boss:
		transitioned.emit(self, "chase")
		return

	var distance := boss.global_position.distance_to(target_node.global_position) if target_node else 9999.0
	if distance <= boss.attack_range:
		# 贴身：继续攻击
		_start_next_attack()
	else:
		# 拉开了：回 chase
		boss.can_move = true
		transitioned.emit(self, "chase")
```

- [ ] **Step 4: Add _start_next_attack helper**

Add after `_finish_attack()`:

```gdscript
## 重新 pick 攻击并启动（自循环用）
func _start_next_attack() -> void:
	var boss := get_boss()
	if not boss:
		transitioned.emit(self, "chase")
		return

	# 检查冷却
	if boss.attack_cooldown > 0:
		boss.can_move = true
		transitioned.emit(self, "chase")
		return

	var mgr := get_attack_manager()
	if not mgr:
		boss.can_move = true
		transitioned.emit(self, "chase")
		return

	var entry: Dictionary = mgr.pick_attack()
	_mode = entry.get("mode", "attack")
	boss.attack_cooldown = mgr.get_cooldown()

	_face_player(boss)

	match _mode:
		"attack":
			_start_step(Step.ATK)
		"combo":
			_start_step(Step.ATK)
		"special":
			_start_step(Step.SP_ATK)
		"projectile":
			exit_control_state()
			boss.can_move = true
			transitioned.emit(self, "projectile")
		"trap":
			exit_control_state()
			boss.can_move = true
			transitioned.emit(self, "trap")
		_:
			_start_step(Step.ATK)
```

- [ ] **Step 5: Rewrite _on_atk_finished — combo always ends with DODGE**

Replace `_on_atk_finished()` (lines 163-175) with:

```gdscript
func _on_atk_finished() -> void:
	match _mode:
		"combo":
			# combo 模式：概率进入 sp_atk，否则直接 DODGE 序列
			var boss := get_boss()
			var chance: float = SP_ATK_CHANCE.get(boss.current_phase, 0.1) if boss else 0.1
			if randf() < chance:
				_start_step(Step.SP_ATK)
			else:
				_start_dodge_sequence()
		_:
			# attack/其他：距离判断
			_finish_attack()
```

- [ ] **Step 6: Rewrite _on_sp_atk_finished**

Replace `_on_sp_atk_finished()` (lines 178-184) with:

```gdscript
func _on_sp_atk_finished() -> void:
	match _mode:
		"combo":
			# combo 中的 sp_atk 结束 → DODGE 序列
			_start_dodge_sequence()
		_:
			# 独立 special 模式 → 距离判断
			_finish_attack()
```

- [ ] **Step 7: Rewrite DODGE as 3-phase sequence**

Replace `_start_dodge()` and `_on_dodge_finished()` (lines 218-241) with:

```gdscript
## ============ DODGE 三阶段序列 ============

## 启动 DODGE 序列：后空翻 + 投匕首 + 布陷阱
func _start_dodge_sequence() -> void:
	_current_step = Step.DODGE_START
	var boss := get_boss()
	if not boss:
		_force_exit_to_chase()
		return

	# 后空翻方向：背离 player
	var dodge_dir := Vector2.RIGHT
	if target_node:
		dodge_dir = (boss.global_position - target_node.global_position).normalized()
	boss.velocity = dodge_dir * dodge_speed

	# 在起跳位置放陷阱
	var mgr := get_attack_manager()
	if mgr:
		mgr.place_trap(boss.global_position)

	# 播放 trap_cast 动画
	enter_control_state("trap_cast")
	DebugConfig.debug("[BKAttack] DODGE_START (trap placed)", "", "combat")

	# 延迟投匕首
	var proj_timer := get_tree().create_timer(dodge_projectile_delay)
	proj_timer.timeout.connect(_on_dodge_projectile_time)

	# 整个 DODGE 持续时间
	_dodge_timer = get_tree().create_timer(dodge_duration)
	_dodge_timer.timeout.connect(_on_dodge_land)


func _on_dodge_projectile_time() -> void:
	if _current_step != Step.DODGE_START and _current_step != Step.DODGE_AIR:
		return
	_current_step = Step.DODGE_AIR
	# 空中投匕首
	var mgr := get_attack_manager()
	var target_pos: Vector2 = target_node.global_position if target_node else Vector2.ZERO
	if mgr:
		mgr.fire_sword_projectile(target_pos)
	DebugConfig.debug("[BKAttack] DODGE_AIR (projectile fired)", "", "combat")


func _on_dodge_land() -> void:
	_current_step = Step.DODGE_LAND
	var boss := get_boss()
	if boss:
		boss.velocity = Vector2.ZERO
	DebugConfig.debug("[BKAttack] DODGE_LAND → chase", "", "combat")
	_force_exit_to_chase()


## 强制退出到 chase（DODGE 结束统一出口）
func _force_exit_to_chase() -> void:
	exit_control_state()
	var boss := get_boss()
	if boss:
		boss.can_move = true
	transitioned.emit(self, "chase")
```

- [ ] **Step 8: Update _start_step to handle new DODGE steps**

In `_start_step()` (lines 132-158), remove the old `Step.DODGE` case. The DODGE sequence is now started via `_start_dodge_sequence()` directly, not through `_start_step()`. If the match still has `Step.DODGE`, remove it.

- [ ] **Step 9: Update _on_animation_finished — remove old DODGE handling**

In `_on_animation_finished()` (lines 105-127), the DODGE steps are now timer-driven, not animation-driven. No changes needed — the existing match doesn't have a DODGE case (DODGE used a timer already). Verify the method still works for ATK, SP_ATK, JUMP_UP, AIR_ATK, JUMP_DOWN.

- [ ] **Step 10: Update physics_process_state — handle DODGE_START/AIR movement**

In `physics_process_state()` (lines 87-102), the existing DODGE case was a no-op. Update to handle new steps:

```gdscript
func physics_process_state(_delta: float) -> void:
	# jump_up 阶段：向 player 移动
	if _current_step == Step.JUMP_UP and not _jump_reached:
		var boss := get_boss()
		if boss and target_node:
			var direction: Vector2 = (target_node.global_position - boss.global_position).normalized()
			boss.velocity = direction * jump_approach_speed
			var distance := boss.global_position.distance_to(target_node.global_position)
			if distance <= boss.attack_range:
				_jump_reached = true
				boss.velocity = Vector2.ZERO

	# DODGE 阶段：velocity 在 _start_dodge_sequence() 中设置，由 BossBase.move_and_slide 处理
```

- [ ] **Step 11: Update exit() — disconnect new timers**

Replace `exit()` (lines 265-281) with:

```gdscript
func exit() -> void:
	exit_control_state()
	_current_step = Step.NONE

	# 断开动画信号
	if _anim_tree_ref and _anim_tree_ref.animation_finished.is_connected(_on_animation_finished):
		_anim_tree_ref.animation_finished.disconnect(_on_animation_finished)

	# 断开 dodge 计时器
	if _dodge_timer and _dodge_timer.timeout.is_connected(_on_dodge_land):
		_dodge_timer.timeout.disconnect(_on_dodge_land)

	# 恢复移动
	var boss := get_boss()
	if boss:
		boss.velocity = Vector2.ZERO
		boss.can_move = true
```

- [ ] **Step 12: Update _on_jump_down_finished — combo接地用DODGE序列**

Replace `_on_jump_down_finished()` (lines 203-213) with:

```gdscript
func _on_jump_down_finished() -> void:
	var boss := get_boss()
	if boss:
		_face_player(boss)
	# 落地后概率接地面 combo 或直接 DODGE 序列
	if randf() < GROUND_COMBO_AFTER_JUMP_CHANCE:
		_mode = "combo"
		_start_step(Step.ATK)
	else:
		_start_dodge_sequence()
```

- [ ] **Step 13: Commit**

```bash
git add Scenes/Characters/Bosses/BladeKeeper/States/BKAttack.gd
git commit -m "feat: rework BKAttack — self-loop distance check + 3-phase DODGE sequence"
```

---

### Task 5: Add evasion system to BossBase + BossBaseState

**Files:**
- Modify: `Core/Characters/BossBase.gd:44-50`
- Modify: `Scenes/Characters/Bosses/Shared/BossBaseState.gd:121-141`

- [ ] **Step 1: Add evasion exports to BossBase**

In `Core/Characters/BossBase.gd`, add after the Phase Settings group (after line 44, before Poise / Counter group):

```gdscript
@export_group("Evasion")
@export var evasion_enabled := false         ## 是否启用受击闪避机制
@export var evasion_chance_per_phase: Dictionary = {} ## {Phase: 概率}
```

- [ ] **Step 2: Update on_damaged with evasion check**

In `Scenes/Characters/Bosses/Shared/BossBaseState.gd`, replace `on_damaged` (lines 123-141) with:

```gdscript
## Boss 特有的 on_damaged 实现
## 优先级：poise 反击 > 闪避(defend/roll) > Phase 3 免疫 > stun
func on_damaged(_damage: Damage, _attacker_position: Vector2 = Vector2.ZERO) -> void:
	var boss := get_boss()
	if not boss:
		return
	if boss.stun_immunity > 0:
		return

	# Poise 检查（优先于闪避和 stun）
	if boss.poise_enabled and boss.take_poise_hit():
		transitioned.emit(self, "counter")
		return

	# 闪避检查：概率触发 defend 或 roll
	if boss.evasion_enabled:
		var chance: float = boss.evasion_chance_per_phase.get(boss.current_phase, 0.0)
		if chance > 0 and randf() < chance:
			var evasion_state: String = ["defend", "roll"].pick_random()
			transitioned.emit(self, evasion_state)
			return

	# Phase 3 眩晕免疫
	if boss.current_phase == BossBase.Phase.PHASE_3:
		return

	transitioned.emit(self, "stun")
```

- [ ] **Step 3: Commit**

```bash
git add Core/Characters/BossBase.gd Scenes/Characters/Bosses/Shared/BossBaseState.gd
git commit -m "feat: add evasion system — on_damaged triggers defend/roll by chance"
```

---

### Task 6: Configure BladeKeeper evasion + fix _on_boss_ready

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd`

- [ ] **Step 1: Move params to _init, add evasion config**

Replace `_on_boss_ready()` (lines 20-27) with `_init()`:

```gdscript
func _init() -> void:
	# 覆盖 BossBase 默认值（inspector 可进一步调整）
	detection_radius = 800.0
	attack_range = 200.0
	is_melee = true
	# 闪避反应
	evasion_enabled = true
	evasion_chance_per_phase = {Phase.PHASE_1: 0.15, Phase.PHASE_2: 0.25, Phase.PHASE_3: 0.35}
	# Poise 反击系统
	poise_enabled = true
	max_poise = 5
	poise_per_phase = {Phase.PHASE_2: 4, Phase.PHASE_3: 3}
```

- [ ] **Step 2: Commit**

```bash
git add Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.gd
git commit -m "feat: configure BK evasion (15%/25%/35%) + move params to _init"
```

---

### Task 7: Make BKRoll dodge backwards

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/States/BKRoll.gd:26-30`

- [ ] **Step 1: Change roll direction from sideways to backwards**

In `Scenes/Characters/Bosses/BladeKeeper/States/BKRoll.gd`, replace the direction logic (lines 26-30) with:

```gdscript
	# 向后闪避（背离玩家）
	_roll_direction = (boss.global_position - target_node.global_position).normalized()
```

- [ ] **Step 2: Commit**

```bash
git add Scenes/Characters/Bosses/BladeKeeper/States/BKRoll.gd
git commit -m "fix: BKRoll dodges backwards (away from player) instead of sideways"
```

---

### Task 8: Add jump tracking in BKChase

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/States/BKChase.gd`

- [ ] **Step 1: Add airborne player detection before attack range check**

In `Scenes/Characters/Bosses/BladeKeeper/States/BKChase.gd`, the class currently overrides `enter()` and `_on_reached_attack_range()`. Add a `physics_process_state` override to detect airborne player.

Add after `_on_reached_attack_range()`:

```gdscript
func physics_process_state(delta: float) -> void:
	# 检测玩家是否在空中 → 跳追
	if target_node and target_node is CharacterBody2D:
		var target_body := target_node as CharacterBody2D
		if not target_body.is_on_floor() and state_machine.states.has("jump"):
			transition_to("jump")
			return

	# 其余逻辑由父类 ChaseState 处理
	super.physics_process_state(delta)
```

Note: this assumes a "Jump" state node exists in the StateMachine (BKAttack handles JUMP_UP/AIR_ATK/JUMP_DOWN internally via its Step enum). If the jump state doesn't exist in the state machine, `states.has("jump")` returns false and this is safely skipped.

- [ ] **Step 2: Commit**

```bash
git add Scenes/Characters/Bosses/BladeKeeper/States/BKChase.gd
git commit -m "feat: BKChase detects airborne player and transitions to jump tracking"
```

---

### Task 9: Integration test

- [ ] **Step 1: Run project and verify**

Run: `mcp__godot__run_project`

Test checklist:
1. Chase: Boss follows player smoothly, no freeze when in range + on cooldown
2. Phase 1: Boss uses attack (single hit) and combo, no defend/roll/jump in attack choices
3. Combo: ATK → (chance SP_ATK) → DODGE (backflip + trap placed + projectile thrown) → chase
4. DODGE: trap appears at launch position, projectile fires mid-air, boss returns to chase after landing
5. Attack self-loop: after single attack, if still close, boss picks another attack instead of chasing
6. Evasion: hit the boss — sometimes triggers defend, sometimes roll (backwards), sometimes stun
7. Poise: hit boss 5 times — counter triggers

- [ ] **Step 2: Check debug output**

Run: `mcp__godot__get_debug_output`

Expected log lines:
- `[BKAttack] DODGE_START (trap placed)`
- `[BKAttack] DODGE_AIR (projectile fired)`
- `[BKAttack] DODGE_LAND → chase`
- No errors

- [ ] **Step 3: Commit fixes if needed**

```bash
git add -A
git commit -m "fix: integration fixes for BK combat decision redesign"
```

---

## Task Dependency Summary

```
Task 1 (Chase freeze fix) ─── independent
Task 2 (Attack pool cleanup) → Task 3 (BKChase route) → Task 4 (BKAttack rework)
Task 5 (Evasion system) → Task 6 (BK evasion config)
Task 7 (BKRoll backwards) ─── independent
Task 8 (Jump tracking) ─── independent (but after Task 3)
Task 9 (Integration test) ─── after all others
```

Tasks 1, 2, 5, 7 can run in parallel. Task 4 depends on Task 2-3. Task 9 is last.
