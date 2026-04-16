# AI Controller Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the Core/AI subsystem (Blackboard + AIController + State) + stock states + AgentAIBase template + DemonSlime2 pilot boss, separating decision logic from state execution.

**Architecture:** AIController holds an in-memory transition table (code-registered via `add_transition`) and a dynamic Blackboard (RefCounted dictionary with `bind_var` property sync). States are pure executors that never decide transitions — they dispatch events, AIController matches rules. AgentAIBase.tscn is the scene template all new enemies inherit.

**Tech Stack:** Godot 4.4.1, GDScript, GUT test framework

**Spec:** `docs/superpowers/specs/2026-04-11-ai-controller-decision-separation-design.md`

---

## File Map

### Core/AI/ (new directory — 4 files)

| File | Responsibility |
|---|---|
| `Core/AI/Blackboard.gd` | Dynamic dictionary (get_var/set_var) + bind_var_to_property + parent scope |
| `Core/AI/State.gd` | Pure executor base class: enter/exit/update/physics_update + dispatch(event) |
| `Core/AI/AIController.gd` | Transition table (add_transition), dispatch, safety tick, blackboard pull for distance/cooldowns |
| `Core/AI/AIEvents.gd` | StringName constants for all events |

### Core/AI/Stock/ (new directory — 6 files)

| File | Responsibility |
|---|---|
| `Core/AI/Stock/IdleState.gd` | Stop movement, set idle animation, no decisions |
| `Core/AI/Stock/ChaseState.gd` | Move toward target, update locomotion blend |
| `Core/AI/Stock/WanderState.gd` | Random direction movement, timer-based |
| `Core/AI/Stock/HitState.gd` | Read damage from BB, apply effects, play hit/stun anim, timer → dispatch hit_recovered |
| `Core/AI/Stock/StunState.gd` | Stun animation, timer → dispatch stun_recovered |
| `Core/AI/Stock/DeathState.gd` | Play death animation, disable owner |

### Scenes/Characters/Templates/ (1 new file)

| File | Responsibility |
|---|---|
| `Scenes/Characters/Templates/AgentAIBase.tscn` | Scene template with AIController + StateMachine + 4 stock states (Idle/Chase/Hit/Death) |

### Scenes/Characters/Bosses/DemonSlime2/ (new directory)

| File | Responsibility |
|---|---|
| `DemonSlime2.gd` | Root script: _setup_blackboard, _setup_transitions, _setup_signals, guard methods |
| `DemonSlime2.tscn` | Inherited scene from AgentAIBase, adds Cleave/Slam/Counter/Defend/Roll/Stun states + BossAttackManager |
| `States/DS2Cleave.gd` | Cleave attack executor |
| `States/DS2Slam.gd` | Slam attack executor |
| `States/DS2Counter.gd` | Counter reaction executor |
| `States/DS2Defend.gd` | Defend reaction executor |
| `States/DS2Roll.gd` | Roll reaction executor |

### Tests (3 new files)

| File | Responsibility |
|---|---|
| `test/unit/test_blackboard.gd` | Unit tests for Blackboard |
| `test/unit/test_ai_controller.gd` | Unit tests for AIController + transition table |
| `test/integration/test_ds2.gd` | Integration tests for DemonSlime2 |

### Script Templates (2 new files)

| File | Responsibility |
|---|---|
| `script_templates/Node/ai_state.gd` | Skeleton for new State subclasses |
| `script_templates/CharacterBody2D/enemy_ai_root.gd` | Skeleton for new enemy root scripts |

---

## Task 1: AIEvents Constants

**Files:**
- Create: `Core/AI/AIEvents.gd`

- [ ] **Step 1: Create AIEvents.gd**

```gdscript
class_name AIEvents

const EV_DAMAGED         := &"damaged"
const EV_DIED            := &"died"
const EV_PHASE_CHANGED   := &"phase_changed"
const EV_ATTACK_FINISHED := &"attack_finished"
const EV_HIT_RECOVERED   := &"hit_recovered"
const EV_STUN_RECOVERED  := &"stun_recovered"
const EV_REACTION_DONE   := &"reaction_finished"
```

- [ ] **Step 2: Commit**

```bash
git add Core/AI/AIEvents.gd
git commit -m "feat(ai): add AIEvents constants"
```

---

## Task 2: Blackboard

**Files:**
- Create: `Core/AI/Blackboard.gd`
- Test: `test/unit/test_blackboard.gd`

- [ ] **Step 1: Write failing tests for Blackboard**

```gdscript
extends GutTest

## Blackboard 单元测试

var _bb: Blackboard

func before_each() -> void:
	_bb = Blackboard.new()

func after_each() -> void:
	_bb = null

# ============ get_var / set_var ============

func test_set_and_get_var() -> void:
	_bb.set_var(&"health", 100.0)
	assert_eq(_bb.get_var(&"health"), 100.0)

func test_get_var_default() -> void:
	assert_eq(_bb.get_var(&"missing", 42), 42)

func test_get_var_missing_no_default() -> void:
	assert_eq(_bb.get_var(&"missing"), null)

func test_has_var() -> void:
	assert_false(_bb.has_var(&"x"))
	_bb.set_var(&"x", 1)
	assert_true(_bb.has_var(&"x"))

func test_overwrite_var() -> void:
	_bb.set_var(&"x", 1)
	_bb.set_var(&"x", 2)
	assert_eq(_bb.get_var(&"x"), 2)

# ============ bind_var ============

func test_bind_var_reads_property() -> void:
	var node := Node2D.new()
	add_child_autofree(node)
	node.position = Vector2(10, 20)
	_bb.bind_var(&"pos_x", node, &"position:x")
	# bind_var should not work with sub-properties, test with simple property
	# Instead test with visible
	node.visible = false
	_bb.bind_var(&"visible", node, &"visible")
	assert_eq(_bb.get_var(&"visible"), false)
	node.visible = true
	assert_eq(_bb.get_var(&"visible"), true)

func test_bind_var_auto_sync() -> void:
	var node := Node.new()
	add_child_autofree(node)
	node.name = "TestNode"
	# Use a custom object with a simple property
	var hc := HealthComponent.new()
	hc.max_health = 100.0
	hc.health = 75.0
	node.add_child(hc)
	_bb.bind_var(&"hp", hc, &"health")
	assert_eq(_bb.get_var(&"hp"), 75.0)
	# Modify the source property — bb should reflect it
	hc.health = 50.0
	assert_eq(_bb.get_var(&"hp"), 50.0)

# ============ parent scope ============

func test_parent_scope_fallback() -> void:
	var parent_bb := Blackboard.new()
	parent_bb.set_var(&"shared", "from_parent")
	_bb.parent = parent_bb
	assert_eq(_bb.get_var(&"shared"), "from_parent")

func test_local_overrides_parent() -> void:
	var parent_bb := Blackboard.new()
	parent_bb.set_var(&"x", 1)
	_bb.parent = parent_bb
	_bb.set_var(&"x", 2)
	assert_eq(_bb.get_var(&"x"), 2)

func test_has_var_checks_parent() -> void:
	var parent_bb := Blackboard.new()
	parent_bb.set_var(&"y", 99)
	_bb.parent = parent_bb
	assert_true(_bb.has_var(&"y"))
```

