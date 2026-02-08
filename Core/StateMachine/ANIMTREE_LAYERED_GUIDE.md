# AnimationTree BlendTree 配置指南

## 概述

使用 **AnimationNodeBlendTree** 作为根节点，结合 OneShot、Blend2、BlendSpace2D 实现：
1. **locomotion 永远播放** - 移动动画作为基础层
2. **攻击叠加** - 使用 OneShot 叠加攻击动画
3. **控制层切换** - 使用 Blend2 切换到 hit/stun/death

## 目标结构

```
AnimationTree
└── Root (AnimationNodeBlendTree)
    │
    ├── locomotion (BlendSpace2D) ─────── 移动混合
    │   ├── (0, 0): idle
    │   ├── (-1, 0.5): walk_left
    │   ├── (1, 0.5): walk_right
    │   ├── (-1, 1): run_left
    │   └── (1, 1): run_right
    │
    ├── attack_oneshot (OneShot) ───────── 攻击叠加层
    │   ├── in: ← locomotion
    │   └── shot: attack_anim
    │
    ├── control_sm (StateMachine) ──────── 控制状态
    │   ├── hit
    │   ├── stun
    │   └── death
    │
    └── control_blend (Blend2) ─────────── 最终输出
        ├── in: ← attack_oneshot (正常状态)
        └── blend: ← control_sm (控制状态)
```

## 在 Godot 编辑器中创建

### 步骤 1: 创建 BlendTree 根节点

1. 选择 AnimationTree 节点
2. Tree Root → 选择 `AnimationNodeBlendTree`
3. 双击进入编辑

### 步骤 2: 添加 locomotion (BlendSpace2D)

1. 右键 → Add Node → BlendSpace2D
2. 重命名为 `locomotion`
3. 双击进入编辑，配置混合点：

| 位置 | 动画 | 说明 |
|------|------|------|
| (0, 0) | idle | 静止 |
| (-1, 0.5) | right_walk | 左走（flip处理） |
| (1, 0.5) | right_walk | 右走 |
| (-1, 1) | right_run | 左跑 |
| (1, 1) | right_run | 右跑 |

4. 设置：
   - Min Space: (-1, 0)
   - Max Space: (1, 1)
   - Blend Mode: Interpolated

### 步骤 3: 添加 attack_oneshot (OneShot)

1. 右键 → Add Node → OneShot
2. 重命名为 `attack_oneshot`
3. 配置：
   - Fade In: 0.05
   - Fade Out: 0.1
   - Mix Mode: Add（叠加模式）
4. 添加攻击动画节点连接到 shot 输入

### 步骤 4: 添加 control_sm (StateMachine)

1. 右键 → Add Node → StateMachine
2. 重命名为 `control_sm`
3. 双击进入，添加状态：
   - `hit` → stunned 动画
   - `stun` → stunned 动画
   - `death` → death 动画
4. 配置转换：hit → stun, stun → death

### 步骤 5: 添加 control_blend (Blend2)

1. 右键 → Add Node → Blend2
2. 重命名为 `control_blend`

### 步骤 6: 连接节点

在 BlendTree 编辑器中连接：

```
locomotion ──────┐
                 ├──→ attack_oneshot ──┐
attack_anim ─────┘                     │
                                       ├──→ control_blend ──→ Output
control_sm ────────────────────────────┘
```

具体连接：
1. `locomotion` → `attack_oneshot` 的 `in` 端口
2. `attack_anim` → `attack_oneshot` 的 `shot` 端口
3. `attack_oneshot` → `control_blend` 的 `in` 端口
4. `control_sm` → `control_blend` 的 `blend` 端口
5. `control_blend` → `Output`

## 参数路径

| 参数 | 路径 | 用途 |
|------|------|------|
| Locomotion Blend | `parameters/locomotion/blend_position` | 控制移动方向和速度 |
| Attack Request | `parameters/attack_oneshot/request` | 触发攻击 |
| Attack Active | `parameters/attack_oneshot/active` | 检查攻击状态 |
| Control Blend | `parameters/control_blend/blend_amount` | 0=正常, 1=控制状态 |
| Control Playback | `parameters/control_sm/playback` | 控制层状态切换 |

## GDScript 控制代码

```gdscript
# 参数路径常量
const PARAM_LOCOMOTION := "parameters/locomotion/blend_position"
const PARAM_ATTACK_REQUEST := "parameters/attack_oneshot/request"
const PARAM_CONTROL_BLEND := "parameters/control_blend/blend_amount"
const PARAM_CONTROL_PLAYBACK := "parameters/control_sm/playback"

# 更新移动动画
func update_locomotion(velocity: Vector2, max_speed: float) -> void:
    var blend := Vector2.ZERO
    var speed = velocity.length()
    if speed > 1.0:
        blend.x = sign(velocity.x)
        blend.y = clampf(speed / max_speed, 0.0, 1.0)
    anim_tree.set(PARAM_LOCOMOTION, blend)

# 触发攻击
func fire_attack() -> void:
    anim_tree.set(PARAM_ATTACK_REQUEST,
        AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

# 进入控制状态
func enter_control(state: String) -> void:
    var playback = anim_tree.get(PARAM_CONTROL_PLAYBACK)
    playback.travel(state)  # "hit", "stun", "death"
    anim_tree.set(PARAM_CONTROL_BLEND, 1.0)

# 退出控制状态
func exit_control() -> void:
    anim_tree.set(PARAM_CONTROL_BLEND, 0.0)
```

## 优势

| 特性 | 说明 |
|------|------|
| locomotion 永不中断 | 移动动画始终作为基础层播放 |
| 攻击可叠加 | 使用 OneShot 实现边走边攻击 |
| 控制状态优先 | Blend2 确保 hit/stun/death 覆盖一切 |
| 参数简单 | 只需控制几个参数，无需复杂的 travel 调用 |
| 编辑器可视化 | 所有配置在编辑器中完成，代码只控制参数 |

## 与 GDScript 状态机的对应

| GDScript State | 动画控制 |
|----------------|----------|
| Idle/Wander/Chase | locomotion blend_position |
| Attack | attack_oneshot request |
| Hit/Knockback | control_sm → "hit" |
| Stun | control_sm → "stun" |
| Death | control_sm → "death" |
