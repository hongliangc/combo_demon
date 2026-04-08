# Hit State 伤害流程重构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move `apply_attack_effects()` from HealthComponent to HitState, making HitState the single unified damage-reaction state that replaces Stun/Knockback states.

**Architecture:** HealthComponent only deducts HP and emits signals. BaseStateMachine caches damage data. HitState reads cached damage on enter, applies effects (property changes + animations), and manages duration/physics. StunEffect/ForceStunEffect become pure data — no state machine manipulation. All Stun/Knockback state nodes and scripts are deleted.

**Tech Stack:** Godot 4.4.1, GDScript, Node-based state machine

---

### Task 1: Strip HealthComponent — remove apply_attack_effects call

**Files:**
- Modify: `Core/Components/HealthComponent.gd:61-108`

- [ ] **Step 1: Remove apply_attack_effects() call from take_damage()**

In `Core/Components/HealthComponent.gd`, replace the `take_damage()` method. Remove the `apply_attack_effects()` call at line 84 and the comment block at lines 81-83. Also delete the `apply_attack_effects()` method (lines 104-108) and update the class docstring (lines 13-19):

```gdscript
## 信号流:
##   HurtBoxComponent.damaged → HealthComponent.take_damage()
##       ├─→ 扣血
##       ├─→ 显示伤害数字
##       ├─→ 发出 health_changed 信号 → 血条 UI
##       └─→ 发出 damaged 信号 → 状态机响应（HitState 应用攻击特效）
```

Remove lines 81-84 (the comment block and `apply_attack_effects` call) so `take_damage()` becomes:

```gdscript
func take_damage(damage_data: Damage, attacker_position: Vector2 = Vector2.ZERO) -> void:
	if not is_alive:
		return

	# 无敌状态检查
	if is_invincible:
		DebugConfig.debug("%s 处于无敌状态，忽略伤害" % owner_body.name, "", "combat")
		return

	# 扣除生命值
	var damage_amount = damage_data.amount
	health -= damage_amount
	health = max(0, health)

	# 显示伤害数字
	display_damage_number(damage_data)

	# 发出信号（让状态机等监听者响应）
	health_changed.emit(health, max_health)
	damaged.emit(damage_data, attacker_position)

	# 检查死亡
	if health <= 0:
		die()
```

Delete the entire `apply_attack_effects()` method (lines 104-108).

- [ ] **Step 2: Verify no compile errors**

Run: `grep -rn "apply_attack_effects" Core/Components/HealthComponent.gd`
Expected: No matches

---

### Task 2: Add damage cache to BaseStateMachine + clean debug prints

**Files:**
- Modify: `Core/StateMachine/BaseStateMachine.gd:23-35,128-177,200-219`

- [ ] **Step 1: Add cache variables**

In `Core/StateMachine/BaseStateMachine.gd`, after line 35 (`var target_node: Node`), add:

```gdscript
## 缓存最近一次伤害数据（供 HitState.enter() 读取）
var last_damage: Damage = null
var last_attacker_position: Vector2 = Vector2.ZERO
```

- [ ] **Step 2: Rewrite _on_owner_damaged — cache + clean debug**

Replace the entire `_on_owner_damaged()` method (lines 171-177) with:

```gdscript
## 当 owner 受到伤害时
func _on_owner_damaged(damage: Damage, attacker_position: Vector2 = Vector2.ZERO) -> void:
	last_damage = damage
	last_attacker_position = attacker_position
	if current_state and current_state.has_method("on_damaged"):
		current_state.on_damaged(damage, attacker_position)
```

- [ ] **Step 3: Clean debug prints in _on_state_transition**

Replace lines 131-148 of `_on_state_transition()` — remove `print()` calls, keep `DebugConfig.debug()`:

