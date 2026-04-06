# 状态机 Bug 修复实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 BladeKeeper 攻击后卡死的三层根因 — `can_transition_to` 语义缺陷、`enter()` 中路由、模板占位状态死锁

**Architecture:** 四个独立改动：(1) BaseStateMachine 中自发转换跳过优先级检查 + 回滚 `_execute_transition` 临时修改；(2) BKAttack 路由逻辑上移到 BKChase + BossAttackManager 添加 `last_picked_entry`；(3) BladeKeeper/DemonSlime 场景移除未实现的模板状态节点；(4) BossBaseState 移除占位逻辑

**Tech Stack:** Godot 4.4.1, GDScript, MCP tools for runtime verification

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `Core/StateMachine/BaseStateMachine.gd` | 自发转换跳过优先级检查 + 回滚 `_execute_transition` |
| Modify | `Scenes/Characters/Bosses/Shared/BossAttackManager.gd` | 添加 `last_picked_entry` 属性 |
| Modify | `Scenes/Characters/Bosses/BladeKeeper/States/BKChase.gd` | 攻击路由决策 |
| Modify | `Scenes/Characters/Bosses/BladeKeeper/States/BKAttack.gd` | 简化 enter()，只处理 combo/special |
| Modify | `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn` | 移除 Patrol/Circle/Retreat 节点 |
| Modify | `Scenes/Characters/Bosses/DemonSlime/DemonSlime.tscn` | 移除 Patrol/Circle/Retreat 节点 |
| Modify | `Scenes/Characters/Bosses/Shared/BossBaseState.gd` | 移除占位 enter()/process_state() |

---

### Task 1: BaseStateMachine — 自发转换跳过优先级检查

**Files:**
- Modify: `Core/StateMachine/BaseStateMachine.gd:128-168`

**背景:** 当前 `_on_state_transition()` 对所有转换都调用 `can_transition_to()`，导致 `can_be_interrupted = false` 的状态（如 BKRoll）在自行结束后也无法转换到同优先级状态。由于所有 `transitioned.emit(self, ...)` 中 `self` 就是 `current_state`，`from_state == current_state` 天然成立，可直接作为"自发"的判据。

同时，当前 `_execute_transition` 有一个临时修改：`current_state = new_state` 被移到 `enter()` 之前。这个临时修改是为了让 `enter()` 中发出的 `transitioned` 信号通过 `from_state == current_state` 检查。但改动 2 会移除 `enter()` 中的路由逻辑，所以这个临时修改应回滚。

- [ ] **Step 1: 修改 `_on_state_transition()` — 自发转换跳过优先级检查**

在 `Core/StateMachine/BaseStateMachine.gd` 中，将 `_on_state_transition()` 方法替换为：

```gdscript
## 状态转换处理（带优先级检查）
func _on_state_transition(from_state: BaseState, new_state_name: String) -> void:
	var state_name_str = str(current_state.name) if current_state else "null"

	# 只处理当前状态的转换请求
	if from_state != current_state:
		var from_name = str(from_state.name) if from_state else "null"
		print("[StateMachine] Ignoring transition from %s (current=%s)" % [from_name, state_name_str])
		return

	# 查找新状态
	var new_state = states.get(new_state_name.to_lower())
	if not new_state:
		print("[StateMachine] State '%s' not found, available: %s" % [new_state_name, states.keys()])
		return

	# 自发转换（from_state == current_state）始终允许，跳过优先级检查
	# 外部中断（on_damaged 等）的目标状态优先级为 REACTION/CONTROL，天然通过高优先级检查
	# 因此这里直接跳过 can_transition_to 检查
	print("[StateMachine] Transitioning: %s -> %s" % [state_name_str, new_state_name])
	# 执行状态转换
	_execute_transition(from_state, new_state)
```

**关键变化:** 移除了 `if current_state and not current_state.can_transition_to(new_state)` 检查块。所有通过 `transitioned` 信号发起的转换都是自发的（因为 `from_state == current_state` 已在上面验证），直接放行。外部中断（`on_damaged`）的目标状态（stun/hit）优先级为 REACTION(1) 或 CONTROL(2)，高于 BEHAVIOR(0)，天然通过。

- [ ] **Step 2: 回滚 `_execute_transition()` — 恢复 enter() 之后赋值**

