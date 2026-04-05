# State Machine Architecture Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate ~25 redundant scripts by introducing BehaviorConfig Resource, absorbing Boss state variants into CommonStates, and cleaning dead code.

**Architecture:** Four-phase approach: (1) dead code cleanup, (2) BehaviorConfig Resource creation, (3) CommonState boss absorption + ground_only mode, (4) EnemyBase/BossBase migration + script deletion. Each phase is independently testable.

**Tech Stack:** Godot 4.4.1+ GDScript, AnimationTree BlendTree, BaseStateMachine priority system, Resource-driven configuration

**Spec:** `docs/superpowers/specs/2026-04-02-statemachine-refactor-design.md`

---

## File Structure

### Files to CREATE
- `Core/Resources/BehaviorConfig.gd` — unified behavior configuration Resource

### Files to MODIFY
- `Core/StateMachine/BaseState.gd` — add `_get_config()`, `evaluate_transition()`, remove dead methods
- `Core/StateMachine/BaseStateMachine.gd` — no changes (already sole AnimationTree activation)
- `Core/StateMachine/EnemyStateMachine.gd` — remove unused force_hit/force_knockback/force_stun
- `Core/StateMachine/CommonStates/IdleState.gd` — absorb BossIdleState logic
- `Core/StateMachine/CommonStates/StunState.gd` — absorb BossStunState logic
- `Core/StateMachine/CommonStates/ChaseState.gd` — add ground_only + boss cooldown
- `Core/StateMachine/CommonStates/WanderState.gd` — add ground_only mode
- `Core/Characters/EnemyBase.gd` — add `behavior_config`, remove redundant @exports, remove AnimationTree activation
- `Core/Characters/BossBase.gd` — add `behavior_config`, remove AnimationTree activation
- `Core/Characters/BaseCharacter.gd` — add shared `_handle_death()` default implementation
- All enemy/boss `.tscn` files — update state script references after deletion

### Files to DELETE
- `Core/Resources/EnemyData.gd` — unused (0 .tscn references)
- `Scenes/Characters/Bosses/Shared/BossIdleState.gd` — absorbed into IdleState
- `Scenes/Characters/Bosses/Shared/BossStunState.gd` — absorbed into StunState
- `Scenes/Characters/Bosses/BladeKeeper/States/BKIdle.gd` — PARAM_ONLY
- `Scenes/Characters/Bosses/DemonSlime/States/DSIdle.gd` — PARAM_ONLY
- `Scenes/Characters/Bosses/Cyclops/States/CyclopsStun.gd` — PARAM_ONLY (only overrides @export)
- `Scenes/Characters/Bosses/Cyclops/States/CyclopsIdle.gd` — maps boss params in _ready()
- `Scenes/Characters/Enemies/ForestBee/States/BeeChase.gd` — PARAM_ONLY (sets 1 flag)
- `Scenes/Characters/Enemies/dinosaur/Scripts/States/EnemyChase.gd` — empty extends ChaseState
- `Scenes/Characters/Enemies/dinosaur/Scripts/States/EnemyStateMachine.gd` — empty extends BaseStateMachine

---

### Task 1: Dead Code Cleanup — Unused Methods

**Files:**
- Modify: `Core/StateMachine/BaseState.gd` (remove 3 methods)
- Modify: `Core/StateMachine/EnemyStateMachine.gd` (remove 3 methods)

- [ ] **Step 1: Remove unused methods from BaseState.gd**

Remove `reset_time_scale()` (line 434-436), `get_animation_params()` (line 346-353), and `move_away_from_target()` (line 280-286). These have 0 callers across the entire codebase.

Delete these three method blocks:

```gdscript
# DELETE: get_animation_params (lines 345-353)
## 获取当前状态的动画参数（子类可重写）
## 返回用于 AnimationTree 或 AnimationHandler 的参数
func get_animation_params() -> Dictionary:
	return {
		"velocity": owner_node.velocity if owner_node is CharacterBody2D else Vector2.ZERO,
		"animation_state": animation_state,
		"priority": priority,
		"can_be_interrupted": can_be_interrupted
	}

# DELETE: move_away_from_target (lines 279-286)
## 远离目标移动
## @param speed: 移动速度
## @param call_move_slide: 是否调用 move_and_slide（默认 true）
func move_away_from_target(speed: float, call_move_slide: bool = true) -> void:
	if owner_node is CharacterBody2D:
		var body = owner_node as CharacterBody2D
		var direction = -get_direction_to_target()
		body.velocity = direction * speed
		if call_move_slide:
			body.move_and_slide()

# DELETE: reset_time_scale (lines 434-436)
## 重置所有 TimeScale 为正常速度
func reset_time_scale() -> void:
	set_locomotion_time_scale(1.0)
	set_control_time_scale(1.0)
```

- [ ] **Step 2: Remove unused convenience methods from EnemyStateMachine.gd**

Remove `force_stun()` (lines 124-129), `force_hit()` (lines 132-133), `force_knockback()` (lines 136-137). All have 0 callers. Keep `is_controlled()`, `is_reacting()`, `can_act()` — these are structural utilities.

Delete:

```gdscript
# DELETE: force_stun (lines 124-129)
## 强制进入眩晕状态
func force_stun(duration: float = -1.0) -> void:
	if duration > 0 and states.has("stun"):
		var stun_state = states["stun"] as StunState
		stun_state.stun_duration = duration
	force_transition("stun")

# DELETE: force_hit (lines 132-133)
## 强制进入受击状态
func force_hit() -> void:
	force_transition("hit")

# DELETE: force_knockback (lines 136-137)
## 强制进入击退状态
func force_knockback() -> void:
	force_transition("knockback")
```

- [ ] **Step 3: Fix AnimationTree triple-activation**

Remove redundant `anim_tree.active = true` from EnemyBase and BossBase (BaseStateMachine._setup_animation_tree() is the sole activation point).

In `Core/Characters/EnemyBase.gd`, delete lines 62-63:

```gdscript
# DELETE from _on_character_ready():
	# 激活 AnimationTree（可通过 use_animation_tree 关闭）
	if anim_tree and use_animation_tree:
		anim_tree.active = true
```

Also remove the now-unused `@export var use_animation_tree := true` (line 37).

In `Core/Characters/BossBase.gd`, delete lines 59-60:

```gdscript
# DELETE from _on_character_ready():
	# 激活 AnimationTree
	if anim_tree:
		anim_tree.active = true
```

- [ ] **Step 4: Delete EnemyData.gd**

```bash
git rm Core/Resources/EnemyData.gd
```

Also remove all references in `EnemyBase.gd`:
- Delete `@export var enemy_data: EnemyData = null` (line 18)
- Delete the `if enemy_data: _apply_enemy_data()` block (lines 55-56)
- Delete the entire `_apply_enemy_data()` method (lines 148-162)

- [ ] **Step 5: Verify no regressions**

```bash
# Search for any remaining references to deleted items
grep -r "EnemyData" --include="*.gd" --include="*.tscn" .
grep -r "reset_time_scale\|get_animation_params\|move_away_from_target" --include="*.gd" .
grep -r "force_hit\|force_knockback\b" --include="*.gd" .
```

Expected: 0 results for all searches.

- [ ] **Step 6: Commit**

```bash
git add Core/StateMachine/BaseState.gd Core/StateMachine/EnemyStateMachine.gd Core/Characters/EnemyBase.gd Core/Characters/BossBase.gd
git rm Core/Resources/EnemyData.gd
git commit -m "refactor: remove unused methods and fix AnimationTree triple-activation

Remove 3 unused BaseState methods (reset_time_scale, get_animation_params,
move_away_from_target), 3 unused EnemyStateMachine methods (force_stun,
force_hit, force_knockback), delete unused EnemyData.gd, and fix AnimationTree
being activated 3 times by keeping only BaseStateMachine as activation point.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 2: Create BehaviorConfig Resource

**Files:**
- Create: `Core/Resources/BehaviorConfig.gd`

- [ ] **Step 1: Create BehaviorConfig.gd**

```gdscript
extends Resource
class_name BehaviorConfig

