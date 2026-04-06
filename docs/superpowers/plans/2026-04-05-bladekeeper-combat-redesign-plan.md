# BladeKeeper 战斗系统重设计 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重设计 BladeKeeper 战斗系统 — 统一攻击状态（combo/jump/普通/特殊）、修复移动/朝向问题、补全动画、清理 BossBase 模板

**Architecture:** BKAttack.gd 使用内部步骤机（Step enum）统一管理所有攻击模式。BossBase.tscn 模板删除所有状态节点，各 Boss 自行添加。所有攻击/技能状态统一 velocity 清零 + 面朝 player + can_move=false。

**Tech Stack:** Godot 4.4.1, GDScript, AnimationTree (BlendTree + control_sm), MCP tools

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `Scenes/Characters/Templates/BossBase.tscn` | 删除 StateMachine 下所有 7 个状态节点 |
| Modify | `Scenes/Characters/Bosses/Shared/BossBaseState.gd` | 移除占位 process_state() |
| Modify | `Scenes/Characters/Bosses/DemonSlime/DemonSlime.tscn` | 自行添加所需状态节点 |
| Modify | `Scenes/Characters/Bosses/Cyclops/Cyclops.tscn` | 自行添加所需状态节点 |
| Modify | `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn` | 添加新动画 + 状态节点调整 |
| Rewrite | `Scenes/Characters/Bosses/BladeKeeper/States/BKAttack.gd` | 统一攻击状态（步骤机） |
| Modify | `Scenes/Characters/Bosses/BladeKeeper/States/BKChase.gd` | 路由更新 |
| Modify | `Scenes/Characters/Bosses/BladeKeeper/States/BKDefend.gd` | velocity清零 + 面朝 + can_move |
| Modify | `Scenes/Characters/Bosses/BladeKeeper/States/BKRoll.gd` | velocity清零 + 面朝 + can_move |
| Modify | `Scenes/Characters/Bosses/BladeKeeper/States/BKProjectile.gd` | velocity清零 + 面朝 + can_move |
| Modify | `Scenes/Characters/Bosses/BladeKeeper/States/BKTrap.gd` | velocity清零 + 面朝 + can_move |
| Modify | `Scenes/Characters/Bosses/BladeKeeper/BKAttackManager.gd` | phase config 更新 |
| Modify | `Scenes/Characters/Bosses/BladeKeeper/Attacks/BKSwordProjectile.gd` | 添加 land 动画 |
| Modify | `Scenes/Characters/Bosses/BladeKeeper/Attacks/BKSwordProjectile.tscn` | AnimatedSprite2D |
| Modify | `Scenes/Characters/Bosses/BladeKeeper/Attacks/BKTrapEntity.gd` | 添加 land + detonate 动画 |
| Modify | `Scenes/Characters/Bosses/BladeKeeper/Attacks/BKTrapEntity.tscn` | AnimatedSprite2D |

---

### Task 1: BossBase 模板清理 — 删除状态节点

**Files:**
- Modify: `Scenes/Characters/Templates/BossBase.tscn:234-254`

**背景:** BossBase.tscn 模板当前有 7 个状态节点（Idle/Patrol/Chase/Circle/Attack/Retreat/Stun），所有脚本都指向同一个 IdleState.gd 作为占位。继承场景无法删除这些节点，导致占位状态死锁。方案：从模板中删除所有状态节点，各 Boss 自行添加。

- [ ] **Step 1: 编辑 BossBase.tscn — 删除 StateMachine 下所有 7 个状态子节点**

在 `Scenes/Characters/Templates/BossBase.tscn` 中删除以下节点块（第 234-254 行）：

```
[node name="Idle" type="Node" parent="StateMachine" unique_id=1900817675]
script = ExtResource("6_idle")

[node name="Patrol" type="Node" parent="StateMachine" unique_id=1743223177]
script = ExtResource("6_idle")

[node name="Chase" type="Node" parent="StateMachine" unique_id=1179073112]
script = ExtResource("6_idle")

[node name="Circle" type="Node" parent="StateMachine" unique_id=701299608]
script = ExtResource("6_idle")

[node name="Attack" type="Node" parent="StateMachine" unique_id=112510037]
script = ExtResource("6_idle")

[node name="Retreat" type="Node" parent="StateMachine" unique_id=2022250956]
script = ExtResource("6_idle")

[node name="Stun" type="Node" parent="StateMachine" unique_id=767657071]
script = ExtResource("6_idle")
```

