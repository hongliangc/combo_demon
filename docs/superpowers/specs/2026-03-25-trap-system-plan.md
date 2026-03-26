# Trap System Implementation Plan

Based on spec: `docs/superpowers/specs/2026-03-25-trap-system-design.md`

## Overview

分 5 个阶段实施，共约 15 步。每步完成后可独立测试。

---

## Phase 1: 基础架构（必须首先完成）

### Step 1: 创建 BaseTrap 基类脚本

**文件**: `Scenes/Levels/Components/Traps/BaseTrap.gd`

```gdscript
extends Node2D
class_name BaseTrap

## 所有机关的基类
## 处理：伤害冷却、激活状态、碰撞检测 → HurtBoxComponent 调用

@export_group("伤害配置")
@export var damage_amount: float = 10.0
@export var effects: Array[AttackEffect] = []

@export_group("时序配置")
@export var activation_delay: float = 0.0   # 场景启动后延迟激活
@export var damage_cooldown: float = 1.0     # 两次伤害的最小间隔

var is_active: bool = true
var _cooldown_timer: float = 0.0
var _damage: Damage = null

func _ready() -> void:
    _build_damage()
    if activation_delay > 0.0:
        is_active = false
        get_tree().create_timer(activation_delay).timeout.connect(func(): is_active = true)
    _on_trap_ready()

func _process(delta: float) -> void:
    if _cooldown_timer > 0.0:
        _cooldown_timer -= delta

# 子类重写此方法做额外初始化
func _on_trap_ready() -> void:
    pass

# 子类调用此方法对玩家造成伤害
func _apply_damage_to(body: Node2D) -> void:
    if not is_active or _cooldown_timer > 0.0:
        return
    var hurt_box = body.get_node_or_null("HurtBoxComponent")
    if hurt_box == null:
        return
    _cooldown_timer = damage_cooldown
    hurt_box.take_damage(_damage, global_position)

func _build_damage() -> void:
    _damage = Damage.new()
    _damage.amount = damage_amount
    _damage.min_amount = damage_amount
    _damage.max_amount = damage_amount
    _damage.effects = effects
```

**要点**：
- 不继承 EnemyBase，是独立的 Node2D
- `_apply_damage_to(body)` 供子类在 `body_entered` 中调用
- `_on_trap_ready()` 是子类的初始化钩子

---

### Step 2: 创建目录结构

在 `Scenes/Levels/Components/Traps/` 下创建以下子目录：
```
SpikeTrap/  FlameJet/  FloatingPlatform/  SpinBlade/
FallingRock/  DartTrap/  ConveyorBelt/  CrumblingPlatform/
LaserFence/  SwingHammer/  LaunchPad/  SawRail/  DemoLevel/
```

---

## Phase 2: ★☆☆ 简单机关（3 种）

### Step 3: SpikeTrap 地刺

**文件**: `Scenes/Levels/Components/Traps/SpikeTrap/SpikeTrap.gd` + `.tscn`

**场景结构**:
```
SpikeTrap (Node2D, script=SpikeTrap.gd)
├── Sprite2D          # 刺的视觉（ColorRect占位：红色 16×24px）
└── DamageZone (Area2D)
    └── CollisionShape2D  # 刺激活时的碰撞区域
```

**脚本逻辑**:
```gdscript
extends BaseTrap
class_name SpikeTrap

@export var extend_time: float = 0.3     # 伸出动画时长
@export var stay_time: float = 1.5       # 伸出后停留时长
@export var retract_time: float = 0.3    # 缩回动画时长
@export var safe_time: float = 2.0       # 缩回后安全等待时长

var _damage_zone: Area2D

func _on_trap_ready() -> void:
    _damage_zone = $DamageZone
    _damage_zone.body_entered.connect(_on_body_entered)
    _start_cycle()

func _on_body_entered(body: Node2D) -> void:
    _apply_damage_to(body)

func _start_cycle() -> void:
    # 缩回状态 → 等 safe_time → 伸出 → 等 stay_time → 缩回 → 循环
    is_active = false
    _damage_zone.monitoring = false
    await get_tree().create_timer(safe_time).timeout
    # 伸出
    var tween = create_tween()
    tween.tween_property($Sprite2D, "scale:y", 1.0, extend_time)
    await tween.finished
    is_active = true
    _damage_zone.monitoring = true
    await get_tree().create_timer(stay_time).timeout
    # 缩回
    is_active = false
    _damage_zone.monitoring = false
    var tween2 = create_tween()
    tween2.tween_property($Sprite2D, "scale:y", 0.0, retract_time)
    await tween2.finished
    _start_cycle()
```