## 统一行为配置 Resource
## 替代散落在 EnemyBase/BossBase 上的 @export 属性
## 支持 Enemy 和 Boss 共用，Boss 字段通过 @export_group("Boss") 分组

# ---- Health ----
@export_group("Health")
@export var max_health := 100
@export var health := 100

# ---- Idle ----
@export_group("Idle")
@export var min_idle_time := 1.0
@export var max_idle_time := 3.0

# ---- Wander ----
@export_group("Wander")
@export var min_wander_time := 2.5
@export var max_wander_time := 10.0
@export var wander_speed := 50.0

# ---- Chase ----
@export_group("Chase")
@export var detection_radius := 100.0
@export var chase_abandon_distance := 200.0
@export var attack_activation_radius := 25.0
@export var chase_speed := 75.0

# ---- Stun ----
@export_group("Stun")
@export var stun_duration := 1.0
@export var stun_anim_speed := 1.0

# ---- Hit ----
@export_group("Hit")
@export var hit_duration := 0.3

# ---- Movement ----
@export_group("Movement")
## 水平移动模式：仅允许 X 轴移动（用于地面敌人如 Snail/Boar）
@export var ground_only := false
@export var has_gravity := false
@export var gravity := 800.0

# ---- Boss 扩展 ----
@export_group("Boss")
@export var is_boss := false
@export var attack_range := 300.0
@export var min_distance := 150.0
@export var stun_immunity_duration := 1.5
```

- [ ] **Step 2: Commit**

```bash
git add Core/Resources/BehaviorConfig.gd
git commit -m "feat: add BehaviorConfig Resource for unified behavior configuration

Single Resource covers Enemy + Boss behavior params. Boss fields gated by
@export_group. Replaces scattered @export properties on EnemyBase/BossBase
and the unused EnemyData Resource.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 3: BaseState — Add _get_config() and evaluate_transition()

**Files:**
- Modify: `Core/StateMachine/BaseState.gd`

- [ ] **Step 1: Add _get_config() helper to BaseState.gd**

Add after the `get_owner_property()` method (around line 322):

```gdscript
## 获取 owner 的 BehaviorConfig（如果有）
## CommonStates 使用此方法获取配置，优先级: config > owner property > @export default
func _get_config() -> BehaviorConfig:
	if owner_node and "behavior_config" in owner_node:
		return owner_node.behavior_config
	return null
```

- [ ] **Step 2: Add evaluate_transition() to BaseState.gd**

Add in the "状态决策方法" section, after `decide_next_state()`:

```gdscript
## 统一距离决策：根据 owner 类型和距离选择下一个状态
## Boss: 考虑 attack_range, min_distance, detection_radius, attack_cooldown
## Enemy: 考虑 detection_radius + attack_activation_radius
## @return 推荐的状态名
func evaluate_transition() -> String:
	if not is_target_alive():
		return _resolve_eval_state("patrol", default_state_name)

	var distance := get_distance_to_target()
	var config := _get_config()

	# Boss 决策路径
	if owner_node is BossBase:
		var boss := owner_node as BossBase
		var det_radius := config.detection_radius if config and config.is_boss else boss.detection_radius
		var atk_range := config.attack_range if config and config.is_boss else boss.attack_range
		var min_dist := config.min_distance if config and config.is_boss else boss.min_distance

		if distance > det_radius:
			return _resolve_eval_state("patrol", default_state_name)
		if distance < min_dist:
			return _resolve_eval_state("retreat", chase_state_name)
		if distance <= atk_range and boss.attack_cooldown <= 0:
			return _resolve_eval_state("attack", default_state_name)
		return _resolve_eval_state("circle", chase_state_name)

	# Enemy 决策路径
	var det_radius := config.detection_radius if config else get_owner_property("detection_radius", detection_radius)
	var atk_radius := config.attack_activation_radius if config else get_owner_property("attack_activation_radius", -1.0)

	if atk_radius > 0 and distance <= atk_radius:
		return _resolve_eval_state("attack", default_state_name)
	if distance <= det_radius:
		return chase_state_name
	return default_state_name


## 检查首选状态是否存在，fallback 到备选
func _resolve_eval_state(preferred: String, fallback: String) -> String:
	if state_machine and state_machine.states.has(preferred):
		return preferred
	return fallback
```

