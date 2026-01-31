# 通用状态机系统

模块化、可复用的状态机系统，适用于 Enemy、Boss、Player 等任何需要状态管理的实体。

## 📁 文件结构

```
Util/StateMachine/
├── base_state_machine.gd  # 状态机基类
├── base_state.gd          # 状态基类
└── README.md             # 本文档
```

## 🚀 快速开始

### 方式 1: 直接使用（推荐用于简单敌人）

在场景树中：
```
Enemy1 (CharacterBody2D)
└── StateMachine (BaseStateMachine)
    ├── Idle (继承 BaseState)
    ├── Chase (继承 BaseState)
    └── Attack (继承 BaseState)
```

**StateMachine 配置：**
- Init State: 选择 `Idle` 节点
- Owner Node Group: 留空（自动使用 get_owner()）
- Target Node Group: `"player"`

### 方式 2: 继承扩展（推荐用于复杂 Boss）

创建自定义状态机：

```gdscript
# boss_state_machine.gd
extends BaseStateMachine

# Boss 特有的阶段转换标志
var is_transitioning_phase := false

func _setup_signals() -> void:
    super._setup_signals()  # 调用父类方法

    # Boss 特有的信号
    if owner_node and owner_node.has_signal("phase_changed"):
        owner_node.phase_changed.connect(_on_phase_changed)

func _on_owner_damaged(damage: Damage) -> void:
    # 阶段转换期间不接受伤害
    if is_transitioning_phase:
        return
    super._on_owner_damaged(damage)

func _on_phase_changed(new_phase: int):
    is_transitioning_phase = true
    # ... Boss 特有的阶段切换逻辑
    await get_tree().create_timer(0.1).timeout
    is_transitioning_phase = false
```

## 📖 状态编写示例

### 简单状态（直接继承 BaseState）

```gdscript
# idle_state.gd
extends BaseState

var idle_time := 0.0

func enter() -> void:
    idle_time = randf_range(1.0, 3.0)
    if owner_node and owner_node.has_method("play_animation"):
        owner_node.play_animation("idle")

func process_state(delta: float) -> void:
    idle_time -= delta

    # 使用基类的工具方法
    if is_target_in_range(100.0):
        transitioned.emit(self, "chase")
    elif idle_time <= 0:
        transitioned.emit(self, "wander")
```

### 复杂状态（自定义）

```gdscript
# boss_enrage_state.gd
extends BaseState

func enter() -> void:
    if owner_node is Boss:
        var boss = owner_node as Boss
        boss.play_animation("enrage")
        boss.speed_multiplier = 1.5

func on_damaged(damage: Damage) -> void:
    # Boss 狂暴状态不会被击晕
    pass  # 不调用父类方法，忽略击晕

func exit() -> void:
    if owner_node is Boss:
        (owner_node as Boss).speed_multiplier = 1.0
```

## 🎯 为新敌人创建状态机

### Enemy1（使用现有状态）

```
Enemy1 (CharacterBody2D, 组: "enemy")
└── StateMachine (BaseStateMachine)
    ├── Idle (复用现有脚本)
    ├── Chase (复用现有脚本)
    └── Attack (复用现有脚本)
```

### Enemy2（部分重写）

```gdscript
# enemy2_chase_state.gd
extends BaseState  # 继承基类，不继承 enemy_chase

func physics_process_state(delta: float) -> void:
    # Enemy2 的特殊追击逻辑（例如会飞）
    var direction = get_direction_to_target()
    if owner_node is CharacterBody2D:
        var body = owner_node as CharacterBody2D
        body.velocity = direction * 200.0  # 更快的速度
        body.move_and_slide()
```

### Enemy3（完全自定义）

```gdscript
# enemy3_teleport_state.gd
extends BaseState

func enter() -> void:
    # Enemy3 的特殊能力：瞬移到玩家附近
    if owner_node is Node2D and target_node is Node2D:
        var random_offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
        (owner_node as Node2D).global_position = (target_node as Node2D).global_position + random_offset

    await get_tree().create_timer(0.5).timeout
    transitioned.emit(self, "attack")
```

## 🔧 BaseStateMachine API

### 导出参数
- `init_state: BaseState` - 初始状态
- `owner_node_group: String` - Owner 节点组名（可选）
- `target_node_group: String` - Target 节点组名（默认 "player"）

### 公共方法
- `force_transition(state_name: String)` - 强制切换状态
- `get_current_state_name() -> String` - 获取当前状态名
- `is_in_state(state_name: String) -> bool` - 检查是否在某状态

### 可重写方法
- `_setup_signals()` - 自定义信号连接

## 🔧 BaseState API

### 自动注入的引用
- `owner_node: Node` - 拥有者节点（Enemy/Boss）
- `target_node: Node` - 目标节点（Player）
- `state_machine: BaseStateMachine` - 所属状态机

### 生命周期方法
- `enter()` - 进入状态
- `process_state(delta)` - 每帧更新
- `physics_process_state(delta)` - 物理帧更新
- `exit()` - 退出状态
- `on_damaged(damage)` - 受到伤害（默认转到 stun）

### 工具方法
- `get_distance_to_target() -> float`
- `get_direction_to_target() -> Vector2`
- `is_target_in_range(range: float) -> bool`
- `is_target_alive() -> bool`
- `try_chase(detection_radius: float) -> bool`

## 📝 迁移现有代码

### 1. 替换 EnemyStateMachine

**之前：**
```gdscript
extends Node
var current_state: EnemyStates
@onready var enemy: Enemy = get_owner()
@onready var player: Hahashin = get_tree().get_first_node_in_group("player")
# ... 大量重复代码
```

**之后：**
```gdscript
extends BaseStateMachine
# 完成！所有逻辑在基类中
```

或直接在编辑器中将脚本改为 `BaseStateMachine`

### 2. 替换状态基类

**之前：**
```gdscript
class_name EnemyStates
signal transitioned(state: EnemyStates, new_state_name: String)
var enemy: Enemy
var player: Hahashin
```

**之后：**
```gdscript
extends BaseState
# 使用 owner_node 和 target_node 替代 enemy 和 player
```

## ⚠️ 注意事项

1. **类型转换**：基类使用 `Node` 类型，使用时需要类型转换：
   ```gdscript
   if owner_node is Enemy:
       var enemy = owner_node as Enemy
       enemy.detection_radius  # 现在可以访问
   ```

2. **信号名称**：owner_node 需要有 `damaged` 信号才能自动连接

3. **组名设置**：如果 owner 不在场景根节点，建议设置 `owner_node_group`

## 🎨 最佳实践

1. **简单敌人**：直接使用 `BaseStateMachine` + `BaseState`
2. **复杂 Boss**：继承 `BaseStateMachine` 添加特殊逻辑
3. **共享状态**：将通用状态（Idle、Chase）放在 `Util/StateMachine/States/`
4. **特定状态**：将特殊状态放在各自的敌人目录中

## 📚 相关文件

- `Scenes/enemies/dinosaur/Scripts/States/` - 原始 Enemy 状态（可作为参考）
- `Scenes/enemies/boss/Scripts/States/` - 原始 Boss 状态（可作为参考）
