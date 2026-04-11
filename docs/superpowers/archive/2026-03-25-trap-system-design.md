# Trap System Design Spec

## Overview

为 Combo Demon 设计一套可复用的机关组件库 + 演示关卡。12 种被动环境机关，难度从 ★☆☆ 到 ★★★ 渐进，充分复用现有 Damage/AttackEffect 系统。机关不可交互，纯被动危险，玩家只需躲避通过。

## Architecture

### 方案：统一基类 + 配置资源

与项目现有模式一致（EnemyBase/BossBase 继承模式，BossPhaseConfig 资源配置模式）。

### BaseTrap 基类

```
BaseTrap (Node2D)
├── damage: Damage           # 复用现有 Damage Resource（含 AttackEffect 数组）
├── is_active: bool          # 是否激活
├── activation_delay: float  # 激活前延迟
├── cooldown: float          # 两次伤害之间的冷却时间
├── DamageZone (Area2D)      # collision mask = Player (layer 2)
└── AnimatedSprite2D / Sprite2D
```

**伤害流程**（复用现有系统）：

```
DamageZone.body_entered(player)
  → 检查 cooldown / is_active
  → player.get_node("HurtBoxComponent").take_damage(damage, position)
  → 现有 AttackEffect 系统自动生效（击退/击飞/眩晕等）
```

### TrapConfig Resource

```gdscript
class_name TrapConfig extends Resource

@export var damage_amount: float = 10.0
@export var effects: Array[AttackEffect] = []
@export var cooldown: float = 1.0
@export var activation_delay: float = 0.0
```

### File Structure

```
Scenes/Levels/Components/Traps/
├── BaseTrap.gd
├── BaseTrap.tscn
├── TrapConfig.gd
├── SpikeTrap/
│   ├── SpikeTrap.gd
│   └── SpikeTrap.tscn
├── FlameJet/
│   ├── FlameJet.gd
│   └── FlameJet.tscn
├── FloatingPlatform/
│   ├── FloatingPlatform.gd
│   └── FloatingPlatform.tscn
├── SpinBlade/
│   ├── SpinBlade.gd
│   └── SpinBlade.tscn
├── FallingRock/
│   ├── FallingRock.gd
│   └── FallingRock.tscn
├── DartTrap/
│   ├── DartTrap.gd
│   └── DartTrap.tscn
├── ConveyorBelt/
│   ├── ConveyorBelt.gd
│   └── ConveyorBelt.tscn
├── CrumblingPlatform/
│   ├── CrumblingPlatform.gd
│   └── CrumblingPlatform.tscn
├── LaserFence/
│   ├── LaserFence.gd
│   └── LaserFence.tscn
├── SwingHammer/
│   ├── SwingHammer.gd
│   └── SwingHammer.tscn
├── LaunchPad/
│   ├── LaunchPad.gd
│   └── LaunchPad.tscn
├── SawRail/
│   ├── SawRail.gd
│   └── SawRail.tscn
└── DemoLevel/
    ├── TrapDemoLevel.gd
    └── TrapDemoLevel.tscn
```

## 12 Trap Designs

### 1. SpikeTrap 地刺陷阱

- **难度**: ★☆☆
- **效果**: 伤害 + KnockBackEffect
- **行为**: 周期性从地面伸出尖刺，有节奏的安全窗口
- **运动**: 垂直伸缩（Tween），可配置伸出/缩回时间和停留时间
- **参数**: `extend_time: 0.3`, `retract_time: 0.3`, `stay_time: 1.5`, `safe_time: 2.0`

### 2. FlameJet 火焰喷射

- **难度**: ★☆☆
- **效果**: 持续伤害 + KnockBackEffect
- **行为**: 墙壁/地面喷出火焰柱，周期性开关，火焰有预警粒子
- **运动**: 无位移，纯区域开关。可配置喷射方向（上/下/左/右）
- **参数**: `fire_duration: 2.0`, `cooldown_duration: 3.0`, `direction: Vector2.UP`, `warn_time: 0.5`

### 3. FloatingPlatform 浮动平台