- [ ] **Step 2: Run tests — verify they fail (Blackboard class not found)**

```bash
cd E:/workspace/4.godot/combo_demon && bash test/run_tests.sh test/unit/test_blackboard.gd
```

Expected: FAIL — `Blackboard` class does not exist.

- [ ] **Step 3: Implement Blackboard.gd**

```gdscript
class_name Blackboard extends RefCounted

## 动态黑板 — AI 决策的统一数据源
## 学 LimboAI blackboard.cpp：动态字典 + bind_var 属性同步 + parent scope

var _data: Dictionary = {}
var _bindings: Dictionary = {}   # StringName → { object: Object, property: StringName }
var parent: Blackboard = null

## 读变量（binding 实时同步 > 本地 > parent > default）
func get_var(var_name: StringName, default: Variant = null) -> Variant:
	if _bindings.has(var_name):
		var b: Dictionary = _bindings[var_name]
		if is_instance_valid(b.object):
			return b.object.get(b.property)
	if _data.has(var_name):
		return _data[var_name]
	if parent:
		return parent.get_var(var_name, default)
	return default

## 写变量
func set_var(var_name: StringName, value: Variant) -> void:
	_data[var_name] = value

func has_var(var_name: StringName) -> bool:
	if _data.has(var_name):
		return true
	if _bindings.has(var_name):
		return true
	if parent:
		return parent.has_var(var_name)
	return false

## 绑定变量到节点属性 — get_var 时实时读取 object.property
func bind_var(var_name: StringName, object: Object, property: StringName) -> void:
	_bindings[var_name] = { "object": object, "property": property }
	if is_instance_valid(object):
		_data[var_name] = object.get(property)

func unbind_var(var_name: StringName) -> void:
	_bindings.erase(var_name)
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
cd E:/workspace/4.godot/combo_demon && bash test/run_tests.sh test/unit/test_blackboard.gd
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Core/AI/Blackboard.gd test/unit/test_blackboard.gd
git commit -m "feat(ai): add Blackboard with dynamic dict, bind_var, parent scope"
```

---

## Task 3: State Base Class

**Files:**
- Create: `Core/AI/State.gd`

- [ ] **Step 1: Create State.gd**

```gdscript
class_name State extends Node

## 纯执行器状态基类
## 只执行行为，不做决策。通过 dispatch(event) 通知 AIController。

## 由 AIController 注入
var ai  # AIController — 不声明类型避免循环引用
var bb: Blackboard
var owner_node: Node

# ---- 生命周期（子类重写）----
func enter() -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

# ---- 向 AIController 发送事件 ----
func dispatch(event: StringName) -> void:
	if ai and ai.has_method("dispatch"):
		ai.dispatch(event)
```

- [ ] **Step 2: Commit**

```bash
git add Core/AI/State.gd
git commit -m "feat(ai): add State pure-executor base class"
```

---

## Task 4: AIController

**Files:**
- Create: `Core/AI/AIController.gd`
- Test: `test/unit/test_ai_controller.gd`

- [ ] **Step 1: Write failing tests for AIController**

```gdscript
extends GutTest

## AIController 单元测试

var _owner: CharacterBody2D
var _ai: AIController
var _sm: Node
var _idle: State
var _chase: State
var _hit: State
var _death: State

func before_each() -> void:
	_owner = CharacterBody2D.new()
	_owner.name = "TestEnemy"
	add_child_autofree(_owner)

	_ai = AIController.new()
	_ai.name = "AIController"
	_ai.initial_state_name = &"idle"
	_owner.add_child(_ai)
	_ai.set_owner(_owner)

	_sm = Node.new()
	_sm.name = "StateMachine"
	_ai.add_child(_sm)

	_idle = State.new()
	_idle.name = "Idle"
	_sm.add_child(_idle)

	_chase = State.new()
	_chase.name = "Chase"
	_sm.add_child(_chase)

	_hit = State.new()
	_hit.name = "Hit"
	_sm.add_child(_hit)

	_death = State.new()
	_death.name = "Death"
	_sm.add_child(_death)

	# Force ready (deferred calls need a frame)
	await get_tree().process_frame
	await get_tree().process_frame

func after_each() -> void:
	_owner = null
	_ai = null

# ============ 初始状态 ============

func test_initial_state() -> void:
	assert_eq(_ai.get_current_state_name(), &"idle")

# ============ 事件式转换 ============

func test_dispatch_event_transition() -> void:
	_ai.add_transition(_idle, _chase, &"detected")
	_ai.dispatch(&"detected")
	assert_eq(_ai.get_current_state_name(), &"chase")

func test_dispatch_no_match_stays() -> void:
	_ai.dispatch(&"unknown_event")
	assert_eq(_ai.get_current_state_name(), &"idle")

# ============ ANYSTATE ============

func test_anystate_transition() -> void:
	_ai.add_transition(_ai.ANYSTATE, _death, AIEvents.EV_DIED)
	_ai.dispatch(AIEvents.EV_DIED)
	assert_eq(_ai.get_current_state_name(), &"death")

func test_anystate_from_any_current() -> void:
	_ai.add_transition(_idle, _chase, &"go")
	_ai.add_transition(_ai.ANYSTATE, _death, AIEvents.EV_DIED)
	_ai.dispatch(&"go")
	assert_eq(_ai.get_current_state_name(), &"chase")
	_ai.dispatch(AIEvents.EV_DIED)
	assert_eq(_ai.get_current_state_name(), &"death")

# ============ Guard ============

func test_guard_blocks_transition() -> void:
	var blocked := true
	_ai.add_transition(_idle, _chase, &"go", func(): return not blocked)
	_ai.dispatch(&"go")
	assert_eq(_ai.get_current_state_name(), &"idle", "guard blocked")
	blocked = false
	_ai.dispatch(&"go")
	assert_eq(_ai.get_current_state_name(), &"chase", "guard passed")

# ============ Priority ============

func test_priority_ordering() -> void:
	_ai.add_transition(_ai.ANYSTATE, _chase, &"x", Callable(), 10)
	_ai.add_transition(_ai.ANYSTATE, _death, &"x", Callable(), 20)
	_ai.dispatch(&"x")
	assert_eq(_ai.get_current_state_name(), &"death", "higher priority wins")

# ============ 条件式转换 ============

func test_conditional_transition_on_tick() -> void:
	var should_go := false
	_ai.add_transition(_idle, _chase, &"", func(): return should_go)
	_ai._evaluate_conditional_transitions()
	assert_eq(_ai.get_current_state_name(), &"idle", "guard false")
	should_go = true
	_ai._evaluate_conditional_transitions()
	assert_eq(_ai.get_current_state_name(), &"chase", "guard true on tick")

# ============ from_state 过滤 ============

func test_from_state_mismatch_ignored() -> void:
	_ai.add_transition(_chase, _hit, &"hit_me")
	_ai.dispatch(&"hit_me")
	assert_eq(_ai.get_current_state_name(), &"idle", "from=chase but current=idle")

# ============ get_state ============

func test_get_state() -> void:
	assert_eq(_ai.get_state(&"idle"), _idle)
	assert_eq(_ai.get_state(&"chase"), _chase)
	assert_null(_ai.get_state(&"nonexistent"))
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
cd E:/workspace/4.godot/combo_demon && bash test/run_tests.sh test/unit/test_ai_controller.gd
```