在同一文件中，将 `_execute_transition()` 方法替换为：

```gdscript
## 执行状态转换（内部方法）
func _execute_transition(from_state: BaseState, new_state: BaseState) -> void:
	# 退出当前状态
	if current_state:
		current_state.exit()

	# 进入新状态
	new_state.enter()

	# enter() 之后更新 current_state（标准顺序）
	current_state = new_state

	# 状态转换日志（仅在调试模式下输出）
	var owner_name = str(owner_node.name) if owner_node else "Unknown"
	var from_name = str(from_state.name) if from_state else "None"
	DebugConfig.debug("[%s] %s -> %s" % [owner_name, from_name, new_state.name], "", "state_machine")
```

**关键变化:** `current_state = new_state` 从 `enter()` 之前移回 `enter()` 之后。之前临时前移是为了支持 `enter()` 中 emit 转换，但改动 2 会移除该模式，所以回滚到标准顺序。

- [ ] **Step 3: 提交**

```bash
git add Core/StateMachine/BaseStateMachine.gd
git commit -m "fix: self-initiated transitions bypass priority check in BaseStateMachine

Transitions emitted via transitioned signal (from_state == current_state)
are always self-initiated — skip can_transition_to() check entirely.
Revert temporary _execute_transition ordering change."
```

---

### Task 2: BossAttackManager — 添加 `last_picked_entry`

**Files:**
- Modify: `Scenes/Characters/Bosses/Shared/BossAttackManager.gd:37-42`

**背景:** BKChase 需要调用 `pick_attack()` 做路由决策，BKAttack 需要读取选中的攻击条目。为避免 double-call `pick_attack()`（结果随机），在 BossAttackManager 上添加 `last_picked_entry` 缓存最近一次 `pick_attack()` 的结果。

- [ ] **Step 1: 添加 `last_picked_entry` 属性并修改 `pick_attack()`**

在 `Scenes/Characters/Bosses/Shared/BossAttackManager.gd` 中，在 `var _cached_player: Node2D` 之后添加属性，并修改 `pick_attack()`:

```gdscript
var _cached_player: Node2D

## 最近一次 pick_attack() 的结果（供状态读取，避免重复调用）
var last_picked_entry: Dictionary = {}
```

将 `pick_attack()` 修改为：

```gdscript
## 从当前阶段攻击池加权选取（结果缓存到 last_picked_entry）
func pick_attack() -> Dictionary:
	var config := get_current_config()
	if not config:
		last_picked_entry = {}
		return last_picked_entry
	last_picked_entry = config.pick_attack()
	return last_picked_entry
```

- [ ] **Step 2: 提交**

```bash
git add Scenes/Characters/Bosses/Shared/BossAttackManager.gd
git commit -m "feat: add last_picked_entry to BossAttackManager

Cache pick_attack() result so Chase can route and Attack can
read the same entry without double-calling."
```

---

### Task 3: BKChase — 攻击路由决策

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/States/BKChase.gd`

**背景:** BKChase 继承 ChaseState 继承 BaseState（不是 BossState），没有 `get_attack_manager()` 方法。需要通过遍历 owner 子节点找到 BossAttackManager。路由模式参考 DSChase：在 Chase 中调用 `pick_attack()` 根据 mode 路由到不同状态。

- [ ] **Step 1: 重写 `_on_reached_attack_range()` 添加路由逻辑**

将 `Scenes/Characters/Bosses/BladeKeeper/States/BKChase.gd` 整体替换为：

```gdscript
extends "res://Core/StateMachine/CommonStates/ChaseState.gd"

## BladeKeeper Chase 状态 — 继承通用 ChaseState
## 每次 enter 读取 Boss 参数（支持阶段变速），重写攻击路由

func _init():
	super._init()
	enable_sprite_flip = true
	give_up_state_name = "idle"

func enter() -> void:
	# 每次进入 chase 时读取当前 Boss 参数（支持阶段变速）
	var boss := owner_node as BossBase
	if boss:
		default_chase_speed = (boss as BladeKeeper).move_speed if boss is BladeKeeper else 180.0
		default_attack_range = boss.attack_range
		default_give_up_range = boss.detection_radius
	super.enter()

