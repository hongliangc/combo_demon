# Combo Demon - MVP第一阶段详细设计文档

> **文档类型**: 详细设计与实现规范
> **创建日期**: 2026-03-07
> **阶段**: 第一阶段 - 内容补充与体验优化
> **预计工期**: 4-6周
> **目标**: 发布可玩的MVP版本

---

## 📋 阶段目标

### 核心目标

**让游戏可以完整游玩并发布MVP版本**

**关键成果（KR）**:
1. ✅ 3个关卡内容完整且有趣
2. ✅ 2个可玩角色，各具特色
3. ✅ 完整技能系统（6+技能）
4. ✅ 音效体验完善
5. ✅ UI/UX优化完成

**发布标准**:
- 游戏可从头到尾完整通关
- 核心玩法有趣且流畅
- 无严重Bug阻碍游玩
- 基础音效和UI完善

---

## 🎯 任务模块详细设计

## 模块1: 关卡内容扩充 ⭐⭐⭐⭐⭐

**优先级**: P0（最高）
**预计工时**: 9天
**负责系统**: 关卡系统、敌人系统、收集物系统

---

### 1.1 Level 1: 冒险关卡 (Adventure)

**当前状态**: 75%完成
**目标状态**: 95%完成
**工时**: 3天

#### 设计目标

**关卡定位**: 新手引导关卡
- 敌人密度：低到中等
- 难度曲线：简单 → 中等
- 探索度：开放地图，鼓励探索
- 目标：收集5个宝箱 + 击败所有敌人

#### 地图布局设计

```
Level 1 地图分区（3个区域）

┌─────────────────────────────────────┐
│  区域1: 入口区域（新手友好）          │
│  ├─ PlayerSpawn                      │
│  ├─ 2只ForestSnail（教学敌人）       │
│  ├─ 1个宝箱（明显位置）              │
│  └─ 教程提示                         │
├─────────────────────────────────────┤
│  区域2: 中心战斗区（主要挑战）        │
│  ├─ 3只ForestBoar（地面冲刺）        │
│  ├─ 2只ForestBee（飞行俯冲）         │
│  ├─ 1只Dinosaur（小Boss）            │
│  ├─ 2个宝箱（战斗后奖励）            │
│  └─ 20个金币散落                     │
└─────────────────────────────────────┘
│  区域3: 传送门前区域（最终考验）      │
│  ├─ 4只混合敌人（高难度组合）        │
│  ├─ 1个隐藏宝箱（需探索）            │
│  ├─ 10个金币                         │
│  └─ Portal（传送到Level 2）          │
└─────────────────────────────────────┘
```

#### 敌人配置详细设计

**区域1: 入口区域（教学）**
```gdscript
# 2只ForestSnail（蜗牛）
位置1: Vector2(300, 400)
├─ HP: 30 (低血量，易击杀)
├─ 行为: WanderState（缓慢漫步）
├─ 攻击: 近战，低伤害(5)
└─ 用途: 教学玩家基础攻击

位置2: Vector2(500, 450)
├─ HP: 30
├─ 行为: IdleState → WanderState
└─ 用途: 教学移动和追踪
```

**区域2: 中心战斗区（主要挑战）**
```gdscript
# 3只ForestBoar（野猪）
位置1: Vector2(800, 400)
├─ HP: 50
├─ 行为: PatrolState（巡逻路径）
├─ 攻击: 冲刺攻击，中伤害(10)
└─ 巡逻路径: [Vector2(800, 400), Vector2(1000, 400)]

位置2: Vector2(900, 300)
├─ HP: 50
├─ 行为: ChaseState（主动追击）
└─ 检测范围: 150像素

位置3: Vector2(1100, 500)
├─ HP: 50
├─ 行为: WanderState
└─ 触发条件: 玩家接近100像素

# 2只ForestBee（蜜蜂）
位置1: Vector2(850, 200)  # 空中位置
├─ HP: 40
├─ 行为: FlyPatrolState（飞行巡逻）
├─ 攻击: 俯冲攻击，中伤害(8)
└─ 飞行路径: 圆形，半径100

位置2: Vector2(1000, 250)
├─ HP: 40
├─ 行为: IdleState（悬停）
└─ 触发: 玩家进入攻击范围

# 1只Dinosaur（小Boss）
位置: Vector2(1200, 400)
├─ HP: 100
├─ 行为: IdleState → ChaseState → AttackState
├─ 攻击: 重击，高伤害(15)
├─ 检测范围: 200像素
└─ 掉落: 保证掉落1个金币堆（5金币）
```

**区域3: 传送门前区域（最终考验）**
```gdscript
# 4只混合敌人（高难度组合）
敌人1: ForestBoar
├─ 位置: Vector2(1500, 350)
├─ HP: 60（提升20%）
└─ 行为: 主动追击

敌人2: ForestBee
├─ 位置: Vector2(1550, 200)
├─ HP: 50（提升25%）
└─ 行为: 飞行俯冲

敌人3: ForestSnail
├─ 位置: Vector2(1600, 450)
├─ HP: 40（提升33%）
└─ 行为: 隐藏 → 突袭

敌人4: Dinosaur
├─ 位置: Vector2(1650, 400)
├─ HP: 120（提升20%）
└─ 行为: 守卫Portal
```

#### 收集物配置

**宝箱布置（5个）**
```gdscript
# 宝箱1: 新手奖励（区域1）
位置: Vector2(400, 380)
├─ 可见性: 明显
├─ 奖励: 10金币
└─ 提示: "打开宝箱获得金币！"

# 宝箱2: 战斗奖励1（区域2）
位置: Vector2(1000, 350)
├─ 可见性: 中等（需清理敌人）
├─ 奖励: 15金币
└─ 解锁条件: 击败区域2的3只ForestBoar

# 宝箱3: 战斗奖励2（区域2）
位置: Vector2(1150, 550)
├─ 可见性: 中等
├─ 奖励: 20金币 + 小概率装备（未来）
└─ 解锁条件: 击败Dinosaur

# 宝箱4: 隐藏宝箱（区域3）
位置: Vector2(1700, 300)  # 需要跳跃或探索
├─ 可见性: 隐藏（地图角落）
├─ 奖励: 30金币
└─ 提示: 无（奖励探索）

# 宝箱5: 终点奖励（区域3）
位置: Vector2(1800, 400)  # Portal旁边
├─ 可见性: 明显
├─ 奖励: 25金币
└─ 提示: "恭喜通过Level 1！"
```

**金币散落（30个）**
```gdscript
区域1: 5个金币
├─ 路径指引（引导玩家前进）
└─ 位置: 连接入口到区域2的路径上

区域2: 20个金币
├─ 战斗区域散落
├─ 鼓励探索地图边缘
└─ 部分在敌人巡逻路径上（风险收益）

区域3: 5个金币
└─ Portal前的最后收集
```

#### 环境优化

**视差背景**
```
背景层次（3层）
├─ 远景层: 山脉（移动速度0.2x）
├─ 中景层: 森林（移动速度0.5x）
└─ 前景层: 草地装饰（移动速度1.0x）
```

**环境音效触发器**
```gdscript
# 触发器1: 入口环境音
位置: Vector2(200, 400)
├─ 音效: wind_ambient.ogg
├─ 音量: 0.3
└─ 循环: true

# 触发器2: 战斗区域音乐
位置: Vector2(900, 400)
├─ 触发条件: 玩家进入区域2
├─ 音乐: level1_combat_bgm.ogg
└─ 淡入时间: 1.0秒

# 触发器3: Portal环境音
位置: Vector2(1750, 400)
├─ 音效: portal_hum.ogg
└─ 循环: true
```

#### 实现任务清单

```
Level 1 实现任务
□ 地图优化
  □ 调整地形布局（3个区域明确分隔）
  □ 添加视差背景（3层）
  □ 放置环境装饰（树木、石头、草丛）
  □ 测试可达性（所有区域可达）

□ 敌人配置
  □ 放置8个敌人到指定位置
  □ 配置每个敌人的行为参数
  □ 设置巡逻路径（ForestBoar）
  □ 测试敌人AI行为
  □ 调整敌人难度平衡

□ 收集物配置
  □ 放置5个宝箱到指定位置
  □ 配置宝箱奖励
  □ 散落30个金币
  □ 测试收集反馈

□ 环境音效
  □ 添加3个音效触发器
  □ 配置背景音乐切换
  □ 测试音效播放

□ 测试关卡
  □ 完整通关测试（5次）
  □ 难度曲线测试
  □ 收集物可达性测试
  □ 性能测试（保持60 FPS）
```

---

### 1.2 Level 2: 迷宫关卡 (Maze)

**当前状态**: 60%完成
**目标状态**: 90%完成
**工时**: 4天

#### 设计目标

**关卡定位**: 探索解谜关卡
- 敌人密度：低（强调探索）
- 难度曲线：中等
- 探索度：迷宫设计，需要思考
- 目标：收集5把钥匙 + 开启所有门

#### 迷宫地图设计

```
Level 2 迷宫布局（9个房间）

┌────┬────┬────┐
│ R1 │ R2 │ R3 │  R1: 入口房间
│    │ 🔑 │    │  R2: 钥匙房间1
├────┼────┼────┤  R3: 宝箱房间
│ R4 │ R5 │ R6 │  R4: 钥匙房间2
│ 🔑 │ 🚪 │ 🔑 │  R5: 中心枢纽（需钥匙）
├────┼────┼────┤  R6: 钥匙房间3
│ R7 │ R8 │ R9 │  R7: 敌人房间
│    │ 🔑 │ 🚪 │  R8: 钥匙房间4
└────┴────┴────┘  R9: 出口（需钥匙）

路径设计（3条）:
路径A: R1 → R2 → R5 → R9（最短，但需2把钥匙）
路径B: R1 → R4 → R5 → R6 → R9（中等，需3把钥匙）
路径C: R1 → R4 → R7 → R8 → R5 → R9（最长，可收集所有钥匙）
```