Expected: FAIL — `AIController` class does not exist.

- [ ] **Step 3: Implement AIController.gd**

```gdscript
class_name AIController extends Node

## AI 总控制器 — 转换表（代码注册）+ 事件分派 + 条件式 safety tick
## 学 LimboAI hsm: add_transition(from, to, event, guard) + dispatch(event)

@export var initial_state_name: StringName = &"idle"
@export var safety_tick_interval: float = 0.2
@export var target_group: StringName = &"player"

var blackboard: Blackboard
var owner_node: Node
var target_node: Node
var states: Dictionary = {}       # StringName → State
var current_state: State
var ANYSTATE: State = null        # 哨兵值，null = 通配

var _transitions: Array = []
var _tick_accum: float = 0.0

# ---- 内部转换结构 ----
class _Transition:
	var from_state: State
	var to_state: State
	var event: StringName
	var guard: Callable
	var priority: int

## 注册转换规则
func add_transition(from: State, to: State, event: StringName = &"",
		guard: Callable = Callable(), priority: int = 0) -> void:
	var t := _Transition.new()
	t.from_state = from
	t.to_state = to
	t.event = event
	t.guard = guard
	t.priority = priority
	_transitions.append(t)
	_transitions.sort_custom(func(a, b): return a.priority > b.priority)

func _ready() -> void:
	owner_node = get_owner()
	blackboard = Blackboard.new()
	_collect_states()
	call_deferred("_deferred_init")

func _deferred_init() -> void:
	_find_target()
	_enter_initial_state()

func _collect_states() -> void:
	var container := get_node_or_null(^"StateMachine")
	if not container:
		return
	for child in container.get_children():
		if child is State:
			var s := child as State
			s.ai = self
			s.bb = blackboard
			s.owner_node = owner_node
			states[StringName(s.name.to_lower())] = s

func _find_target() -> void:
	if target_group != &"":
		target_node = get_tree().get_first_node_in_group(target_group)

func _enter_initial_state() -> void:
	var s: State = states.get(initial_state_name)
	if s:
		current_state = s
		current_state.enter()

# ---- 主循环 ----
func _physics_process(delta: float) -> void:
	_update_blackboard(delta)
	if current_state:
		current_state.physics_update(delta)
	_tick_accum += delta
	if _tick_accum >= safety_tick_interval:
		_tick_accum = 0.0
		_evaluate_conditional_transitions()

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

# ---- Blackboard 更新（仅计算值 — 属性用 bind）----
func _update_blackboard(delta: float) -> void:
	if is_instance_valid(target_node) and owner_node is Node2D:
		var dist: float = (owner_node as Node2D).global_position.distance_to(
			(target_node as Node2D).global_position)
		blackboard.set_var(&"distance", dist)
		blackboard.set_var(&"target_position", (target_node as Node2D).global_position)
		blackboard.set_var(&"target_alive",
			target_node.get("alive") if "alive" in target_node else true)
	else:
		blackboard.set_var(&"distance", INF)
		blackboard.set_var(&"target_alive", false)
	var atk_cd: float = blackboard.get_var(&"attack_cooldown", 0.0)
	if atk_cd > 0:
		blackboard.set_var(&"attack_cooldown", maxf(0.0, atk_cd - delta))
	var gcd: float = blackboard.get_var(&"global_cooldown", 0.0)
	if gcd > 0:
		blackboard.set_var(&"global_cooldown", maxf(0.0, gcd - delta))

# ---- 事件分派 ----
func dispatch(event: StringName) -> void:
	if current_state == null or event == &"":
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

## 条件式转换评估（event 为空的规则，safety tick 时调用）
func _evaluate_conditional_transitions() -> void:
	if current_state == null:
		return
	for t in _transitions:
		if t.event != &"":
			continue
		if t.from_state != null and t.from_state != current_state:
			continue
		if t.guard.is_valid() and not t.guard.call():
			continue
		_change_state(t.to_state)
		return

func _change_state(new_state: State) -> void:
	if new_state == null:
		return
	if current_state:
		current_state.exit()
	current_state = new_state
	current_state.enter()
	DebugConfig.debug("[AI] → %s" % new_state.name, "", "state_machine")

func get_current_state_name() -> StringName:
	return StringName(current_state.name.to_lower()) if current_state else &""

func get_state(state_name: StringName) -> State:
	return states.get(state_name)
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
cd E:/workspace/4.godot/combo_demon && bash test/run_tests.sh test/unit/test_ai_controller.gd
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Core/AI/AIController.gd test/unit/test_ai_controller.gd
git commit -m "feat(ai): add AIController with code-registered transitions and dispatch"
```

---

## Task 5: Stock States