```gdscript
func _on_state_transition(from_state: BaseState, new_state_name: String) -> void:
	var _owner_name := str(owner_node.name) if owner_node else "Unknown"

	# 只处理当前状态的转换请求
	if from_state != current_state:
		return

	# 查找新状态
	var new_state = states.get(new_state_name.to_lower())
	if not new_state:
		push_warning("[StateMachine] [%s] State '%s' not found, available: %s" % [_owner_name, new_state_name, states.keys()])
		return

	# 执行状态转换
	_execute_transition(from_state, new_state)
```

- [ ] **Step 4: Update recover_from_stun — remove StunState dependency**

Replace the `recover_from_stun()` method (lines 201-219) with:

```gdscript
## 从眩晕状态恢复（供外部调用，如技能结束后）
## 直接清理标记并转换到恢复状态
func recover_from_stun() -> void:
	# 停止当前状态的 timer（如果有）
	if current_state and current_state.has_method("stop_timer"):
		current_state.stop_timer()

	# 重置 owner 的状态标志
	if owner_node:
		if "stunned" in owner_node:
			owner_node.stunned = false
		if "can_move" in owner_node:
			owner_node.can_move = true

	# 转换到恢复状态（优先 wander，其次 idle）
	var recovery_state = StateNames.WANDER if states.has(StateNames.WANDER) else StateNames.IDLE
	if states.has(recovery_state):
		force_transition(recovery_state)
		DebugConfig.debug("[StateMachine] 从眩晕恢复 -> %s" % recovery_state, "", "state_machine")
```

---

### Task 3: Simplify BaseState.on_damaged — unified route to hit

**Files:**
- Modify: `Core/StateMachine/BaseState.gd:132-166`

- [ ] **Step 1: Replace on_damaged with simplified version**

Replace the entire `on_damaged()` method (lines 132-166) with:

```gdscript
## 受到伤害时的回调（子类可重写）
## 统一路由到 hit 状态，由 HitState 根据效果类型决定动画和行为
func on_damaged(_damage: Damage, _attacker_position: Vector2) -> void:
	if not state_machine:
		return
	if state_machine.states.has("hit"):
		transitioned.emit(self, "hit")
```

---

### Task 4: Simplify StunEffect — remove state machine manipulation

**Files:**
- Modify: `Core/Resources/StunEffect.gd`

- [ ] **Step 1: Rewrite StunEffect**

Replace the entire file content of `Core/Resources/StunEffect.gd` with:

```gdscript
extends AttackEffect
class_name StunEffect

## 眩晕特效 - 标记目标为眩晕状态
## 实际状态切换由 HitState 根据此效果类型决定

@export_group("眩晕参数")
## 眩晕持续时间
@export var stun_duration: float = 1.5

func _init():
	effect_name = "眩晕"
	duration = 1.5

func apply_effect(target: CharacterBody2D, _damage_source_position: Vector2) -> void:
	super.apply_effect(target, _damage_source_position)
	if "stunned" in target:
		target.stunned = true
	if show_debug_info:
		DebugConfig.info("眩晕: %s %.1fs" % [target.name, stun_duration], "", "effect")

func get_description() -> String:
	return "眩晕 - 持续: %.1f秒" % stun_duration
```

---

### Task 5: Simplify ForceStunEffect — remove state machine manipulation

**Files:**
- Modify: `Core/Resources/ForceStunEffect.gd`

- [ ] **Step 1: Rewrite ForceStunEffect**

Replace the entire file content of `Core/Resources/ForceStunEffect.gd` with:

```gdscript
extends AttackEffect
class_name ForceStunEffect

## 强制眩晕特效 - 停止移动 + 标记眩晕
## 实际状态切换由 HitState 根据此效果类型决定

@export_group("眩晕参数")
## 眩晕持续时间
@export var stun_duration: float = 3.0

## 是否停止敌人移动
@export var stop_movement: bool = true

func _init():
	effect_name = "强制眩晕"
	duration = 3.0

func apply_effect(target: CharacterBody2D, damage_source_position: Vector2) -> void:
	super.apply_effect(target, damage_source_position)
	if stop_movement:
		target.velocity = Vector2.ZERO
	if "can_move" in target:
		target.can_move = false
	if "stunned" in target:
		target.stunned = true
	if show_debug_info:
		DebugConfig.info("强制眩晕: %s %.1fs" % [target.name, stun_duration], "", "effect")

func get_description() -> String:
	return "强制眩晕 - 持续: %.1f秒" % stun_duration
```