## 重写：到达攻击范围时，从 BossAttackManager 选择攻击模式并路由
func _on_reached_attack_range() -> String:
	var boss := owner_node as BossBase
	if not boss or boss.attack_cooldown > 0:
		return ""  # 冷却中，留在 chase

	# 查找 BossAttackManager（BKChase 继承 BaseState，无 get_attack_manager()）
	var mgr: BossAttackManager = null
	for child in boss.get_children():
		if child is BossAttackManager:
			mgr = child
			break

	if not mgr:
		return "attack"

	var entry: Dictionary = mgr.pick_attack()
	var mode: String = entry.get("mode", "attack")
	boss.attack_cooldown = mgr.get_cooldown()

	match mode:
		"defend":
			return "defend"
		"projectile":
			return "projectile"
		"trap":
			return "trap"
		"special":
			return "attack"  # special 由 BKAttack 处理
		_:
			if mode.begins_with("roll"):
				return "roll"
			return "attack"
```

**关键变化:**
- `_on_reached_attack_range()` 不再仅返回 `"attack"`，而是根据 `pick_attack()` 结果路由
- `boss.attack_cooldown` 在 Chase 中设置（之前在 BKAttack.enter() 中）
- `special` mode 路由到 `"attack"`（BKAttack 从 `mgr.last_picked_entry` 读取 mode）

- [ ] **Step 2: 提交**

```bash
git add Scenes/Characters/Bosses/BladeKeeper/States/BKChase.gd
git commit -m "refactor: move attack mode routing from BKAttack to BKChase

Chase now calls pick_attack() and routes to defend/roll/projectile/trap/attack
based on mode. BKAttack no longer needs to do routing in enter()."
```

---

### Task 4: BKAttack — 简化 enter()

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/States/BKAttack.gd:15-52`

**背景:** 路由决策已移至 BKChase。BKAttack.enter() 只需处理 combo 和 special 两种情况。从 `mgr.last_picked_entry` 读取 mode（不再调用 `pick_attack()`），不再设置 `attack_cooldown`。

- [ ] **Step 1: 简化 `enter()` — 移除路由分支**

将 `Scenes/Characters/Bosses/BladeKeeper/States/BKAttack.gd` 的 `enter()` 替换为：

```gdscript
func enter() -> void:
	var boss := get_boss()
	if not boss:
		transitioned.emit(self, "idle")
		return

	_anim_tree_ref = get_anim_tree()

	# 从 BossAttackManager.last_picked_entry 读取模式（由 BKChase 调用 pick_attack() 设置）
	var mgr := get_attack_manager()
	var mode: String = mgr.last_picked_entry.get("mode", "attack") if mgr else "attack"

	if mode == "special":
		_is_special = true
		_current_combo_step = 0
		enter_control_state("sp_atk")
	else:
		_is_special = false
		_current_combo_step = 0
		enter_control_state(COMBO_ANIMS[0])

	if _anim_tree_ref:
		_anim_tree_ref.animation_finished.connect(_on_animation_finished)
```

**关键变化:**
- 不再调用 `mgr.pick_attack()`，改为读取 `mgr.last_picked_entry`
- 移除 `boss.attack_cooldown = ...`（已在 BKChase 中设置）
- 移除 `defend`/`roll`/`combo` 路由分支（已在 BKChase 中处理）
- `combo` mode 不再需要特殊处理（降级为普通连击，与 default 一致）

- [ ] **Step 2: 提交**

```bash
git add Scenes/Characters/Bosses/BladeKeeper/States/BKAttack.gd
git commit -m "refactor: simplify BKAttack.enter() - remove routing branches

enter() now only handles combo and special modes.
Reads mode from mgr.last_picked_entry instead of calling pick_attack().
Routing decision moved to BKChase._on_reached_attack_range()."
```

---