同时删除不再使用的 `ext_resource` 引用（IdleState.gd 的 `6_idle`），前提是确认其他节点不引用它。

**注意:** 删除后 StateMachine 节点变为空节点（仅有 script）。保留 `init_state = NodePath("Idle")` 行 — 各继承场景会覆盖这个值。

- [ ] **Step 2: 验证 DemonSlime.tscn — 确认状态节点仍在**

DemonSlime.tscn 继承 BossBase.tscn，已有自定义状态节点覆盖（Idle/Chase/Attack/Stun/Cleave/Slam）。BossBase 删除模板节点后，DemonSlime 中通过 `index=N` 引用的继承节点（Idle index=0, Chase index=2, Attack index=4, Stun index=6）会丢失。

需要将 DemonSlime.tscn 中的继承节点改为独立节点（添加 `type="Node"`）。具体操作：

查找 DemonSlime.tscn 中所有 `parent="StateMachine"` 且没有 `type=` 的节点行（这些是继承节点），添加 `type="Node"`，去掉 `index=N`。

继承节点格式：`[node name="Idle" parent="StateMachine" index="0" unique_id=...]`
独立节点格式：`[node name="Idle" type="Node" parent="StateMachine" unique_id=...]`

DemonSlime 需要保留的状态：Idle, Chase, Attack(→Cleave脚本), Stun, Cleave, Slam

**不需要的继承节点（Patrol index=1, Circle index=3, Retreat index=5）不会出现在 DemonSlime.tscn 中**（因为没有属性覆盖），删除模板后自然消失。

- [ ] **Step 3: 验证 Cyclops.tscn — 确认状态节点仍在**

Cyclops.tscn 所有 7 个状态都有自定义脚本覆盖。同样需要将继承节点改为独立节点。

Cyclops 需要保留的状态：Idle, Patrol, Chase, Circle, Attack, Retreat, Stun

- [ ] **Step 4: 验证 BladeKeeper.tscn — 确认状态节点仍在**

BladeKeeper 当前有覆盖的继承节点：Idle(index=0), Chase(index=2), Attack(index=4), Stun(index=6)。以及独立添加的节点：Defend, Roll, Projectile, Trap。

需要将继承节点改为独立节点（添加 `type="Node"`，去掉 `index=N`）。

---

### Task 2: BossBaseState.gd — 移除占位逻辑

**Files:**
- Modify: `Scenes/Characters/Bosses/Shared/BossBaseState.gd:13-23`

- [ ] **Step 1: 删除占位 process_state()**

删除 `Scenes/Characters/Bosses/Shared/BossBaseState.gd` 中第 13-23 行的占位逻辑：

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

替换为空行（保持代码结构）。`_init()` 和后续的缓存引用代码不变。

---

### Task 3: BKAttack.gd — 重写为统一攻击状态

**Files:**
- Rewrite: `Scenes/Characters/Bosses/BladeKeeper/States/BKAttack.gd`

**背景:** BKAttack 使用步骤机（Step enum）管理所有攻击模式。mode 从 `BossAttackManager.last_picked_entry` 读取。攻击期间 `can_be_interrupted = false`，`boss.can_move = false`，`boss.velocity = Vector2.ZERO`。

- [ ] **Step 1: 重写 BKAttack.gd**

将 `Scenes/Characters/Bosses/BladeKeeper/States/BKAttack.gd` 完全替换为：