- **难度**: ★☆☆
- **效果**: 无伤害，纯移动挑战
- **行为**: 上下或左右循环移动的平台，玩家跳上去随之移动
- **运动**: Tween 驱动，可配置路径点、速度、停留时间
- **参数**: `move_to: Vector2`, `move_speed: 50.0`, `wait_time: 1.0`
- **注意**: 继承 AnimatableBody2D 而非 BaseTrap（无伤害），需要 sync_to_physics 使玩家跟随

### 4. SpinBlade 旋转刀刃

- **难度**: ★★☆
- **效果**: 伤害 + KnockUpEffect
- **行为**: 围绕中心点旋转的带刺转盘，玩家计算旋转间隙通过
- **运动**: 绕轴匀速旋转（_process 中 rotation += speed * delta）
- **参数**: `rotation_speed: 2.0` (rad/s), `blade_count: 2`, `radius: 64.0`

### 5. FallingRock 落石陷阱

- **难度**: ★★☆
- **效果**: 伤害 + StunEffect
- **行为**: 玩家经过触发区时从天花板掉落石头，有阴影预警
- **运动**: 触发式垂直下落（apply gravity），落地后消失并重置
- **参数**: `fall_speed: 400.0`, `warning_time: 0.5`, `reset_time: 3.0`
- **实现**: 检测区（Area2D trigger）+ 石头实体（分离），触发后石头开始下落

### 6. DartTrap 箭矢陷阱

- **难度**: ★★☆
- **效果**: 伤害 + KnockBackEffect
- **行为**: 墙壁中周期性射出飞行物
- **运动**: 直线飞行，可配置射速、间隔、方向
- **参数**: `fire_interval: 2.0`, `projectile_speed: 300.0`, `direction: Vector2.LEFT`
- **注意**: 可复用 BossProjectile 的飞行和碰撞逻辑，或创建轻量 TrapProjectile

### 7. ConveyorBelt 传送带

- **难度**: ★★☆
- **效果**: ForceStunEffect 变体（强制位移，不完全锁定）
- **行为**: 站上去被推向一个方向，玩家需逆向移动或快速跳过
- **运动**: 无视觉位移，对区域内玩家持续施加力
- **参数**: `push_direction: Vector2.RIGHT`, `push_force: 80.0`
- **实现**: 不继承 BaseTrap，自定义 Area2D + _physics_process 中对玩家施加速度偏移

### 8. CrumblingPlatform 消失平台

- **难度**: ★★★
- **效果**: 无伤害，坠落危险
- **行为**: 踩上后抖动 → 延迟碎裂消失 → 一段时间后重生
- **运动**: 静态 → Tween shake → 隐藏（碰撞禁用）→ 定时重生
- **参数**: `shake_time: 0.8`, `crumble_delay: 0.3`, `respawn_time: 4.0`
- **实现**: StaticBody2D / AnimatableBody2D，通过碰撞层开关控制消失/出现

### 9. LaserFence 激光栅栏

- **难度**: ★★★
- **效果**: 高伤害 + StunEffect
- **行为**: 两点之间能量光束，周期性开关，水平或垂直放置
- **运动**: 无位移，RayCast2D 检测 + Line2D 视觉表现，开关有闪烁预警
- **参数**: `on_duration: 2.0`, `off_duration: 2.5`, `warn_time: 0.8`, `end_point: Vector2`

### 10. SwingHammer 锤摆

- **难度**: ★★★
- **效果**: 高伤害 + KnockUpEffect
- **行为**: 从天花板悬挂大锤，来回摆动
- **运动**: 钟摆式旋转（sin 函数驱动 rotation）
- **参数**: `swing_angle: 60.0` (degrees), `swing_period: 3.0` (seconds)
- **实现**: 锚点 + 锤臂（Sprite2D），rotation = max_angle * sin(time * frequency)

### 11. LaunchPad 弹射器

- **难度**: ★★☆
- **效果**: 强制 KnockUpEffect（高力度）
- **行为**: 踩上去将玩家弹射到高处，既是机关也是通路
- **运动**: 静态触发，对玩家施加向上力
- **参数**: `launch_force: 600.0`, `launch_direction: Vector2.UP`
- **实现**: 继承 BaseTrap，使用高力度 KnockUpEffect，damage_amount 可设为 0