---

### Task 6: Rewrite HitState — unified damage reaction state

**Files:**
- Modify: `Core/StateMachine/CommonStates/HitState.gd`

- [ ] **Step 1: Rewrite HitState completely**

Replace the entire file content of `Core/StateMachine/CommonStates/HitState.gd` with:

```gdscript
extends BaseState
class_name HitState

## 统一受击反应状态
## 处理所有伤害反应：硬直、眩晕、击退、击飞
## 属于反应层，可打断行为层状态
##
## 流程：
## 1. enter() 从 state_machine 读取缓存的 Damage
## 2. 遍历 effects 应用属性修改（velocity、stunned 等）
## 3. 根据最高优先级效果选择动画和持续时间
## 4. 到期/速度归零后 decide_next_state() 恢复

func _init():
	priority = StatePriority.REACTION
	can_be_interrupted = false
	animation_state = "hit"

# ============ 配置 ============
@export_group("受击设置")
## 受击硬直持续时间（无特殊效果时使用）
@export var hit_duration := 0.2
## 受伤时是否重新进入 hit（重置效果）
@export var reset_on_damage := true

@export_group("击退物理")
## 击退摩擦力系数，越大减速越快
@export var knockback_friction := 8.0
## 最小速度阈值（低于此值视为停止）
@export var min_velocity := 10.0

# ============ 运行时状态 ============
var _is_stunned := false
var _has_knockback := false


func enter() -> void:
	_is_stunned = false
	_has_knockback = false

	var damage: Damage = state_machine.last_damage
	var attacker_pos: Vector2 = state_machine.last_attacker_position

	if damage and not damage.effects.is_empty():
		_apply_effects(damage, attacker_pos)
	else:
		_start_hit_stagger()


func _apply_effects(damage: Damage, attacker_pos: Vector2) -> void:
	# 应用所有效果（修改属性、设置 velocity、启动 tween 等）
	for effect in damage.effects:
		if effect:
			effect.apply_effect(owner_node as CharacterBody2D, attacker_pos)

	# 根据效果类型选择动画和持续时间
	# 优先级: ForceStunEffect > StunEffect > KnockBack/KnockUp > 普通硬直
	var stun_effect := _find_effect(damage, "ForceStunEffect")
	if not stun_effect:
		stun_effect = _find_effect(damage, "StunEffect")

	if stun_effect:
		# 眩晕模式
		var duration: float = stun_effect.stun_duration if "stun_duration" in stun_effect else 1.5
		_is_stunned = true
		enter_control_state("stunned")
		start_timer(duration)
		if "stunned" in owner_node:
			owner_node.stunned = true
		DebugConfig.debug("受击眩晕: %s %.1fs" % [owner_node.name, duration], "", "state_machine")
	elif damage.has_effect("KnockBackEffect") or damage.has_effect("KnockUpEffect"):
		# 击退/击飞模式：效果已设置 velocity/tween，由 physics 处理减速
		_has_knockback = true
		enter_control_state("hit")
		# 不启动定时器，由 physics_process_state 检测速度归零后结束
		DebugConfig.debug("受击击退: %s" % owner_node.name, "", "state_machine")
	else:
		# 其他效果（如 GatherEffect）：普通硬直
		_start_hit_stagger()


func _start_hit_stagger() -> void:
	stop_movement()
	enter_control_state("hit")
	start_timer(hit_duration)
	DebugConfig.debug("受击硬直: %s %.2fs" % [owner_node.name, hit_duration], "", "state_machine")


func physics_process_state(delta: float) -> void:
	if not _has_knockback:
		# 非击退模式：保持静止
		stop_movement()
		return

	if owner_node is not CharacterBody2D:
		return
	var body := owner_node as CharacterBody2D

	# 击退减速
	if body.velocity.length() > min_velocity:
		body.velocity = body.velocity.lerp(Vector2.ZERO, knockback_friction * delta)
		body.move_and_slide()
	else:
		body.velocity = Vector2.ZERO
		_has_knockback = false
		# 击退结束：如果不是眩晕，结束 hit
		if not _is_stunned:
			decide_next_state()


func exit() -> void:
	stop_timer()
	exit_control_state()

	# 清除眩晕标记
	if _is_stunned:
		if "stunned" in owner_node:
			owner_node.stunned = false
		if "can_move" in owner_node:
			owner_node.can_move = true
		_on_stun_exit()

	_is_stunned = false
	_has_knockback = false

	DebugConfig.debug("受击结束: %s" % owner_node.name, "", "state_machine")


## 眩晕退出钩子（Boss: 设置眩晕免疫计时器）
func _on_stun_exit() -> void:
	if owner_node is BossBase:
		var boss := owner_node as BossBase
		var config := _get_config()
		var immunity := config.stun_immunity_duration if config and config.is_boss else 1.5
		boss.stun_immunity = immunity


## 受到伤害时的回调 — 重新进入 hit（完整 exit + enter 流程）
func on_damaged(_damage: Damage, _attacker_position: Vector2) -> void:
	if reset_on_damage:
		state_machine.force_transition("hit")


## 根据玩家距离决定下一个状态
## Boss: 使用 evaluate_transition() 统一决策
func decide_next_state() -> void:
	if owner_node is BossBase:
		var next := evaluate_transition()
		transition_to(next)
		return
	super.decide_next_state()


## 在 damage.effects 中查找指定类型的效果
func _find_effect(damage: Damage, effect_class_name: String) -> AttackEffect:
	for effect in damage.effects:
		if effect and effect.get_script() and effect.get_script().get_global_name() == effect_class_name:
			return effect
	return null
```