**Files:**
- Create: `Core/AI/Stock/IdleState.gd`
- Create: `Core/AI/Stock/ChaseState.gd`
- Create: `Core/AI/Stock/WanderState.gd`
- Create: `Core/AI/Stock/HitState.gd`
- Create: `Core/AI/Stock/StunState.gd`
- Create: `Core/AI/Stock/DeathState.gd`

- [ ] **Step 1: Create IdleState.gd**

```gdscript
extends State

## Stock Idle — 停止移动，播放 idle 动画，无决策

func enter() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	var tree: AnimationTree = owner_node.get_node_or_null(^"AnimationTree") if owner_node else null
	if tree:
		tree.set("parameters/control_blend/blend_amount", 0.0)
		tree.set("parameters/locomotion/blend_position", Vector2.ZERO)

func physics_update(_delta: float) -> void:
	if owner_node is CharacterBody2D:
		var body := owner_node as CharacterBody2D
		body.velocity = Vector2.ZERO
		body.move_and_slide()
```

- [ ] **Step 2: Create ChaseState.gd**

```gdscript
extends State

## Stock Chase — 向目标移动，更新 locomotion 动画

@export var default_speed: float = 80.0

func enter() -> void:
	pass

func physics_update(_delta: float) -> void:
	if owner_node is not CharacterBody2D:
		return
	var body := owner_node as CharacterBody2D
	var target_pos: Vector2 = bb.get_var(&"target_position", body.global_position)
	var speed: float = bb.get_var(&"chase_speed", default_speed)
	var dir: Vector2 = (target_pos - body.global_position).normalized()
	body.velocity = dir * speed
	body.move_and_slide()
	# Update animation
	var tree: AnimationTree = owner_node.get_node_or_null(^"AnimationTree") if owner_node else null
	if tree:
		tree.set("parameters/control_blend/blend_amount", 0.0)
		var blend_x: float = sign(dir.x) if abs(dir.x) > 0.1 else 0.0
		var blend_y: float = clampf(body.velocity.length() / maxf(speed, 1.0), 0.0, 1.0)
		tree.set("parameters/locomotion/blend_position", Vector2(blend_x, blend_y))
	# Flip sprite
	if owner_node.has_method("_update_facing"):
		owner_node._update_facing()
	elif "sprite" in owner_node and owner_node.sprite is CanvasItem and "flip_h" in owner_node.sprite:
		if abs(dir.x) > 0.1:
			owner_node.sprite.flip_h = dir.x < 0

func exit() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
```

- [ ] **Step 3: Create WanderState.gd**

```gdscript
extends State

## Stock Wander — 随机方向移动，定时结束

@export var default_speed: float = 50.0
@export var min_time: float = 2.0
@export var max_time: float = 5.0

var _direction: Vector2
var _timer: Timer

func enter() -> void:
	_direction = Vector2.RIGHT.rotated(randf_range(0, TAU))
	_ensure_timer()
	_timer.wait_time = randf_range(min_time, max_time)
	_timer.start()

func physics_update(_delta: float) -> void:
	if owner_node is not CharacterBody2D:
		return
	var body := owner_node as CharacterBody2D
	var speed: float = bb.get_var(&"wander_speed", default_speed)
	body.velocity = _direction * speed
	body.move_and_slide()
	var tree: AnimationTree = owner_node.get_node_or_null(^"AnimationTree") if owner_node else null
	if tree:
		tree.set("parameters/control_blend/blend_amount", 0.0)
		var blend_x := sign(_direction.x) if abs(_direction.x) > 0.1 else 0.0
		tree.set("parameters/locomotion/blend_position", Vector2(blend_x, 0.3))

func exit() -> void:
	if _timer:
		_timer.stop()

func _ensure_timer() -> void:
	if not _timer:
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.timeout.connect(_on_timeout)
		add_child(_timer)

func _on_timeout() -> void:
	dispatch(AIEvents.EV_ATTACK_FINISHED)  # reuse as "wander done"
```

- [ ] **Step 4: Create HitState.gd**

```gdscript
extends State

## Stock Hit — 受击反应：读 BB damage, 应用 effects, 播动画, timer 结束后 dispatch hit_recovered

@export var default_duration: float = 0.3

var _timer: Timer

func enter() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO

	var damage: Damage = bb.get_var(&"last_damage")
	var attacker_pos: Vector2 = bb.get_var(&"last_attacker_pos", Vector2.ZERO)

	# Apply effects (knockback, stun, etc.)
	if damage and not damage.effects.is_empty():
		for effect in damage.effects:
			if effect:
				effect.apply_effect(owner_node as CharacterBody2D, attacker_pos)

	# Play hit animation
	var tree: AnimationTree = owner_node.get_node_or_null(^"AnimationTree") if owner_node else null
	if tree:
		tree.set("parameters/control_blend/blend_amount", 1.0)
		var pb = tree.get("parameters/control_sm/playback")
		if pb:
			pb.start(&"hit", true)

	# Timer
	_ensure_timer()
	_timer.wait_time = default_duration
	_timer.start()

func physics_update(delta: float) -> void:
	if owner_node is CharacterBody2D:
		var body := owner_node as CharacterBody2D
		body.velocity = body.velocity.lerp(Vector2.ZERO, 8.0 * delta)
		body.move_and_slide()

func exit() -> void:
	if _timer:
		_timer.stop()
	var tree: AnimationTree = owner_node.get_node_or_null(^"AnimationTree") if owner_node else null
	if tree:
		tree.set("parameters/control_blend/blend_amount", 0.0)
	bb.set_var(&"recently_hit", false)

func _ensure_timer() -> void:
	if not _timer:
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.timeout.connect(_on_timeout)
		add_child(_timer)

func _on_timeout() -> void:
	dispatch(AIEvents.EV_HIT_RECOVERED)
```

- [ ] **Step 5: Create StunState.gd**

```gdscript
extends State

## Stock Stun — 眩晕动画 + timer → dispatch stun_recovered

@export var default_duration: float = 1.5

var _timer: Timer

func enter() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	if "stunned" in owner_node:
		owner_node.stunned = true
	var tree: AnimationTree = owner_node.get_node_or_null(^"AnimationTree") if owner_node else null
	if tree:
		tree.set("parameters/control_blend/blend_amount", 1.0)
		var pb = tree.get("parameters/control_sm/playback")
		if pb:
			pb.start(&"stunned", true)
	_ensure_timer()
	_timer.wait_time = default_duration
	_timer.start()

func exit() -> void:
	if _timer:
		_timer.stop()
	if "stunned" in owner_node:
		owner_node.stunned = false
	var tree: AnimationTree = owner_node.get_node_or_null(^"AnimationTree") if owner_node else null
	if tree:
		tree.set("parameters/control_blend/blend_amount", 0.0)

func _ensure_timer() -> void:
	if not _timer:
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.timeout.connect(_on_timeout)
		add_child(_timer)

func _on_timeout() -> void:
	dispatch(AIEvents.EV_STUN_RECOVERED)
```