### 12. SawRail 锯齿轨道

- **难度**: ★★★
- **效果**: 高伤害 + KnockBackEffect
- **行为**: 沿预设轨道移动的锯齿，轨道可直线/曲线/环形
- **运动**: PathFollow2D 驱动
- **参数**: `move_speed: 100.0`, `loop: true`, `ping_pong: false`
- **实现**: Path2D（关卡中手绘路径）+ PathFollow2D + DamageZone 跟随

## AttackEffect 映射表

| AttackEffect       | 使用的机关                              |
|--------------------|-----------------------------------------|
| KnockBackEffect    | 地刺、火焰、箭矢、锯齿轨道             |
| KnockUpEffect      | 旋转刀刃、锤摆、弹射器                  |
| StunEffect         | 落石、激光栅栏                           |
| ForceStunEffect    | 传送带（变体：仅推力，不锁定）           |
| 无效果（纯移动）   | 浮动平台、消失平台                       |

## Demo Level Layout

横向卷轴，约 4000×600px（4 屏宽度），分为 4 个区域：

### 区域 1：入门（★☆☆）

- 地刺 ×3：慢节奏，间距大，学习 timing
- 浮动平台 ×2：上下移动，速度慢，学习跟随跳跃
- 火焰喷射 ×1：长间隔，预警明显，学习等待安全窗口

### 区域 2：进阶（★★☆）

- 旋转刀刃 ×2：不同转速和半径，穿越旋转间隙
- 箭矢 + 浮动平台：在移动平台上躲箭，第一次机关组合
- 传送带 + 地刺：被推向地刺方向，逆行 + 躲避双重挑战

### 区域 3：高阶（★★★）

- 消失平台连跳 ×5：必须快速连续跳跃
- 落石 + 激光栅栏：上下双重威胁
- 锤摆走廊 ×3：不同相位，精准站位等待

### 区域 4：终极（★★★）

- 锯齿轨道迷宫：多条交叉轨道，观察找安全路径
- 弹射器 + 旋转刀刃：弹射穿过刀刃间隙，timing + 空中判断
- 全机关混合终点：所有类型随机组合，到达终点 = 通关

### 关卡基础设施

- **重生点**: 每个区域入口设置重生点（复用 KillZone 逻辑反向使用）
- **地形**: 复用现有 TileMapLayer，简单平台地形
- **相机**: 复用 FollowCamera，水平跟随，限制垂直范围
- **玩家**: 复用 PlayerBase，生成于左端起点

## Special Implementation Notes

### 非 BaseTrap 继承的机关

以下机关因功能特殊，不继承 BaseTrap：

- **FloatingPlatform**: 继承 AnimatableBody2D（需要物理平台特性，sync_to_physics）
- **CrumblingPlatform**: 继承 AnimatableBody2D（需要碰撞体开关）
- **ConveyorBelt**: 自定义 Area2D（持续力而非瞬时伤害）
- **SawRail**: 基于 Path2D + PathFollow2D 结构

其余 8 种继承 BaseTrap。

### 物理层使用

```
DamageZone (Area2D):
  collision_layer = 0        # 不占任何层
  collision_mask = 2         # 仅检测 Player

MovingPlatform (AnimatableBody2D):
  collision_layer = 1        # World 层（玩家可站立）
  collision_mask = 0         # 不检测其他物体

TrapProjectile (Area2D):     # DartTrap 使用
  collision_layer = 5        # Enemy Projectile 层
  collision_mask = 2         # 检测 Player
```

### 视觉占位

演示场景使用简单几何图形（ColorRect / Polygon2D）作为占位视觉，后续可替换为正式美术资源。每种机关用不同颜色区分：

- 红色系：伤害类（地刺、火焰、激光）
- 蓝色系：移动类（浮动平台、传送带）
- 黄色系：击飞类（旋转刀刃、锤摆、弹射器）
- 灰色系：物理类（落石、消失平台、锯齿）