**默认配置**:
- `damage_amount = 10`, `damage_cooldown = 0.5`
- effects: `[KnockBackEffect]`（force=150，方向由伤害位置计算）

---

### Step 4: FlameJet 火焰喷射

**文件**: `Scenes/Levels/Components/Traps/FlameJet/FlameJet.gd` + `.tscn`

**场景结构**:
```
FlameJet (Node2D)
├── Nozzle (Sprite2D)         # 喷嘴（ColorRect橙色 16×16px）
├── Flame (Sprite2D)          # 火焰体（ColorRect红色，初始scale.y=0）
├── WarnParticles (GPUParticles2D)  # 预警粒子（可省略，改用颜色闪烁）
└── DamageZone (Area2D)
    └── CollisionShape2D
```

**脚本逻辑**:
- `@export var direction: Vector2 = Vector2.UP`（喷射方向）
- `@export var fire_duration: float = 2.0`
- `@export var cooldown_duration: float = 3.0`
- `@export var warn_time: float = 0.5`（预警闪烁时长）
- 循环：预警闪烁 → 喷火（DamageZone active）→ 关闭 → 循环
- effects: `[KnockBackEffect]`（force=100）

---

### Step 5: FloatingPlatform 浮动平台

**文件**: `Scenes/Levels/Components/Traps/FloatingPlatform/FloatingPlatform.gd` + `.tscn`

**注意**：继承 `AnimatableBody2D`（非 BaseTrap，无伤害）

**场景结构**:
```
FloatingPlatform (AnimatableBody2D, sync_to_physics=true)
├── Sprite2D         # 平台视觉（ColorRect绿色 80×16px）
└── CollisionShape2D # 物理碰撞（RectangleShape2D 80×8）
```

**脚本逻辑**:
```gdscript
extends AnimatableBody2D
class_name FloatingPlatform

@export var move_offset: Vector2 = Vector2(0, -80)  # 移动距离
@export var move_speed: float = 50.0
@export var wait_time: float = 1.0

var _origin: Vector2

func _ready() -> void:
    _origin = position
    _start_loop()

func _start_loop() -> void:
    var target_a = _origin + move_offset
    var duration = move_offset.length() / move_speed
    while true:
        var t1 = create_tween()
        t1.tween_property(self, "position", target_a, duration).set_trans(Tween.TRANS_SINE)
        await t1.finished
        await get_tree().create_timer(wait_time).timeout
        var t2 = create_tween()
        t2.tween_property(self, "position", _origin, duration).set_trans(Tween.TRANS_SINE)
        await t2.finished
        await get_tree().create_timer(wait_time).timeout
```

---

## Phase 3: ★★☆ 中级机关（5 种）

### Step 6: SpinBlade 旋转刀刃

**场景结构**:
```
SpinBlade (Node2D)      ← BaseTrap
├── Pivot (Node2D)      ← 旋转的锚点
│   ├── Blade (Sprite2D)        # ColorRect 黄色 64×8px，x偏移=32
│   └── DamageZone (Area2D)     # 跟随 Blade 的碰撞区
└── Center (Sprite2D)           # 轴心视觉
```

**脚本逻辑**:
```gdscript
@export var rotation_speed: float = 2.0  # rad/s
@export var blade_count: int = 2

func _process(delta: float) -> void:
    super._process(delta)  # 处理冷却计时
    $Pivot.rotation += rotation_speed * delta
```
- 多刀刃：在 `_on_trap_ready()` 中动态实例化多个 Blade，均匀分布角度
- effects: `[KnockUpEffect]`（height=60）

---

### Step 7: FallingRock 落石

**场景结构**:
```
FallingRock (Node2D)
├── TriggerZone (Area2D)   # 玩家触发区（宽区域，在岩石正下方）
│   └── CollisionShape2D
├── Shadow (Sprite2D)      # 预警阴影（ColorRect深灰色，初始scale=0）
├── Rock (CharacterBody2D) # 岩石实体
│   ├── Sprite2D
│   └── DamageZone (Area2D)
└── RespawnTimer (Timer)
```

**脚本逻辑**:
- TriggerZone.body_entered → 开始预警动画（Shadow scale 0→1，warn_time 秒）
- 预警结束 → 岩石开始下落（`_process` 中施加重力）
- 岩石碰地（StaticBody2D/TileMap）→ 调用 `_apply_damage_to` 对范围内玩家
- effects: `[StunEffect]`（duration=1.0）

