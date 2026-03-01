# Level1 场景修复：重力与位置问题 (2026-02-26)

## 修复概览

在 Level1 场景测试中发现并修复了 6 个关键问题，主要涉及：
- 敌人死亡后不消失
- 敌人移动朝向反了
- Hahashin 没有重力影响
- Hahashin 初始位置不正确
- PlayerSpawn 位置设置顺序错误
- 敌人动画系统优化

---

## 问题 1: 敌人死亡后不消失

### 症状
敌人生命值归零后，死亡动画播放，但节点不会从场景中删除。

### 根本原因
`EnemyBase._handle_death()` 只播放动画，没有调用 `queue_free()`。

### 解决方案
**文件**: `Core/Characters/EnemyBase.gd:76-98`

```gdscript
func _handle_death() -> void:
    # 停止状态机
    var state_machine = get_node_or_null("EnemyStateMachine")
    if state_machine:
        state_machine.set_physics_process(false)
        state_machine.set_process(false)

    # 通过 AnimationTree 播放死亡动画
    if anim_tree:
        anim_tree.set("parameters/control_sm/transition_request", "death")
        if anim_player:
            await anim_player.animation_finished
        else:
            await get_tree().create_timer(0.3).timeout
        queue_free()  # 关键修复
    else:
        await get_tree().create_timer(0.3).timeout
        queue_free()
```

### 知识点：`queue_free()` vs `free()`
- `queue_free()`: 延迟删除，在当前帧结束时删除（推荐，安全）
- `free()`: 立即删除（危险，可能导致访问已删除节点的错误）

---

## 问题 2: 敌人移动时朝向反了

### 症状
敌人向左移动时面朝右，向右移动时面朝左。

### 根本原因
翻转逻辑 `flip_h = velocity.x < 0` 与精灵默认朝向不匹配。

### 解决方案
**文件**: `Core/Characters/EnemyBase.gd:107-117`

```gdscript
func _update_sprite_facing() -> void:
    if not sprite or not alive or velocity.x == 0:
        return

    # 精灵默认朝向左边，向右移动时翻转
    if sprite is Sprite2D:
        (sprite as Sprite2D).flip_h = velocity.x > 0
    elif sprite is AnimatedSprite2D:
        (sprite as AnimatedSprite2D).flip_h = velocity.x > 0
```

### 知识点：精灵翻转约定
- **标准约定**（精灵默认朝右）：`flip_h = velocity.x < 0`
- **本项目约定**（精灵默认朝左）：`flip_h = velocity.x > 0`

**建议**：统一所有精灵资源朝向右边，使代码逻辑一致。

---

## 问题 3: Hahashin 初始位置不正确

### 解决方案
**文件**: `Scenes/Levels/Level1_Adventure/Level1.tscn:803-805`

调整 PlayerSpawn 位置到地面：
```gdscript
# 修复前：position = Vector2(348, 489)
# 修复后：position = Vector2(100, 430)  # 与地面敌人 y 坐标一致
```

---

## 问题 4: Hahashin 没有重力影响（核心问题）

### 症状
Hahashin 可以在空中行走，不受重力影响掉落。

### 根本原因 1: PlayerBase 缺少重力系统

**解决方案**: `Core/Characters/PlayerBase.gd:16-37`

```gdscript
# 添加重力配置
@export_group("Physics")
@export var has_gravity := true
@export var gravity := 980.0

func _physics_process(delta: float) -> void:
    # 应用重力
    if has_gravity:
        if not is_on_floor():
            velocity.y += gravity * delta
        elif velocity.y > 0:
            velocity.y = 0
```

### 根本原因 2: MovementComponent 覆盖垂直速度（关键）

MovementComponent 的 `process_movement()` 将整个 velocity（包括 y 轴）移向 target_velocity，抵消了重力。

**问题代码**:
```gdscript
# 错误：覆盖整个 velocity，包括重力产生的 y 速度
var target_velocity = Vector2.ZERO
if can_move:
    target_velocity = input_direction * max_speed
owner_body.velocity = owner_body.velocity.move_toward(target_velocity, acceleration)
```