---

### Task 7: Update StateNames + EnemyStateMachine

**Files:**
- Modify: `Core/StateMachine/StateNames.gd:8,10`
- Modify: `Core/StateMachine/EnemyStateMachine.gd:30-34,80-91`

- [ ] **Step 1: Remove STUN/KNOCKBACK from StateNames**

In `Core/StateMachine/StateNames.gd`, remove lines 8 and 10:

```gdscript
const STUN := "stun"        # DELETE this line
const KNOCKBACK := "knockback"  # DELETE this line
```

The file should become:
```gdscript
class_name StateNames
## Canonical state name constants for transition_to() calls.
## Values must match the node names used in state machine scenes.

const IDLE := "idle"
const CHASE := "chase"
const ATTACK := "attack"
const HIT := "hit"
const WANDER := "wander"
const SPECIALSKILL := "specialskill"
```

- [ ] **Step 2: Update EnemyStateMachine — remove Stun/Knockback creation + stun_duration export**

In `Core/StateMachine/EnemyStateMachine.gd`:

Remove the `stun_duration` export (line 34):
```gdscript
## Stun 状态的眩晕时间          # DELETE
@export var stun_duration := 1.0  # DELETE
```

Replace lines 79-91 in `_create_basic_states()` (Hit/Knockback/Stun section + init_state):

```gdscript
	# Hit (反应层) - 统一受击状态
	var hit = _create_state("res://Core/StateMachine/CommonStates/HitState.gd", "Hit")
	hit.hit_duration = hit_duration

	# 设置初始状态
	init_state = idle
```

This removes the Knockback and Stun state creation at lines 84-88.

---

### Task 8: Update BossStateMachine + BossBaseState

**Files:**
- Modify: `Scenes/Characters/Bosses/Shared/BossStateMachine.gd`
- Modify: `Scenes/Characters/Bosses/Shared/BossBaseState.gd:142-160`