#### 房间详细设计

**R1: 入口房间**
```gdscript
房间尺寸: 300x300
├─ PlayerSpawn: Vector2(150, 250)
├─ 出口: 连接R2（东）、R4（南）
├─ 内容:
│   ├─ 教程提示: "寻找5把钥匙开启门"
│   └─ 5个金币（引导路径）
└─ 敌人: 无（安全区）
```

**R2: 钥匙房间1**
```gdscript
房间尺寸: 300x300
├─ 入口: R1（西）、R3（东）、R5（南）
├─ 内容:
│   ├─ 钥匙1: Vector2(150, 150)（明显位置）
│   └─ 5个金币
└─ 敌人: 1只ForestSnail（守卫）
    ├─ HP: 40
    └─ 位置: Vector2(150, 200)
```

**R3: 宝箱房间**
```gdscript
房间尺寸: 300x300
├─ 入口: R2（西）、R6（南）
├─ 内容:
│   ├─ 宝箱1: Vector2(150, 150)
│   │   └─ 奖励: 20金币
│   └─ 10个金币散落
└─ 敌人: 无（奖励房间）
```

**R4: 钥匙房间2**
```gdscript
房间尺寸: 300x300
├─ 入口: R1（北）、R5（东）、R7（南）
├─ 内容:
│   ├─ 钥匙2: Vector2(100, 150)（角落）
│   └─ 5个金币
└─ 敌人: 1只ForestBoar（巡逻）
    ├─ HP: 60
    ├─ 位置: 巡逻路径
    └─ 路径: [Vector2(100, 100), Vector2(250, 250)]
```

**R5: 中心枢纽（核心房间）**
```gdscript
房间尺寸: 400x400
├─ 入口: R2（北）、R4（西）、R6（东）、R8（南）
├─ 门禁系统:
│   ├─ 北门: 需要钥匙1（通往R2）
│   ├─ 西门: 无限制（通往R4）
│   ├─ 东门: 需要钥匙3（通往R6）
│   └─ 南门: 需要钥匙4（通往R8）
├─ 内容:
│   ├─ 中心雕像（装饰）
│   └─ 10个金币（十字路口）
└─ 敌人: 2只ForestBee（空中巡逻）
    ├─ HP: 50
    └─ 飞行路径: 环绕中心
```

**R6: 钥匙房间3**
```gdscript
房间尺寸: 300x300
├─ 入口: R3（北）、R5（西）、R9（南）
├─ 内容:
│   ├─ 钥匙3: Vector2(200, 150)（高台，需跳跃）
│   └─ 宝箱2: Vector2(100, 250)
│       └─ 奖励: 15金币
└─ 敌人: 1只Dinosaur（守卫钥匙）
    ├─ HP: 100
    └─ 位置: Vector2(200, 200)
```

**R7: 敌人房间（挑战）**
```gdscript
房间尺寸: 300x300
├─ 入口: R4（北）、R8（东）
├─ 内容:
│   ├─ 宝箱3: Vector2(150, 150)
│   │   └─ 奖励: 25金币（战斗后）
│   └─ 5个金币
└─ 敌人: 3只混合敌人（高难度）
    ├─ 1只ForestBoar（HP: 70）
    ├─ 1只ForestBee（HP: 60）
    └─ 1只ForestSnail（HP: 50）
```

**R8: 钥匙房间4**
```gdscript
房间尺寸: 300x300
├─ 入口: R5（北）、R7（西）
├─ 内容:
│   ├─ 钥匙4: Vector2(150, 100)（隐藏在墙后）
│   └─ 5个金币
└─ 敌人: 1只ForestSnail（隐藏）
    ├─ HP: 40
    └─ 行为: HideState → 玩家接近时突袭
```

**R9: 出口房间（终点）**
```gdscript
房间尺寸: 300x300
├─ 入口: R6（北）
├─ 门禁: 需要钥匙5（主门）
├─ 内容:
│   ├─ 钥匙5: Vector2(150, 250)（需通过挑战获得）
│   ├─ Portal: Vector2(150, 100)（通往Level 3）
│   └─ 宝箱4: Vector2(200, 200)
│       └─ 奖励: 30金币
└─ 敌人: 1只Dinosaur（最终守卫）
    ├─ HP: 120
    ├─ 位置: Vector2(150, 150)
    └─ 掉落: 钥匙5（击败后获得）
```

#### 门禁系统设计

**MazeDoor组件参数**
```gdscript
class MazeDoor extends Node2D

# 门的配置
@export var door_id: String = "door_1"
@export var required_key_id: String = "key_1"
@export var is_locked: bool = true

# 视觉反馈
@export var locked_sprite: Texture
@export var unlocked_sprite: Texture

# 音效
@export var unlock_sound: AudioStream
@export var locked_sound: AudioStream  # 尝试开启时

# 信号
signal door_opened(door_id: String)
signal door_locked_attempted(door_id: String)

# 交互逻辑
func try_open() -> bool:
    if not is_locked:
        open_door()
        return true

    # 检查玩家是否有钥匙
    if LevelManager.has_key(required_key_id):
        unlock_and_open()
        LevelManager.use_key(required_key_id)
        return true
    else:
        show_locked_feedback()
        return false
```

#### 实现任务清单

```
Level 2 实现任务
□ 迷宫地图设计
  □ 创建9个房间场景
  □ 连接房间（门和通道）
  □ 设置房间尺寸和边界
  □ 测试迷宫可达性

□ 门禁系统
  □ 完善MazeDoor.gd逻辑
  □ 放置5个门到指定位置
  □ 配置每个门的required_key_id
  □ 添加门的视觉反馈
  □ 测试门禁交互

□ 钥匙配置
  □ 放置5把钥匙到指定房间
  □ 配置钥匙拾取逻辑
  □ 添加钥匙拾取音效
  □ 测试钥匙收集

□ 敌人配置
  □ 放置6个敌人到指定房间
  □ 配置敌人巡逻路径
  □ 调整敌人难度
  □ 测试敌人行为

□ 收集物配置
  □ 放置4个宝箱
  □ 散落50个金币
  □ 配置奖励

□ 测试迷宫
  □ 测试3条路径通关
  □ 测试门禁系统
  □ 测试迷宫探索体验
  □ 性能测试
```

---

### 1.3 Level 3: Boss战 (Boss Fight)

**当前状态**: 80%完成
**目标状态**: 95%完成
**工时**: 2天

#### 设计目标

**关卡定位**: 高潮Boss战
- 敌人：单一Boss（多阶段）
- 难度曲线：高难度
- 场地：空旷竞技场
- 目标：击败Boss通关游戏

#### 场景优化设计

**竞技场布局**
```
Boss竞技场（圆形/方形）
尺寸: 800x600

┌─────────────────────────────┐
│                             │
│    ┌─────────────┐          │
│    │             │          │
│    │   Boss区域  │          │
│    │             │          │
│    └─────────────┘          │
│                             │
│  ○ PlayerSpawn              │
└─────────────────────────────┘

元素:
├─ 中心平台（Boss活动区）
├─ 外围战斗区（玩家活动区）
├─ 环境危险区（可选）
│   ├─ 熔岩池（边缘）
│   └─ 尖刺陷阱（地面）
└─ 装饰柱子（遮挡物）
```

#### Boss阶段演出优化

**Phase 1 → Phase 2 转换（HP 66%）**
```gdscript
# 阶段转换演出
func transition_to_phase_2():
    # 1. 停止战斗
    boss.invincible = true
    boss.play_animation("roar")

    # 2. 镜头特写
    CameraManager.zoom_to_target(boss, Vector2(1.5, 1.5), 1.0)
    await get_tree().create_timer(1.0).timeout

    # 3. 屏幕震动
    CameraManager.shake(0.5, 10.0)

    # 4. 粒子特效
    var phase_effect = preload("res://Effects/PhaseTransition.tscn").instantiate()
    boss.add_child(phase_effect)

    # 5. 音效
    SoundManager.play_sfx("boss_roar")

    # 6. UI提示
    UIManager.show_toast("Boss进入第二阶段！", 2.0)

    # 7. 恢复战斗
    await get_tree().create_timer(2.0).timeout
    boss.invincible = false
    boss.current_phase = 2
    CameraManager.reset_zoom(1.0)
```

**Phase 2 → Phase 3 转换（HP 33%）**
```gdscript
# 更强烈的演出
func transition_to_phase_3():
    boss.invincible = true
    boss.play_animation("enrage")

    # 时间缩放（慢动作）
    TimeManager.set_time_scale(0.3, 2.0)

    # 镜头特写 + 震动
    CameraManager.zoom_to_target(boss, Vector2(2.0, 2.0), 1.5)
    CameraManager.shake(1.0, 20.0)

    # 红色闪光
    var flash = ColorRect.new()
    flash.color = Color(1, 0, 0, 0.5)
    flash.size = get_viewport_rect().size
    add_child(flash)

    var tween = create_tween()
    tween.tween_property(flash, "modulate:a", 0.0, 1.0)
    tween.tween_callback(flash.queue_free)

    # 音效
    SoundManager.play_sfx("boss_enrage")

    # UI提示
    UIManager.show_toast("Boss狂暴了！小心！", 3.0)

    await get_tree().create_timer(3.0).timeout
    boss.invincible = false
    boss.current_phase = 3
    CameraManager.reset_zoom(1.5)
    TimeManager.reset_time_scale()
```

