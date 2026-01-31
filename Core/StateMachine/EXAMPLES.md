# 状态机使用示例

## 示例 1: 创建简单敌人 Enemy1（完全复用）

### 场景结构
```
Enemy1.tscn
└── Enemy1 (CharacterBody2D)
    ├── Sprite2D
    ├── CollisionShape2D
    ├── Health (Health Component)
    └── StateMachine (BaseStateMachine)  ← 直接使用基类
        ├── Idle (idle_state.gd)         ← 复用通用状态
        ├── Chase (chase_state.gd)       ← 复用通用状态
        ├── Stun (stun_state.gd)         ← 复用通用状态
        └── Attack (enemy1_attack.gd)    ← 唯一自定义状态
```

### Enemy1 脚本
```gdscript
# enemy1.gd
extends CharacterBody2D
class_name Enemy1

signal damaged(damage: Damage)

@export var max_health := 50
@export var chase_speed := 80.0
@export var detection_radius := 120.0

var health := 50
var alive := true
var stunned := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func play_animation(anim_name: String) -> void:
    if anim_player.has_animation(anim_name):
        anim_player.play(anim_name)

func on_damaged(damage: Damage, _attacker_pos: Vector2 = Vector2.ZERO) -> void:
    health -= damage.amount
    damaged.emit(damage)  # 触发状态机的 on_damaged

    if health <= 0:
        alive = false
        queue_free()
```

### 唯一需要自定义的状态：Attack
```gdscript
# enemy1_attack.gd
extends BaseState

@export var attack_damage := 10.0
@export var attack_cooldown := 1.0

var can_attack := true

func enter() -> void:
    if owner_node and owner_node.has_method("play_animation"):
        owner_node.play_animation("attack")

    # 执行攻击
    _perform_attack()

    # 攻击后返回追击
    await get_tree().create_timer(0.5).timeout
    transitioned.emit(self, "chase")

func _perform_attack() -> void:
    if not can_attack:
        return

    # 这里实现攻击逻辑
    print("Enemy1 攻击!")
    can_attack = false

    await get_tree().create_timer(attack_cooldown).timeout
    can_attack = true
```

### StateMachine 配置（在编辑器中）
- **Init State**: Idle 节点
- **Owner Node Group**: 留空
- **Target Node Group**: `player`

**完成！** Enemy1 只需要一个自定义攻击状态，其他全部复用。

---

## 示例 2: Enemy2 - 飞行敌人（部分重写）

Enemy2 是飞行敌人，需要自定义 Chase 状态，但其他状态可以复用。

### 场景结构
```
Enemy2.tscn
└── Enemy2 (CharacterBody2D)
    └── StateMachine (BaseStateMachine)
        ├── Idle (idle_state.gd)          ← 复用
        ├── Chase (enemy2_chase.gd)       ← 自定义飞行追击
        ├── Stun (stun_state.gd)          ← 复用
        └── Dive (enemy2_dive.gd)         ← 新增俯冲攻击
```

### 自定义飞行追击
```gdscript
# enemy2_chase.gd
extends BaseState

@export var fly_speed := 150.0
@export var hover_height := 100.0  # 悬停高度
@export var dive_range := 80.0

func physics_process_state(_delta: float) -> void:
    if not is_target_alive():
        transitioned.emit(self, "idle")
        return

    var distance = get_distance_to_target()

    # 足够近，发起俯冲
    if distance <= dive_range:
        transitioned.emit(self, "dive")
        return

    # 飞向玩家，但保持高度
    if owner_node is CharacterBody2D and target_node is Node2D:
        var body = owner_node as CharacterBody2D
        var target_pos = (target_node as Node2D).global_position
        target_pos.y -= hover_height  # 保持在玩家上方

        var direction = (target_pos - body.global_position).normalized()
        body.velocity = direction * fly_speed
        body.move_and_slide()
```

### 俯冲攻击状态
```gdscript
# enemy2_dive.gd
extends BaseState

@export var dive_speed := 300.0

func enter() -> void:
    if owner_node and owner_node.has_method("play_animation"):
        owner_node.play_animation("dive")

func physics_process_state(_delta: float) -> void:
    if owner_node is CharacterBody2D and target_node is Node2D:
        var body = owner_node as CharacterBody2D
        var direction = get_direction_to_target()

        body.velocity = direction * dive_speed
        body.move_and_slide()

        # 撞到地面或玩家后返回
        if body.is_on_floor() or get_distance_to_target() < 20.0:
            transitioned.emit(self, "chase")
```

---

## 示例 3: Enemy3 - 法师敌人（完全自定义状态，但复用状态机）

Enemy3 是远程法师，所有状态都自定义，但状态机框架复用。

### 场景结构
```
Enemy3.tscn
└── Enemy3 (CharacterBody2D)
    └── StateMachine (BaseStateMachine)
        ├── Idle (enemy3_idle.gd)
        ├── KeepDistance (enemy3_keep_distance.gd)  # 保持距离
        ├── CastSpell (enemy3_cast_spell.gd)        # 施法
        └── Teleport (enemy3_teleport.gd)           # 瞬移
```