**解决方案**: `Core/Components/MovementComponent.gd:94-120`

```gdscript
func process_movement(delta: float) -> void:
    if not owner_body:
        return

    # 只处理 x 轴，保留 y 轴用于重力
    var target_velocity_x = 0.0
    if can_move:
        target_velocity_x = input_direction.x * max_speed

    # 只修改水平速度，保留垂直速度
    var acceleration = (1.0 / acceleration_time) * max_speed * delta
    owner_body.velocity.x = move_toward(owner_body.velocity.x, target_velocity_x, acceleration)

    # velocity.y 保持不变，由 PlayerBase 的重力系统处理
    owner_body.move_and_slide()
```

### 核心设计原则：组件职责分离

**❌ 错误**：组件覆盖整个 velocity
```gdscript
# 问题：覆盖了 velocity.y（重力）
owner.velocity = owner.velocity.move_toward(target, accel)
```

**✅ 正确**：组件只修改自己负责的部分
```gdscript
# 只修改 x 轴，y 轴由基类管理
owner.velocity.x = move_toward(owner.velocity.x, target_x, accel)
```

### 架构层次
```
PlayerBase._physics_process()
    └─ 应用重力（管理 velocity.y）
    └─ MovementComponent.process_movement()
        └─ 处理水平移动（只修改 velocity.x）
```

---

## 问题 5: PlayerSpawn 位置设置顺序错误

### 症状
设置 `player.global_position` 后，玩家实际位置与预期不符。

### 根本原因
在节点未添加到场景树时设置 `global_position`，导致位置计算错误。

### 解决方案
**文件**: `Scenes/CommonScript/PlayerSpawn.gd:31-49`

```gdscript
# 错误顺序
player.global_position = self.global_position  # 先设置位置
add_child(player)  # 后添加到场景树

# 正确顺序
add_child(player)  # 先添加到场景树
player.global_position = self.global_position  # 然后设置位置
```

### 知识点：Godot 节点生命周期

```
Instantiate → Add to Tree → _enter_tree() → _ready()
             ↑
             在这之后 global_position 才正确
```

**关键**：未在树中的节点，`global_position` 可能无效或产生意外结果。

### 节点初始化的正确模式

```gdscript
func spawn_entity(scene: PackedScene, spawn_pos: Vector2) -> Node:
    # 1. 实例化
    var entity = scene.instantiate()

    # 2. 添加到场景树
    add_child(entity)

    # 3. 设置位置/属性（此时可以安全访问 global_position）
    entity.global_position = spawn_pos

    # 4. 初始化状态
    if entity.has_method("initialize"):
        entity.initialize()

    return entity
```

---

## 问题 6: 敌人动画系统优化

### 优化
通过 AnimationTree 的状态机播放死亡动画，而不是直接使用 AnimationPlayer：

```gdscript
# 优化前：关闭 AnimationTree，使用 AnimationPlayer
if anim_tree:
    anim_tree.active = false
if anim_player:
    anim_player.play("death")

# 优化后：统一使用 AnimationTree
if anim_tree:
    anim_tree.set("parameters/control_sm/transition_request", "death")
```

### 优势
1. 统一架构：所有动画都通过 AnimationTree 管理
2. 更好的混合：AnimationTree 可以平滑过渡到死亡动画
3. 减少切换成本：不需要关闭/启用不同的动画系统

---

## 相关问题发散

### 1. 重力相关常见问题

**问题 A：角色"粘"在天花板上**
```gdscript
func _physics_process(delta: float) -> void:
    velocity.y += gravity * delta
    move_and_slide()

    # 修复：碰到天花板时清零向上速度
    if is_on_ceiling():
        velocity.y = 0
```

**问题 B：角色穿过地面**
```gdscript
# 原因：重力值太大或帧率太低
# 解决方案：
# 1. 降低重力值
gravity = 800.0  # 而不是 2000.0

# 2. 限制最大下落速度
@export var max_fall_speed := 500.0
velocity.y = min(velocity.y, max_fall_speed)
```

