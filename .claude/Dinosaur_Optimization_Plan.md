# Dinosaur AI 优化架构方案

## 1. 问题分析

### 1.1 当前架构的问题

#### 问题 1: 代码与编辑器配置脱节
- **现状**：
  - AnimationTree 结构在编辑器中配置（StateMachine + BlendSpace2D + Blend2）
  - 但参数控制在 `EnemyAnimationHandler.gd` 中进行
  - 两层配置增加了维护难度

#### 问题 2: 动画处理器职责混乱
- **现状**：
  - `EnemyAnimationHandler` 作为中间层
  - 处理 locomotion blend、control 层切换、attack oneshot
  - 增加了单点故障风险

#### 问题 3: 状态机与动画树的关系不清楚
- **现状**：
  - 状态机处理游戏逻辑
  - 动画处理器处理动画参数
  - 应该是"状态机 → 设置动画参数 → AnimationTree 自动响应"

#### 问题 4: 编码复杂度高
- **现状**：
  - `EnemyStateMachine` 处理状态创建和转换
  - `EnemyAnimationHandler` 处理动画参数同步
  - 多个状态脚本处理具体逻辑
  - 代码分散，难以追踪流程

#### 问题 5: 编辑器配置不完整
- **现状**：
  - AnimationTree 缺少完整的转换配置
  - 没有充分利用 AnimationTree 的状态机转换
  - 很多逻辑依然在代码中

---

## 2. 优化目标

### 2.1 架构目标
```
敌人状态脚本
    ↓ (设置参数: blend_position, travel, oneshot request)
AnimationTree 参数
    ↓ (自动处理)
AnimationPlayer
    ↓
最终动画表现
```

### 2.2 设计原则
1. **单一职责**：状态脚本只负责游戏逻辑 + 动画参数设置
2. **编辑器优先**：所有可配置项都在编辑器中完成
3. **删除中间层**：移除 EnemyAnimationHandler，由状态脚本直接控制
4. **清晰的优先级**：使用 AnimationTree 的层级来管理优先级
5. **简化代码**：减少状态脚本数量和复杂度

---

## 3. 新架构设计

### 3.1 场景结构

```
Enemy (CharacterBody2D)
├── Sprite2D
├── CollisionShape2D
├── HurtBoxComponent (Area2D)
│   └── CollisionShape2D
├── AnimationPlayer
│   └── AnimationLibrary
│       ├── idle
│       ├── left_walk / right_walk
│       ├── left_run / right_run
│       ├── attack
│       ├── hit
│       ├── stunned
│       └── death
│
├── AnimationTree
│   └── AnimationNodeBlendTree (Root)
│       ├── locomotion (BlendSpace2D)
│       │   ├── idle
│       │   ├── left_walk
│       │   ├── right_walk
│       │   ├── left_run
│       │   └── right_run
│       │
│       ├── attack_oneshot (OneShot)
│       │   └── attack
│       │
│       ├── control_blend (Blend2)
│       │   ├── in: attack_oneshot
│       │   ├── blend: control_sm
│       │   └── out: Output
│       │
│       └── control_sm (StateMachine)
│           ├── hit
│           ├── stunned
│           └── death
│
├── HealthComponent
└── EnemyStateMachine
    ├── Idle
    ├── Wander
    ├── Chase
    ├── Attack
    ├── Hit
    ├── Knockback
    └── Stun
```

### 3.2 AnimationTree 配置

#### 参数路径
```gdscript
# 移动混合
"parameters/locomotion/blend_position" → Vector2(-1..1, 0..1)

# 攻击触发
"parameters/attack_oneshot/request" → ONE_SHOT_REQUEST_FIRE/ABORT

# 控制层混合
"parameters/control_blend/blend_amount" → 0.0 (正常) / 1.0 (控制)

# 控制层状态切换
"parameters/control_sm/playback" → travel("hit"/"stunned"/"death")
```