#### 音效配置

**Boss音效清单**
```gdscript
Boss音效资源
├─ boss_roar.wav - 阶段转换吼叫
├─ boss_enrage.wav - 狂暴音效
├─ boss_footstep.wav - 脚步声（重）
├─ boss_attack_melee.wav - 近战攻击
├─ boss_attack_projectile.wav - 投射物发射
├─ boss_attack_laser.wav - 激光蓄力
├─ boss_attack_aoe.wav - 范围攻击
├─ boss_hit.wav - Boss受伤
├─ boss_death.wav - Boss死亡
└─ boss_bgm.ogg - Boss战背景音乐
```

**音效触发配置**
```gdscript
# 在Boss.gd中添加
func _ready():
    super._ready()

    # 播放Boss战BGM
    SoundManager.play_bgm("boss_bgm")

    # 连接音效信号
    health_component.damaged.connect(_on_boss_hit)
    health_component.died.connect(_on_boss_death)

func _on_boss_hit(_damage: Damage):
    SoundManager.play_sfx("boss_hit")

func _on_boss_death():
    SoundManager.play_sfx("boss_death")
    SoundManager.stop_bgm()
```

#### 环境危险区（可选）

**熔岩池设计**
```gdscript
# LavalPool.gd
extends Area2D

@export var damage_per_second: float = 10.0
@export var tick_interval: float = 0.5

var players_in_lava: Array[Node] = []

func _ready():
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node):
    if body.is_in_group("player"):
        players_in_lava.append(body)
        start_damage_timer()

func _on_body_exited(body: Node):
    if body in players_in_lava:
        players_in_lava.erase(body)

func start_damage_timer():
    while players_in_lava.size() > 0:
        await get_tree().create_timer(tick_interval).timeout
        apply_lava_damage()

func apply_lava_damage():
    for player in players_in_lava:
        var damage = Damage.new()
        damage.amount = damage_per_second * tick_interval
        player.health_component.take_damage(damage)
```

#### 实现任务清单

```
Level 3 实现任务
□ 场景美化
  □ 优化竞技场地形
  □ 添加背景装饰
  □ 设置光照效果
  □ 放置遮挡物（柱子）

□ 阶段转换演出
  □ 实现Phase 1→2转换动画
  □ 实现Phase 2→3转换动画
  □ 测试演出流畅性
  □ 调整演出时长

□ Boss音效配置
  □ 采购/录制10个Boss音效
  □ 在Boss.gd中集成音效触发
  □ 配置Boss战BGM
  □ 测试音效同步

□ 环境危险区（可选）
  □ 创建熔岩池场景
  □ 放置2-3个熔岩池
  □ 测试伤害逻辑
  □ 添加视觉警告

□ 测试Boss战
  □ 完整Boss战测试（10次）
  □ 测试3个阶段转换
  □ 测试音效播放
  □ 难度平衡调整
```

---

## 模块2: 第二玩家角色实现 ⭐⭐⭐⭐⭐

**优先级**: P0（最高）
**预计工时**: 5天
**负责系统**: 角色系统、技能系统、UI系统

---

### 2.1 Princess角色设计文档

#### 角色定位

**Princess（公主）- 远程法师**

**核心特点**:
- 远程攻击（150像素）
- 低生命值，高伤害
- 灵活移动
- 魔法主题技能

**属性设计**:
```gdscript
# Princess.tres 配置
class Princess extends PlayerBase

# 基础属性
max_health: 80  # -20% vs Hahashin(100)
move_speed: 90   # -10% vs Hahashin(100)
attack_range: 150  # 远程

# 攻击属性
attack_damage: 12  # +20% vs Hahashin(10)
attack_speed: 0.8  # 攻击间隔（秒）

# 防御属性
defense: 5  # 低防御
```

**角色对比**:
| 属性 | Hahashin | Princess | 差异 |
|------|----------|----------|------|
| HP | 100 | 80 | -20% |
| 移动速度 | 100 | 90 | -10% |
| 攻击范围 | 近战(50) | 远程(150) | +200% |
| 攻击伤害 | 10 | 12 | +20% |
| 定位 | 近战战士 | 远程法师 | - |

#### 技能设计

**普通攻击：火球术（FireBall）**
```gdscript
# 技能参数
名称: "火球术"
类型: 投射物
冷却: 0.8秒（攻击间隔）
伤害: 12
射程: 150像素
弹速: 300像素/秒
特效: 火焰粒子

# 实现
class FireBall extends BaseBullet:
    speed: float = 300.0
    lifetime: float = 0.5  # 0.5秒后消失
    damage_amount: float = 12.0

    # 命中特效
    on_hit_effect: preload("res://Effects/FireballExplosion.tscn")
```

**技能1 (X键)：冰冻射线（FrostRay）**
```gdscript
# 技能参数
名称: "冰冻射线"
类型: 持续射线
冷却: 5秒
持续时间: 2秒
伤害: 5/秒（持续伤害）
射程: 200像素
宽度: 20像素
特效: 减速50%（持续2秒）

# 实现
class FrostRay extends Node2D:
    # 射线检测
    func cast_ray():
        var space_state = get_world_2d().direct_space_state
        var query = PhysicsRayQueryParameters2D.create(
            player.global_position,
            player.global_position + direction * 200
        )
        query.collision_mask = 4  # Enemy层

        var result = space_state.intersect_ray(query)
        if result:
            apply_frost_damage(result.collider)
            apply_slow_effect(result.collider)

    func apply_slow_effect(enemy: Node):
        enemy.move_speed *= 0.5  # 减速50%
        await get_tree().create_timer(2.0).timeout
        enemy.move_speed /= 0.5  # 恢复
```

**技能2 (W键)：传送闪现（Blink）**
```gdscript
# 技能参数
名称: "传送闪现"
类型: 位移技能
冷却: 8秒
距离: 150像素
无敌帧: 0.3秒
消耗: 无

# 实现
class PrincessBlinkState extends BaseState:
    priority = Priority.REACTION

    func enter():
        super.enter()

        # 1. 获取传送目标位置
        var direction = player.get_input_direction()
        var target_pos = player.global_position + direction * 150

        # 2. 检查目标位置是否可达
        target_pos = clamp_to_walkable_area(target_pos)

        # 3. 播放传送特效（起点）
        spawn_blink_effect(player.global_position)

        # 4. 设置无敌
        player.invincible = true
        player.visible = false

        # 5. 瞬间移动
        player.global_position = target_pos

        # 6. 播放传送特效（终点）
        await get_tree().create_timer(0.3).timeout
        spawn_blink_effect(player.global_position)

        # 7. 恢复可见
        player.visible = true
        player.invincible = false

        # 8. 返回地面状态
        state_machine.transition_to("ground")
```

**技能3 (E键)：魔法护盾（MagicShield）**
```gdscript
# 技能参数
名称: "魔法护盾"
类型: 防御增益
冷却: 10秒
持续时间: 3秒
效果: 吸收50点伤害
视觉: 蓝色护盾光环

# 实现
class MagicShield extends Node:
    var shield_hp: float = 50.0
    var duration: float = 3.0

    func _ready():
        # 连接受伤信号
        player.health_component.damaged.connect(_on_damaged)

        # 显示护盾特效
        var shield_sprite = preload("res://Effects/MagicShield.tscn").instantiate()
        player.add_child(shield_sprite)

        # 定时器
        await get_tree().create_timer(duration).timeout
        deactivate_shield()

    func _on_damaged(damage: Damage):
        if shield_hp > 0:
            # 护盾吸收伤害
            var absorbed = min(damage.amount, shield_hp)
            shield_hp -= absorbed
            damage.amount -= absorbed

            # 播放护盾受击音效
            SoundManager.play_sfx("shield_hit")

            if shield_hp <= 0:
                deactivate_shield()
```

**特殊技能 (V键)：时间静止（TimeStop）**
```gdscript
# 技能参数
名称: "时间静止"
类型: 范围控制 + 群体伤害
冷却: 20秒
范围: 圆形，半径250像素
持续时间: 3秒
伤害: 每个敌人30点（时间恢复时）
特效: 时间静止，敌人定格

# 实现
class PrincessTimeStopState extends BaseState:
    priority = Priority.REACTION

    var affected_enemies: Array[Node] = []

    func enter():
        super.enter()

        # 1. 播放施法动画
        play_animation("timestop_cast")

        # 2. 检测范围内敌人
        affected_enemies = detect_enemies_in_circle(250.0)

        # 3. 时间静止特效
        apply_timestop_visual()

        # 4. 冻结敌人
        for enemy in affected_enemies:
            freeze_enemy(enemy)

        # 5. 播放音效
        SoundManager.play_sfx("timestop_activate")

        # 6. 等待持续时间
        await get_tree().create_timer(3.0).timeout

        # 7. 时间恢复 + 爆炸伤害
        for enemy in affected_enemies:
            unfreeze_enemy(enemy)
            apply_explosion_damage(enemy)

        # 8. 恢复状态
        state_machine.transition_to("ground")

    func freeze_enemy(enemy: Node):
        enemy.set_physics_process(false)
        enemy.set_process(false)
        # 视觉效果：灰度
        enemy.modulate = Color(0.5, 0.5, 0.5, 1.0)

    func unfreeze_enemy(enemy: Node):
        enemy.set_physics_process(true)
        enemy.set_process(true)
        enemy.modulate = Color(1, 1, 1, 1)

    func apply_explosion_damage(enemy: Node):
        var damage = Damage.new()
        damage.amount = 30.0
        enemy.health_component.take_damage(damage)

        # 爆炸特效
        var explosion = preload("res://Effects/TimeStopExplosion.tscn").instantiate()
        enemy.add_child(explosion)
```

