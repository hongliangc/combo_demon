# 陷阱开发指南 (trap-guide.md)

## 1. 陷阱系统概述

陷阱位于 `Scenes/Levels/Components/Traps/`，属于 Business 层。
所有陷阱继承自 `BaseTrap`，遵循统一的激活/伤害/冷却循环。

## 2. 陷阱生命周期

```
IDLE → [触发条件] → WARNING → [delay] → ACTIVE → [duration] → COOLDOWN → [cooldown] → IDLE
```

| 阶段 | 行为 | 视觉 |
|------|------|------|
| IDLE | 等待触发 | 静态外观 |
| WARNING | 预警，不造成伤害 | 闪烁/颜色变化 |
| ACTIVE | 造成伤害 | 完整动画/特效 |
| COOLDOWN | 冷却，不响应 | 淡出/暗淡 |

## 3. 新陷阱开发步骤

### Step 1: 创建脚本

```gdscript
extends BaseTrap
class_name SpikeTrap

## 地刺陷阱 - 踩到后延迟弹出地刺

@export var spike_height: float = 32.0

func _trigger() -> void:
    _start_warning()

func _activate() -> void:
    $AnimationPlayer.play("spike_up")
    _apply_damage_in_area()

func _deactivate() -> void:
    $AnimationPlayer.play("spike_down")

func _apply_damage_in_area() -> void:
    var damage = _create_damage()
    for body in $DamageArea.get_overlapping_bodies():
        var hurt_box = body.get_node_or_null("HurtBoxComponent")
        if hurt_box:
            hurt_box.take_damage(damage, global_position)
```

### Step 2: 创建场景

```
SpikeTrap (Node2D) [script: SpikeTrap.gd]
├── Sprite2D                    # 陷阱外观
├── AnimationPlayer             # 激活/冷却动画
├── DetectionArea (Area2D)      # 触发检测区域
│   └── CollisionShape2D
├── DamageArea (Area2D)         # 伤害判定区域
│   └── CollisionShape2D
└── WarningEffect (Node2D)      # 预警特效（可选）
```

### Step 3: 配置物理层

| 区域 | Layer | Mask | 说明 |
|------|-------|------|------|
| DetectionArea | 7 (Object) | 2 (Player) | 检测玩家进入 |
| DamageArea | 5 (Enemy Projectile) | 2 (Player) | 作为伤害源 |

若陷阱也伤害敌人：DamageArea Mask 加上 4 (Enemy)

### Step 4: 连接信号

```gdscript
func _ready() -> void:
    $DetectionArea.body_entered.connect(_on_body_entered)
    $DetectionArea.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
    if current_state == TrapState.IDLE:
        _trigger()

func _on_body_exited(_body: Node2D) -> void:
    pass  # 某些陷阱需要在离开时重置
```

## 4. 常见陷阱类型模板

### 4.1 持续伤害区域（毒沼/火焰地面）

```gdscript
extends BaseTrap
class_name DamageZoneTrap

@export var tick_interval: float = 0.5

var _tick_timer: float = 0.0
var _bodies_in_zone: Array[Node2D] = []

func _physics_process(delta: float) -> void:
    if _bodies_in_zone.is_empty():
        return
    _tick_timer += delta
    if _tick_timer >= tick_interval:
        _tick_timer = 0.0
        _apply_tick_damage()

func _apply_tick_damage() -> void:
    var damage = _create_damage()
    for body in _bodies_in_zone:
        if is_instance_valid(body):
            var hurt_box = body.get_node_or_null("HurtBoxComponent")
            if hurt_box:
                hurt_box.take_damage(damage, global_position)
```

### 4.2 弹射陷阱（弹簧/风柱）

```gdscript
extends BaseTrap
class_name LaunchTrap

@export var launch_force: float = 600.0
@export var launch_direction: Vector2 = Vector2.UP

func _activate() -> void:
    for body in $DamageArea.get_overlapping_bodies():
        if body is CharacterBody2D:
            body.velocity = launch_direction.normalized() * launch_force
```

### 4.3 定时触发陷阱（锯齿/火柱）

```gdscript
extends BaseTrap
class_name TimedTrap

@export var auto_cycle: bool = true

func _ready() -> void:
    super._ready()
    if auto_cycle:
        _start_cycle()

func _start_cycle() -> void:
    while true:
        await get_tree().create_timer(cooldown_time).timeout
        _activate()
        await get_tree().create_timer(active_duration).timeout
        _deactivate()
```

## 5. 伤害配置

```gdscript
func _create_damage() -> Damage:
    if damage_resource:
        return damage_resource.duplicate()
    var dmg = Damage.new()
    dmg.amount = damage_amount
    return dmg
```

添加攻击效果：
```gdscript
@export var knockback_force: float = 200.0

func _create_damage() -> Damage:
    var dmg = super._create_damage()
    if knockback_force > 0.0:
        var kb = KnockBackEffect.new()
        kb.knockback_force = knockback_force
        dmg.effects.append(kb)
    return dmg
```

## 6. 调试日志

```gdscript
func _trigger() -> void:
    DebugConfig.debug("[%s] 陷阱触发, state=%s" % [name, TrapState.keys()[current_state]], "", "combat")

func _activate() -> void:
    DebugConfig.debug("[%s] 陷阱激活, damage=%.1f" % [name, damage_amount], "", "combat")
```
