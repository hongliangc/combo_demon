# 自治组件架构重构 - 2026-01-18

## 概述

将 Player 类从耦合的 Handler 架构重构为完全自治的组件架构，参考状态机（BaseState）的设计模式。

## 设计理念

### 状态机模式启发

参考 `BaseStateMachine` 和 `BaseState` 的设计：

1. **自治性**：状态内部完全封装业务逻辑，外部只需要配置参数
2. **依赖注入**：状态机自动注入 `owner_node`、`target_node`
3. **信号解耦**：通过信号通信，不直接调用外部代码
4. **可重载性**：通过继承和重写方法实现定制化

### 组件架构设计

```
Player (Hahashin)
├── MovementComponent       # 自动处理：输入、移动、加速度、精灵翻转
├── AnimationComponent      # 自动处理：动画播放、AnimationTree管理
├── CombatComponent         # 自动处理：技能输入、伤害切换、技能执行
├── SkillManager            # 自动处理：特殊攻击完整流程
└── HealthComponent         # 管理：生命值、受伤、死亡
```

## 架构对比

### 旧架构（Handler 模式）

```gdscript
# ❌ 问题：业务逻辑在组件外部

# hahashin.gd（278行）
func _process(delta):
    movement_component.update_input_direction()  # 手动调用

func _physics_process(delta):
    movement_component.apply_movement(delta)     # 手动调用

# movement_hander.gd（63行）
func _process(delta):
    # 处理技能输入
    for key in animation_handler.skill_config.keys():
        if Input.is_action_just_pressed(key):
            animation_handler.play_animation(key)
            movement_component.can_move = false

func _physics_process(delta):
    # 处理加速度
    velocity = velocity.move_toward(target, acceleration * delta)
    # 处理精灵翻转
    if movement_component.last_face_direction.x < 0:
        anim_sprite.flip_h = true

# animation_hander.gd（121行）
var skill_config = { ... }  # 技能配置硬编码
func play_animation(name):
    # 处理特殊攻击
    if config.get("needs_preparation"):
        if not player.prepare_special_attack():
            return
        player.movement_component.can_move = false
        await player.execute_special_attack_movement()
    playback.travel(name)
```

**问题总结**：
- 业务逻辑分散在 3 个文件中（hahashin, movement_hander, animation_hander）
- 组件不自治，需要外部手动调用
- 组件间紧耦合，直接相互调用
- 技能配置硬编码在 handler 中

### 新架构（自治组件）

```gdscript
# ✅ 优势：业务逻辑在组件内部

# hahashin.gd（119行，-51%）
func _ready():
    _connect_component_signals()

# 组件生命周期由组件自己管理
# MovementComponent 自动处理 _process 和 _physics_process
# CombatComponent 自动处理技能输入
# SkillManager 自动处理特殊攻击

# MovementComponent.gd（180行，完全自治）
func _ready():
    owner_body = get_parent() as CharacterBody2D
    sprite_node = owner_body.get_node_or_null(sprite_node_path)
    hitbox_node = owner_body.get_node_or_null(hitbox_node_path)

func _process(delta):
    update_input_direction()  # 自动运行

func _physics_process(delta):
    process_movement(delta)   # 自动运行
    update_sprite_flip()      # 自动翻转精灵和Hitbox

# CombatComponent.gd（238行，完全自治）
func _ready():
    _find_components()        # 自动查找其他组件
    _setup_default_skills()   # 自动初始化技能配置

func _process(delta):
    if auto_process_input:
        process_skill_input()  # 自动处理技能输入

func execute_skill(skill_name):
    # 自动播放动画、音效
    # 自动禁用/恢复移动
    # 自动委托特殊技能给 SkillManager

# SkillManager.gd（256行，完全自治）
func _ready():
    _find_components()
    combat_component.skill_started.connect(_on_combat_skill_started)

func _on_combat_skill_started(skill_name):
    if skill_name == "atk_sp":
        _execute_special_attack_flow()  # 自动执行完整流程

func _execute_special_attack_flow():
    # 1. 检测敌人
    # 2. 禁用移动
    # 3. 移动到敌人
    # 4. 播放动画
    # 5. 聚集敌人（由动画事件触发）
```

**优势总结**：
- 业务逻辑完全封装在组件内部
- 组件自动运行，不需要外部手动调用
- 组件间通过信号解耦，不直接调用
- 技能配置参数化，可通过 @export 或代码配置
- Player 类极简（119行），只负责组件协调

## 组件详解

### 1. MovementComponent（自治移动组件）

**功能**：
- ✅ 自动处理输入更新（`_process`）
- ✅ 自动处理移动和加速度（`_physics_process`）
- ✅ 自动翻转精灵和 Hitbox
- ✅ 发射信号（`direction_changed`, `velocity_changed`, `sprite_flipped`）

