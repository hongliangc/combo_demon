# 状态机迁移指南

将现有的 `enemy_state_machine` 和 `boss_state_machine` 迁移到新的模块化系统。

## 🎯 迁移收益

- **消除重复代码**: Enemy 和 Boss 状态机有 90% 相同代码
- **提高可维护性**: 修复 bug 只需改一处
- **加速开发**: 新敌人创建时间减少 70%+
- **更好的扩展性**: 统一接口，易于添加新功能

---

## 📋 迁移步骤

### 方式 A: 渐进式迁移（推荐）

保留现有系统，新敌人使用新系统，逐步迁移。

#### 步骤 1: 创建测试敌人

1. 复制 `Scenes/enemies/dinosaur/dinosaur.tscn` 为 `test_enemy.tscn`
2. 在新场景中：
   - 删除 `StateMachine` 节点
   - 添加新的 `StateMachine` 节点（类型: `BaseStateMachine`）
   - 添加状态子节点

#### 步骤 2: 迁移状态

**旧的 Idle 状态:**
```gdscript
# Scenes/enemies/dinosaur/Scripts/States/enemy_idle.gd
extends EnemyStates

@export var min_idle_time := 1.0
@export var max_idle_time := 3.0
var idle_time := 0.0

func enter():
    idle_time = randf_range(min_idle_time, max_idle_time)

func process_state(delta: float):
    idle_time -= delta
    if idle_time <= 0:
        transitioned.emit(self, "wander")
    if try_chase():  # 基类方法
        pass
```

**新的 Idle 状态:**
```gdscript
# 直接使用 Util/StateMachine/CommonStates/idle_state.gd
# 在编辑器中配置:
# - Min Idle Time: 1.0
# - Max Idle Time: 3.0
# - Detection Radius: 100.0
```

**如果需要自定义:**
```gdscript
# enemy_idle.gd (继承通用状态)
extends "res://Util/StateMachine/CommonStates/idle_state.gd"

# 重写部分逻辑
func enter() -> void:
    super.enter()  # 调用父类
    print("Enemy 开始待机")
```

#### 步骤 3: 更新状态引用

**旧代码:**
```gdscript
var enemy: Enemy
var player: Hahashin

func process_state(delta: float):
    var distance = player.global_position.distance_to(enemy.global_position)
    if distance < enemy.detection_radius:
        enemy.velocity = ...
```

**新代码:**
```gdscript
# 使用基类提供的引用和方法
func physics_process_state(delta: float):
    var distance = get_distance_to_target()  # 基类方法

    if owner_node is Enemy:
        var enemy = owner_node as Enemy
        if distance < enemy.detection_radius:
            if owner_node is CharacterBody2D:
                (owner_node as CharacterBody2D).velocity = ...
```

#### 步骤 4: 测试

1. 运行游戏，确认新敌人行为正常
2. 对比新旧敌人行为是否一致
3. 修复差异

---

### 方式 B: 直接替换（快速但风险高）

直接修改现有的状态机和状态。

#### 步骤 1: 修改 enemy_state_machine.gd

**替换方案 1: 直接继承（最少改动）**

```gdscript
# Scenes/enemies/dinosaur/Scripts/States/enemy_state_machine.gd
extends BaseStateMachine  # 改这一行

# 删除以下代码（已在基类中实现）:
# - var current_state
# - var states: Dictionary
# - var enemy: Enemy
# - var player: Hahashin
# - _ready() 中的状态初始化逻辑
# - _process() 和 _physics_process()
# - on_transition()
# - on_damaged()

# 如果需要保留 enemy 和 player 的类型提示，添加:
var enemy: Enemy:
    get: return owner_node as Enemy

var player: Hahashin:
    get: return target_node as Hahashin
```

**替换方案 2: 直接使用基类**

在场景中，将 StateMachine 的脚本直接改为:
```
res://Util/StateMachine/base_state_machine.gd
```

#### 步骤 2: 修改状态基类

**enemy_base_state.gd:**