```gdscript
extends BossState

## BladeKeeper 统一攻击状态 — combo/jump/普通/特殊
## 内部步骤机驱动，所有攻击模式共用此状态

const NORMAL_ATKS := ["atk_1", "atk_2", "atk_3"]

## sp_atk 在 combo 中的触发概率（按阶段）
const SP_ATK_CHANCE := {
	BossBase.Phase.PHASE_1: 0.1,
	BossBase.Phase.PHASE_2: 0.3,
	BossBase.Phase.PHASE_3: 0.6,
}

## 落地后接地面 combo 的概率
const GROUND_COMBO_AFTER_JUMP_CHANCE := 0.5

## air_atk 触发概率
const AIR_ATK_CHANCE := 0.6

## dodge 后跳参数
@export var dodge_speed := 300.0
@export var dodge_duration := 0.3

## jump 突进参数
@export var jump_approach_speed := 350.0

enum Step {
	NONE,
	ATK,         ## 普通攻击（随机 atk_1/2/3）
	SP_ATK,      ## 特殊攻击
	DODGE,       ## 后跳撤退
	JUMP_UP,     ## 跳跃上升 + 靠近
	AIR_ATK,     ## 空中攻击
	JUMP_DOWN,   ## 下落
}

var _current_step: Step = Step.NONE
var _mode: String = "attack"
var _anim_tree_ref: AnimationTree
var _dodge_timer: SceneTreeTimer
var _jump_reached := false  ## jump_up 是否已到达 player 附近


func _init() -> void:
	priority = StatePriority.BEHAVIOR
	can_be_interrupted = false


func enter() -> void:
	var boss := get_boss()
	if not boss:
		transitioned.emit(self, "idle")
		return

	# 统一初始化：停止移动 + 禁止移动 + 面朝玩家
	boss.velocity = Vector2.ZERO
	boss.can_move = false
	_face_player(boss)

	_anim_tree_ref = get_anim_tree()
	_current_step = Step.NONE
	_jump_reached = false

	# 从 last_picked_entry 读取 mode
	var mgr := get_attack_manager()
	_mode = mgr.last_picked_entry.get("mode", "attack") if mgr else "attack"

	# 连接动画完成信号
	if _anim_tree_ref and not _anim_tree_ref.animation_finished.is_connected(_on_animation_finished):
		_anim_tree_ref.animation_finished.connect(_on_animation_finished)

	# 根据 mode 启动第一步
	match _mode:
		"attack":
			_start_step(Step.ATK)
		"combo":
			_start_step(Step.ATK)
		"special":
			_start_step(Step.SP_ATK)
		"jump":
			_start_step(Step.JUMP_UP)
		_:
			_start_step(Step.ATK)


func physics_process_state(_delta: float) -> void:
	# jump_up 阶段：向 player 移动
	if _current_step == Step.JUMP_UP and not _jump_reached:
		var boss := get_boss()
		if boss and target_node:
			var direction := (target_node.global_position - boss.global_position).normalized()
			boss.velocity = direction * jump_approach_speed
			# 到达攻击范围内 → 停止靠近
			var distance := boss.global_position.distance_to(target_node.global_position)
			if distance <= boss.attack_range:
				_jump_reached = true
				boss.velocity = Vector2.ZERO

	# dodge 阶段：后跳移动
	if _current_step == Step.DODGE:
		# velocity 在 _start_dodge() 中设置，由 BossBase._physics_process 的 move_and_slide 处理
		pass


func _on_animation_finished(anim_name: StringName) -> void:
	match _current_step:
		Step.ATK:
			# 检查当前播放的动画是否是我们的攻击动画
			if str(anim_name) not in NORMAL_ATKS:
				return
			_on_atk_finished()
		Step.SP_ATK:
			if anim_name != &"sp_atk":
				return
			_on_sp_atk_finished()
		Step.JUMP_UP:
			if anim_name != &"jump_up":
				return
			_on_jump_up_finished()
		Step.AIR_ATK:
			if anim_name != &"air_atk":
				return
			_on_air_atk_finished()
		Step.JUMP_DOWN:
			if anim_name != &"jump_down":
				return
			_on_jump_down_finished()


## ============ 步骤启动 ============

func _start_step(step: Step) -> void:
	_current_step = step
	var boss := get_boss()
	match step:
		Step.ATK:
			var atk_name: String = NORMAL_ATKS[randi() % NORMAL_ATKS.size()]
			enter_control_state(atk_name)
			DebugConfig.debug("[BKAttack] ATK: %s" % atk_name, "", "combat")
		Step.SP_ATK:
			enter_control_state("sp_atk")
			DebugConfig.debug("[BKAttack] SP_ATK", "", "combat")
		Step.DODGE:
			_start_dodge()
		Step.JUMP_UP:
			_jump_reached = false
			enter_control_state("jump_up")
			DebugConfig.debug("[BKAttack] JUMP_UP", "", "combat")
		Step.AIR_ATK:
			if boss:
				boss.velocity = Vector2.ZERO
			enter_control_state("air_atk")
			DebugConfig.debug("[BKAttack] AIR_ATK", "", "combat")
		Step.JUMP_DOWN:
			if boss:
				boss.velocity = Vector2.ZERO
			enter_control_state("jump_down")
			DebugConfig.debug("[BKAttack] JUMP_DOWN", "", "combat")


## ============ 步骤完成处理 ============

func _on_atk_finished() -> void:
	match _mode:
		"combo":
			# combo 模式：概率进入 sp_atk，否则 dodge
			var boss := get_boss()
			var chance: float = SP_ATK_CHANCE.get(boss.current_phase, 0.1) if boss else 0.1
			if randf() < chance:
				_start_step(Step.SP_ATK)
			else:
				_start_step(Step.DODGE)
		_:
			# 普通攻击：直接结束
			_finish_attack()


func _on_sp_atk_finished() -> void:
	match _mode:
		"combo":
			# combo 中的 sp_atk 结束 → dodge
			_start_step(Step.DODGE)
		_:
			# 独立 special 模式 → 直接结束
			_finish_attack()


func _on_jump_up_finished() -> void:
	var boss := get_boss()
	if boss:
		boss.velocity = Vector2.ZERO
	# 概率触发空中攻击
	if randf() < AIR_ATK_CHANCE:
		_start_step(Step.AIR_ATK)
	else:
		_start_step(Step.JUMP_DOWN)


func _on_air_atk_finished() -> void:
	_start_step(Step.JUMP_DOWN)


func _on_jump_down_finished() -> void:
	var boss := get_boss()
	if boss:
		_face_player(boss)
	# 落地后概率接地面 combo 或直接 dodge
	if randf() < GROUND_COMBO_AFTER_JUMP_CHANCE:
		# 接地面 combo：ATK → 概率 SP_ATK → DODGE
		_mode = "combo"
		_start_step(Step.ATK)
	else:
		_start_step(Step.DODGE)


## ============ Dodge 后跳 ============

func _start_dodge() -> void:
	_current_step = Step.DODGE
	var boss := get_boss()
	if not boss:
		_finish_attack()
		return

	# 后跳方向：背离 player
	var dodge_dir := Vector2.RIGHT
	if target_node:
		dodge_dir = (boss.global_position - target_node.global_position).normalized()
	boss.velocity = dodge_dir * dodge_speed

	# 复用 roll 动画作为 dodge
	enter_control_state("roll")
	DebugConfig.debug("[BKAttack] DODGE (dir=%s)" % dodge_dir, "", "combat")

	# 计时器结束后停止
	_dodge_timer = get_tree().create_timer(dodge_duration)
	_dodge_timer.timeout.connect(_on_dodge_finished)


func _on_dodge_finished() -> void:
	var boss := get_boss()
	if boss:
		boss.velocity = Vector2.ZERO
	_finish_attack()


## ============ 结束攻击 ============

func _finish_attack() -> void:
	exit_control_state()
	var next := evaluate_combat_transition(false)
	transitioned.emit(self, next)


## ============ 工具方法 ============

func _face_player(boss: BossBase) -> void:
	if not target_node:
		return
	var sprite := boss.get_node_or_null("AnimatedSprite2D") as Node2D
	if sprite and "flip_h" in sprite:
		sprite.flip_h = boss.global_position.x > target_node.global_position.x


func exit() -> void:
	exit_control_state()
	_current_step = Step.NONE

	# 断开信号
	if _anim_tree_ref and _anim_tree_ref.animation_finished.is_connected(_on_animation_finished):
		_anim_tree_ref.animation_finished.disconnect(_on_animation_finished)

	# 断开 dodge 计时器
	if _dodge_timer and _dodge_timer.timeout.is_connected(_on_dodge_finished):
		_dodge_timer.timeout.disconnect(_on_dodge_finished)

	# 恢复移动
	var boss := get_boss()
	if boss:
		boss.velocity = Vector2.ZERO
		boss.can_move = true
```