- [ ] **Step 6: Create DeathState.gd**

```gdscript
extends State

## Stock Death — 播放死亡动画，禁用 owner

func enter() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	var tree: AnimationTree = owner_node.get_node_or_null(^"AnimationTree") if owner_node else null
	if tree:
		tree.set("parameters/control_blend/blend_amount", 1.0)
		var pb = tree.get("parameters/control_sm/playback")
		if pb:
			pb.start(&"death", true)
	# Disable collision and processing
	if owner_node:
		owner_node.set_physics_process(false)
		var col: CollisionShape2D = owner_node.get_node_or_null(^"CollisionShape2D")
		if col:
			col.set_deferred(&"disabled", true)
```

- [ ] **Step 7: Commit**

```bash
git add Core/AI/Stock/
git commit -m "feat(ai): add 6 stock states (Idle/Chase/Wander/Hit/Stun/Death)"
```

---

## Task 6: AgentAIBase Scene Template

**Files:**
- Create: `Scenes/Characters/Templates/AgentAIBase.tscn` (via MCP)

- [ ] **Step 1: Create AgentAIBase.tscn using MCP**

Use `mcp__godot__create_scene` to create the scene, then `mcp__godot__add_node` to add children. The template structure:

```
AgentAIBase (CharacterBody2D, script=EnemyBase.gd, groups=["enemy"])
├── Sprite2D
├── AnimationPlayer
├── AnimationTree
├── CollisionShape2D
├── HurtBoxComponent (Area2D, script=HurtBoxComponent.gd)
│   └── CollisionShape2D
├── HitBoxComponent (Area2D, script=HitBoxComponent.gd)
│   └── CollisionShape2D
├── HealthComponent (script=HealthComponent.gd)
├── HealthBar (ProgressBar)
├── DamageNumbersAnchor (Node2D)
└── AIController (script=AIController.gd)
    └── StateMachine (Node)
        ├── Idle (script=Core/AI/Stock/IdleState.gd)
        ├── Chase (script=Core/AI/Stock/ChaseState.gd)
        ├── Hit (script=Core/AI/Stock/HitState.gd)
        └── Death (script=Core/AI/Stock/DeathState.gd)
```

Alternatively, duplicate existing `EnemyBase.tscn` and replace `EnemyStateMachine` subtree with new `AIController` subtree.

- [ ] **Step 2: Verify the template opens correctly in Godot editor**

```
mcp__godot__launch_editor
```

Open the scene in the editor to verify the node tree is correct.

- [ ] **Step 3: Commit**

```bash
git add Scenes/Characters/Templates/AgentAIBase.tscn
git commit -m "feat(ai): add AgentAIBase scene template with AIController + stock states"
```

---

## Task 7: Script Templates

**Files:**
- Create: `script_templates/Node/ai_state.gd`
- Create: `script_templates/CharacterBody2D/enemy_ai_root.gd`

- [ ] **Step 1: Create ai_state.gd**

```gdscript
# meta-description: AI State (pure executor, emits events)
extends State

func enter() -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func exit() -> void:
	pass
```

- [ ] **Step 2: Create enemy_ai_root.gd**

```gdscript
# meta-description: Enemy/Boss root script with AI wiring
extends EnemyBase  # Change to BossBase for bosses

@onready var ai: AIController = $AIController
@onready var health_comp: HealthComponent = $HealthComponent

func _ready() -> void:
	super._ready()
	_setup_blackboard()
	_setup_transitions()
	_setup_signals()

func _setup_blackboard() -> void:
	var bb := ai.blackboard
	bb.bind_var(&"health", health_comp, &"health")
	bb.bind_var(&"max_health", health_comp, &"max_health")

func _setup_transitions() -> void:
	var idle: State = ai.get_state(&"idle")
	var chase: State = ai.get_state(&"chase")
	var hit: State = ai.get_state(&"hit")
	var death: State = ai.get_state(&"death")
	# Behavior
	ai.add_transition(idle, chase, &"", _guard_detected)
	ai.add_transition(chase, idle, &"", _guard_target_lost)
	# Reactions
	ai.add_transition(ai.ANYSTATE, hit, AIEvents.EV_DAMAGED, Callable(), 10)
	ai.add_transition(hit, chase, AIEvents.EV_HIT_RECOVERED, _guard_target_alive, 10)
	ai.add_transition(hit, idle, AIEvents.EV_HIT_RECOVERED, Callable(), 0)
	ai.add_transition(ai.ANYSTATE, death, AIEvents.EV_DIED, Callable(), 100)

func _setup_signals() -> void:
	if health_comp:
		health_comp.damaged.connect(_on_damaged)
		health_comp.died.connect(_on_died)

func _on_damaged(damage: Damage, attacker_pos: Vector2) -> void:
	var bb := ai.blackboard
	bb.set_var(&"last_damage", damage)
	bb.set_var(&"last_attacker_pos", attacker_pos)
	bb.set_var(&"recently_hit", true)
	ai.dispatch(AIEvents.EV_DAMAGED)

func _on_died() -> void:
	ai.dispatch(AIEvents.EV_DIED)

func _guard_detected() -> bool:
	var bb := ai.blackboard
	return bb.get_var(&"target_alive", false) and bb.get_var(&"distance", INF) < 300.0

func _guard_target_lost() -> bool:
	var bb := ai.blackboard
	return not bb.get_var(&"target_alive", false) or bb.get_var(&"distance", INF) > 400.0

func _guard_target_alive() -> bool:
	return ai.blackboard.get_var(&"target_alive", false)
```

- [ ] **Step 3: Commit**

```bash
git add script_templates/
git commit -m "feat(ai): add Godot script templates for State and enemy root"
```

---

## Task 8: DemonSlime2 States

**Files:**
- Create: `Scenes/Characters/Bosses/DemonSlime2/States/DS2Cleave.gd`
- Create: `Scenes/Characters/Bosses/DemonSlime2/States/DS2Slam.gd`
- Create: `Scenes/Characters/Bosses/DemonSlime2/States/DS2Counter.gd`
- Create: `Scenes/Characters/Bosses/DemonSlime2/States/DS2Defend.gd`
- Create: `Scenes/Characters/Bosses/DemonSlime2/States/DS2Roll.gd`