#### 动画配置

**所需动画（使用Princess资源包）**
```
Princess动画列表
├─ idle - 待机
├─ walk - 行走
├─ run - 奔跑
├─ attack - 普通攻击（施法动作）
├─ skill_x - 冰冻射线施法
├─ skill_w - 传送闪现消失
├─ skill_e - 魔法护盾展开
├─ skill_v - 时间静止施法
├─ hit - 受伤
├─ death - 死亡
└─ jump - 跳跃（如果有）
```

**AnimationTree配置**（复用PlayerBase结构）
```
BlendTree
├─ locomotion (BlendSpace2D)
│   ├─ (0, 0) idle
│   ├─ (±1, 0.5) walk
│   └─ (±1, 1.0) run
├─ attack_oneshot
│   ├─ attack（火球术）
│   ├─ skill_x（冰冻射线）
│   ├─ skill_e（魔法护盾）
│   └─ skill_v（时间静止）
└─ control_sm
    ├─ hit
    └─ death
```

#### 实现任务清单

```
Princess角色实现
□ 角色基础
  □ 创建Princess.gd（继承PlayerBase）
  □ 创建Princess.tscn（继承PlayerBase.tscn）
  □ 配置Princess.tres角色数据
  □ 配置精灵和碰撞体

□ 动画系统
  □ 导入Princess动画资源
  □ 创建AnimationPlayer
  □ 配置AnimationTree（BlendTree）
  □ 测试动画播放

□ 普通攻击
  □ 创建FireBall.gd + FireBall.tscn
  □ 实现火球发射逻辑
  □ 配置火球伤害和碰撞
  □ 添加火球特效
  □ 测试攻击手感

□ 技能1 - 冰冻射线
  □ 创建PrincessFrostRayState.gd
  □ 实现射线检测逻辑
  □ 实现减速效果
  □ 创建射线视觉特效
  □ 测试技能

□ 技能2 - 传送闪现
  □ 创建PrincessBlinkState.gd
  □ 实现传送逻辑
  □ 创建传送特效
  □ 实现无敌帧
  □ 测试技能

□ 技能3 - 魔法护盾
  □ 创建MagicShield.gd组件
  □ 实现伤害吸收逻辑
  □ 创建护盾视觉特效
  □ 测试技能

□ 特殊技能V - 时间静止
  □ 创建PrincessTimeStopState.gd
  □ 实现范围检测
  □ 实现敌人冻结
  □ 实现爆炸伤害
  □ 创建特效
  □ 测试技能

□ 平衡性调整
  □ 调整技能伤害数值
  □ 调整冷却时间
  □ 测试与Hahashin的平衡
  □ 玩家测试反馈

□ UI集成
  □ 在角色选择界面添加Princess
  □ 配置角色卡片
  □ 测试角色选择
```

---

## 模块3: 技能系统完善 ⭐⭐⭐⭐

**优先级**: P0（最高）
**预计工时**: 6天
**负责系统**: 技能系统、状态机系统、UI系统

---

### 3.1 Hahashin技能补完

**当前技能状态**:
- ✅ 左键：普通斩击
- ❌ X键：风刃斩（待实现）
- ❌ W键：旋风斩（待实现）
- ❌ E键：影分身（待实现）
- ✅ V键：疾风连击（已完成）
- ✅ R键：翻滚闪避（已完成）

---

### 3.2 X技能：风刃斩（WindBlade）

**工时**: 2天

**技能设计**:
```gdscript
# 技能参数
名称: "风刃斩"
类型: 投射物
冷却: 3秒
伤害: 15 (1.5倍普通攻击)
射程: 300像素
弹速: 400像素/秒
特效: 击退效果
消耗: 无

# 视觉表现
- 蓝色斩击波投射物
- 旋转动画
- 命中时爆炸特效
- whoosh音效
```

**实现设计**:

**1. 创建投射物**
```gdscript
# WindBlade.gd
class_name WindBlade
extends BaseBullet

@export var speed: float = 400.0
@export var lifetime: float = 0.75  # 300像素 / 400速度
@export var damage_amount: float = 15.0
@export var knockback_force: float = 200.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: HitBoxComponent = $HitBoxComponent

func _ready():
    super._ready()

    # 配置伤害
    var damage = Damage.new()
    damage.amount = damage_amount

    # 添加击退效果
    var knockback = KnockBackEffect.new()
    knockback.force = knockback_force
    damage.effects.append(knockback)

    hitbox.damage = damage
    hitbox.destroy_owner_on_hit = true

    # 播放旋转动画
    sprite.play("spin")

    # 定时销毁
    get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta):
    position += transform.x * speed * delta
```

**2. 创建状态类**
```gdscript
# PlayerWindBladeState.gd
class_name PlayerWindBladeState
extends BaseState

@export var cooldown: float = 3.0
var last_cast_time: float = -999.0

func can_cast() -> bool:
    return Time.get_ticks_msec() / 1000.0 - last_cast_time >= cooldown

func enter():
    super.enter()

    if not can_cast():
        # 冷却中，返回地面状态
        state_machine.transition_to("ground")
        return

    # 播放施法动画
    fire_attack("skill_x")

    # 等待动画播放到发射帧
    await get_tree().create_timer(0.2).timeout

    # 发射风刃
    spawn_wind_blade()

    # 记录施法时间
    last_cast_time = Time.get_ticks_msec() / 1000.0

    # 等待动画结束
    await get_tree().create_timer(0.3).timeout

    # 返回地面状态
    state_machine.transition_to("ground")

func spawn_wind_blade():
    var wind_blade = preload("res://Scenes/Weapons/WindBlade/WindBlade.tscn").instantiate()

    # 设置位置和方向
    wind_blade.global_position = player.global_position
    wind_blade.rotation = player.get_facing_direction_angle()

    # 添加到场景
    player.get_parent().add_child(wind_blade)

    # 播放音效
    SoundManager.play_sfx("skill_x_cast")
```

**3. 集成到输入系统**
```gdscript
# 在PlayerGroundState.gd中添加
func physics_process(delta):
    super.physics_process(delta)

    # 检测X键输入
    if Input.is_action_just_pressed("atk_1"):
        var wind_blade_state = state_machine.get_state("wind_blade")
        if wind_blade_state.can_cast():
            state_machine.transition_to("wind_blade")
```

**实现任务**:
```
X技能 - 风刃斩
□ 创建投射物
  □ WindBlade.gd + WindBlade.tscn
  □ 配置精灵和动画（旋转）
  □ 配置HitBoxComponent
  □ 配置击退效果
  □ 测试投射物飞行

□ 创建状态
  □ PlayerWindBladeState.gd
  □ 实现冷却系统
  □ 实现发射逻辑
  □ 集成到状态机

□ 动画和特效
  □ 施法动画（Hahashin挥剑）
  □ 风刃旋转动画
  □ 命中爆炸特效
  □ 音效（施法+命中）

□ 测试和平衡
  □ 测试技能释放
  □ 测试冷却系统
  □ 调整伤害数值
  □ 调整弹速和射程
```

---

### 3.3 W技能：旋风斩（Whirlwind）

**工时**: 2天

**技能设计**:
```gdscript
# 技能参数
名称: "旋风斩"
类型: 近战范围攻击
冷却: 5秒
持续时间: 0.5秒
伤害: 每次8点（共5次 = 40点总伤害）
攻击频率: 0.1秒/次（5次）
范围: 圆形，半径100像素
特效: 玩家原地旋转，禁用移动
消耗: 无

# 视觉表现
- 玩家360度旋转
- 蓝色旋风粒子环绕
- 连续攻击音效
- 旋风特效
```

**实现设计**:

**1. 创建攻击区域**
```gdscript
# WhirlwindAttack.gd
class_name WhirlwindAttack
extends Area2D

@export var damage_per_hit: float = 8.0
@export var hit_interval: float = 0.1
@export var total_hits: int = 5

var hit_count: int = 0
var enemies_in_range: Array[Node] = []

func _ready():
    # 配置碰撞
    collision_layer = 0
    collision_mask = 4  # Enemy层

    # 连接信号
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

    # 开始攻击循环
    start_attack_loop()

func start_attack_loop():
    while hit_count < total_hits:
        await get_tree().create_timer(hit_interval).timeout
        perform_hit()
        hit_count += 1

    # 结束后销毁
    queue_free()

func perform_hit():
    for enemy in enemies_in_range:
        if is_instance_valid(enemy):
            apply_damage(enemy)

    # 播放音效
    SoundManager.play_sfx("whirlwind_hit")

func apply_damage(enemy: Node):
    var damage = Damage.new()
    damage.amount = damage_per_hit

    if enemy.has_node("HealthComponent"):
        enemy.get_node("HealthComponent").take_damage(damage)

func _on_body_entered(body: Node):
    if body.is_in_group("enemy"):
        enemies_in_range.append(body)

func _on_body_exited(body: Node):
    if body in enemies_in_range:
        enemies_in_range.erase(body)
```