---

### Task 4: BKChase.gd — 路由更新

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/States/BKChase.gd:40-52`

- [ ] **Step 1: 更新 `_on_reached_attack_range()` 路由逻辑**

将 `Scenes/Characters/Bosses/BladeKeeper/States/BKChase.gd` 的 match 块替换为：

```gdscript
	match mode:
		"defend":
			return "defend"
		"roll":
			return "roll"
		"projectile":
			return "projectile"
		"trap":
			return "trap"
		_:
			# attack, combo, special, jump 统一由 BKAttack 处理
			return "attack"
```

**变化:** 移除之前的 `"projectile"`, `"trap"` 路由（改回独立状态名）。`"attack"`, `"combo"`, `"special"`, `"jump"` 统一路由到 `"attack"` 状态（BKAttack 从 last_picked_entry 读 mode）。

---

### Task 5: 攻击/技能状态统一修复 — velocity 清零 + 面朝 + can_move

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/States/BKDefend.gd:16-21`
- Modify: `Scenes/Characters/Bosses/BladeKeeper/States/BKRoll.gd:14-30`
- Modify: `Scenes/Characters/Bosses/BladeKeeper/States/BKProjectile.gd:11-15`
- Modify: `Scenes/Characters/Bosses/BladeKeeper/States/BKTrap.gd:11-15`