- [ ] **Step 1: Create DS2Cleave.gd**

```gdscript
extends State

## DS2 Cleave — 扇形冲击波攻击

@export var cleave_cooldown: float = 2.5

var _anim_tree: AnimationTree

func enter() -> void:
	bb.set_var(&"attack_cooldown", cleave_cooldown)
	bb.set_var(&"global_cooldown", 0.3)
	bb.set_var(&"last_action", &"cleave")
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	_anim_tree = owner_node.get_node_or_null(^"AnimationTree") if owner_node else null
	if _anim_tree:
		_anim_tree.animation_finished.connect(_on_anim_finished, CONNECT_ONE_SHOT)
		_anim_tree.set("parameters/control_blend/blend_amount", 1.0)
		var pb = _anim_tree.get("parameters/control_sm/playback")
		if pb:
			pb.start(&"cleave", true)

func _on_anim_finished(_name: StringName) -> void:
	# Spawn shockwave — preload from Attacks/ directory
	# var shockwave_scene := preload("res://Scenes/Characters/Bosses/DemonSlime2/Attacks/FanShockwave.tscn")
	# ... instantiate and position ...
	dispatch(AIEvents.EV_ATTACK_FINISHED)

func exit() -> void:
	if _anim_tree:
		_anim_tree.set("parameters/control_blend/blend_amount", 0.0)
		if _anim_tree.animation_finished.is_connected(_on_anim_finished):
			_anim_tree.animation_finished.disconnect(_on_anim_finished)
```

- [ ] **Step 2: Create DS2Slam.gd**

```gdscript
extends State

## DS2 Slam — 近身地面冲击

@export var slam_cooldown: float = 3.0

var _anim_tree: AnimationTree

func enter() -> void:
	bb.set_var(&"attack_cooldown", slam_cooldown)
	bb.set_var(&"global_cooldown", 0.5)
	bb.set_var(&"last_action", &"slam")
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	_anim_tree = owner_node.get_node_or_null(^"AnimationTree") if owner_node else null
	if _anim_tree:
		_anim_tree.animation_finished.connect(_on_anim_finished, CONNECT_ONE_SHOT)
		_anim_tree.set("parameters/control_blend/blend_amount", 1.0)
		var pb = _anim_tree.get("parameters/control_sm/playback")
		if pb:
			pb.start(&"slam", true)

func _on_anim_finished(_name: StringName) -> void:
	dispatch(AIEvents.EV_ATTACK_FINISHED)

func exit() -> void:
	if _anim_tree:
		_anim_tree.set("parameters/control_blend/blend_amount", 0.0)
		if _anim_tree.animation_finished.is_connected(_on_anim_finished):
			_anim_tree.animation_finished.disconnect(_on_anim_finished)
```

- [ ] **Step 3: Create DS2Counter.gd**

```gdscript
extends State

## DS2 Counter — Poise 破防后的反击动作

var _anim_tree: AnimationTree

func enter() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	_anim_tree = owner_node.get_node_or_null(^"AnimationTree") if owner_node else null
	if _anim_tree:
		_anim_tree.animation_finished.connect(_on_anim_finished, CONNECT_ONE_SHOT)
		_anim_tree.set("parameters/control_blend/blend_amount", 1.0)
		var pb = _anim_tree.get("parameters/control_sm/playback")
		if pb:
			pb.start(&"counter", true)

func _on_anim_finished(_name: StringName) -> void:
	dispatch(AIEvents.EV_REACTION_DONE)

func exit() -> void:
	if _anim_tree:
		_anim_tree.set("parameters/control_blend/blend_amount", 0.0)
		if _anim_tree.animation_finished.is_connected(_on_anim_finished):
			_anim_tree.animation_finished.disconnect(_on_anim_finished)
```

- [ ] **Step 4: Create DS2Defend.gd**

```gdscript
extends State

## DS2 Defend — 格挡动作

var _anim_tree: AnimationTree

func enter() -> void:
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO
	_anim_tree = owner_node.get_node_or_null(^"AnimationTree") if owner_node else null
	if _anim_tree:
		_anim_tree.animation_finished.connect(_on_anim_finished, CONNECT_ONE_SHOT)
		_anim_tree.set("parameters/control_blend/blend_amount", 1.0)
		var pb = _anim_tree.get("parameters/control_sm/playback")
		if pb:
			pb.start(&"defend", true)

func _on_anim_finished(_name: StringName) -> void:
	dispatch(AIEvents.EV_REACTION_DONE)

func exit() -> void:
	if _anim_tree:
		_anim_tree.set("parameters/control_blend/blend_amount", 0.0)
		if _anim_tree.animation_finished.is_connected(_on_anim_finished):
			_anim_tree.animation_finished.disconnect(_on_anim_finished)
```

- [ ] **Step 5: Create DS2Roll.gd**

```gdscript
extends State

## DS2 Roll — 翻滚回避

@export var roll_speed: float = 200.0
@export var roll_duration: float = 0.4

var _direction: Vector2
var _timer: Timer

func enter() -> void:
	# Roll away from attacker
	var attacker_pos: Vector2 = bb.get_var(&"last_attacker_pos", Vector2.ZERO)
	if owner_node is CharacterBody2D and attacker_pos != Vector2.ZERO:
		_direction = ((owner_node as CharacterBody2D).global_position - attacker_pos).normalized()
	else:
		_direction = Vector2.RIGHT
	_ensure_timer()
	_timer.wait_time = roll_duration
	_timer.start()

func physics_update(_delta: float) -> void:
	if owner_node is CharacterBody2D:
		var body := owner_node as CharacterBody2D
		body.velocity = _direction * roll_speed
		body.move_and_slide()

func exit() -> void:
	if _timer:
		_timer.stop()
	if owner_node is CharacterBody2D:
		(owner_node as CharacterBody2D).velocity = Vector2.ZERO

func _ensure_timer() -> void:
	if not _timer:
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.timeout.connect(func(): dispatch(AIEvents.EV_REACTION_DONE))
		add_child(_timer)
```

- [ ] **Step 6: Commit**

```bash
git add Scenes/Characters/Bosses/DemonSlime2/States/
git commit -m "feat(ds2): add 5 DemonSlime2 states (Cleave/Slam/Counter/Defend/Roll)"
```

---

## Task 9: DemonSlime2 Root Script + Scene