**2. 创建状态类**
```gdscript
# PlayerWhirlwindState.gd
class_name PlayerWhirlwindState
extends BaseState

@export var cooldown: float = 5.0
@export var duration: float = 0.5

var last_cast_time: float = -999.0
var whirlwind_attack: WhirlwindAttack

func can_cast() -> bool:
    return Time.get_ticks_msec() / 1000.0 - last_cast_time >= cooldown

func enter():
    super.enter()

    if not can_cast():
        state_machine.transition_to("ground")
        return

    # 禁用移动
    player.movement_component.can_move = false

    # 播放旋转动画
    fire_attack("skill_w")

    # 创建攻击范围
    spawn_whirlwind_attack()

    # 创建视觉特效
    spawn_whirlwind_effect()

    # 记录施法时间
    last_cast_time = Time.get_ticks_msec() / 1000.0

    # 等待持续时间
    await get_tree().create_timer(duration).timeout

    # 恢复移动
    player.movement_component.can_move = true

    # 返回地面状态
    state_machine.transition_to("ground")

func spawn_whirlwind_attack():
    whirlwind_attack = preload("res://Scenes/Weapons/Whirlwind/WhirlwindAttack.tscn").instantiate()
    whirlwind_attack.global_position = player.global_position
    player.add_child(whirlwind_attack)

func spawn_whirlwind_effect():
    var effect = preload("res://Effects/WhirlwindEffect.tscn").instantiate()
    player.add_child(effect)

    # 音效
    SoundManager.play_sfx("whirlwind_start")
```

**3. 创建旋风特效**
```gdscript
# WhirlwindEffect.gd
extends CPUParticles2D

func _ready():
    # 配置粒子
    amount = 50
    lifetime = 0.5
    emitting = true
    one_shot = true

    # 圆形发射
    emission_shape = EMISSION_SHAPE_RING
    emission_ring_radius = 100.0
    emission_ring_inner_radius = 80.0

    # 旋转运动
    direction = Vector2(0, -1)
    spread = 180
    initial_velocity_min = 100
    initial_velocity_max = 150

    # 颜色
    color = Color(0.5, 0.8, 1.0, 0.8)

    # 自动销毁
    await get_tree().create_timer(lifetime).timeout
    queue_free()
```

**实现任务**:
```
W技能 - 旋风斩
□ 创建攻击区域
  □ WhirlwindAttack.gd + WhirlwindAttack.tscn
  □ 配置Area2D和碰撞形状
  □ 实现多段攻击逻辑
  □ 测试攻击范围

□ 创建状态
  □ PlayerWhirlwindState.gd
  □ 实现冷却系统
  □ 实现移动禁用
  □ 集成到状态机

□ 特效和动画
  □ 旋转动画（Hahashin旋转）
  □ WhirlwindEffect粒子特效
  □ 音效（开始+连击）

□ 测试和平衡
  □ 测试技能释放
  □ 测试多段伤害
  □ 调整伤害和频率
  □ 测试与敌人互动
```

---

### 3.4 E技能：影分身（ShadowClone）

**工时**: 2天

**技能设计**:
```gdscript
# 技能参数
名称: "影分身"
类型: 召唤技能
冷却: 8秒
分身数量: 2个
分身生命: 10秒或受到3次伤害
分身伤害: 50%玩家伤害
分身行为: 自动攻击最近敌人
特效: 半透明分身 + 烟雾生成

# 视觉表现
- 玩家施法动作
- 烟雾爆发
- 2个半透明分身出现
- 分身跟随玩家移动（保持距离）
```

**实现设计**:

**1. 创建分身NPC**
```gdscript
# ShadowClone.gd
class_name ShadowClone
extends CharacterBody2D

@export var master: Node  # 主人（玩家）
@export var lifetime: float = 10.0
@export var max_hits: int = 3
@export var damage_multiplier: float = 0.5

var current_hits: int = 0
var target_enemy: Node = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var detection_area: Area2D = $DetectionArea

func _ready():
    # 设置半透明
    modulate = Color(1, 1, 1, 0.5)

    # 连接信号
    health_component.damaged.connect(_on_damaged)
    detection_area.body_entered.connect(_on_enemy_detected)

    # 定时消失
    get_tree().create_timer(lifetime).timeout.connect(disappear)

    # 播放待机动画
    sprite.play("idle")

func _physics_process(delta):
    if target_enemy and is_instance_valid(target_enemy):
        attack_enemy()
    else:
        follow_master()

func follow_master():
    if not master:
        return

    # 保持与主人的距离
    var distance_to_master = global_position.distance_to(master.global_position)

    if distance_to_master > 100:
        # 移动向主人
        var direction = global_position.direction_to(master.global_position)
        velocity = direction * 80
        move_and_slide()

        sprite.play("run")
    else:
        sprite.play("idle")

func attack_enemy():
    # 移动向敌人
    var direction = global_position.direction_to(target_enemy.global_position)
    velocity = direction * 100
    move_and_slide()

    # 足够近时攻击
    if global_position.distance_to(target_enemy.global_position) < 50:
        perform_attack()

func perform_attack():
    sprite.play("attack")

    # 计算伤害
    var damage = Damage.new()
    damage.amount = master.attack_damage * damage_multiplier

    # 应用伤害
    if target_enemy.has_node("HealthComponent"):
        target_enemy.get_node("HealthComponent").take_damage(damage)

    # 冷却
    await get_tree().create_timer(1.0).timeout

func _on_damaged(_damage: Damage):
    current_hits += 1

    if current_hits >= max_hits:
        disappear()

func _on_enemy_detected(body: Node):
    if body.is_in_group("enemy") and not target_enemy:
        target_enemy = body

func disappear():
    # 播放消失特效
    var poof = preload("res://Effects/ShadowClonePoof.tscn").instantiate()
    get_parent().add_child(poof)
    poof.global_position = global_position

    queue_free()
```

**2. 创建状态类**
```gdscript
# PlayerShadowCloneState.gd
class_name PlayerShadowCloneState
extends BaseState

@export var cooldown: float = 8.0
@export var clone_count: int = 2

var last_cast_time: float = -999.0

func can_cast() -> bool:
    return Time.get_ticks_msec() / 1000.0 - last_cast_time >= cooldown

func enter():
    super.enter()

    if not can_cast():
        state_machine.transition_to("ground")
        return

    # 播放施法动画
    fire_attack("skill_e")

    # 等待施法
    await get_tree().create_timer(0.3).timeout

    # 生成分身
    spawn_shadow_clones()

    # 记录施法时间
    last_cast_time = Time.get_ticks_msec() / 1000.0

    # 返回地面状态
    state_machine.transition_to("ground")

func spawn_shadow_clones():
    for i in range(clone_count):
        # 创建分身
        var clone = preload("res://Scenes/Characters/Player/ShadowClone/ShadowClone.tscn").instantiate()
        clone.master = player

        # 设置位置（玩家周围）
        var angle = (i / float(clone_count)) * TAU
        var offset = Vector2(cos(angle), sin(angle)) * 50
        clone.global_position = player.global_position + offset

        # 添加到场景
        player.get_parent().add_child(clone)

        # 生成烟雾特效
        var smoke = preload("res://Effects/SmokeEffect.tscn").instantiate()
        clone.add_child(smoke)

    # 音效
    SoundManager.play_sfx("shadow_clone_summon")
```

**实现任务**:
```
E技能 - 影分身
□ 创建分身NPC
  □ ShadowClone.gd + ShadowClone.tscn
  □ 配置精灵（半透明）
  □ 实现跟随逻辑
  □ 实现攻击逻辑
  □ 实现生命周期

□ 创建状态
  □ PlayerShadowCloneState.gd
  □ 实现冷却系统
  □ 实现生成逻辑
  □ 集成到状态机

□ 特效和动画
  □ 施法动画
  □ 烟雾生成特效
  □ 分身消失特效
  □ 音效

□ 测试和平衡
  □ 测试分身AI
  □ 测试分身攻击
  □ 调整分身伤害
  □ 测试分身生命周期
```

---

### 3.5 技能冷却UI

**工时**: 1天（与技能实现并行）

**UI设计**:

```
技能冷却UI布局

HUD
├─ SkillBar (HBoxContainer)
│   ├─ SkillIcon_X
│   │   ├─ Icon (TextureRect) - 风刃斩图标
│   │   ├─ Cooldown (Label) - "2.5s"
│   │   ├─ Overlay (ColorRect) - 冷却遮罩
│   │   └─ Keybind (Label) - "X"
│   ├─ SkillIcon_W
│   │   └─ [同上]
│   ├─ SkillIcon_E
│   │   └─ [同上]
│   └─ SkillIcon_V
│       └─ [同上]
```

**实现设计**:

```gdscript
# SkillIcon.gd
class_name SkillIcon
extends Control

@export var skill_name: String = "skill_x"
@export var skill_icon: Texture
@export var keybind_text: String = "X"
@export var cooldown_duration: float = 3.0

@onready var icon: TextureRect = $Icon
@onready var cooldown_label: Label = $Cooldown
@onready var overlay: ColorRect = $Overlay
@onready var keybind_label: Label = $Keybind

var is_on_cooldown: bool = false
var cooldown_remaining: float = 0.0

func _ready():
    # 配置图标
    icon.texture = skill_icon
    keybind_label.text = keybind_text

    # 初始状态
    cooldown_label.visible = false
    overlay.visible = false

func _process(delta):
    if is_on_cooldown:
        cooldown_remaining -= delta

        if cooldown_remaining <= 0:
            end_cooldown()
        else:
            update_cooldown_display()

func start_cooldown():
    is_on_cooldown = true
    cooldown_remaining = cooldown_duration

    cooldown_label.visible = true
    overlay.visible = true
    overlay.color = Color(0, 0, 0, 0.6)

func end_cooldown():
    is_on_cooldown = false
    cooldown_label.visible = false
    overlay.visible = false

    # 播放可用闪光
    flash_available()

func update_cooldown_display():
    cooldown_label.text = "%.1f" % cooldown_remaining

    # 更新遮罩透明度
    var progress = cooldown_remaining / cooldown_duration
    overlay.color.a = 0.6 * progress

func flash_available():
    var tween = create_tween()
    tween.tween_property(icon, "modulate", Color(1.5, 1.5, 1.5, 1), 0.2)
    tween.tween_property(icon, "modulate", Color(1, 1, 1, 1), 0.2)
```