```gdscript
# Scenes/enemies/dinosaur/Scripts/States/enemy_base_state.gd
extends BaseState
class_name EnemyStates  # 保留类名，避免破坏现有引用

# 添加便捷访问器（可选）
var enemy: Enemy:
    get: return owner_node as Enemy

var player: Hahashin:
    get: return target_node as Hahashin

# 删除基类已有的方法:
# - signal transitioned
# - try_chase()
# - get_distance_to_player()
# - on_damaged()

# 如果你的 try_chase 逻辑不同，可以保留并重写:
func try_chase() -> bool:
    if player and player.alive:
        var distance = get_distance_to_target()  # 基类方法
        if "detection_radius" in enemy:
            if distance <= enemy.detection_radius:
                transitioned.emit(self, "chase")
                return true
    return false
```

#### 步骤 3: 更新具体状态

以 **Chase 状态** 为例：

**旧代码:**
```gdscript
# enemy_chase.gd
extends EnemyStates

func physics_process_state(delta: float):
    var direction = player.global_position - enemy.global_position
    direction = direction.normalized()

    enemy.velocity = direction * enemy.chase_speed
    enemy.move_and_slide()

    var distance = get_distance_to_player()
    if distance > enemy.chase_radius:
        transitioned.emit(self, "idle")
```

**新代码（基本不用改）:**
```gdscript
# enemy_chase.gd
extends EnemyStates  # 现在继承自 BaseState

func physics_process_state(delta: float):
    # 使用基类方法
    var direction = get_direction_to_target()

    # 通过 enemy 访问器获取类型
    if enemy:
        enemy.velocity = direction * enemy.chase_speed
        enemy.move_and_slide()

        var distance = get_distance_to_target()
        if distance > enemy.chase_radius:
            transitioned.emit(self, "idle")
```

---

### 迁移 Boss 状态机

Boss 状态机有特殊的阶段转换逻辑，需要保留。

#### 选项 1: 保留 boss_state_machine.gd（推荐）

```gdscript
# boss_state_machine.gd
extends BaseStateMachine  # 继承基类

var is_transitioning_phase := false

# 保留 Boss 特有的初始化
func _setup_signals() -> void:
    super._setup_signals()  # 调用基类

    # Boss 特有信号
    if owner_node and owner_node.has_signal("phase_changed"):
        owner_node.phase_changed.connect(_on_phase_changed)

# 重写 damaged 处理
func _on_owner_damaged(damage: Damage) -> void:
    if is_transitioning_phase:
        return
    super._on_owner_damaged(damage)

# 保留阶段转换逻辑
func _on_phase_changed(new_phase: int):
    is_transitioning_phase = true
    print("Boss 阶段改变: Phase %d" % (new_phase + 1))

    # 使用基类的 force_transition
    match new_phase:
        Boss.Phase.PHASE_2:
            if target_node and "alive" in target_node and target_node.alive:
                var distance = get_distance_to_target()
                if distance <= (owner_node as Boss).attack_range:
                    force_transition("circle")
                else:
                    force_transition("chase")
        Boss.Phase.PHASE_3:
            force_transition("enrage")

    await get_tree().create_timer(0.1).timeout
    is_transitioning_phase = false

# 添加便捷方法
func get_distance_to_target() -> float:
    if owner_node is Node2D and target_node is Node2D:
        return (owner_node as Node2D).global_position.distance_to((target_node as Node2D).global_position)
    return INF
```

#### 更新 boss_base_state.gd

```gdscript
# boss_base_state.gd
extends BaseState
class_name BossState

# 便捷访问器
var boss: Boss:
    get: return owner_node as Boss

var player: Hahashin:
    get: return target_node as Hahashin

# 基类已提供的方法可以删除:
# - get_distance_to_player() → get_distance_to_target()
# - get_direction_to_player() → get_direction_to_target()
# - is_player_in_range() → is_target_in_range()

# 保留 Boss 特有的 on_damaged 逻辑
func on_damaged(_damage: Damage):
    if boss and boss.current_phase != Boss.Phase.PHASE_3:
        transitioned.emit(self, "stun")
```

---

## 🔍 常见问题

### Q1: 现有状态中使用 `enemy.xxx`，报错找不到属性

**问题:**
```gdscript
var distance = enemy.global_position.distance_to(player.global_position)
# 错误: owner_node 是 Node 类型，没有 global_position
```