#### 优先级系统
```
第一层：control_sm (StateMachine)
  - hit
  - stunned
  - death
  优先级: 通过 Blend2 的 blend_amount 实现（1.0 时完全切换）

第二层：attack_oneshot (OneShot)
  - 叠加到 locomotion 上方

第三层：locomotion (BlendSpace2D)
  - 基础移动动画
```

---

## 4. 代码优化

### 4.1 状态脚本职责简化

**当前**：
- 处理游戏逻辑
- 设置 AnimationTree 参数（通过 EnemyAnimationHandler）
- 检查动画是否播放完成

**改进后**：
- 处理游戏逻辑
- **直接** 设置 AnimationTree 参数
- 通过 AnimationTree 信号检查动画完成

### 4.2 删除 EnemyAnimationHandler

**原因**：
- 职责可由状态脚本直接完成
- 作为中间层增加了复杂度
- 不符合"编辑器优先"原则

**改进**：
- 状态脚本通过 `get_node("AnimationTree")` 直接访问
- 在状态的 `enter()` 方法中设置动画参数
- 在 `physics_update()` 中实时更新 locomotion blend

### 4.3 简化状态机脚本

**当前 EnemyStateMachine**：
- 使用 Preset 系统动态创建状态
- 复杂的初始化逻辑

**改进**：
- 状态直接在场景中配置（编辑器）
- 脚本只负责状态转换逻辑
- 初始化逻辑简化

---

## 5. 实施步骤

### 第 1 步：配置 AnimationTree
**文件**：Dinosaur.tscn
- 确保 AnimationTree 结构完整
- 验证所有参数路径正确

### 第 2 步：改进状态脚本
**文件**：各状态脚本（Idle, Chase, Attack 等）
- 添加对 AnimationTree 的直接控制
- 移除对 EnemyAnimationHandler 的依赖

### 第 3 步：简化状态机
**文件**：EnemyStateMachine.gd
- 删除 Preset 系统
- 保留基础状态转换逻辑

### 第 4 步：删除 EnemyAnimationHandler
**文件**：删除 EnemyAnimationHandler.gd
- 场景中移除该节点

### 第 5 步：更新场景配置
**文件**：Dinosaur.tscn
- 调整节点和脚本引用
- 配置初始状态指向

### 第 6 步：测试验证
- 测试各状态的动画切换
- 验证优先级系统是否正常工作
- 检查动画流畅性

---

## 6. 核心实现示例

### 6.1 改进后的状态脚本基类

```gdscript
extends Node
class_name EnemyState

@export var enemy: CharacterBody2D
@export var anim_tree: AnimationTree
@export var animation_player: AnimationPlayer

# 状态优先级
enum StatePriority {
	BEHAVIOR = 1,
	REACTION = 5,
	CONTROL = 10
}

var priority := StatePriority.BEHAVIOR
var uninterruptible := false

# 动画参数常量
const PARAM_LOCOMOTION = "parameters/locomotion/blend_position"
const PARAM_ATTACK = "parameters/attack_oneshot/request"
const PARAM_CONTROL_BLEND = "parameters/control_blend/blend_amount"
const PARAM_CONTROL_PLAYBACK = "parameters/control_sm/playback"

func enter(_msg := {}) -> void:
	pass

func exit() -> void:
	pass

func update(delta: float) -> void:
	pass

func physics_update(delta: float) -> void:
	pass

# 动画控制方法
func set_locomotion(blend: Vector2) -> void:
	if anim_tree:
		anim_tree.set(PARAM_LOCOMOTION, blend)

func fire_attack() -> void:
	if anim_tree:
		anim_tree.set(PARAM_ATTACK, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func enter_control_state(state: String) -> void:
	if anim_tree:
		var playback = anim_tree.get(PARAM_CONTROL_PLAYBACK)
		if playback:
			playback.travel(state)
		anim_tree.set(PARAM_CONTROL_BLEND, 1.0)

func exit_control_state() -> void:
	if anim_tree:
		anim_tree.set(PARAM_CONTROL_BLEND, 0.0)
```