**问题 C：角色在斜坡上滑动**
```gdscript
func _physics_process(delta: float) -> void:
    velocity.y += gravity * delta
    move_and_slide()

    # 在斜坡上停止时不滑动
    if is_on_floor() and velocity.length() < 1.0:
        velocity = Vector2.ZERO
```

### 2. 组件化架构中的职责分离

**原则**：组件不应覆盖基类管理的状态

```gdscript
# ❌ 错误示例：组件覆盖整个状态
class_name BadMovementComponent
func process_movement(delta: float) -> void:
    # 问题：覆盖了基类管理的重力
    owner.velocity = calculate_velocity()

# ✅ 正确示例：组件只修改自己负责的部分
class_name GoodMovementComponent
func process_movement(delta: float) -> void:
    # 只修改水平速度，不影响垂直速度
    owner.velocity.x = calculate_horizontal_velocity()
```

### 3. 2D 平台游戏物理系统完整示例

```gdscript
class_name PlatformerCharacter extends CharacterBody2D

@export_group("Physics")
@export var gravity := 980.0
@export var max_fall_speed := 500.0
@export var jump_velocity := -400.0

@export_group("Movement")
@export var max_speed := 200.0
@export var acceleration := 1000.0
@export var friction := 800.0

func _physics_process(delta: float) -> void:
    # 1. 应用重力
    if not is_on_floor():
        velocity.y += gravity * delta
        velocity.y = min(velocity.y, max_fall_speed)

    # 2. 处理跳跃
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = jump_velocity

    # 3. 处理水平移动
    var input_dir = Input.get_axis("left", "right")
    if input_dir != 0:
        velocity.x = move_toward(velocity.x, input_dir * max_speed, acceleration * delta)
    else:
        velocity.x = move_toward(velocity.x, 0, friction * delta)

    # 4. 移动
    move_and_slide()
```

### 4. 节点初始化常见陷阱

**陷阱 1：过早访问 global_position**
```gdscript
# ❌ 错误
var node = Node2D.new()
node.global_position = Vector2(100, 100)  # 无效！
add_child(node)

# ✅ 正确
var node = Node2D.new()
add_child(node)
node.global_position = Vector2(100, 100)
```

**陷阱 2：在 _ready() 中访问未初始化的子节点**
```gdscript
# 更安全的做法
func _ready() -> void:
    call_deferred("setup_children")

func setup_children() -> void:
    $Child.global_position = Vector2(100, 100)
```

**陷阱 3：忽略父节点的 transform**
```gdscript
# 如果父节点有缩放或旋转，global_position 的计算会受影响
parent.scale = Vector2(2, 2)
child.position = Vector2(10, 10)
print(child.global_position)  # 不是 (10, 10)！
```

---

## 总结

### 修复的文件
1. `Core/Characters/EnemyBase.gd` - 死亡处理、朝向、动画
2. `Core/Characters/PlayerBase.gd` - 重力系统
3. `Core/Components/MovementComponent.gd` - **修复重力冲突（关键）**
4. `Scenes/CommonScript/PlayerSpawn.gd` - 位置设置顺序、场景路径
5. `Scenes/Levels/Level1_Adventure/Level1.tscn` - 玩家初始位置

### 核心教训
1. **组件职责分离**：组件只修改自己负责的状态，不覆盖基类管理的属性
2. **节点生命周期**：先添加到场景树，再设置全局属性
3. **重力系统分层**：基类应用重力，组件只处理水平移动
4. **资源清理**：角色死亡后必须调用 `queue_free()`
5. **精灵朝向约定**：了解资源默认朝向，编写匹配的翻转逻辑

### 测试结果
- ✅ 敌人死亡后正确消失
- ✅ 敌人移动方向与朝向一致
- ✅ Hahashin 正确生成在地面位置 (100, 430)
- ✅ Hahashin 受重力影响，正常站立在地面
- ✅ 敌人检测到玩家并切换到追击状态
- ✅ 无运行时错误

---

**日期**: 2026-02-26
**Godot 版本**: 4.4.1
**测试场景**: Level1_Adventure