- [ ] **Step 1: 修改 BKDefend.gd enter() 和 exit()**

在 `BKDefend.gd` 的 `enter()` 开头添加：

```gdscript
func enter() -> void:
	var boss := get_boss()
	if boss:
		boss.velocity = Vector2.ZERO
		boss.can_move = false
	_face_player()
	_took_hit = false
	_anim_tree_ref = get_anim_tree()
	enter_control_state("defend")
	_timer = get_tree().create_timer(defend_duration)
	_timer.timeout.connect(_on_defend_timeout)
```

在 `exit()` 中恢复 can_move：

```gdscript
func exit() -> void:
	exit_control_state()
	if _timer and _timer.timeout.is_connected(_on_defend_timeout):
		_timer.timeout.disconnect(_on_defend_timeout)
	var boss := get_boss()
	if boss:
		boss.can_move = true
```

添加 `_face_player()` 辅助方法：

```gdscript
func _face_player() -> void:
	if not target_node or not owner_node:
		return
	var sprite := owner_node.get_node_or_null("AnimatedSprite2D") as Node2D
	if sprite and "flip_h" in sprite:
		sprite.flip_h = owner_node.global_position.x > target_node.global_position.x
```

- [ ] **Step 2: 修改 BKRoll.gd enter() 和 exit()**

在 `BKRoll.gd` 的 `enter()` 开头添加 velocity 清零和面朝：

```gdscript
func enter() -> void:
	var boss := get_boss()
	if not boss or not target_node:
		transitioned.emit(self, "idle")
		return

	boss.velocity = Vector2.ZERO
	boss.can_move = false
	_face_player()

	_anim_tree_ref = get_anim_tree()

	# 侧向闪避（垂直于面向玩家的方向）
	var to_player: Vector2 = (target_node.global_position - boss.global_position).normalized()
	_roll_direction = Vector2(-to_player.y, to_player.x)
	if randf() > 0.5:
		_roll_direction = -_roll_direction

	enter_control_state("roll")
	if _anim_tree_ref:
		_anim_tree_ref.animation_finished.connect(_on_roll_finished)
```

在 `exit()` 中恢复 can_move：

```gdscript
func exit() -> void:
	exit_control_state()
	if _anim_tree_ref and _anim_tree_ref.animation_finished.is_connected(_on_roll_finished):
		_anim_tree_ref.animation_finished.disconnect(_on_roll_finished)
	var boss := get_boss()
	if boss:
		boss.velocity = Vector2.ZERO
		boss.can_move = true
```

添加 `_face_player()` 辅助方法（同 BKDefend）。

- [ ] **Step 3: 修改 BKProjectile.gd enter() 和 exit()**

```gdscript
func enter() -> void:
	var boss := get_boss()
	if boss:
		boss.velocity = Vector2.ZERO
		boss.can_move = false
	_face_player()
	_anim_tree_ref = get_anim_tree()
	enter_control_state("projectile_cast")
	if _anim_tree_ref:
		_anim_tree_ref.animation_finished.connect(_on_cast_finished)

func exit() -> void:
	exit_control_state()
	if _anim_tree_ref and _anim_tree_ref.animation_finished.is_connected(_on_cast_finished):
		_anim_tree_ref.animation_finished.disconnect(_on_cast_finished)
	var boss := get_boss()
	if boss:
		boss.can_move = true
```

添加 `_face_player()` 辅助方法（同 BKDefend）。

- [ ] **Step 4: 修改 BKTrap.gd enter() 和 exit()**