**Files:**
- Create: `Scenes/Characters/Bosses/DemonSlime2/DemonSlime2.gd`
- Create: `Scenes/Characters/Bosses/DemonSlime2/DemonSlime2.tscn` (inherited from AgentAIBase.tscn, via MCP or manual)

- [ ] **Step 1: Create DemonSlime2.gd**

The complete root script with `_setup_blackboard`, `_setup_transitions`, `_setup_signals`, all guard methods. Use the code from spec §5.2 verbatim — see `docs/superpowers/specs/2026-04-11-ai-controller-decision-separation-design.md` §5.2.

```gdscript
class_name DemonSlime2 extends BossBase

## DemonSlime2 — 新 AI 架构试点 Boss

const PHASE_SPEED := {
	Phase.PHASE_1: 1.0,
	Phase.PHASE_2: 1.3,
	Phase.PHASE_3: 1.5,
}

@export var base_move_speed := 80.0

@onready var ai: AIController = $AIController
@onready var health_comp: HealthComponent = $HealthComponent
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var move_speed: float:
	get: return base_move_speed * PHASE_SPEED.get(current_phase, 1.0)

func _on_boss_ready() -> void:
	detection_radius = 600.0
	attack_range = 250.0
	min_distance = 80.0
	_setup_blackboard()
	_setup_transitions()
	_setup_signals()

func _setup_blackboard() -> void:
	var bb := ai.blackboard
	bb.bind_var(&"health", health_comp, &"health")
	bb.bind_var(&"max_health", health_comp, &"max_health")
	bb.bind_var(&"current_phase", self, &"current_phase")
	bb.set_var(&"detection_radius", detection_radius)
	bb.set_var(&"attack_range", attack_range)
	bb.set_var(&"attack_cooldown", 0.0)
	bb.set_var(&"global_cooldown", 0.0)
	bb.set_var(&"last_action", &"")
	bb.set_var(&"recently_hit", false)
	bb.set_var(&"chase_speed", base_move_speed)

func _setup_transitions() -> void:
	var idle: State = ai.get_state(&"idle")
	var chase: State = ai.get_state(&"chase")
	var cleave: State = ai.get_state(&"cleave")
	var slam: State = ai.get_state(&"slam")
	var hit: State = ai.get_state(&"hit")
	var stun: State = ai.get_state(&"stun")
	var death: State = ai.get_state(&"death")
	var counter: State = ai.get_state(&"counter")
	var defend: State = ai.get_state(&"defend")
	var roll: State = ai.get_state(&"roll")

	# Behavior (conditional — evaluated on safety tick)
	ai.add_transition(idle, chase, &"", _guard_detected)
	ai.add_transition(chase, idle, &"", _guard_target_lost)
	ai.add_transition(chase, slam, &"", _guard_can_slam, 20)
	ai.add_transition(chase, cleave, &"", _guard_can_cleave, 10)

	# Attack finished (event)
	ai.add_transition(cleave, chase, AIEvents.EV_ATTACK_FINISHED)
	ai.add_transition(slam, chase, AIEvents.EV_ATTACK_FINISHED)

	# Reactions (ANYSTATE, by priority)
	ai.add_transition(ai.ANYSTATE, death, AIEvents.EV_DIED, Callable(), 100)
	ai.add_transition(ai.ANYSTATE, chase, AIEvents.EV_PHASE_CHANGED, _guard_target_alive, 50)
	ai.add_transition(ai.ANYSTATE, counter, AIEvents.EV_DAMAGED, _guard_poise_broken, 30)
	ai.add_transition(ai.ANYSTATE, defend, AIEvents.EV_DAMAGED, _guard_evasion_defend, 20)
	ai.add_transition(ai.ANYSTATE, roll, AIEvents.EV_DAMAGED, _guard_evasion_roll, 19)
	ai.add_transition(ai.ANYSTATE, hit, AIEvents.EV_DAMAGED, Callable(), 10)

	# Recovery
	ai.add_transition(hit, chase, AIEvents.EV_HIT_RECOVERED, _guard_target_alive, 10)
	ai.add_transition(hit, idle, AIEvents.EV_HIT_RECOVERED, Callable(), 0)
	ai.add_transition(stun, chase, AIEvents.EV_STUN_RECOVERED, _guard_target_alive, 10)
	ai.add_transition(stun, idle, AIEvents.EV_STUN_RECOVERED, Callable(), 0)
	ai.add_transition(counter, chase, AIEvents.EV_REACTION_DONE)
	ai.add_transition(defend, chase, AIEvents.EV_REACTION_DONE)
	ai.add_transition(roll, chase, AIEvents.EV_REACTION_DONE)

func _setup_signals() -> void:
	if health_comp:
		health_comp.damaged.connect(_on_damaged)
		health_comp.died.connect(_on_died)
	phase_changed.connect(_on_phase_changed)

# ---- Guard methods ----
func _guard_detected() -> bool:
	var bb := ai.blackboard
	return bb.get_var(&"target_alive", false) and bb.get_var(&"distance", INF) < detection_radius

func _guard_target_lost() -> bool:
	var bb := ai.blackboard
	return not bb.get_var(&"target_alive", false) or bb.get_var(&"distance", INF) > 700.0

func _guard_target_alive() -> bool:
	return ai.blackboard.get_var(&"target_alive", false)

func _guard_can_cleave() -> bool:
	var bb := ai.blackboard
	if bb.get_var(&"attack_cooldown", 1.0) > 0: return false
	if bb.get_var(&"global_cooldown", 1.0) > 0: return false
	if bb.get_var(&"distance", INF) > attack_range: return false
	if bb.get_var(&"last_action") == &"cleave": return false
	return true

func _guard_can_slam() -> bool:
	var bb := ai.blackboard
	if bb.get_var(&"attack_cooldown", 1.0) > 0: return false
	if bb.get_var(&"global_cooldown", 1.0) > 0: return false
	if bb.get_var(&"distance", INF) > 180.0: return false
	if bb.get_var(&"current_phase", 0) < 1: return false
	return true

func _guard_poise_broken() -> bool:
	return ai.blackboard.get_var(&"poise_broken", false)

func _guard_evasion_defend() -> bool:
	return ai.blackboard.get_var(&"evasion_rolled", false) and randf() < 0.5

func _guard_evasion_roll() -> bool:
	return ai.blackboard.get_var(&"evasion_rolled", false)

# ---- Signal handlers ----
func _on_damaged(damage: Damage, attacker_pos: Vector2) -> void:
	var bb := ai.blackboard
	bb.set_var(&"last_damage", damage)
	bb.set_var(&"last_attacker_pos", attacker_pos)
	bb.set_var(&"recently_hit", true)
	bb.set_var(&"poise_broken", _check_poise(damage))
	bb.set_var(&"evasion_rolled", _check_evasion())
	ai.dispatch(AIEvents.EV_DAMAGED)

func _on_died() -> void:
	ai.dispatch(AIEvents.EV_DIED)

func _on_phase_changed(_new_phase: int) -> void:
	ai.dispatch(AIEvents.EV_PHASE_CHANGED)

func _update_facing() -> void:
	if velocity.x != 0 and sprite:
		sprite.flip_h = velocity.x < 0

func _check_poise(_damage: Damage) -> bool:
	if not poise_enabled:
		return false
	return take_poise_hit()

func _check_evasion() -> bool:
	if not evasion_enabled:
		return false
	var chance: float = evasion_chance_per_phase.get(current_phase, 0.0)
	return chance > 0 and randf() < chance
```