### 保持距离状态
```gdscript
# enemy3_keep_distance.gd
extends BaseState

@export var preferred_distance := 200.0  # 偏好距离
@export var move_speed := 60.0

func physics_process_state(_delta: float) -> void:
    var distance = get_distance_to_target()

    # 太近了，瞬移
    if distance < 100.0:
        transitioned.emit(self, "teleport")
        return

    # 距离合适，施法
    if distance >= 150.0 and distance <= 250.0:
        transitioned.emit(self, "castspell")
        return

    # 调整距离
    if owner_node is CharacterBody2D:
        var body = owner_node as CharacterBody2D
        var direction = get_direction_to_target()

        # 太近则后退，太远则前进
        if distance < preferred_distance:
            direction *= -1  # 反向，后退

        body.velocity = direction * move_speed
        body.move_and_slide()
```

### 施法状态
```gdscript
# enemy3_cast_spell.gd
extends BaseState

const FIREBALL = preload("res://Weapons/bullet/fire/fire_bullet.tscn")

@export var cast_time := 1.0
@export var spell_cooldown := 2.0

var is_casting := false

func enter() -> void:
    is_casting = true

    if owner_node and owner_node.has_method("play_animation"):
        owner_node.play_animation("cast")

    # 施法延迟
    await get_tree().create_timer(cast_time).timeout

    # 发射火球
    _cast_fireball()

    # 冷却后返回
    await get_tree().create_timer(spell_cooldown).timeout
    transitioned.emit(self, "keepdistance")

func _cast_fireball() -> void:
    if not is_target_alive():
        return

    var fireball = FIREBALL.instantiate()
    get_tree().root.add_child(fireball)

    if owner_node is Node2D:
        fireball.global_position = (owner_node as Node2D).global_position
        fireball.direction = get_direction_to_target()
```

---

## 示例 4: Boss - 继承状态机添加阶段逻辑

Boss 需要阶段转换，继承 BaseStateMachine 扩展功能。

### 自定义 Boss 状态机
```gdscript
# boss_state_machine.gd
extends BaseStateMachine

var is_transitioning_phase := false

func _setup_signals() -> void:
    super._setup_signals()

    # Boss 特有信号
    if owner_node and owner_node.has_signal("phase_changed"):
        owner_node.phase_changed.connect(_on_phase_changed)

func _on_owner_damaged(damage: Damage) -> void:
    # 阶段转换期间无敌
    if is_transitioning_phase:
        return
    super._on_owner_damaged(damage)

func _on_phase_changed(new_phase: int):
    is_transitioning_phase = true
    print("Boss 进入阶段 %d" % (new_phase + 1))

    # 根据阶段切换状态
    match new_phase:
        1:  # 第二阶段
            force_transition("enrage")
        2:  # 第三阶段
            force_transition("ultimate")

    await get_tree().create_timer(0.5).timeout
    is_transitioning_phase = false
```

---

## 快速创建新敌人的步骤

### 1. 确定需要哪些状态
- **简单近战敌人**: Idle + Chase + Attack + Stun（4 个状态，只需自定义 Attack）
- **远程敌人**: Idle + KeepDistance + Shoot + Stun
- **飞行敌人**: Idle + FlyChase + Dive + Stun
- **Boss**: 多个攻击状态 + 阶段转换

### 2. 复用或自定义
- **100% 复用**: 直接用 `CommonStates/` 下的状态
- **部分复用**: 复用 Idle/Stun，自定义 Chase/Attack
- **完全自定义**: 全新状态，但状态机框架复用

### 3. 场景设置（以 Enemy1 为例）

1. 创建 `Enemy1.tscn`
2. 添加 `StateMachine` 节点（脚本设为 `BaseStateMachine`）
3. 为 StateMachine 添加状态子节点：
   - 右键 → 添加子节点 → Node
   - 重命名为 `Idle`
   - 附加脚本 `res://Util/StateMachine/CommonStates/idle_state.gd`
   - 配置导出参数（detection_radius 等）
4. 重复添加其他状态
5. 设置 StateMachine 的 `Init State` 为 Idle 节点

**完成！** 新敌人创建完毕，无需修改状态机代码。

---

## 对比：传统方式 vs 模块化方式

### 传统方式（每个敌人都要写）
```
Enemy1/
  ├── enemy1.gd
  ├── enemy1_state_machine.gd  ← 重复代码
  └── States/
      ├── enemy1_base_state.gd  ← 重复代码
      ├── enemy1_idle.gd
      ├── enemy1_chase.gd
      ├── enemy1_attack.gd
      └── enemy1_stun.gd
```

**工作量**: 7 个文件，大量重复代码

### 模块化方式
```
Enemy1/
  ├── enemy1.gd
  └── States/
      └── enemy1_attack.gd  ← 唯一需要写的
```

**工作量**: 2 个文件，其他全部复用

**减少代码量**: ~70-80%

---

## 总结

- **Enemy1**（简单）: 只需自定义 Attack，其他复用 → 节省 80% 代码
- **Enemy2**（中等）: 自定义 Chase + Dive，其他复用 → 节省 60% 代码
- **Enemy3**（复杂）: 全部自定义状态，但框架复用 → 节省 40% 代码
- **Boss**（高级）: 继承状态机添加逻辑 → 灵活扩展

**核心优势**: 代码复用 + 灵活扩展 + 易于维护