- [ ] **Step 1: Clean BossStateMachine — remove debug prints and stale comments**

Replace the entire `_on_owner_damaged()` method in `Scenes/Characters/Bosses/Shared/BossStateMachine.gd` (lines 17-53):

```gdscript
func _on_owner_damaged(damage: Damage, attacker_position: Vector2 = Vector2.ZERO) -> void:
	if is_transitioning_phase:
		return

	var boss := owner_node as BossBase
	if boss:
		if boss.stun_immunity > 0:
			return

		# Poise 检查（优先于闪避）
		if boss.poise_enabled and boss.take_poise_hit():
			force_transition("counter")
			return

		# 闪避检查：概率触发 defend 或 roll
		if boss.evasion_enabled:
			var chance: float = boss.evasion_chance_per_phase.get(boss.current_phase, 0.0)
			if chance > 0 and randf() < chance:
				var evasion_state: String = ["defend", "roll"].pick_random()
				force_transition(evasion_state)
				return

	# 通过决策链 → 缓存伤害 + 传递给当前状态
	super._on_owner_damaged(damage, attacker_position)
```

- [ ] **Step 2: Update BossBaseState.on_damaged — "stun" → "hit" + clean comments**

Replace lines 142-160 in `Scenes/Characters/Bosses/Shared/BossBaseState.gd`:

```gdscript
# ============ 受伤响应 ============

## Boss 特有的 on_damaged 实现
## poise 反击和闪避已提升到 BossStateMachine._on_owner_damaged()
## 此处仅保留 Phase 3 免疫，其余统一路由到 hit
func on_damaged(_damage: Damage, _attacker_position: Vector2 = Vector2.ZERO) -> void:
	var boss := get_boss()
	if not boss:
		return
	if boss.stun_immunity > 0:
		return
	if boss.current_phase == BossBase.Phase.PHASE_3:
		return
	transitioned.emit(self, "hit")
```

---

### Task 9: Update SkillManager + CyclopsAttack references

**Files:**
- Modify: `Core/Components/SkillManager.gd:365-416`
- Modify: `Scenes/Characters/Bosses/Cyclops/States/CyclopsAttack.gd:191`

- [ ] **Step 1: Update SkillManager._stun_enemy() — "stun" → "hit"**

Replace lines 365-390 in `Core/Components/SkillManager.gd`:

```gdscript
# ============ 内部方法：敌人眩晕管理 ============
## 眩晕敌人（内部方法）
## 强制敌人进入 hit 状态并停止自动恢复 timer，直到V技能结束
func _stun_enemy(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return

	# 设置眩晕状态标志
	if "stunned" in enemy:
		enemy.stunned = true
	if "can_move" in enemy:
		enemy.can_move = false

	# 强制停止移动
	if enemy is CharacterBody2D:
		(enemy as CharacterBody2D).velocity = Vector2.ZERO

	# 强制切换到 hit 状态
	var state_machine = _find_state_machine(enemy)
	if state_machine:
		if state_machine.has_method("force_transition"):
			state_machine.force_transition("hit")
			# 关键：停止 hit 状态的自动恢复 timer，防止敌人在V技能结束前恢复
			var hit_state = state_machine.states.get("hit")
			if hit_state and hit_state.has_method("stop_timer"):
				hit_state.stop_timer()
```

Also update the comment in `_unstun_all_enemies()` (line 392-393):
```gdscript
## 恢复所有被眩晕的敌人（内部方法）
## 调用 recover_from_stun 清理标记并恢复行为
```

- [ ] **Step 2: Update CyclopsAttack.on_damaged — "stun" → "hit"**

In `Scenes/Characters/Bosses/Cyclops/States/CyclopsAttack.gd`, line 191, replace:

```gdscript
	transitioned.emit(self, "stun")
```
with:
```gdscript
	transitioned.emit(self, "hit")
```