- [ ] **Step 3: Commit**

```bash
git add Core/StateMachine/BaseState.gd
git commit -m "feat: add _get_config() and evaluate_transition() to BaseState

_get_config() provides type-safe BehaviorConfig access for CommonStates.
evaluate_transition() unifies distance-based state decisions for both
Enemy and Boss, replacing 4 scattered implementations.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 4: CommonState Boss Absorption

**Files:**
- Modify: `Core/StateMachine/CommonStates/IdleState.gd`
- Modify: `Core/StateMachine/CommonStates/StunState.gd`
- Modify: `Core/StateMachine/CommonStates/ChaseState.gd`
- Modify: `Core/StateMachine/CommonStates/WanderState.gd`

- [ ] **Step 1: IdleState — absorb BossIdleState logic**

Replace the current `_evaluate_idle_transition()` method in `IdleState.gd`:

```gdscript
## 评估 Idle 状态中的转换（子类可重写）
## Boss: 使用 attack_range + detection_radius + cooldown 决策
## Enemy: 检查攻击范围 → 检查追击范围
func _evaluate_idle_transition() -> void:
	# Boss 决策路径
	if owner_node is BossBase:
		var boss := owner_node as BossBase
		if not is_target_alive():
			return
		var distance := get_distance_to_target()
		var config := _get_config()
		var atk_range := config.attack_range if config and config.is_boss else boss.attack_range
		var det_radius := config.detection_radius if config and config.is_boss else boss.detection_radius
		if distance <= atk_range and boss.attack_cooldown <= 0:
			transition_to("attack")
		elif distance <= det_radius:
			transition_to("chase")
		return

	# Enemy 默认行为
	if try_attack():
		return
	if try_chase():
		return
```

Also update `enter()` to read idle times from config:

```gdscript
func enter() -> void:
	# 从 config 读取 idle 时间（如果可用）
	var config := _get_config()
	var min_t := config.min_idle_time if config else min_idle_time
	var max_t := config.max_idle_time if config else max_idle_time

	var duration = min_t if use_fixed_time else randf_range(min_t, max_t)
	start_timer(duration, _on_idle_timeout)

	# 停止移动
	if stop_immediately:
		stop_movement()

	# 设置动画：idle 位置（0, 0）
	set_locomotion(Vector2.ZERO)
```

- [ ] **Step 2: StunState — absorb BossStunState logic**

Update `_on_stun_exit()` to handle Boss stun immunity:

```gdscript
## 眩晕退出钩子（子类可重写）
## Boss: 设置眩晕免疫计时器
func _on_stun_exit() -> void:
	if owner_node is BossBase:
		var boss := owner_node as BossBase
		var config := _get_config()
		var immunity := config.stun_immunity_duration if config and config.is_boss else 1.5
		boss.stun_immunity = immunity
```

Override `decide_next_state()` to use Boss distance decision:

```gdscript
## 根据玩家距离决定下一个状态
## Boss: 使用 evaluate_transition() 统一决策
## Enemy: 使用 BaseState 默认行为
func decide_next_state() -> void:
	if owner_node is BossBase:
		var next := evaluate_transition()
		transition_to(next)
		return
	# Enemy 默认
	super.decide_next_state()
```

Also update `enter()` to read stun_duration from config:

```gdscript
func enter() -> void:
	var config := _get_config()
	var duration := config.stun_duration if config else stun_duration
	var anim_speed := config.stun_anim_speed if config else stun_anim_speed
	start_timer(duration)

	# 检查是否有击退速度
	if owner_node is CharacterBody2D:
		var body = owner_node as CharacterBody2D
		var has_knockback = body.velocity.length() > KNOCKBACK_SPEED_THRESHOLD
		if not has_knockback:
			stop_movement()

	enter_control_state("stunned")
	set_control_time_scale(anim_speed)

	if "stunned" in owner_node:
		owner_node.stunned = true

	DebugConfig.debug("眩晕: %s 开始" % owner_node.name, "", "state_machine")