---

### Step 8: DartTrap 箭矢

**场景结构**:
```
DartTrap (Node2D)        ← BaseTrap（仅管理计时，不直接检测）
├── Nozzle (Sprite2D)    # 发射口视觉
└── FireTimer (Timer)    # 射击间隔计时器
```

**TrapProjectile**（轻量抛射物）：
```
TrapProjectile (Area2D)
├── Sprite2D
├── CollisionShape2D
└── LifeTimer (Timer)    # 超时自毁
```

**脚本逻辑**:
- `FireTimer.timeout` → 实例化 TrapProjectile，设置 direction 和 speed
- TrapProjectile._physics_process → `position += direction * speed * delta`
- TrapProjectile.body_entered → `_apply_damage_to(body)` → `queue_free()`
- effects: `[KnockBackEffect]`（force=200）

---

### Step 9: ConveyorBelt 传送带

**注意**：不继承 BaseTrap，自定义实现

**场景结构**:
```
ConveyorBelt (AnimatableBody2D)
├── Sprite2D              # 传送带视觉（ColorRect蓝色 128×16px）
├── CollisionShape2D      # 物理地面
└── PushZone (Area2D)     # 检测站在上面的玩家
    └── CollisionShape2D
```

**脚本逻辑**:
```gdscript
@export var push_direction: Vector2 = Vector2.RIGHT
@export var push_force: float = 80.0

func _physics_process(delta: float) -> void:
    for body in $PushZone.get_overlapping_bodies():
        if body is PlayerBase:
            body.velocity.x += push_direction.x * push_force * delta
```

---

### Step 10: LaunchPad 弹射器

继承 BaseTrap，`damage_amount = 0`（无伤害），使用高力度 KnockUpEffect：

**脚本逻辑**:
```gdscript
@export var launch_force: float = 700.0

func _on_trap_ready() -> void:
    $DamageZone.body_entered.connect(func(body):
        if body is PlayerBase:
            body.velocity.y = -launch_force
            _cooldown_timer = damage_cooldown
    )
```

---

## Phase 4: ★★★ 高级机关（4 种）

### Step 11: CrumblingPlatform 消失平台

继承 `AnimatableBody2D`：

**状态机**（简单枚举）：`SOLID → SHAKING → GONE → RESPAWNING → SOLID`

```gdscript
func _on_body_entered(_body: Node2D) -> void:
    if state == State.SOLID:
        _start_shake()

func _start_shake() -> void:
    state = State.SHAKING
    # Tween: 随机偏移 position.x ±2px，shake_time 秒
    await get_tree().create_timer(shake_time).timeout
    _crumble()

func _crumble() -> void:
    state = State.GONE
    $CollisionShape2D.disabled = true
    visible = false
    await get_tree().create_timer(respawn_time).timeout
    _respawn()
```

---

### Step 12: LaserFence 激光栅栏

继承 BaseTrap：

**场景结构**:
```
LaserFence (Node2D)
├── Line2D              # 激光视觉（蓝/白色，width=3）
├── DamageZone (Area2D)
│   └── CollisionShape2D  # CapsuleShape2D / RectangleShape2D 覆盖激光线段
└── WarnTimer (Timer)
```

**脚本逻辑**:
- `@export var end_point: Vector2`（相对于自身的激光终点）
- `@export var on_duration: float = 2.0`
- `@export var off_duration: float = 2.5`
- `@export var warn_time: float = 0.8`（预警：Line2D 颜色闪烁）
- Line2D.points = [Vector2.ZERO, end_point]，CollisionShape2D 根据 end_point 自动设置
- effects: `[StunEffect]`（duration=1.5）

---

### Step 13: SwingHammer 锤摆

继承 BaseTrap：

**场景结构**:
```
SwingHammer (Node2D)
├── Arm (Node2D)           # 摆臂（绕自身原点旋转）
│   ├── ArmSprite (Sprite2D)   # 连杆视觉
│   ├── Hammer (Sprite2D)      # 锤头视觉（ColorRect 灰色，位于 Arm 末端）
│   └── DamageZone (Area2D)   # 跟随锤头
└── AnchorSprite (Sprite2D)   # 锚点视觉
```

**脚本逻辑**:
```gdscript
@export var arm_length: float = 80.0
@export var swing_angle: float = 60.0   # degrees，摆幅半角
@export var swing_period: float = 3.0   # 完整周期（秒）

var _time: float = 0.0

func _process(delta: float) -> void:
    super._process(delta)
    _time += delta
    var angle = deg_to_rad(swing_angle) * sin(_time * TAU / swing_period)
    $Arm.rotation = angle
```