- [ ] **Step 2: Create DemonSlime2.tscn as inherited scene from AgentAIBase.tscn**

Use MCP or manual editor:
1. Inherit `AgentAIBase.tscn`
2. Override root script to `DemonSlime2.gd`
3. Replace Sprite2D with AnimatedSprite2D (hide Sprite2D, add AnimatedSprite2D)
4. Add to StateMachine: Cleave, Slam, Counter, Defend, Roll nodes with their scripts
5. Add StunState to StateMachine
6. Add BossAttackManager node (optional, for attack pools — can be deferred)

- [ ] **Step 3: Commit**

```bash
git add Scenes/Characters/Bosses/DemonSlime2/
git commit -m "feat(ds2): add DemonSlime2 pilot boss with new AI architecture"
```

---

## Task 10: Integration Tests

**Files:**
- Create: `test/integration/test_ds2.gd`

- [ ] **Step 1: Write integration tests**

```gdscript
extends GutTest

## DemonSlime2 集成测试

var _ds2: DemonSlime2
var _ai: AIController

func before_each() -> void:
	# Minimal DemonSlime2 setup without full scene
	_ds2 = DemonSlime2.new()
	_ds2.name = "DemonSlime2"

	var hc := HealthComponent.new()
	hc.name = "HealthComponent"
	hc.max_health = 200.0
	hc.health = 200.0
	_ds2.add_child(hc)

	_ai = AIController.new()
	_ai.name = "AIController"
	_ds2.add_child(_ai)

	var sm := Node.new()
	sm.name = "StateMachine"
	_ai.add_child(sm)

	# Add stock states
	for state_name in ["Idle", "Chase", "Hit", "Death", "Stun"]:
		var s := State.new()
		s.name = state_name
		sm.add_child(s)

	# Add DS2 states
	for state_name in ["Cleave", "Slam", "Counter", "Defend", "Roll"]:
		var s := State.new()
		s.name = state_name
		sm.add_child(s)

	add_child_autofree(_ds2)
	await get_tree().process_frame
	await get_tree().process_frame

func after_each() -> void:
	_ds2 = null
	_ai = null

func test_initial_state_is_idle() -> void:
	assert_eq(_ai.get_current_state_name(), &"idle")

func test_dispatch_damaged_goes_to_hit() -> void:
	var bb := _ai.blackboard
	bb.set_var(&"last_damage", null)
	bb.set_var(&"last_attacker_pos", Vector2.ZERO)
	bb.set_var(&"recently_hit", true)
	_ai.dispatch(AIEvents.EV_DAMAGED)
	assert_eq(_ai.get_current_state_name(), &"hit")

func test_dispatch_died_goes_to_death() -> void:
	_ai.dispatch(AIEvents.EV_DIED)
	assert_eq(_ai.get_current_state_name(), &"death")

func test_guard_detected_triggers_chase() -> void:
	_ai.blackboard.set_var(&"target_alive", true)
	_ai.blackboard.set_var(&"distance", 100.0)
	_ai._evaluate_conditional_transitions()
	assert_eq(_ai.get_current_state_name(), &"chase")

func test_guard_can_cleave() -> void:
	# Move to chase first
	_ai.blackboard.set_var(&"target_alive", true)
	_ai.blackboard.set_var(&"distance", 100.0)
	_ai._evaluate_conditional_transitions()
	assert_eq(_ai.get_current_state_name(), &"chase")
	# Set conditions for cleave
	_ai.blackboard.set_var(&"attack_cooldown", 0.0)
	_ai.blackboard.set_var(&"global_cooldown", 0.0)
	_ai.blackboard.set_var(&"distance", 200.0)
	_ai.blackboard.set_var(&"last_action", &"")
	_ai._evaluate_conditional_transitions()
	assert_eq(_ai.get_current_state_name(), &"cleave")

func test_attack_finished_returns_to_chase() -> void:
	# Get to cleave state
	_ai.blackboard.set_var(&"target_alive", true)
	_ai.blackboard.set_var(&"distance", 100.0)
	_ai.blackboard.set_var(&"attack_cooldown", 0.0)
	_ai.blackboard.set_var(&"global_cooldown", 0.0)
	_ai.blackboard.set_var(&"last_action", &"")
	_ai._evaluate_conditional_transitions()  # idle → chase
	_ai._evaluate_conditional_transitions()  # chase → cleave
	assert_eq(_ai.get_current_state_name(), &"cleave")
	_ai.dispatch(AIEvents.EV_ATTACK_FINISHED)
	assert_eq(_ai.get_current_state_name(), &"chase")
```

- [ ] **Step 2: Run tests**

```bash
cd E:/workspace/4.godot/combo_demon && bash test/run_tests.sh test/integration/test_ds2.gd
```

Expected: All tests PASS.

- [ ] **Step 3: Commit**

```bash
git add test/integration/test_ds2.gd
git commit -m "test(ds2): add DemonSlime2 integration tests"
```

---

## Task 11: Runtime Verification

- [ ] **Step 1: Run DemonSlime2 in-game**

Use MCP to launch the project with DemonSlime2 placed in a test level:

```
mcp__godot__run_project
```

- [ ] **Step 2: Check debug logs**

```
mcp__godot__get_debug_output
```

Look for `[AI] → idle`, `[AI] → chase`, `[AI] → cleave`, `[AI] → hit` patterns.

- [ ] **Step 3: Fix any runtime issues found**

Iterate on any issues discovered during runtime testing.

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "fix(ds2): runtime fixes from in-game verification"
```