```

- [ ] **Step 3: ChaseState — add ground_only + boss cooldown**

Add `@export var ground_only := false` to ChaseState's export group:

```gdscript
# ============ 移动设置 ============
@export_group("移动设置")
## 水平移动模式（仅 X 轴，用于地面敌人如 Snail/Boar）
@export var ground_only := false
```

Update `physics_process_state()` to handle ground_only:

```gdscript
func physics_process_state(_delta: float) -> void:
	if not is_target_alive():
		transition_to(default_state_name)
		return

	# 从 config 或 owner 获取参数
	var config := _get_config()
	var give_up_range: float = config.chase_abandon_distance if config else get_owner_property("chase_abandon_distance", default_give_up_range)
	var attack_range: float = config.attack_activation_radius if config else get_owner_property("attack_activation_radius", default_attack_range)
	var speed: float = config.chase_speed if config else get_owner_property("chase_speed", default_chase_speed)
	var is_ground: bool = config.ground_only if config else ground_only

	var distance = get_distance_to_target()

	# 距离太远，放弃追击
	if distance > give_up_range:
		transition_to(give_up_state_name)
		return

	# 检查特殊技能（冷却完成 + 概率）
	var ss := state_machine.states.get(StateNames.SPECIALSKILL) as SpecialSkillState
	if ss and ss.can_trigger(distance):
		transition_to(StateNames.SPECIALSKILL)
		return

	# 进入攻击范围
	if distance <= attack_range:
		var target_state := _on_reached_attack_range()
		if target_state != "":
			transition_to(target_state)
		return

	# 移动向目标
	if is_ground:
		_move_ground_only(speed)
	else:
		move_toward_target(speed)

	# 更新动画
	_update_animation_locomotion()


## 地面模式移动：仅 X 轴
func _move_ground_only(speed: float) -> void:
	if owner_node is not CharacterBody2D:
		return
	var body := owner_node as CharacterBody2D
	var dir := get_direction_to_target()
	body.velocity.x = sign(dir.x) * speed
	# 保留 Y 轴速度（重力由 EnemyBase._physics_process 处理）
	body.move_and_slide()
```

Update `_on_reached_attack_range()` to check Boss cooldown:

```gdscript
## 到达攻击范围时的状态选择（子类可重写）
## Boss: 检查攻击冷却
## Enemy: 直接进入攻击
func _on_reached_attack_range() -> String:
	if owner_node is BossBase:
		var boss := owner_node as BossBase
		if boss.attack_cooldown > 0:
			return ""  # 空字符串 = 继续当前行为
		return attack_state_name
	return attack_state_name
```

- [ ] **Step 4: WanderState — add ground_only mode**

Add ground_only support to `physics_process_state()`:

```gdscript
func physics_process_state(_delta: float) -> void:
	# 检测玩家
	if enable_player_detection:
		if try_chase():
			return

	# 移动
	if owner_node is CharacterBody2D:
		var body = owner_node as CharacterBody2D
		var config := _get_config()
		var speed: float = config.wander_speed if config else get_owner_property("wander_speed", default_wander_speed)
		var is_ground: bool = config.ground_only if config else false

		if is_ground:
			# 地面模式：仅 X 轴移动
			body.velocity.x = sign(wander_direction.x) * speed
		else:
			body.velocity = wander_direction * speed

		body.move_and_slide()

		# 更新动画
		var blend_x = sign(wander_direction.x) if abs(wander_direction.x) > 0.1 else 0.0
		var max_speed: float = config.chase_speed if config else get_owner_property("chase_speed", 100.0)
		var blend_y = clampf(speed / max_speed, 0.0, 0.5)
		set_locomotion(Vector2(blend_x, blend_y))