---

### Task 10: Delete all Stun/Knockback state scripts

**Files:**
- Delete: `Core/StateMachine/CommonStates/StunState.gd`
- Delete: `Core/StateMachine/CommonStates/KnockbackState.gd`
- Delete: `Scenes/Characters/Bosses/Shared/BossStunState.gd`
- Delete: `Scenes/Characters/Bosses/BladeKeeper/States/BKStun.gd`
- Delete: `Scenes/Characters/Bosses/DemonSlime/States/DSStun.gd`
- Delete: `Scenes/Characters/Bosses/Cyclops/States/CyclopsStun.gd`
- Delete: `Scenes/Characters/Enemies/ForestBee/States/BeeStun.gd`
- Delete: `Scenes/Characters/Enemies/ForestBoar/States/BoarStun.gd`
- Delete: `Scenes/Characters/Enemies/ForestSnail/States/SnailStun.gd`
- Delete: `Scenes/Characters/Enemies/Dinosaur/Scripts/States/EnemyStun.gd`

- [ ] **Step 1: Delete all 10 files**

```bash
rm Core/StateMachine/CommonStates/StunState.gd
rm Core/StateMachine/CommonStates/KnockbackState.gd
rm Scenes/Characters/Bosses/Shared/BossStunState.gd
rm Scenes/Characters/Bosses/BladeKeeper/States/BKStun.gd
rm Scenes/Characters/Bosses/DemonSlime/States/DSStun.gd
rm Scenes/Characters/Bosses/Cyclops/States/CyclopsStun.gd
rm Scenes/Characters/Enemies/ForestBee/States/BeeStun.gd
rm Scenes/Characters/Enemies/ForestBoar/States/BoarStun.gd
rm Scenes/Characters/Enemies/ForestSnail/States/SnailStun.gd
rm Scenes/Characters/Enemies/Dinosaur/Scripts/States/EnemyStun.gd
```

- [ ] **Step 2: Verify deletion**

```bash
find . -name "*Stun*.gd" -o -name "*Knockback*.gd" | grep -v KnockBack | grep -v KnockUp
```
Expected: Only `KnockBackEffect.gd` and `KnockUpEffect.gd` remain (they are effects, not states).

---

### Task 11: Update .tscn scenes — replace Stun/Knockback nodes with Hit

**CRITICAL**: Boss scenes (BladeKeeper, DemonSlime, Cyclops) currently have **Stun** but NO **Hit** node. They need Stun replaced with Hit. Enemy scenes (EnemyBase, Dinosaur) have both Hit and Stun/Knockback — remove Stun/Knockback only. ForestBee and ForestBoar inherit from EnemyBase — remove their Stun override.

**Files:**
- Modify: `Scenes/Characters/Templates/EnemyBase.tscn`
- Modify: `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn`
- Modify: `Scenes/Characters/Bosses/DemonSlime/DemonSlime.tscn`
- Modify: `Scenes/Characters/Bosses/Cyclops/Cyclops.tscn`
- Modify: `Scenes/Characters/Enemies/Dinosaur/Dinosaur.tscn`
- Modify: `Scenes/Characters/Enemies/ForestBee/ForestBee.tscn`
- Modify: `Scenes/Characters/Enemies/ForestBoar/ForestBoar.tscn`

- [ ] **Step 1: EnemyBase.tscn — remove Stun + Knockback nodes and ext_resources**

In `Scenes/Characters/Templates/EnemyBase.tscn`:

Remove these ext_resource lines:
```
[ext_resource type="Script" uid="uid://fyj4em6c6s13" path="res://Core/StateMachine/CommonStates/StunState.gd" id="11_stun"]
[ext_resource type="Script" uid="uid://cx4hx0vi34say" path="res://Core/StateMachine/CommonStates/KnockbackState.gd" id="12_knockback"]
```