### 6.2 改进后的 IdleState

```gdscript
extends EnemyState
class_name EnemyIdleState

@export var idle_time_range := Vector2(1.0, 3.0)

var decision_timer := 0.0
var idle_time := 0.0

func enter(_msg := {}) -> void:
	priority = StatePriority.BEHAVIOR
	uninterruptible = false
	enemy.velocity = Vector2.ZERO
	set_locomotion(Vector2.ZERO)  # idle 位置
	idle_time = randf_range(idle_time_range.x, idle_time_range.y)
	decision_timer = 0.0

func physics_update(delta: float) -> void:
	decision_timer += delta
	if decision_timer >= idle_time:
		_make_decision()
		decision_timer = 0.0
		idle_time = randf_range(idle_time_range.x, idle_time_range.y)

func _make_decision() -> void:
	# 根据玩家距离决定下一个状态
	pass
```

---

## 7. 对比：改进前后

| 方面 | 改进前 | 改进后 |
|------|--------|--------|
| 脚本数量 | EnemyStateMachine + EnemyAnimationHandler + 7个状态 | EnemyStateMachine + 5-7个状态 |
| 中间层 | 有（EnemyAnimationHandler） | 无 |
| 动画参数设置 | 通过 EnemyAnimationHandler | 状态脚本直接设置 |
| 配置位置 | 代码 + 编辑器混合 | 主要在编辑器 |
| 维护难度 | 高（多层级） | 低（直接）|
| 代码复杂度 | 高 | 中等 |
| 性能 | 正常 | 稍优（少一层中间调用）|
| 可读性 | 一般 | 优秀 |

---

## 8. 文件清单

### 需要修改的文件
- [ ] `Scenes/Characters/Enemies/dinosaur/dinosaur.tscn` - AnimationTree 配置
- [ ] `Core/StateMachine/BaseState.gd` - 添加基础控制方法
- [ ] `Scenes/Characters/Enemies/dinosaur/Scripts/States/EnemyIdle.gd`
- [ ] `Scenes/Characters/Enemies/dinosaur/Scripts/States/EnemyChase.gd`
- [ ] `Scenes/Characters/Enemies/dinosaur/Scripts/States/EnemyAttack.gd`
- [ ] `Scenes/Characters/Enemies/dinosaur/Scripts/States/EnemyStun.gd`
- [ ] `Scenes/Characters/Enemies/dinosaur/Scripts/States/EnemyWander.gd`
- [ ] `Scenes/Characters/Enemies/dinosaur/Scripts/EnemyStateMachine.gd` - 简化

### 需要删除的文件
- [ ] `Scenes/Characters/Enemies/dinosaur/Scripts/EnemyAnimationHandler.gd`

### 需要创建的文件
- [ ] `Scenes/Characters/Enemies/dinosaur/Scripts/States/EnemyBaseState.gd` - 改进的基类

---

## 9. 实施风险和缓解措施

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| 动画树配置错误 | 动画播放异常 | 在编辑器中多次验证 |
| 状态脚本兼容性 | 功能破坏 | 保持接口一致性 |
| 过渡期混乱 | 调试困难 | 详细注释，逐步替换 |
| 优先级系统失效 | 状态错乱 | 充分测试状态切换 |

---

## 10. 测试检查清单

- [ ] Idle 状态正常播放（idle 动画）
- [ ] Chase 状态移动混合正确（walk → run）
- [ ] Attack 状态动画叠加（locomotion + attack oneshot）
- [ ] Hit 状态优先级生效（被攻击时中断其他状态）
- [ ] Stun 状态完全控制（无法移动）
- [ ] 状态过渡的动画淡出淡入流畅
- [ ] 没有动画卡顿或跳帧
- [ ] 敌人正确面向玩家
- [ ] 死亡状态正常播放死亡动画