**实现任务**:
```
技能冷却UI
□ 创建SkillIcon组件
  □ SkillIcon.gd + SkillIcon.tscn
  □ 配置UI布局
  □ 实现冷却逻辑
  □ 实现视觉反馈

□ 创建SkillBar
  □ SkillBar.tscn（HBoxContainer）
  □ 添加4个SkillIcon实例
  □ 配置图标和快捷键

□ 集成到游戏
  □ 在LevelHUD中添加SkillBar
  □ 连接技能系统信号
  □ 测试冷却显示

□ 视觉优化
  □ 添加图标资源
  □ 添加闪光动画
  □ 添加音效
```

---

## 模块4: 音效系统完善 ⭐⭐⭐

**优先级**: P1（强烈推荐）
**预计工时**: 3天
**负责系统**: 音效系统、UI系统

---

### 4.1 音效资源清单

**音效需求总计**: 约30个音效文件

#### 战斗音效（15个）

```
攻击音效 (5个)
├─ slash_1.wav - 轻攻击（普通斩击）
├─ slash_2.wav - 重攻击（蓄力攻击）
├─ slash_3.wav - 暴击音效
├─ fireball_shoot.wav - 火球发射（Princess）
└─ magic_cast.wav - 魔法施法通用

受伤音效 (3个)
├─ player_hurt_1.wav - 玩家受伤1
├─ player_hurt_2.wav - 玩家受伤2（轻伤）
└─ enemy_hurt.wav - 敌人受伤

技能音效 (5个)
├─ skill_x_cast.wav - X技能释放（whoosh）
├─ whirlwind_start.wav - W技能开始（旋风）
├─ whirlwind_hit.wav - W技能命中（连击）
├─ shadow_clone_summon.wav - E技能召唤（烟雾）
└─ timestop_activate.wav - V技能时间静止

特效音效 (2个)
├─ knockback.wav - 击退音效
└─ explosion.wav - 爆炸音效（火球命中等）
```

#### 环境音效（10个）

```
背景音乐 (4个)
├─ menu_bgm.ogg - 主菜单音乐（循环）
├─ level1_bgm.ogg - Level 1背景音乐
├─ level2_bgm.ogg - Level 2背景音乐
└─ boss_bgm.ogg - Boss战音乐

环境音效 (6个)
├─ footstep_1.wav - 脚步声1
├─ footstep_2.wav - 脚步声2
├─ wind_ambient.ogg - 风声环境音（循环）
├─ portal_open.wav - 传送门打开
├─ portal_hum.ogg - 传送门嗡鸣（循环）
└─ chest_open.wav - 宝箱打开
```

#### UI音效（5个）

```
UI交互音效
├─ button_click.wav - 按钮点击
├─ button_hover.wav - 按钮悬停
├─ panel_open.wav - 面板打开
├─ success.wav - 成功提示（收集物）
└─ error.wav - 错误提示（门锁定）
```

### 4.2 音效采购策略

**推荐资源库**:
1. **Freesound.org** （免费，需署名）
2. **OpenGameArt.org** （免费，CC0许可）
3. **itch.io Audio Assets** （免费+付费）
4. **Kenney.nl** （免费，CC0许可）
5. **Sonniss.com** （年度免费包）

**采购流程**:
```
1. 搜索关键词
   例: "sword slash", "fireball", "footstep"

2. 试听筛选
   - 音质清晰
   - 风格统一
   - 长度适中（<2秒）

3. 下载和整理
   - 统一格式：WAV（音效）/ OGG（音乐）
   - 统一命名：snake_case
   - 统一采样率：44.1kHz

4. 导入Godot
   - 放置到 Assets/Sound/
   - 配置导入设置
```

### 4.3 SoundManager扩展

**更新SoundManager.gd**:

```gdscript
# SoundManager.gd
extends Node

# 音频播放器池
var sfx_players: Array[AudioStreamPlayer] = []
var bgm_player: AudioStreamPlayer = null

# 音量设置
var master_volume: float = 1.0
var bgm_volume: float = 0.7
var sfx_volume: float = 1.0

# 音效资源字典
var sfx_library: Dictionary = {}
var bgm_library: Dictionary = {}

func _ready():
    # 创建BGM播放器
    bgm_player = AudioStreamPlayer.new()
    bgm_player.bus = "Music"
    add_child(bgm_player)

    # 创建SFX播放器池（10个）
    for i in range(10):
        var player = AudioStreamPlayer.new()
        player.bus = "SFX"
        add_child(player)
        sfx_players.append(player)

    # 加载音效库
    load_sound_library()

func load_sound_library():
    # 战斗音效
    sfx_library["slash_1"] = preload("res://Assets/Sound/SFX/slash_1.wav")
    sfx_library["slash_2"] = preload("res://Assets/Sound/SFX/slash_2.wav")
    sfx_library["fireball_shoot"] = preload("res://Assets/Sound/SFX/fireball_shoot.wav")
    sfx_library["player_hurt"] = preload("res://Assets/Sound/SFX/player_hurt_1.wav")
    sfx_library["enemy_hurt"] = preload("res://Assets/Sound/SFX/enemy_hurt.wav")

    # 技能音效
    sfx_library["skill_x_cast"] = preload("res://Assets/Sound/SFX/skill_x_cast.wav")
    sfx_library["whirlwind_start"] = preload("res://Assets/Sound/SFX/whirlwind_start.wav")
    sfx_library["shadow_clone_summon"] = preload("res://Assets/Sound/SFX/shadow_clone_summon.wav")

    # UI音效
    sfx_library["button_click"] = preload("res://Assets/Sound/SFX/button_click.wav")
    sfx_library["success"] = preload("res://Assets/Sound/SFX/success.wav")

    # 背景音乐
    bgm_library["menu"] = preload("res://Assets/Sound/BGM/menu_bgm.ogg")
    bgm_library["level1"] = preload("res://Assets/Sound/BGM/level1_bgm.ogg")
    bgm_library["boss"] = preload("res://Assets/Sound/BGM/boss_bgm.ogg")

func play_sfx(sfx_name: String, volume_db: float = 0.0):
    if not sfx_library.has(sfx_name):
        push_error("SFX not found: " + sfx_name)
        return

    # 找到空闲播放器
    var player = get_available_sfx_player()
    if player:
        player.stream = sfx_library[sfx_name]
        player.volume_db = volume_db
        player.play()

func get_available_sfx_player() -> AudioStreamPlayer:
    for player in sfx_players:
        if not player.playing:
            return player

    # 如果没有空闲，返回第一个（覆盖）
    return sfx_players[0]

func play_bgm(bgm_name: String, fade_in: float = 1.0):
    if not bgm_library.has(bgm_name):
        push_error("BGM not found: " + bgm_name)
        return

    # 停止当前BGM
    if bgm_player.playing:
        stop_bgm(fade_in)
        await get_tree().create_timer(fade_in).timeout

    # 播放新BGM
    bgm_player.stream = bgm_library[bgm_name]
    bgm_player.volume_db = -80  # 从静音开始
    bgm_player.play()

    # 淡入
    var tween = create_tween()
    tween.tween_property(bgm_player, "volume_db", 0.0, fade_in)

func stop_bgm(fade_out: float = 1.0):
    if not bgm_player.playing:
        return

    # 淡出
    var tween = create_tween()
    tween.tween_property(bgm_player, "volume_db", -80, fade_out)
    tween.tween_callback(bgm_player.stop)

func set_master_volume(volume: float):
    master_volume = clamp(volume, 0.0, 1.0)
    AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))

func set_bgm_volume(volume: float):
    bgm_volume = clamp(volume, 0.0, 1.0)
    var bus_idx = AudioServer.get_bus_index("Music")
    AudioServer.set_bus_volume_db(bus_idx, linear_to_db(bgm_volume))

func set_sfx_volume(volume: float):
    sfx_volume = clamp(volume, 0.0, 1.0)
    var bus_idx = AudioServer.get_bus_index("SFX")
    AudioServer.set_bus_volume_db(bus_idx, linear_to_db(sfx_volume))
```

### 4.4 音效集成点

**在游戏中的触发点**:

```
角色系统
├─ PlayerBase.gd
│   └─ _on_damaged() → play_sfx("player_hurt")
├─ EnemyBase.gd
│   └─ _on_damaged() → play_sfx("enemy_hurt")
└─ 各状态类
    └─ 攻击状态 → play_sfx("slash_1")

技能系统
├─ PlayerWindBladeState → play_sfx("skill_x_cast")
├─ PlayerWhirlwindState → play_sfx("whirlwind_start")
└─ PlayerShadowCloneState → play_sfx("shadow_clone_summon")

UI系统
├─ Button._pressed() → play_sfx("button_click")
├─ Collectible.collect() → play_sfx("success")
└─ MazeDoor.try_open() → play_sfx("error")

关卡系统
├─ Level1._ready() → play_bgm("level1")
├─ Level3._ready() → play_bgm("boss")
└─ Portal.activate() → play_sfx("portal_open")
```

### 4.5 实现任务清单