```

Also update `enter()` to read config:

```gdscript
func enter() -> void:
	var config := _get_config()
	var is_ground: bool = config.ground_only if config else false

	# 设置方向
	if is_ground:
		# 地面模式：随机左或右
		wander_direction = Vector2.RIGHT if randf() > 0.5 else Vector2.LEFT
	elif random_direction:
		wander_direction = Vector2.RIGHT.rotated(randf_range(0, TAU))
	else:
		wander_direction = fixed_direction.normalized()

	# 设置定时器
	var min_time: float = config.min_wander_time if config else get_owner_property("min_wander_time", min_wander_time)
	var max_time: float = config.max_wander_time if config else get_owner_property("max_wander_time", max_wander_time)
	start_timer(randf_range(min_time, max_time), _on_wander_timeout)
```

- [ ] **Step 5: Commit**

```bash
git add Core/StateMachine/CommonStates/IdleState.gd Core/StateMachine/CommonStates/StunState.gd Core/StateMachine/CommonStates/ChaseState.gd Core/StateMachine/CommonStates/WanderState.gd
git commit -m "feat: absorb Boss variants into CommonStates + add ground_only mode

IdleState: boss distance decision with attack_range + cooldown check
StunState: boss stun immunity + evaluate_transition() recovery
ChaseState: ground_only horizontal movement + boss cooldown at attack range
WanderState: ground_only horizontal wander mode
All states read BehaviorConfig via _get_config() with @export fallback.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 5: EnemyBase/BossBase Migration + Death Logic Extraction

**Files:**
- Modify: `Core/Characters/EnemyBase.gd`
- Modify: `Core/Characters/BossBase.gd`
- Modify: `Core/Characters/BaseCharacter.gd`

- [ ] **Step 1: Add behavior_config to EnemyBase.gd**

Replace the scattered @export AI parameters with a single BehaviorConfig reference. Keep backward compatibility — existing .tscn @export overrides still work via `get_owner_property()` fallback in CommonStates.

At the top of EnemyBase.gd, add:

```gdscript
# ============ 行为配置（优先于散落 @export）============
@export var behavior_config: BehaviorConfig = null
```

Update `_on_character_ready()` to apply config to existing properties (backward compat):

```gdscript
func _on_character_ready() -> void:
	assert(anim_player != null, "%s: missing AnimationPlayer child node" % name)
	assert(anim_tree != null, "%s: missing AnimationTree child node" % name)

	# 应用行为配置（如果有）
	if behavior_config:
		_apply_behavior_config()

	# 查找精灵节点
	_find_sprite()

	# 子类钩子
	_on_enemy_ready()
```

Add `_apply_behavior_config()`:

```gdscript
## 从 BehaviorConfig 应用配置到本地属性（向后兼容）
func _apply_behavior_config() -> void:
	if not behavior_config:
		return
	max_health = behavior_config.max_health
	health = behavior_config.health
	min_wander_time = behavior_config.min_wander_time
	max_wander_time = behavior_config.max_wander_time
	wander_speed = behavior_config.wander_speed
	detection_radius = behavior_config.detection_radius
	chase_abandon_distance = behavior_config.chase_abandon_distance
	attack_activation_radius = behavior_config.attack_activation_radius
	chase_speed = behavior_config.chase_speed
	has_gravity = behavior_config.has_gravity
	gravity = behavior_config.gravity
	# 同步到 HealthComponent
	if health_component:
		health_component.max_health = max_health
		health_component.health = health
```

- [ ] **Step 2: Add behavior_config to BossBase.gd**

Add at the top of BossBase exports:

```gdscript
# ============ 行为配置（可选）============
@export var behavior_config: BehaviorConfig = null
```

Update `_on_character_ready()`:

```gdscript
func _on_character_ready() -> void:
	# 应用行为配置
	if behavior_config and behavior_config.is_boss:
		detection_radius = behavior_config.detection_radius
		attack_range = behavior_config.attack_range
		min_distance = behavior_config.min_distance

	# 监听生命值变化以检查阶段转换
	if health_component:
		health_component.health_changed.connect(_on_health_changed)

	# 调用子类钩子
	_on_boss_ready()
```

- [ ] **Step 3: Extract shared death logic to BaseCharacter**

Add default `_handle_death()` implementation to `BaseCharacter.gd`:

```gdscript
## 默认死亡处理：停止状态机 → 播放 death 动画 → queue_free
## 子类可重写此方法以自定义死亡逻辑
func _handle_death() -> void:
	# 停止状态机
	_stop_state_machine()

	# 尝试播放死亡动画
	var played := await _play_death_animation()
	if not played:
		await _play_fallback_death()

	queue_free()


## 停止所有状态机子节点
func _stop_state_machine() -> void:
	for child in get_children():
		if child is BaseStateMachine:
			child.set_physics_process(false)
			child.set_process(false)
			break


## 尝试通过 AnimationTree 播放 death 动画，返回是否成功
func _play_death_animation() -> bool:
	var anim_tree_node := get_node_or_null("AnimationTree") as AnimationTree
	var anim_player_node := get_node_or_null("AnimationPlayer") as AnimationPlayer

	if anim_tree_node and anim_tree_node.active and anim_player_node and anim_player_node.has_animation("death"):
		anim_tree_node.set("parameters/control_blend/blend_amount", 1.0)
		var playback = anim_tree_node.get("parameters/control_sm/playback")
		if playback:
			playback.start("death", true)
			var death_anim = anim_player_node.get_animation("death")
			var wait_time = death_anim.length if death_anim else 0.5
			await get_tree().create_timer(wait_time).timeout
			return true

	# Fallback: 直接用 AnimationPlayer
	if anim_player_node and anim_player_node.has_animation("death"):
		anim_player_node.play("death")
		await anim_player_node.animation_finished
		return true

	return false


## 默认死亡动画回退：简单延迟（子类可重写为白闪等）
func _play_fallback_death() -> void:
	await get_tree().create_timer(0.5).timeout
```

- [ ] **Step 4: Simplify EnemyBase._handle_death()**

Replace the existing `_handle_death()` in EnemyBase.gd with:

```gdscript
## 死亡处理：使用 BaseCharacter 默认 + EnemyBase 白闪 fallback
func _handle_death() -> void:
	_stop_state_machine()

	var played := await _play_death_animation()
	if not played:
		await _play_default_death_animation()

	queue_free()
```

Keep `_play_default_death_animation()` (the white flash effect) as-is — it's EnemyBase-specific.

- [ ] **Step 5: Simplify BossBase._handle_death()**

Replace with:

```gdscript
func _handle_death() -> void:
	boss_defeated.emit()
	await super._handle_death()
```

Since BaseCharacter._handle_death() now does the AnimationTree/AnimationPlayer death + queue_free, BossBase only needs to emit the signal and delegate.

- [ ] **Step 6: Commit**

