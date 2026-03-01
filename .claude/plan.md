# Dinosaur 状态机重构计划

## 一、当前架构分析

### 1.1 现有结构
```
Dinosaur (CharacterBody2D)
├── Sprite2D
├── AnimationPlayer          # 动画：idle, death, left_run, left_walk, right_run, right_walk, stunned
├── HealthComponent
├── AnimationHandler         # 代码控制动画切换（根据velocity和stunned标志）
├── EnemyStateMachine        # 状态机
│   ├── Idle                 # 继承 CommonStates/IdleState
│   ├── Wander               # 继承 CommonStates/WanderState
│   ├── Chase                # 继承 CommonStates/ChaseState
│   ├── Attack               # 继承 CommonStates/AttackState
│   └── Stun                 # 继承 CommonStates/StunState
├── HurtBoxComponent
├── HealthBar
└── AttackAnchor
```

### 1.2 现有问题
1. **缺少状态优先级系统**：所有状态平级，无法正确处理打断逻辑
2. **缺少可打断性检查**：攻击中被击可能导致状态异常
3. **动画控制分散**：AnimationHandler 独立于状态机，动画同步依赖 velocity/stunned 标志
4. **缺少反应状态**：没有 Hit、Knockback、Launch 等受击反应状态

---

## 二、重构目标

按照文档策略实现：
1. **状态分层优先级系统**：控制层 > 反应层 > 行为层
2. **可打断性机制**：状态声明是否可被打断
3. **动画参数同步**：状态机设置动画参数，动画系统响应
4. **扩展反应状态**：添加 Hit、Knockback 等状态

---

## 三、状态优先级层次

```
┌─────────────────────────────────────────┐
│  控制层 CONTROL (Priority: 2)            │
│  - StunState (眩晕)                      │
│  - FrozenState (冰冻)                    │
│  特点：最高优先级，可打断所有状态          │
├─────────────────────────────────────────┤
│  反应层 REACTION (Priority: 1)           │
│  - HitState (轻击硬直)                   │
│  - KnockbackState (击退)                 │
│  - LaunchState (击飞)                    │
│  特点：可打断行为层，不可被同层打断        │
├─────────────────────────────────────────┤
│  行为层 BEHAVIOR (Priority: 0)           │
│  - IdleState (待机)                      │
│  - WanderState (巡游)                    │
│  - ChaseState (追击)                     │
│  - AttackState (攻击)                    │
│  特点：基础AI行为，可被高层打断           │
└─────────────────────────────────────────┘
```

---

## 四、实施步骤

### 步骤1：增强 BaseState 基类

**文件**: `Core/StateMachine/BaseState.gd`

新增内容：
```gdscript
# 状态优先级枚举
enum StatePriority {
    BEHAVIOR = 0,    # 行为层（idle, wander, chase, attack）
    REACTION = 1,    # 反应层（hit, knockback, launch）
    CONTROL = 2      # 控制层（stun, frozen）
}

# 新增属性
@export var priority: StatePriority = StatePriority.BEHAVIOR
@export var can_be_interrupted: bool = true
@export var animation_state: String = ""

# 新增方法
func can_transition_to(new_state: BaseState) -> bool
func get_animation_params() -> Dictionary
```

### 步骤2：增强 BaseStateMachine

**文件**: `Core/StateMachine/BaseStateMachine.gd`

新增内容：
```gdscript
# 新增信号
signal animation_state_changed(state_name: String, params: Dictionary)

# 修改 _on_state_transition 添加优先级检查
# 新增 force_transition 方法（忽略优先级）
```

### 步骤3：更新 CommonStates 优先级配置

| 状态文件 | 优先级 | 可打断 | 动画状态 |
|---------|--------|--------|---------|
| IdleState.gd | BEHAVIOR | true | "idle" |
| WanderState.gd | BEHAVIOR | true | "wander" |
| ChaseState.gd | BEHAVIOR | true | "chase" |
| AttackState.gd | BEHAVIOR | false | "attack" |
| StunState.gd | CONTROL | false | "stunned" |

### 步骤4：新增反应状态

**新文件**: `Core/StateMachine/CommonStates/HitState.gd`
- 优先级: REACTION
- 可打断: false
- 功能: 轻击硬直，短暂停顿后恢复

**新文件**: `Core/StateMachine/CommonStates/KnockbackState.gd`
- 优先级: REACTION
- 可打断: false
- 功能: 击退物理模拟

### 步骤5：重构 EnemyAnimationHandler

**文件**: `Scenes/Characters/Enemies/dinosaur/Scripts/EnemyAnimationHandler.gd`

改为信号驱动模式：
```gdscript
func _ready() -> void:
    var state_machine = enemy.get_node("EnemyStateMachine")
    state_machine.animation_state_changed.connect(_on_animation_state_changed)

func _on_animation_state_changed(state_name: String, params: Dictionary) -> void:
    # 根据状态播放对应动画
```

### 步骤6：更新 Dinosaur 状态配置

确保每个Enemy状态正确设置优先级和动画状态属性。

---

## 五、文件变更清单

### 修改文件
1. `Core/StateMachine/BaseState.gd` - 添加优先级枚举和可打断性
2. `Core/StateMachine/BaseStateMachine.gd` - 添加优先级检查和动画信号
3. `Core/StateMachine/CommonStates/StunState.gd` - 设置 CONTROL 优先级
4. `Core/StateMachine/CommonStates/IdleState.gd` - 设置 BEHAVIOR 优先级
5. `Core/StateMachine/CommonStates/ChaseState.gd` - 设置 BEHAVIOR 优先级
6. `Core/StateMachine/CommonStates/WanderState.gd` - 设置 BEHAVIOR 优先级
7. `Core/StateMachine/CommonStates/AttackState.gd` - 设置 BEHAVIOR 优先级，不可打断
8. `Scenes/Characters/Enemies/dinosaur/Scripts/EnemyAnimationHandler.gd` - 信号驱动

### 新增文件
1. `Core/StateMachine/CommonStates/HitState.gd` - 轻击反应状态
2. `Core/StateMachine/CommonStates/KnockbackState.gd` - 击退反应状态

---

## 六、验证要点

1. **优先级测试**：
   - 行为中被击 → 切换到反应状态 ✓
   - 反应中被眩晕 → 切换到控制状态 ✓
   - 攻击中被轻击 → 根据配置决定是否打断 ✓

2. **动画同步测试**：
   - 状态切换时动画正确响应 ✓
   - 移动动画根据方向正确翻转 ✓

3. **回归测试**：
   - 原有 Idle → Wander → Chase → Attack 流程正常 ✓
   - 受击进入 Stun 状态正常 ✓