### Task 5: 移除 BladeKeeper 和 DemonSlime 的模板占位状态节点

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn`
- Modify: `Scenes/Characters/Bosses/DemonSlime/DemonSlime.tscn`

**背景:** BossBase.tscn 模板预置 7 个状态节点。BladeKeeper 和 DemonSlime 不需要 Patrol/Circle/Retreat，进入这些状态后会触发 BossBaseState 占位逻辑（force_transition 循环）。正确做法：在继承场景中删除不需要的节点。`_resolve_state("retreat", "chase")` 找不到 retreat 时会自动 fallback 到 chase。

**重要:** 这需要在 Godot 编辑器的继承场景中"标记删除"节点。在 .tscn 文件中，这对应在继承节点上不存在子节点定义（Godot 继承场景中删除节点会在 .tscn 中添加 `__meta__` 或直接从文件中移除该节点的覆盖）。

由于 .tscn 文件是文本格式，最可靠的方式是：用 MCP Godot 工具或手动编辑 .tscn 文件。

- [ ] **Step 1: 分析 BladeKeeper.tscn 中需要移除的节点**

先读取 BladeKeeper.tscn，找到 Patrol、Circle、Retreat 节点定义。在 Godot 继承场景中，如果这些节点没有自定义属性覆盖，它们只作为继承节点存在。

从 BossBase.tscn 继承的节点在子场景 .tscn 中只在有属性覆盖时才会出现。要"删除"继承节点，需要在 .tscn 文件中添加 `instance_placeholder` 或使用编辑器。

**最安全的方式:** 使用 Godot MCP 工具打开编辑器操作，或者在 .tscn 中给这些节点设置一个标记脚本。

**实际方案:** 由于直接从 .tscn 文本中删除继承节点行并不能真正删除节点（它们仍从父场景继承），我们改用以下方法：

给 BladeKeeper 和 DemonSlime 的 Patrol/Circle/Retreat 节点挂上一个最小脚本来覆盖行为，使其立即转出。但这与移除节点的设计不同。

**最终方案:** 在 Godot 编辑器中手动操作。在 .tscn 文件中，继承场景要删除父场景的节点，需要找到这些节点的 `[node]` 行并确认是否可以移除。

让我们检查这些节点在 .tscn 中的实际表现，然后决定具体操作方式。

**操作:** 读取 .tscn 文件中 Patrol、Circle、Retreat 相关行，使用编辑器或手动添加 `__meta__` 标记来删除。

> **Note to implementer:** 先读取 BladeKeeper.tscn 搜索 `Patrol`、`Circle`、`Retreat` 节点行。Godot 4 继承场景中，可以通过在 .tscn 中完全移除这些节点的 `[node]` 块来实现删除（如果它们只是继承的，没有自定义属性，则不会有 `[node]` 块 — 此时节点会自动从父场景继承且无法通过文本编辑删除）。如果节点有属性覆盖（如 Retreat 的 `can_be_interrupted`），移除 `[node]` 块只是移除覆盖，节点仍从父场景继承。

> **推荐方法:** 使用 MCP Godot 编辑器打开场景手动删除，或者修改 BossBaseState 占位逻辑为安全退出（Task 6 的方案已覆盖）。如果无法通过文本编辑实现，则跳过节点删除，依赖 Task 6 的占位清理 + Task 1 的转换修复。

- [ ] **Step 2: 在 BladeKeeper.tscn 中处理 Patrol/Circle/Retreat**

在 BladeKeeper.tscn 中搜索这三个节点。如果它们有 `[node]` 块且有属性覆盖，修改它们的 script 指向一个立即退出的脚本，或移除覆盖属性。

**BladeKeeper.tscn 中 Retreat 节点有覆盖属性（`can_be_interrupted = false`），需要移除该覆盖行。Patrol 和 Circle 可能没有覆盖。**

对于没有 `[node]` 块的继承节点：它们从 BossBase.tscn 自动继承，无法通过文本编辑删除。这种情况下依赖 Task 6（BossBaseState 占位行为改为安全退出到 chase/idle）。

**如果 .tscn 中存在 Retreat 的 `[node]` 块，移除其中的属性覆盖：**

搜索并移除类似这样的行：
```
[node name="Retreat" ... ]
can_be_interrupted = false
```

改为不出现该 `[node]` 块（让 Retreat 使用父场景默认值 + BossBaseState 默认 `_init()` 中的 `can_be_interrupted = true`）。

- [ ] **Step 3: 对 DemonSlime.tscn 执行同样操作**

检查 DemonSlime.tscn 中 Patrol/Circle/Retreat 节点是否有属性覆盖，如有则移除。

- [ ] **Step 4: 提交**

```bash
git add Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn Scenes/Characters/Bosses/DemonSlime/DemonSlime.tscn
git commit -m "fix: remove property overrides from unused template states