Remove these node blocks:
```
[node name="Stun" type="Node" parent="EnemyStateMachine" unique_id=283105885]
script = ExtResource("11_stun")

[node name="Knockback" type="Node" parent="EnemyStateMachine" unique_id=186048944]
script = ExtResource("12_knockback")
```

- [ ] **Step 2: BladeKeeper.tscn — replace Stun node with Hit node**

In `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn`:

Replace the ext_resource for BKStun:
```
[ext_resource type="Script" uid="uid://ch1jnbnbvsbkf" path="res://Scenes/Characters/Bosses/BladeKeeper/States/BKStun.gd" id="13_stun"]
```
with:
```
[ext_resource type="Script" path="res://Core/StateMachine/CommonStates/HitState.gd" id="13_hit"]
```

Replace the Stun node block (lines 1490-1495):
```
[node name="Stun" type="Node" parent="StateMachine" index="3" unique_id=767657071]
script = ExtResource("13_stun")
stun_duration = 0.5
priority = 2
```
with:
```
[node name="Hit" type="Node" parent="StateMachine" index="3" unique_id=767657071]
script = ExtResource("13_hit")
```

- [ ] **Step 3: DemonSlime.tscn — replace Stun node with Hit node**

In `Scenes/Characters/Bosses/DemonSlime/DemonSlime.tscn`:

Replace the ext_resource:
```
[ext_resource type="Script" uid="uid://bbusd5dblsjc7" path="res://Scenes/Characters/Bosses/DemonSlime/States/DSStun.gd" id="10_stun"]
```
with:
```
[ext_resource type="Script" path="res://Core/StateMachine/CommonStates/HitState.gd" id="10_hit"]
```

Replace the Stun node block (lines 133-135):
```
[node name="Stun" type="Node" parent="StateMachine" unique_id=767657071]
script = ExtResource("10_stun")
stun_duration = 1.5
```
with:
```
[node name="Hit" type="Node" parent="StateMachine" unique_id=767657071]
script = ExtResource("10_hit")
```

- [ ] **Step 4: Cyclops.tscn — replace Stun node with Hit node**

In `Scenes/Characters/Bosses/Cyclops/Cyclops.tscn`:

Replace the ext_resource:
```
[ext_resource type="Script" uid="uid://fyj4em6c6s13" path="res://Core/StateMachine/CommonStates/StunState.gd" id="17_stun"]
```
with:
```
[ext_resource type="Script" path="res://Core/StateMachine/CommonStates/HitState.gd" id="17_hit"]
```

Replace the Stun node block (lines 105-108):
```
[node name="Stun" type="Node" parent="StateMachine" unique_id=767657071]
script = ExtResource("17_stun")
stun_duration = 1.0
stun_anim_speed = 1.0
```
with:
```
[node name="Hit" type="Node" parent="StateMachine" unique_id=767657071]
script = ExtResource("17_hit")
```

- [ ] **Step 5: Dinosaur.tscn — remove Stun + Knockback nodes and ext_resources**

In `Scenes/Characters/Enemies/Dinosaur/Dinosaur.tscn`:

Remove these ext_resource lines:
```
[ext_resource type="Script" uid="uid://3u7x8q6guvnv" path="res://Scenes/Characters/Enemies/Dinosaur/Scripts/States/EnemyStun.gd" id="13_lik7o"]
[ext_resource type="Script" uid="uid://cx4hx0vi34say" path="res://Core/StateMachine/CommonStates/KnockbackState.gd" id="16_knockback"]
```

Remove these node blocks:
```
[node name="Stun" type="Node" parent="EnemyStateMachine" unique_id=269923157]
script = ExtResource("13_lik7o")

[node name="Knockback" type="Node" parent="EnemyStateMachine" unique_id=1650094293]
script = ExtResource("16_knockback")
```

- [ ] **Step 6: ForestBee.tscn — remove Stun node override and ext_resource**

In `Scenes/Characters/Enemies/ForestBee/ForestBee.tscn`:

Remove this ext_resource:
```
[ext_resource type="Script" uid="uid://c6asbaaqtflf6" path="res://Scenes/Characters/Enemies/ForestBee/States/BeeStun.gd" id="10_stun"]
```

Remove this node block:
```
[node name="Stun" parent="EnemyStateMachine" parent_id_path=PackedInt32Array(1432708593) index="5" unique_id=283105885]
script = ExtResource("10_stun")
```

- [ ] **Step 7: ForestBoar.tscn — remove Stun node override and ext_resource**

In `Scenes/Characters/Enemies/ForestBoar/ForestBoar.tscn`:

Remove this ext_resource:
```
[ext_resource type="Script" uid="uid://ccvcw825pql6b" path="res://Scenes/Characters/Enemies/ForestBoar/States/BoarStun.gd" id="12_stun"]
```

Remove this node block:
```
[node name="Stun" parent="EnemyStateMachine" parent_id_path=PackedInt32Array(1432708593) index="5" unique_id=283105885]
script = ExtResource("12_stun")
```

---

### Task 12: Update test files

**Files:**
- Modify: `test/unit/test_state_machine.gd`
- Modify: `test/integration/test_damage_pipeline.gd`

- [ ] **Step 1: Update test_state_machine.gd — replace stun/knockback with hit-only**

In `test/unit/test_state_machine.gd`:

Line 11 — change default state names:
```gdscript
func _create_state_machine(state_names: Array[String] = ["idle", "chase", "hit"]) -> Dictionary:
```

Lines 28-30 — remove "stun" case, keep "hit" and remove "knockback":
```gdscript
		"hit":
			state.priority = BaseState.StatePriority.REACTION
```

Line 59 — remove stun assertion:
```gdscript
	assert_true(sm.states.has("hit"))    # was: assert_true(sm.states.has("stun"))
```

Lines 98-99 — change "stun" transitions to "hit":
```gdscript
	idle.transitioned.emit(idle, "hit")       # was: "stun"
	assert_eq(sm.current_state.name, "hit")   # was: "stun"
```

Update all remaining test functions that reference "stun" → "hit". Remove any tests specifically about CONTROL-priority stun behavior (those are now handled within HitState).

- [ ] **Step 2: Update test_damage_pipeline.gd — replace stun/knockback with hit**

In `test/integration/test_damage_pipeline.gd`:

Line 43 — remove stun state creation, keep hit:
```gdscript
	# Remove: ["stun", BaseState.StatePriority.CONTROL],
```

Line 102 — change assertion:
```gdscript
	assert_eq(_sm.current_state.name, "hit")   # was: "stun"
```

Lines 115-126 — remove knockback state creation and test, or convert to verify HitState handles knockback effect internally.

---

### Task 13: Smoke test — run project and verify

- [ ] **Step 1: Grep for stale references**

```bash
grep -rn "StateNames.STUN\|StateNames.KNOCKBACK\|\"stun\"\|\"knockback\"" --include="*.gd" | grep -v "test/" | grep -v "stunned" | grep -v "stun_immunity" | grep -v "stun_duration" | grep -v "effect"
```
Expected: No matches (only test files and effect-related property names should remain).

- [ ] **Step 2: Run project to verify no crash on scene load**

Use `mcp__godot__run_project` to launch the game. Verify:
- Game starts without errors
- Enter a level with enemies
- Attack an enemy → should enter Hit state, play hit animation, recover

- [ ] **Step 3: Test Boss poise/evasion**

Attack BladeKeeper multiple times:
- poise_enabled=true → should trigger counter on poise break
- evasion_enabled=true → should randomly trigger defend/roll
- When neither triggers → should enter Hit state with effect applied

Use `mcp__godot__get_debug_output` to check for state transition logs.

- [ ] **Step 4: Test V skill stun**

Activate V skill near enemies:
- Enemies should enter Hit state and stay stunned
- V skill ends → enemies should recover via recover_from_stun