```
音效系统完善
□ 音效资源采购
  □ 搜索和下载30个音效
  □ 格式转换（WAV/OGG）
  □ 导入到Godot项目
  □ 配置导入设置

□ SoundManager扩展
  □ 更新SoundManager.gd
  □ 创建音频总线（Master/Music/SFX）
  □ 实现音效播放池
  □ 实现BGM淡入淡出

□ 音效集成
  □ 在角色系统添加音效触发
  □ 在技能系统添加音效触发
  □ 在UI系统添加音效触发
  □ 在关卡系统添加音效触发

□ 测试音效
  □ 测试所有音效播放
  □ 测试音量控制
  □ 测试BGM切换
  □ 测试音效同步性
```

---

## 模块5: UI/UX优化 ⭐⭐⭐

**优先级**: P1（强烈推荐）
**预计工时**: 4天
**负责系统**: UI系统、输入系统

---

### 5.1 设置菜单 (Settings Menu)

**工时**: 1天

**功能需求**:
- 音频设置（主音量、BGM、SFX）
- 视频设置（全屏、分辨率、垂直同步）
- 游戏设置（难度、语言）
- 按键绑定（自定义按键）

**UI设计**:

```
SettingsMenu.tscn
├─ Panel (背景)
├─ Title (Label) - "设置"
├─ TabContainer
│   ├─ Audio (音频设置)
│   │   ├─ MasterVolumeSlider (HSlider)
│   │   ├─ BGMVolumeSlider (HSlider)
│   │   └─ SFXVolumeSlider (HSlider)
│   ├─ Video (视频设置)
│   │   ├─ FullscreenCheckbox (CheckBox)
│   │   ├─ ResolutionOption (OptionButton)
│   │   └─ VSyncCheckbox (CheckBox)
│   └─ Game (游戏设置)
│       ├─ DifficultyOption (OptionButton)
│       └─ LanguageOption (OptionButton)
├─ ApplyButton (Button)
├─ CancelButton (Button)
└─ CloseButton (Button)
```

**实现代码**:

```gdscript
# SettingsMenu.gd
extends Control

@onready var master_slider: HSlider = $TabContainer/Audio/MasterVolumeSlider
@onready var bgm_slider: HSlider = $TabContainer/Audio/BGMVolumeSlider
@onready var sfx_slider: HSlider = $TabContainer/Audio/SFXVolumeSlider

@onready var fullscreen_check: CheckBox = $TabContainer/Video/FullscreenCheckbox
@onready var resolution_option: OptionButton = $TabContainer/Video/ResolutionOption
@onready var vsync_check: CheckBox = $TabContainer/Video/VSyncCheckbox

@onready var difficulty_option: OptionButton = $TabContainer/Game/DifficultyOption

var settings: Dictionary = {}

func _ready():
    # 加载设置
    load_settings()

    # 连接信号
    master_slider.value_changed.connect(_on_master_volume_changed)
    bgm_slider.value_changed.connect(_on_bgm_volume_changed)
    sfx_slider.value_changed.connect(_on_sfx_volume_changed)

    fullscreen_check.toggled.connect(_on_fullscreen_toggled)
    resolution_option.item_selected.connect(_on_resolution_selected)
    vsync_check.toggled.connect(_on_vsync_toggled)

    $ApplyButton.pressed.connect(_on_apply_pressed)
    $CancelButton.pressed.connect(_on_cancel_pressed)
    $CloseButton.pressed.connect(hide)

func load_settings():
    # 从配置文件加载
    settings = ConfigManager.load_settings()

    # 应用到UI
    master_slider.value = settings.get("master_volume", 1.0)
    bgm_slider.value = settings.get("bgm_volume", 0.7)
    sfx_slider.value = settings.get("sfx_volume", 1.0)

    fullscreen_check.button_pressed = settings.get("fullscreen", false)
    resolution_option.selected = settings.get("resolution_index", 1)
    vsync_check.button_pressed = settings.get("vsync", true)

func _on_master_volume_changed(value: float):
    SoundManager.set_master_volume(value)

func _on_bgm_volume_changed(value: float):
    SoundManager.set_bgm_volume(value)

func _on_sfx_volume_changed(value: float):
    SoundManager.set_sfx_volume(value)
    # 播放测试音效
    SoundManager.play_sfx("button_click")

func _on_fullscreen_toggled(pressed: bool):
    if pressed:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
    else:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_resolution_selected(index: int):
    var resolutions = [
        Vector2i(1280, 720),
        Vector2i(1920, 1080),
        Vector2i(2560, 1440)
    ]
    DisplayServer.window_set_size(resolutions[index])

func _on_vsync_toggled(pressed: bool):
    if pressed:
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
    else:
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _on_apply_pressed():
    save_settings()
    UIManager.show_toast("设置已保存", 2.0)

func _on_cancel_pressed():
    load_settings()
    hide()

func save_settings():
    settings["master_volume"] = master_slider.value
    settings["bgm_volume"] = bgm_slider.value
    settings["sfx_volume"] = sfx_slider.value
    settings["fullscreen"] = fullscreen_check.button_pressed
    settings["resolution_index"] = resolution_option.selected
    settings["vsync"] = vsync_check.button_pressed

    ConfigManager.save_settings(settings)
```

---

### 5.2 暂停菜单 (Pause Menu)

**工时**: 0.5天

**功能需求**:
- ESC键暂停游戏
- 继续游戏
- 打开设置
- 返回主菜单
- 退出游戏

**UI设计**:

```
PauseMenu.tscn
├─ Overlay (ColorRect) - 半透明遮罩
├─ Panel (背景面板)
├─ Title (Label) - "暂停"
├─ ResumeButton (Button) - "继续游戏"
├─ SettingsButton (Button) - "设置"
├─ MainMenuButton (Button) - "返回主菜单"
└─ QuitButton (Button) - "退出游戏"
```

**实现代码**:

```gdscript
# PauseMenu.gd
extends Control

func _ready():
    # 初始隐藏
    visible = false

    # 连接信号
    $ResumeButton.pressed.connect(_on_resume_pressed)
    $SettingsButton.pressed.connect(_on_settings_pressed)
    $MainMenuButton.pressed.connect(_on_main_menu_pressed)
    $QuitButton.pressed.connect(_on_quit_pressed)

func _input(event):
    if event.is_action_pressed("ui_cancel"):  # ESC键
        toggle_pause()

func toggle_pause():
    if visible:
        resume_game()
    else:
        pause_game()

func pause_game():
    visible = true
    get_tree().paused = true

    # 播放音效
    SoundManager.play_sfx("panel_open")

func resume_game():
    visible = false
    get_tree().paused = false

    # 播放音效
    SoundManager.play_sfx("button_click")

func _on_resume_pressed():
    resume_game()

func _on_settings_pressed():
    # 打开设置菜单
    UIManager.open_panel("settings", UIManager.UILayer.POPUP, false)

func _on_main_menu_pressed():
    # 确认对话框
    var dialog = UIManager.show_confirm_dialog(
        "返回主菜单",
        "确定要返回主菜单吗？当前进度将丢失。"
    )

    var confirmed = await dialog.confirmed
    if confirmed:
        resume_game()
        get_tree().change_scene_to_file("res://Scenes/UI/Screens/MainMenu/MainMenu.tscn")

func _on_quit_pressed():
    # 确认对话框
    var dialog = UIManager.show_confirm_dialog(
        "退出游戏",
        "确定要退出游戏吗？"
    )

    var confirmed = await dialog.confirmed
    if confirmed:
        get_tree().quit()
```

---

### 5.3 教程系统 (Tutorial System)

**工时**: 1.5天

**功能需求**:
- 关键时刻显示教程提示
- 可跳过教程
- 记录已显示的教程

**教程设计**:

```
教程触发点
├─ Level 1 开始
│   ├─ "使用WASD移动"
│   ├─ "左键攻击敌人"
│   ├─ "按V键释放特殊技能"
│   └─ "收集5个宝箱"
├─ 首次遇到敌人
│   └─ "小心敌人！使用R键翻滚闪避"
├─ 首次获得宝箱
│   └─ "太好了！收集更多宝箱获得金币"
├─ Level 2 开始
│   └─ "寻找钥匙开启门"
└─ Boss战前
    └─ "前方有强敌！注意血量和Boss攻击"
```

**实现代码**:

```gdscript
# TutorialManager.gd (AutoLoad)
extends Node

var shown_tutorials: Array[String] = []
var tutorial_data: Dictionary = {
    "movement": {
        "title": "移动",
        "text": "使用WASD键或方向键移动角色",
        "icon": preload("res://Assets/UI/Icons/wasd.png")
    },
    "attack": {
        "title": "攻击",
        "text": "左键点击攻击敌人",
        "icon": preload("res://Assets/UI/Icons/mouse_left.png")
    },
    "special_attack": {
        "title": "特殊技能",
        "text": "按V键释放强力特殊攻击",
        "icon": preload("res://Assets/UI/Icons/v_key.png")
    },
    "dodge": {
        "title": "闪避",
        "text": "按R键翻滚闪避敌人攻击",
        "icon": preload("res://Assets/UI/Icons/r_key.png")
    }
}

func show_tutorial(tutorial_id: String):
    # 检查是否已显示
    if tutorial_id in shown_tutorials:
        return

    # 检查是否存在
    if not tutorial_data.has(tutorial_id):
        push_error("Tutorial not found: " + tutorial_id)
        return

    # 显示教程弹窗
    var popup = preload("res://Scenes/UI/Components/TutorialPopup.tscn").instantiate()
    popup.setup(tutorial_data[tutorial_id])
    UIManager.add_panel(popup, UIManager.UILayer.TOOLTIP)

    # 记录已显示
    shown_tutorials.append(tutorial_id)
    save_shown_tutorials()

func reset_tutorials():
    shown_tutorials.clear()
    save_shown_tutorials()

func save_shown_tutorials():
    var save_data = {
        "shown_tutorials": shown_tutorials
    }
    var file = FileAccess.open("user://tutorial_progress.json", FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(save_data))
        file.close()

func load_shown_tutorials():
    var file = FileAccess.open("user://tutorial_progress.json", FileAccess.READ)
    if file:
        var json = JSON.parse_string(file.get_as_text())
        if json and json.has("shown_tutorials"):
            shown_tutorials = json["shown_tutorials"]
        file.close()
```