**配置参数**：
```gdscript
@export var max_speed: float = 100.0
@export var acceleration_time: float = 0.1
@export var sprite_node_path: NodePath = ^"AnimatedSprite2D"
@export var hitbox_node_path: NodePath = ^"%Hitbox"
```

**可重载方法**：
```gdscript
func get_input() -> Vector2          # 子类可实现 AI 控制
func process_movement(delta)         # 自定义移动逻辑
func update_sprite_flip()            # 自定义翻转逻辑
```

**依赖注入**：
```gdscript
func _ready():
    owner_body = get_parent() as CharacterBody2D  # 自动获取
    sprite_node = owner_body.get_node_or_null(sprite_node_path)
    hitbox_node = owner_body.get_node_or_null(hitbox_node_path)
```

### 2. AnimationComponent（动画管理组件）

**功能**：
- ✅ 管理 AnimationTree
- ✅ 播放动画（travel）
- ✅ 控制时间缩放
- ✅ 发射信号（`animation_started`, `animation_finished`）

**配置参数**：
```gdscript
@export var animation_tree_path: NodePath = ^"AnimationTree"
@export var state_machine_param: String = "parameters/StateMachine/playback"
@export var time_scale_param: String = "parameters/TimeScale/scale"
```

**公共 API**：
```gdscript
func play(animation_name, time_scale, blend_time)
func get_current_state() -> String
func is_playing(animation_name) -> bool
```

### 3. CombatComponent（自治战斗组件）

**功能**：
- ✅ 自动处理技能输入（`_process`）
- ✅ 管理技能配置（`skill_configs` 字典）
- ✅ 自动播放动画和音效
- ✅ 自动禁用/恢复移动
- ✅ 管理伤害类型切换
- ✅ 委托特殊技能给 SkillManager

**配置参数**：
```gdscript
@export var damage_types: Array[Damage] = []
@export var auto_process_input: bool = true
```

**技能配置示例**：
```gdscript
add_skill("atk_1", {
    "input_action": "attack",
    "sound_effect": null,
    "time_scale": 2.0,
    "disable_movement": true
})

add_skill("roll", {
    "input_action": "roll",
    "time_scale": 2.0,
    "roll_speed": 400
})
```

**组件间通信**：
```gdscript
func _find_components():
    animation_component = owner_node.get_node_or_null("AnimationComponent")
    movement_component = owner_node.get_node_or_null("MovementComponent")
```

**可重载方法**：
```gdscript
func process_skill_input()           # 自定义输入处理
func _setup_default_skills()         # 自定义技能配置
```

### 4. SkillManager（自治技能管理组件）

**功能**：
- ✅ 自动监听 `CombatComponent.skill_started` 信号
- ✅ 自动执行特殊攻击完整流程：
  1. 检测前方敌人（扇形范围）
  2. 禁用移动
  3. 移动到敌人位置（Tween）
  4. 播放动画和音效
  5. 聚集敌人（动画事件触发）

**配置参数**：
```gdscript
@export var detection_radius: float = 300.0
@export var detection_angle: float = 45.0
@export var move_duration: float = 0.2
@export var gather_duration: float = 0.3
@export var special_attack_skill_name: String = "atk_sp"
@export var auto_handle_special_attack: bool = true
```

**自动处理流程**：
```gdscript
func _on_combat_skill_started(skill_name):
    if skill_name == "atk_sp":
        _execute_special_attack_flow()

func _execute_special_attack_flow():
    # 1. 检测敌人
    if not _prepare_special_attack(...):
        special_attack_cancelled.emit()
        return

    # 2. 禁用移动
    movement_component.can_move = false

    # 3. 移动到敌人
    await _execute_movement(body)

    # 4. 播放动画
    _play_attack_animation()
```

### 5. HealthComponent（健康管理组件）

保持不变，已经是良好的组件设计。

## 代码量对比

| 文件 | 旧版本 | 新版本 | 变化 |
|------|--------|--------|------|
| hahashin.gd | 278行 | 119行 | **-57%** |
| movement_hander.gd | 63行 | ❌ 删除 | - |
| animation_hander.gd | 121行 | ❌ 删除 | - |
| MovementComponent.gd | 91行 | 180行 | +89行（完全自治） |
| AnimationComponent.gd | - | 97行 | +97行（新增） |
| CombatComponent.gd | 71行 | 238行 | +167行（完全自治） |
| SkillManager.gd | 164行 | 256行 | +92行（完全自治） |
| **总计** | **788行** | **890行** | **+102行（+13%）** |

**收益**：
- ✅ 主类极简（-57%）
- ✅ 组件完全解耦
- ✅ 业务逻辑内聚
- ✅ 可重用性强
- ✅ 可测试性强
- ✅ 可扩展性强

## 关键设计模式

### 1. 依赖注入