```bash
git add Core/Characters/BaseCharacter.gd Core/Characters/EnemyBase.gd Core/Characters/BossBase.gd
git commit -m "feat: add behavior_config to EnemyBase/BossBase + extract death logic

EnemyBase/BossBase accept optional BehaviorConfig Resource.
Shared death logic (stop state machine, play death animation, fallback)
extracted to BaseCharacter._handle_death() default implementation.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 6: Delete PARAM_ONLY Scripts + Update .tscn References

**Files:**
- Delete: 10 PARAM_ONLY scripts (see list below)
- Modify: ~6 `.tscn` files to update script references

- [ ] **Step 1: Identify all .tscn files referencing scripts to delete**

```bash
grep -rl "BKIdle\|DSIdle\|CyclopsStun\|CyclopsIdle\|BossIdleState\|BossStunState\|BeeChase\|EnemyChase\b" --include="*.tscn" .
```

For each match, the state node in the .tscn needs to point to the corresponding CommonState instead:

| Deleted Script | Replacement Script | Affected .tscn |
|---|---|---|
| BKIdle.gd | IdleState.gd | BladeKeeper.tscn |
| DSIdle.gd | IdleState.gd | DemonSlime.tscn |
| CyclopsIdle.gd | IdleState.gd | Cyclops.tscn |
| CyclopsStun.gd | StunState.gd | Cyclops.tscn |
| BossIdleState.gd | IdleState.gd | (if any .tscn uses it directly) |
| BossStunState.gd | StunState.gd | (if any .tscn uses it directly) |
| BeeChase.gd | ChaseState.gd | ForestBee.tscn |
| EnemyChase.gd | ChaseState.gd | Dinosaur.tscn |

- [ ] **Step 2: Update .tscn state node scripts**

For each affected .tscn, change the `[ext_resource]` line pointing to the deleted script to point to the CommonState script instead. Then verify `@export` overrides on the state nodes still make sense.

Example for BladeKeeper.tscn — find the line:
```
[ext_resource type="Script" path="res://Scenes/Characters/Bosses/BladeKeeper/States/BKIdle.gd" ...]
```
Replace path with:
```
[ext_resource type="Script" path="res://Core/StateMachine/CommonStates/IdleState.gd" ...]
```

For ForestBee.tscn — BeeChase only set `enable_sprite_flip = false`, so after switching to ChaseState.gd, add/keep that @export override on the Chase node:
```
[node name="Chase" ...]
enable_sprite_flip = false
```

- [ ] **Step 3: Delete the scripts**

```bash
git rm Scenes/Characters/Bosses/Shared/BossIdleState.gd
git rm Scenes/Characters/Bosses/Shared/BossStunState.gd
git rm Scenes/Characters/Bosses/BladeKeeper/States/BKIdle.gd
git rm Scenes/Characters/Bosses/DemonSlime/States/DSIdle.gd
git rm Scenes/Characters/Bosses/Cyclops/States/CyclopsStun.gd
git rm Scenes/Characters/Bosses/Cyclops/States/CyclopsIdle.gd
git rm Scenes/Characters/Enemies/ForestBee/States/BeeChase.gd
git rm Scenes/Characters/Enemies/dinosaur/Scripts/States/EnemyChase.gd
git rm Scenes/Characters/Enemies/dinosaur/Scripts/States/EnemyStateMachine.gd
```

- [ ] **Step 4: Verify no broken references**

```bash
# Search for any remaining references to deleted files
grep -r "BKIdle\|DSIdle\|CyclopsStun\|CyclopsIdle\|BossIdleState\|BossStunState\|BeeChase\|EnemyChase" --include="*.gd" --include="*.tscn" .
```

Expected: Only the CommonState files themselves and HEAVY boss scripts that inherit from them.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: delete 10 PARAM_ONLY scripts, update .tscn to use CommonStates

Deleted: BKIdle, DSIdle, CyclopsIdle, CyclopsStun, BossIdleState,
BossStunState, BeeChase, EnemyChase, dinosaur EnemyStateMachine.
All .tscn state nodes now point directly to CommonState scripts with
@export overrides for per-enemy customization.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 7: MCP Validation — Run All Scenes

**Files:** None (validation only)

- [ ] **Step 1: Run project and verify no errors**

Use MCP to launch the game and check for errors:

```
mcp__godot__run_project
mcp__godot__get_debug_output
```

Check for:
- No "Script not found" errors (deleted scripts referenced from .tscn)
- No "Method not found" errors (removed methods still called)
- No "Property not found" errors (removed @exports referenced in .tscn)

- [ ] **Step 2: Verify state machine transitions**

Check debug output for each enemy type:
- Standard enemies (Bear, Slime, Dragon, etc.): Idle → Wander → Chase → Attack cycle
- Ground enemies (Snail, Boar): horizontal-only movement in Chase/Wander
- Bosses (BladeKeeper, Cyclops, DemonSlime): Idle → Chase → Attack with cooldown + phase transitions

- [ ] **Step 3: Verify AnimationTree**

Confirm each character's AnimationTree activates exactly once (no triple-activation log warnings).

- [ ] **Step 4: Fix any issues found**

If any validation errors are found, fix them and re-commit.

---

## Summary of Changes

| Metric | Before | After |
|--------|--------|-------|
| State scripts | ~45 | ~20 |
| PARAM_ONLY scripts | ~15 | 0 |
| Config Resources | EnemyData (unused) | BehaviorConfig |
| AnimationTree activations | 3x per entity | 1x |
| BaseState dead methods | 3 | 0 |
| EnemyStateMachine dead methods | 3 | 0 |
| Intermediate abstraction files | 2 (BossIdleState, BossStunState) | 0 |