```gdscript
func enter() -> void:
	var boss := get_boss()
	if boss:
		boss.velocity = Vector2.ZERO
		boss.can_move = false
	_face_player()
	_anim_tree_ref = get_anim_tree()
	enter_control_state("trap_cast")
	if _anim_tree_ref:
		_anim_tree_ref.animation_finished.connect(_on_cast_finished)

func exit() -> void:
	exit_control_state()
	if _anim_tree_ref and _anim_tree_ref.animation_finished.is_connected(_on_cast_finished):
		_anim_tree_ref.animation_finished.disconnect(_on_cast_finished)
	var boss := get_boss()
	if boss:
		boss.can_move = true
```

添加 `_face_player()` 辅助方法（同 BKDefend）。

---

### Task 6: BKAttackManager.gd — Phase Config 更新

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/BKAttackManager.gd:155-193`

- [ ] **Step 1: 替换 `_setup_default_phases()`**

将 `_setup_default_phases()` 方法替换为：

```gdscript
func _setup_default_phases() -> void:
	# Phase 1: 基础近战
	var p1 := BossPhaseConfig.new()
	p1.cooldown = 1.5
	p1.attacks = [
		{"mode": "attack", "weight": 5},
		{"mode": "combo", "weight": 2},
		{"mode": "defend", "weight": 2},
		{"mode": "projectile", "weight": 1},
	]
	phase_configs[BossBase.Phase.PHASE_1] = p1

	# Phase 2: 加入跳跃/翻滚/陷阱
	var p2 := BossPhaseConfig.new()
	p2.cooldown = 1.2
	p2.attacks = [
		{"mode": "attack", "weight": 3},
		{"mode": "combo", "weight": 3},
		{"mode": "jump", "weight": 2},
		{"mode": "defend", "weight": 2},
		{"mode": "roll", "weight": 2},
		{"mode": "projectile", "weight": 2},
		{"mode": "trap", "weight": 2},
		{"mode": "special", "weight": 1},
	]
	phase_configs[BossBase.Phase.PHASE_2] = p2

	# Phase 3: 全技能 + 更激进
	var p3 := BossPhaseConfig.new()
	p3.cooldown = 0.8
	p3.attacks = [
		{"mode": "attack", "weight": 2},
		{"mode": "combo", "weight": 3},
		{"mode": "jump", "weight": 3},
		{"mode": "defend", "weight": 1},
		{"mode": "roll", "weight": 2},
		{"mode": "projectile", "weight": 2},
		{"mode": "trap", "weight": 2},
		{"mode": "special", "weight": 2},
	]
	phase_configs[BossBase.Phase.PHASE_3] = p3

	DebugConfig.debug("[BKAttackManager] 默认阶段配置已加载 (3 phases)", "", "combat")
```

- [ ] **Step 2: 移除不再使用的 combo 工厂方法**

删除以下方法（第 107-152 行），这些由旧 combo 系统使用，不再需要：

```gdscript
## 组合技工厂 — BladeKeeper 使用状态序列式组合技
static func resolve_bk_combo(factory_name: String) -> Dictionary: ...
static func _create_blade_storm() -> Dictionary: ...
static func _create_shadow_strike() -> Dictionary: ...
static func _create_ultimate_chain() -> Dictionary: ...
```

同时删除 `_execute_combo_entry()` 方法（第 69-74 行）。

更新 `_execute_attack()` 方法，移除 combo 分支：

```gdscript
func _execute_attack(entry: Dictionary, _target_pos: Vector2) -> void:
	var mode: String = entry.get("mode", "")
	match mode:
		"attack", "combo", "special", "jump":
			pass  # 由 BKAttack 状态统一处理
		"defend":
			pass  # 由 BKDefend 状态处理
		"roll":
			pass  # 由 BKRoll 状态处理
		"projectile":
			pass  # 由 BKProjectile 状态处理
		"trap":
			pass  # 由 BKTrap 状态处理
```

---

### Task 7: AnimationTree — 补充 jump/air_atk/dodge 动画

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/BladeKeeper.tscn`

**背景:** 当前 control_sm 有 atk_1/2/3, sp_atk, defend, roll, projectile_cast, trap_cast, hit, stun, death。需要新增 jump_up, air_atk, jump_down 动画状态。dodge 复用 roll 动画（BKAttack._start_dodge 已使用 `enter_control_state("roll")`）。

- [ ] **Step 1: 在 AnimationPlayer 中创建新 Animation**

在 BladeKeeper.tscn 的 AnimationPlayer 中创建 3 个新 Animation：