组件自动获取所需的节点引用：

```gdscript
# MovementComponent
func _ready():
    owner_body = get_parent() as CharacterBody2D
    sprite_node = owner_body.get_node_or_null(sprite_node_path)

# CombatComponent
func _find_components():
    animation_component = owner_node.get_node_or_null("AnimationComponent")
    movement_component = owner_node.get_node_or_null("MovementComponent")
```

### 2. 信号解耦

组件间通过信号通信，不直接调用：

```gdscript
# SkillManager 监听 CombatComponent
combat_component.skill_started.connect(_on_combat_skill_started)

# CombatComponent 监听 AnimationComponent
animation_component.animation_finished.connect(_on_skill_animation_finished)

# Player 监听 HealthComponent
health_component.died.connect(_on_died)
```

### 3. 模板方法模式

提供可重载的方法供子类定制：

```gdscript
# MovementComponent
func get_input() -> Vector2:  # 子类可重载实现 AI
    return Input.get_vector(...)

func process_movement(delta):  # 子类可重载自定义移动
    # 默认实现

# CombatComponent
func _setup_default_skills():  # 子类可重载配置技能
    add_skill("atk_1", {...})
```

### 4. 策略模式

技能配置参数化，支持运行时修改：

```gdscript
# 可通过代码动态添加技能
combat_component.add_skill("new_skill", {
    "input_action": "custom_key",
    "time_scale": 1.5
})

# 可移除技能
combat_component.remove_skill("old_skill")
```

## 迁移指南

### 步骤 1：在 Godot 编辑器中配置场景

打开 `hahashin.tscn`，添加新组件节点：

```
Hahashin (CharacterBody2D)
├── HealthComponent (Node)
├── MovementComponent (Node)          # 新增
├── AnimationComponent (Node)         # 新增
├── CombatComponent (Node)
└── SkillManager (Node)
```

### 步骤 2：配置组件参数

**MovementComponent**：
```
max_speed: 100
acceleration_time: 0.1
sprite_node_path: "AnimatedSprite2D"
hitbox_node_path: "%Hitbox"
```

**AnimationComponent**：
```
animation_tree_path: "AnimationTree"
```

**CombatComponent**：
```
damage_types: [Physical.tres, KnockUp.tres, SpecialAttack.tres]
auto_process_input: true
```

**SkillManager**：
```
detection_radius: 300
detection_angle: 45
auto_handle_special_attack: true
```

### 步骤 3：删除旧节点

从场景中删除：
- `MovementHandler` 节点
- `AnimationHandler` 节点

### 步骤 4：测试

运行游戏并测试：
- [ ] 基本移动（WASD）
- [ ] 普通攻击（J）
- [ ] 翻滚（K）
- [ ] 特殊攻击（V）
- [ ] 精灵翻转
- [ ] 受伤和死亡
- [ ] 动画播放

## 扩展示例

### 创建 AI 控制的敌人

```gdscript
# EnemyMovementComponent.gd
extends MovementComponent

# 重载输入方法，实现 AI 控制
func get_input() -> Vector2:
    # 不使用键盘输入，使用 AI 逻辑
    if target_node:
        var direction = (target_node.global_position - owner_body.global_position).normalized()
        return direction
    return Vector2.ZERO
```

### 自定义技能配置

```gdscript
# CustomCombatComponent.gd
extends CombatComponent

func _setup_default_skills():
    add_skill("dash", {
        "input_action": "dash",
        "time_scale": 3.0,
        "dash_speed": 800,
        "invincible": true
    })

    add_skill("heavy_attack", {
        "input_action": "heavy_attack",
        "time_scale": 0.5,
        "damage_multiplier": 3.0
    })
```

## 总结

### 架构优势

1. **自治性**：组件内部完全封装业务逻辑
2. **解耦性**：组件间通过信号通信，低耦合
3. **可重用性**：组件可在不同实体间复用
4. **可扩展性**：通过继承和重载实现定制
5. **可测试性**：组件独立，易于单元测试
6. **可维护性**：业务逻辑内聚，易于理解和修改

### 设计原则

- ✅ **单一职责原则**：每个组件只负责一个领域
- ✅ **开闭原则**：对扩展开放，对修改关闭
- ✅ **依赖倒置原则**：依赖抽象（信号），不依赖具体
- ✅ **接口隔离原则**：组件提供最小化的公共 API
- ✅ **组合优于继承**：通过组件组合构建复杂行为

### 参考资料

- 状态机实现：`Util/StateMachine/base_state_machine.gd`
- 状态基类：`Util/StateMachine/base_state.gd`
- 眩晕状态示例：`Util/StateMachine/CommonStates/stun_state.gd`

---

**作者**：Claude Sonnet 4.5
**日期**：2026-01-18
**版本**：v2.0 - 自治组件架构