Remove can_be_interrupted overrides from inherited Patrol/Circle/Retreat
nodes in BladeKeeper and DemonSlime scenes."
```

---

### Task 6: BossBaseState — 将占位逻辑改为安全退出

**Files:**
- Modify: `Scenes/Characters/Bosses/Shared/BossBaseState.gd:13-32`

**背景:** BossBase.tscn 模板的 Patrol/Circle/Retreat 使用 BossBaseState.gd 脚本。当前有临时添加的 `enter()`/`process_state()` 占位行为来防止死锁。

由于 Godot 继承场景中无法通过文本编辑可靠删除继承节点，这些节点可能仍然存在。改为：移除 `enter()` 占位但保留 `process_state()` 安全退出逻辑（改用 `transitioned.emit` 而非 `force_transition`），作为防御性编码。

**设计变更:** 原 spec 说"移除占位逻辑"，但考虑到继承节点可能无法删除，改为"简化占位逻辑为最小安全退出"。

- [ ] **Step 1: 移除 `enter()` 并简化 `process_state()`**

将 `Scenes/Characters/Bosses/Shared/BossBaseState.gd` 的占位代码块替换为：

```gdscript
# ============ 占位状态安全退出 ============
# BossBase 模板的 Patrol/Circle/Retreat 等未覆盖的状态。
# process_state() 仅对脚本 == BossState 本身的节点生效，立即转到 chase/idle。

func process_state(_delta: float) -> void:
	# 仅对未被子类覆盖的占位状态（脚本 == BossState 本身）生效
	if get_script() != BossState:
		return
	# 安全退出到 chase 或 idle
	var next := _resolve_state("chase", "idle")
	transitioned.emit(self, next)
```

**关键变化:**
- 移除 `enter()` 覆盖（不再需要手动设 `can_be_interrupted = true`，因为 `_init()` 已设置且 Task 1 的自发转换修复确保能退出）
- `process_state()` 改用 `transitioned.emit` 而非 `force_transition`（符合自发转换语义）
- 移除 `evaluate_combat_transition()` 调用（占位状态无需复杂决策，直接去 chase/idle）

- [ ] **Step 2: 提交**

```bash
git add Scenes/Characters/Bosses/Shared/BossBaseState.gd
git commit -m "fix: simplify BossBaseState placeholder to safe exit via transitioned signal

Remove enter() override. Placeholder process_state() now emits
transitioned signal instead of force_transition for clean exit."
```

---

### Task 7: 运行时验证

**Files:** None (runtime testing only)

- [ ] **Step 1: 启动游戏验证 BladeKeeper**

使用 MCP 工具运行项目：

```
mcp__godot__run_project
```

在 LevelBladeKeeper 场景中观察：
1. BladeKeeper 是否能在攻击后正常返回 chase
2. BladeKeeper 是否能在 stun 后正常恢复
3. BladeKeeper 是否不再卡在角落
4. defend/roll/projectile/trap 是否正常触发

- [ ] **Step 2: 检查 debug 日志**

```
mcp__godot__get_debug_output
```

验证日志中：
- 不出现 `Rejected:` 行（自发转换不再被拒绝）
- 状态转换正常：`Attack -> chase`, `Stun -> wander/chase`, `Roll -> chase` 等
- 不出现 `Ignoring transition` 异常

- [ ] **Step 3: 验证 DemonSlime**

切换到 DemonSlime 关卡，验证：
1. DemonSlime 攻击循环正常
2. 占位状态（如意外进入 Retreat）能安全退出
3. 无卡死现象

- [ ] **Step 4: 验证 Cyclops**

切换到 Cyclops 关卡，验证：
1. Cyclops 全部 7 个状态正常工作（未受改动影响）
2. Retreat 状态正常（Cyclops 有自己的 CyclopsRetreat 实现）

- [ ] **Step 5: 停止游戏**

```
mcp__godot__stop_project
```

---

## 执行顺序

Task 1 → Task 2 → Task 3 → Task 4 → Task 5 → Task 6 → Task 7

Task 1-2 是基础设施改动，Task 3-4 依赖 Task 2 的 `last_picked_entry`，Task 5-6 是清理，Task 7 是验证。