---

### Step 14: SawRail 锯齿轨道

**场景结构**:
```
SawRail (Node2D)
├── Path2D              # 运动路径（在编辑器中手绘）
│   └── PathFollow2D
│       ├── Saw (Sprite2D)       # 锯齿视觉（ColorRect红色 24×24px）
│       └── DamageZone (Area2D)
└── RailVisual (Line2D)  # 轨道视觉辅助（可选）
```

**脚本逻辑**:
```gdscript
@export var move_speed: float = 100.0
@export var ping_pong: bool = false

var _direction: float = 1.0

func _process(delta: float) -> void:
    super._process(delta)
    var follow = $Path2D/PathFollow2D
    follow.progress += move_speed * _direction * delta
    if ping_pong:
        if follow.progress_ratio >= 1.0 or follow.progress_ratio <= 0.0:
            _direction *= -1.0
```

---

## Phase 5: 演示关卡搭建

### Step 15: 搭建 TrapDemoLevel

**文件**: `Scenes/Levels/Components/Traps/DemoLevel/TrapDemoLevel.tscn`

**步骤**:
1. 新建场景，根节点 Node2D，添加 TileMapLayer（复用 Level1 的 TileSet）
2. 铺设地形：4000×600px 横向，平台布局如 spec 所述
3. 每个区域入口放置 KillZone（触发 `player.trigger_fall_death()`）作为重生点标记
4. 按照关卡设计放置机关实例（见 spec 区域 1-4 详情）
5. 添加 FollowCamera，水平跟随，`limit_left/right` 设置关卡边界
6. 添加 Portal.tscn 作为终点（复用现有组件）

**关键参数（对应 spec）**:

| 区域 | 机关实例 | 建议 X 范围 |
|------|---------|------------|
| 入门 | SpikeTrap×3, FloatingPlatform×2, FlameJet×1 | 0 ~ 800 |
| 进阶 | SpinBlade×2, DartTrap+FloatingPlatform, ConveyorBelt+SpikeTrap | 900 ~ 1900 |
| 高阶 | CrumblingPlatform×5, FallingRock+LaserFence, SwingHammer×3 | 2000 ~ 3000 |
| 终极 | SawRail×3, LaunchPad+SpinBlade, 混合终点 | 3100 ~ 4000 |

---

## Implementation Order & Dependencies

```
Phase 1 (必须先完成)
  Step 1: BaseTrap.gd          ← 所有其他机关的依赖
  Step 2: 目录结构

Phase 2 (可并行)
  Step 3: SpikeTrap
  Step 4: FlameJet
  Step 5: FloatingPlatform     ← 无依赖，独立实现

Phase 3 (可并行，依赖 BaseTrap)
  Step 6: SpinBlade
  Step 7: FallingRock
  Step 8: DartTrap             ← 需先创建 TrapProjectile
  Step 9: ConveyorBelt         ← 无依赖 BaseTrap
  Step 10: LaunchPad

Phase 4 (可并行，依赖 BaseTrap)
  Step 11: CrumblingPlatform   ← 无依赖 BaseTrap
  Step 12: LaserFence
  Step 13: SwingHammer
  Step 14: SawRail

Phase 5 (最后)
  Step 15: DemoLevel           ← 依赖所有机关完成
```

## Testing Checklist (每种机关)

- [ ] 机关碰撞区域正确（不误触玩家不该碰的地方）
- [ ] 伤害通过 HurtBoxComponent 正确传递
- [ ] AttackEffect 在玩家状态机中正确触发（knockout/stun/knockback 状态切换）
- [ ] 机关冷却时间防止多次连续伤害
- [ ] 机关循环无内存泄漏（Tween/Timer 正确清理）
- [ ] 浮动/消失平台玩家跟随物理正确
- [ ] 在演示关卡中各区域难度节奏符合预期

## Notes

- **占位视觉**：全部使用 ColorRect 或简单 Sprite2D，后续替换美术资源
- **物理层**: DamageZone `collision_layer=0, collision_mask=2`（仅检测 Player）
- **平台物理层**: AnimatableBody2D `collision_layer=1`（World 层）
- **TrapProjectile 物理层**: `collision_layer=5, collision_mask=2`（Enemy Projectile 层）
- **LaunchPad**: `damage_amount=0` + KnockUpEffect 高力度，不扣血只弹射