**解决:**
```gdscript
# 方式 1: 使用基类方法
var distance = get_distance_to_target()

# 方式 2: 类型转换
if owner_node is CharacterBody2D:
    var body = owner_node as CharacterBody2D
    var pos = body.global_position

# 方式 3: 添加访问器（在 EnemyStates 中）
var enemy: Enemy:
    get: return owner_node as Enemy
```

### Q2: 状态机找不到 owner_node

**原因:** 没有正确设置场景结构。

**解决:**
确保状态机是实体的**子节点**：
```
✅ 正确:
Enemy (CharacterBody2D) ← owner
└── StateMachine (BaseStateMachine)

❌ 错误:
Node
├── Enemy (CharacterBody2D)
└── StateMachine (BaseStateMachine)
```

### Q3: 状态转换不工作

**检查清单:**
1. 状态节点名称是否正确（大小写）
2. 转换时使用 `transitioned.emit(self, "state_name")`
3. 状态名使用小写: `"idle"`, `"chase"`, 不是 `"Idle"`

### Q4: 想保留旧代码作为参考

**建议:**
```bash
# 备份旧文件
cp enemy_state_machine.gd enemy_state_machine.gd.backup
cp enemy_base_state.gd enemy_base_state.gd.backup

# 迁移后如果有问题，可以对比
```

---

## ✅ 迁移检查清单

### Enemy 迁移
- [ ] `enemy_state_machine.gd` 继承 `BaseStateMachine`
- [ ] `enemy_base_state.gd` 继承 `BaseState`
- [ ] 删除重复的状态机逻辑代码
- [ ] 更新状态中的 `enemy` 和 `player` 引用
- [ ] 测试所有状态转换
- [ ] 测试受伤 → 眩晕流程

### Boss 迁移
- [ ] `boss_state_machine.gd` 继承 `BaseStateMachine`
- [ ] 保留并更新 `_on_phase_changed` 方法
- [ ] `boss_base_state.gd` 继承 `BaseState`
- [ ] 更新所有 Boss 状态
- [ ] 测试阶段转换逻辑
- [ ] 测试所有攻击状态

### 通用检查
- [ ] 所有状态转换正常工作
- [ ] 伤害和眩晕系统正常
- [ ] 没有报错或警告
- [ ] 性能没有明显下降
- [ ] 代码更简洁易读

---

## 📊 迁移前后对比

### 代码行数对比

| 文件 | 迁移前 | 迁移后 | 减少 |
|------|--------|--------|------|
| enemy_state_machine.gd | ~53 行 | ~10 行 | -81% |
| enemy_base_state.gd | ~53 行 | ~15 行 | -72% |
| boss_state_machine.gd | ~99 行 | ~35 行 | -65% |
| boss_base_state.gd | ~53 行 | ~15 行 | -72% |
| **总计** | **~258 行** | **~75 行** | **-71%** |

### 维护成本

| 任务 | 迁移前 | 迁移后 |
|------|--------|--------|
| 修复状态机 bug | 修改 2+ 文件 | 修改 1 个基类 |
| 添加新功能 | 每个敌人都要改 | 只改基类 |
| 创建新敌人 | 复制 7+ 文件 | 复制 2 文件 |
| 理解代码结构 | 需要看多个文件 | 看一个基类 |

---

## 🚀 迁移后的优势

1. **新敌人创建速度提升 5 倍**
   - 之前: 7 个文件，200+ 行代码
   - 之后: 1-2 个文件，20-50 行代码

2. **Bug 修复效率提升**
   - 修一个地方 = 修所有敌人

3. **代码可读性提升**
   - 统一接口，一目了然
   - 新团队成员上手更快

4. **灵活性提升**
   - 保留完全自定义的能力
   - 同时享受代码复用的好处

---

## 💡 下一步

迁移完成后，考虑：

1. **创建更多通用状态**
   - Patrol（巡逻）
   - Flee（逃跑）
   - Alert（警戒）

2. **添加调试工具**
   - 状态可视化
   - 状态转换日志
   - 性能分析

3. **文档完善**
   - 为每个状态添加注释
   - 创建状态转换图

4. **考虑 C++ 优化**
   - 状态机核心逻辑用 GDExtension
   - 保持 GDScript 的易用性