**教程弹窗组件**:

```gdscript
# TutorialPopup.gd
extends Control

@onready var icon: TextureRect = $Panel/Icon
@onready var title_label: Label = $Panel/Title
@onready var text_label: Label = $Panel/Text
@onready var close_button: Button = $Panel/CloseButton
@onready var skip_button: Button = $Panel/SkipButton

var can_close: bool = false

func setup(tutorial: Dictionary):
    title_label.text = tutorial["title"]
    text_label.text = tutorial["text"]
    icon.texture = tutorial["icon"]

    # 连接信号
    close_button.pressed.connect(_on_close_pressed)
    skip_button.pressed.connect(_on_skip_pressed)

    # 3秒后可关闭
    await get_tree().create_timer(3.0).timeout
    can_close = true
    close_button.disabled = false

func _on_close_pressed():
    if can_close:
        queue_free()

func _on_skip_pressed():
    TutorialManager.reset_tutorials()
    queue_free()
```

**在关卡中触发教程**:

```gdscript
# Level1.gd
extends Node2D

func _ready():
    # 显示移动教程
    TutorialManager.show_tutorial("movement")

    # 3秒后显示攻击教程
    await get_tree().create_timer(3.0).timeout
    TutorialManager.show_tutorial("attack")

func _on_first_enemy_detected():
    TutorialManager.show_tutorial("dodge")

func _on_first_chest_collected():
    TutorialManager.show_tutorial("collect")
```

---

### 5.4 HUD优化

**工时**: 1天

**优化内容**:
1. 添加技能冷却显示（已在模块3设计）
2. 添加金币/宝箱计数器
3. 优化血条样式
4. 添加连击数显示

**HUD布局**:

```
LevelHUD
├─ TopLeft (VBoxContainer)
│   ├─ HealthBar (优化版)
│   ├─ ComboCounter (连击显示)
│   └─ LevelObjective (关卡目标)
├─ TopRight (VBoxContainer)
│   ├─ CoinCounter (金币)
│   └─ ChestCounter (宝箱)
├─ Bottom (HBoxContainer)
│   └─ SkillBar (技能冷却)
└─ Center (VBoxContainer)
    └─ BossHealthBar (Boss血条)
```

**优化血条**:

```gdscript
# HealthBar.gd (优化版)
extends ProgressBar

@export var show_numbers: bool = true
@export var gradient_colors: bool = true

@onready var number_label: Label = $NumberLabel

func _ready():
    # 配置渐变色
    if gradient_colors:
        setup_gradient()

func setup_gradient():
    # 绿 → 黄 → 红渐变
    var stylebox = get_theme_stylebox("fill")
    if stylebox is StyleBoxFlat:
        stylebox.bg_color = Color(0, 1, 0)  # 初始绿色

func update_health(current: float, maximum: float):
    max_value = maximum
    value = current

    # 更新数字显示
    if show_numbers and number_label:
        number_label.text = "%d / %d" % [current, maximum]

    # 更新颜色
    if gradient_colors:
        update_color(current / maximum)

    # 播放动画
    animate_change()

func update_color(percent: float):
    var stylebox = get_theme_stylebox("fill")
    if stylebox is StyleBoxFlat:
        if percent > 0.6:
            stylebox.bg_color = Color(0, 1, 0)  # 绿色
        elif percent > 0.3:
            stylebox.bg_color = Color(1, 1, 0)  # 黄色
        else:
            stylebox.bg_color = Color(1, 0, 0)  # 红色

func animate_change():
    # 闪烁动画
    var tween = create_tween()
    tween.tween_property(self, "modulate:a", 0.5, 0.1)
    tween.tween_property(self, "modulate:a", 1.0, 0.1)
```

**添加连击计数器**:

```gdscript
# ComboCounter.gd
extends Label

var combo_count: int = 0
var combo_timeout: float = 2.0
var last_hit_time: float = 0.0

func _ready():
    visible = false

    # 连接玩家攻击信号
    get_tree().get_first_node_in_group("player").hit_enemy.connect(_on_hit_enemy)

func _process(delta):
    if combo_count > 0:
        # 检查超时
        if Time.get_ticks_msec() / 1000.0 - last_hit_time > combo_timeout:
            reset_combo()

func _on_hit_enemy():
    combo_count += 1
    last_hit_time = Time.get_ticks_msec() / 1000.0

    # 更新显示
    update_display()

    # 播放音效
    if combo_count > 5:
        SoundManager.play_sfx("combo_high")

func update_display():
    text = "%d Combo!" % combo_count
    visible = true

    # 缩放动画
    var tween = create_tween()
    tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
    tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

func reset_combo():
    combo_count = 0
    visible = false
```

### 5.5 实现任务清单

```
UI/UX优化
□ 设置菜单
  □ 创建SettingsMenu.tscn
  □ 实现音频设置
  □ 实现视频设置
  □ 实现保存/加载配置
  □ 测试设置功能

□ 暂停菜单
  □ 创建PauseMenu.tscn
  □ 实现暂停逻辑
  □ 集成ESC键触发
  □ 测试暂停功能

□ 教程系统
  □ 创建TutorialManager.gd
  □ 创建TutorialPopup.tscn
  □ 配置教程数据
  □ 在关卡中集成触发
  □ 测试教程显示

□ HUD优化
  □ 优化HealthBar样式
  □ 创建ComboCounter
  □ 创建CoinCounter
  □ 创建ChestCounter
  □ 集成到LevelHUD
  □ 测试HUD显示
```

---

## 📊 总体实施计划

### 开发顺序建议

**Week 1-2: 关卡内容 + 音效**
```
Day 1-3: Level 1 内容扩充
Day 4-6: Level 2 迷宫设计
Day 7-8: Level 3 Boss优化
Day 9-10: 音效采购和集成
```

**Week 3-4: Princess角色 + UI**
```
Day 11-13: Princess基础实现
Day 14-15: Princess技能系统
Day 16-17: UI优化（设置、暂停）
Day 18: 教程系统
```

**Week 5-6: Hahashin技能 + 打磨**
```
Day 19-20: X技能 - 风刃斩
Day 21-22: W技能 - 旋风斩
Day 23-24: E技能 - 影分身
Day 25: 技能冷却UI
Day 26-27: HUD优化
Day 28-30: 全面测试和调优
```

### 测试检查清单

```
□ 功能测试
  □ 3个关卡可完整通关
  □ 2个角色可正常游玩
  □ 所有技能正常释放
  □ 音效正常播放
  □ UI交互正常

□ 性能测试
  □ 保持60 FPS
  □ 无明显卡顿
  □ 加载时间<3秒
  □ 内存占用<500MB

□ 平衡性测试
  □ 难度曲线合理
  □ 技能冷却合适
  □ 敌人配置合理
  □ 收集物奖励合理

□ 用户体验测试
  □ 教程清晰易懂
  □ UI反馈及时
  □ 音效增强体验
  □ 无严重Bug
```

---

## 📝 交付物清单

### 代码交付

```
新增脚本（预计40+个）
├─ Characters/
│   ├─ Princess.gd
│   └─ ShadowClone.gd
├─ States/
│   ├─ PlayerWindBladeState.gd
│   ├─ PlayerWhirlwindState.gd
│   ├─ PlayerShadowCloneState.gd
│   └─ Princess技能状态（4个）
├─ Weapons/
│   ├─ WindBlade.gd
│   ├─ WhirlwindAttack.gd
│   └─ FireBall.gd
├─ UI/
│   ├─ SettingsMenu.gd
│   ├─ PauseMenu.gd
│   ├─ TutorialPopup.gd
│   ├─ SkillIcon.gd
│   └─ ComboCounter.gd
└─ Managers/
    └─ TutorialManager.gd
```

### 场景交付

```
新增场景（预计30+个）
├─ Characters/
│   ├─ Princess.tscn
│   └─ ShadowClone.tscn
├─ Weapons/
│   ├─ WindBlade.tscn
│   ├─ WhirlwindAttack.tscn
│   └─ FireBall.tscn
├─ UI/
│   ├─ SettingsMenu.tscn
│   ├─ PauseMenu.tscn
│   ├─ TutorialPopup.tscn
│   ├─ SkillBar.tscn
│   └─ ComboCounter.tscn
└─ Effects/
    ├─ WhirlwindEffect.tscn
    ├─ ShadowClonePoof.tscn
    └─ 各种技能特效
```

### 资源交付

```
新增资源
├─ Audio/ (30个音效文件)
│   ├─ SFX/ (25个)
│   └─ BGM/ (5个)
├─ Data/
│   └─ Princess.tres
└─ Effects/
    └─ 各种粒子特效
```

### 文档交付

```
更新文档
├─ DevLog/planning/
│   └─ mvp_phase1_detailed_design_2026-03.md（本文档）
├─ DevLog/sessions/
│   └─ mvp_phase1_implementation_log_2026-03.md（实施日志）
└─ DevLog/INDEX.md（更新索引）
```

---

**文档维护者**: 产品经理 + 开发团队
**最后更新**: 2026-03-07
**文档版本**: v1.0
**预计Token**: ~8000