**jump_up** — 使用 `03_jump_up` 素材（3 帧）:
- `Assets/Art/BLADE_KEEPER/PNG animations/03_jump_up/03_jump_up_1.png`
- `Assets/Art/BLADE_KEEPER/PNG animations/03_jump_up/03_jump_up_2.png`
- `Assets/Art/BLADE_KEEPER/PNG animations/03_jump_up/03_jump_up_3.png`
- 帧率：10 FPS（duration ≈ 0.3s）

**air_atk** — 使用 `air_atk` 素材（8 帧）:
- `Assets/Art/BLADE_KEEPER/PNG animations/air_atk/air_atk1.png` ~ `air_atk8.png`
- 帧率：12 FPS（duration ≈ 0.67s）

**jump_down** — 使用 `03_jump_down` 素材（3 帧）:
- `Assets/Art/BLADE_KEEPER/PNG animations/03_jump_down/03_jump_down_1.png`
- `Assets/Art/BLADE_KEEPER/PNG animations/03_jump_down/03_jump_down_2.png`
- `Assets/Art/BLADE_KEEPER/PNG animations/03_jump_down/03_jump_down_3.png`
- 帧率：10 FPS（duration ≈ 0.3s）

> **Note:** 这些动画需要在 .tscn 文件中以 `[sub_resource type="Animation"]` 形式定义，包含 SpriteFrames track。参考已有的 atk_1/defend 等动画的格式。由于 .tscn 文件手动编辑 Animation 资源非常繁琐，**推荐使用 Godot MCP 工具或编辑器操作**。

- [ ] **Step 2: 在 control_sm 中添加新状态**

在 `AnimationNodeStateMachine_control` 中添加 3 个新 `AnimationNodeAnimation` 节点：

```
states/jump_up/node = SubResource("AnimationNodeAnimation_jump_up")
states/jump_up/position = Vector2(800, -50)
states/air_atk/node = SubResource("AnimationNodeAnimation_air_atk")
states/air_atk/position = Vector2(800, 50)
states/jump_down/node = SubResource("AnimationNodeAnimation_jump_down")
states/jump_down/position = Vector2(800, 150)
```

每个节点对应的 `[sub_resource]`:

```
[sub_resource type="AnimationNodeAnimation" id="AnimationNodeAnimation_jump_up"]
animation = &"jump_up"

[sub_resource type="AnimationNodeAnimation" id="AnimationNodeAnimation_air_atk"]
animation = &"air_atk"

[sub_resource type="AnimationNodeAnimation" id="AnimationNodeAnimation_jump_down"]
animation = &"jump_down"
```

**不需要添加状态间转换（transitions）**— BKAttack 使用 `enter_control_state()` 内的 `playback.start()` 直接跳转，不依赖 AnimationNodeStateMachine 的 transitions。

---

### Task 8: 投射物/陷阱动画完善

**Files:**
- Modify: `Scenes/Characters/Bosses/BladeKeeper/Attacks/BKSwordProjectile.gd`
- Modify: `Scenes/Characters/Bosses/BladeKeeper/Attacks/BKSwordProjectile.tscn`
- Modify: `Scenes/Characters/Bosses/BladeKeeper/Attacks/BKTrapEntity.gd`
- Modify: `Scenes/Characters/Bosses/BladeKeeper/Attacks/BKTrapEntity.tscn`

- [ ] **Step 1: BKSwordProjectile — 添加 AnimatedSprite2D 和 land 动画**

将 BKSwordProjectile.tscn 中的 `Sprite2D` 节点替换为 `AnimatedSprite2D`，配置两个动画：

**SpriteFrames 配置：**
- `throw`（默认）: 单帧 `projectile_throw.png`
- `land`: 5 帧 `projectile_land_1.png` ~ `projectile_land_5.png`，帧率 12 FPS，不循环

修改 BKSwordProjectile.gd — 添加命中/超时后的 land 动画：

```gdscript
extends Area2D
class_name BKSwordProjectile

## 剑气投射物 — 直线飞行，命中播放 land 动画后消失

@export var speed := 400.0
@export var lifetime := 4.0
@export var damage_config: Damage

var _direction := Vector2.RIGHT
var _lifetime_timer: SceneTreeTimer
var _landed := false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	_sprite.play("throw")
	_lifetime_timer = get_tree().create_timer(lifetime)
	_lifetime_timer.timeout.connect(_play_land)

func set_direction(dir: Vector2) -> void:
	_direction = dir.normalized()
	rotation = dir.angle()

func _physics_process(delta: float) -> void:
	if _landed:
		return
	position += _direction * speed * delta

func _play_land() -> void:
	if _landed:
		return
	_landed = true
	_sprite.play("land")
	_sprite.animation_finished.connect(queue_free)

func _on_hitbox_area_entered(_area: Area2D) -> void:
	_play_land()
```

- [ ] **Step 2: BKTrapEntity — 添加 AnimatedSprite2D 和 land/detonate 动画**

将 BKTrapEntity.tscn 中的 `Sprite2D` 节点替换为 `AnimatedSprite2D`，配置三个动画：

**SpriteFrames 配置：**
- `throw`（默认）: 单帧 `trap_throw.png`
- `land`: 3 帧 `trap_land_1.png` ~ `trap_land_3.png`，帧率 8 FPS，不循环
- `detonate`: 5 帧 `trap_detonate_1.png` ~ `trap_detonate_5.png`，帧率 12 FPS，不循环

修改 BKTrapEntity.gd — 添加落地和爆炸动画：

```gdscript
extends Area2D
class_name BKTrapEntity

## 地面陷阱 — 落地待机，接触触发爆炸动画 + ForceStun

@export var trap_lifetime := 8.0
@export var damage_config: Damage
@export var stun_duration := 0.5

var _triggered := false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# 播放落地动画
	_sprite.play("land")
	_sprite.animation_finished.connect(_on_land_finished)

	modulate.a = 0.3
	var lifetime_timer := get_tree().create_timer(trap_lifetime)
	lifetime_timer.timeout.connect(_expire)
	body_entered.connect(_on_body_entered)

func _on_land_finished() -> void:
	if _sprite.animation == "land":
		# 落地完成，进入待机（停在最后一帧）
		_sprite.stop()

func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if not body.is_in_group("player"):
		return
	_triggered = true
	_trigger(body)

func _trigger(body: Node2D) -> void:
	modulate.a = 1.0
	# 播放爆炸动画
	_sprite.play("detonate")
	_sprite.animation_finished.connect(func(): queue_free())

	# 应用伤害
	if damage_config:
		var dmg := damage_config.duplicate(true) as Damage
		var stun_effect := ForceStunEffect.new()
		stun_effect.duration = stun_duration
		dmg.effects.append(stun_effect)
		for child in body.get_children():
			if child.has_method("take_damage"):
				child.take_damage(dmg, global_position)
				break

func _expire() -> void:
	if _triggered:
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
```

---

### Task 9: 运行时验证

**Files:** None (runtime testing only)

- [ ] **Step 1: 使用 MCP 运行项目**

```
mcp__godot__run_project
```

- [ ] **Step 2: 验证 BladeKeeper 状态流程**

在 LevelBladeKeeper 场景中验证：

1. **attack mode**: 播放随机单次攻击，攻击时不移动、面朝玩家，结束后恢复
2. **combo mode**: 随机 atk → 概率 sp_atk → dodge 后跳，后跳方向背离玩家
3. **jump mode**: jump_up 靠近玩家 → 可选 air_atk → jump_down → 可选接地面 combo 或 dodge
4. **defend**: 格挡时不移动，受击反击
5. **roll**: 侧向翻滚，面朝玩家
6. **projectile**: 释放剑气，不移动，面朝玩家
7. **trap**: 布置陷阱，不移动，面朝玩家
8. **stun**: 眩晕恢复正常

- [ ] **Step 3: 检查 debug 日志**

```
mcp__godot__get_debug_output
```

验证：
- `[BKAttack]` 日志显示正确的步骤流转
- 无 `Rejected:` 或 `Ignoring transition` 异常
- 状态转换正常

- [ ] **Step 4: 验证 DemonSlime 和 Cyclops**

切换关卡验证：
1. DemonSlime 所有状态正常
2. Cyclops 所有状态正常
3. 无因 BossBase 模板改动导致的回归问题

- [ ] **Step 5: 停止项目**

```
mcp__godot__stop_project
```

---

## 执行顺序

Task 1 → Task 2 → Task 3 → Task 4 → Task 5 → Task 6 → Task 7 → Task 8 → Task 9

- Task 1-2: 基础设施（模板清理）
- Task 3-6: BladeKeeper 核心改动（BKAttack 重写 + 路由 + 状态修复 + phase config）
- Task 7-8: 动画/表现层
- Task 9: 运行时验证
