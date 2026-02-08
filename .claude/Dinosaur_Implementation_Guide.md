# Dinosaur AI 优化实施指南

## 目录
1. [改进总结](#改进总结)
2. [关键改进](#关键改进)
3. [代码结构](#代码结构)
4. [配置检查清单](#配置检查清单)
5. [测试验证步骤](#测试验证步骤)
6. [常见问题](#常见问题)

---

## 改进总结

### 核心改进方向
从"代码驱动动画"转变为"状态驱动动画树"：

```
之前: 状态脚本 → EnemyAnimationHandler → AnimationTree
现在: 状态脚本 → 直接调用 BaseState 方法 → AnimationTree
```

### 量化收益
- **代码行数**：减少 ~30%（删除 EnemyAnimationHandler）
- **中间层数**：从 3 层减少到 2 层
- **维护复杂度**：显著降低
- **调试难度**：降低（直接跟踪状态→动画）
- **性能**：略微提升（少一层中间调用）

---

## 关键改进

### 1. BaseState 增强

**新增方法**：
```gdscript
# 设置移动动画混合
set_locomotion(blend: Vector2)

# 触发攻击动画
fire_attack()
abort_attack()

# 控制层状态管理
enter_control_state(state_name: String)
exit_control_state()

# 直接访问 AnimationTree
get_anim_tree() -> AnimationTree
```

**用途**：
- 所有状态脚本可直接调用这些方法
- 无需依赖 EnemyAnimationHandler
- 代码更清晰，逻辑更直接

### 2. 状态脚本改进

#### IdleState
```gdscript
func enter() -> void:
    set_locomotion(Vector2.ZERO)  # idle 位置

func physics_process_state(delta) -> void:
    set_locomotion(Vector2.ZERO)  # 保持 idle
```

#### ChaseState
```gdscript
func enter() -> void:
    set_locomotion(Vector2.ONE)  # 最大速度

func physics_process_state(delta) -> void:
    move_toward_target(speed)
    # 实时更新 locomotion blend_position
    set_locomotion(Vector2(blend_x, blend_y))
```

#### AttackState
```gdscript
func enter() -> void:
    fire_attack()  # 直接触发 OneShot

func exit() -> void:
    abort_attack()  # 中止攻击动画
```

#### HitState
```gdscript
func enter() -> void:
    enter_control_state("hit")  # 进入反应层

func exit() -> void:
    exit_control_state()  # 返回行为层
```

#### StunState
```gdscript
func enter() -> void:
    enter_control_state("stunned")  # 进入控制层

func exit() -> void:
    exit_control_state()  # 返回行为层
```

### 3. AnimationTree 配置（编辑器中）

**完整结构**：
```
AnimationTree (Root)
└── AnimationNodeBlendTree
    ├── locomotion (BlendSpace2D)
    │   ├── idle (0, 0)
    │   ├── walk_left (-1, 0.5) / walk_right (1, 0.5)
    │   ├── run_left (-1, 1.0) / run_right (1, 1.0)
    │
    ├── attack_oneshot (OneShot)
    │   ├── fade_in: 0.05
    │   ├── fade_out: 0.1
    │   └── mix_mode: Add
    │
    ├── control_sm (StateMachine)
    │   ├── hit → stunned 动画
    │   ├── stunned → stunned 动画
    │   └── death → death 动画
    │
    └── Output (Blend2)
        ├── in: attack_oneshot
        └── blend: control_sm (0.0 = 正常, 1.0 = 控制)
```

**参数路径**（代码中使用）：
```gdscript
"parameters/locomotion/blend_position"       # Vector2
"parameters/attack_oneshot/request"          # ONE_SHOT_REQUEST_FIRE/ABORT
"parameters/control_sm/playback"             # StateMachine playback
"parameters/control_blend/blend_amount"      # 0.0 - 1.0
```

### 4. 删除 EnemyAnimationHandler

**原因**：
- 职责已合并到状态脚本
- 作为中间层增加复杂度
- 不符合直接驱动原则

**移除步骤**：
1. 在 Dinosaur.tscn 中删除 AnimationHandler 节点
2. 从场景脚本中删除对它的引用
3. 确保所有动画参数在状态脚本中直接设置

---

## 代码结构

### 改进后的类图
```
BaseState (核心基类)
├── 新增方法：set_locomotion, fire_attack, enter_control_state 等
│
├── IdleState (行为层)
│   ├── enter: set_locomotion(0, 0)
│   └── 定时切换到 Wander/Chase
│
├── ChaseState (行为层)
│   ├── enter: set_locomotion(1, 1)
│   └── 实时更新 blend_position
│
├── WanderState (行为层)
│   └── 移动中更新 blend_position
│
├── AttackState (行为层)
│   ├── enter: fire_attack()
│   └── exit: abort_attack()
│
├── HitState (反应层)
│   ├── enter: enter_control_state("hit")
│   └── exit: exit_control_state()
│
├── StunState (控制层)
│   ├── enter: enter_control_state("stunned")
│   └── exit: exit_control_state()
│
└── KnockbackState (反应层)
    ├── enter: enter_control_state("knockback")  [可选]
    └── 处理击退物理
```

### 数据流图
```
玩家输入 / AI 决策
    ↓
StateMachine.change_state(state_name)
    ↓
State.enter()
    ├→ set_locomotion() / fire_attack() / enter_control_state()
    └→ 设置 AnimationTree 参数
        ↓
    AnimationTree 自动处理混合和切换
        ↓
    AnimationPlayer 播放对应动画
        ↓
    ✓ 最终动画表现
```

---

## 配置检查清单

### AnimationTree 编辑器配置

- [ ] **根节点**：设置为 AnimationNodeBlendTree
- [ ] **locomotion**：
  - [ ] BlendSpace2D 配置
  - [ ] 5 个混合点（idle, walk_left, walk_right, run_left, run_right）
  - [ ] 位置范围正确（x: -1~1, y: 0~1）
  - [ ] 混合模式：Interpolated
- [ ] **attack_oneshot**：
  - [ ] OneShot 节点
  - [ ] Fade In: 0.05s
  - [ ] Fade Out: 0.1s
  - [ ] Mix Mode: Add
- [ ] **control_sm**：
  - [ ] StateMachine 节点
  - [ ] 包含 hit, stunned, death 状态
  - [ ] 自动转换配置（可选）
- [ ] **output（Blend2）**：
  - [ ] in 连接到 attack_oneshot
  - [ ] blend 连接到 control_sm playback

### 场景配置

- [ ] **Enemy 节点**：
  - [ ] 添加 HealthComponent
  - [ ] 添加 Hurtbox (Area2D)
- [ ] **AnimationPlayer**：
  - [ ] 所有必需的动画已添加
  - [ ] 动画名称与代码匹配
- [ ] **AnimationTree**：
  - [ ] anim_player 属性指向正确节点
  - [ ] active = true（脚本设置或编辑器设置）
- [ ] **EnemyStateMachine**：
  - [ ] 所有状态节点已添加为子节点
  - [ ] init_state 指向 Idle
- [ ] **删除**：
  - [ ] 移除 AnimationHandler 节点

### 代码配置

- [ ] **BaseState.gd**：添加了 AnimationTree 控制方法
- [ ] **各状态脚本**：使用 set_locomotion(), fire_attack() 等方法
- [ ] **Enemy.gd**：
  - [ ] 提供 anim_tree, animation_player 属性
  - [ ] 导出所需参数

---

## 测试验证步骤

### 1. 单个状态测试

**测试 IdleState**：
- [ ] 敌人进入场景后进入 Idle 状态
- [ ] 精灵保持 idle 动画（不活动）
- [ ] AnimationTree 的 locomotion/blend_position = (0, 0)

**测试 ChaseState**：
- [ ] 靠近敌人时它进入 Chase
- [ ] 精灵播放 walk 或 run 动画
- [ ] 能正确跟踪玩家
- [ ] blend_position 实时变化（根据速度）

**测试 AttackState**：
- [ ] 进入攻击范围时切换到 Attack
- [ ] 敌人停止移动
- [ ] attack_oneshot 触发，动画叠加到 locomotion 上
- [ ] 可看到攻击动画

**测试 HitState**：
- [ ] 被玩家攻击时进入 Hit
- [ ] control_blend = 1.0（混合到控制层）
- [ ] 播放 hit/stunned 动画
- [ ] Hit 结束后返回之前的状态

**测试 StunState**：
- [ ] 被眩晕时进入 Stun
- [ ] control_blend = 1.0
- [ ] 完全无法移动或攻击
- [ ] 眩晕时间结束后恢复

### 2. 状态转换测试

- [ ] Idle → Chase（靠近）
- [ ] Chase → Attack（足够近）
- [ ] Attack → Chase（距离变远）
- [ ] Any → Hit（被攻击）
- [ ] Hit → Idle（恢复后）
- [ ] Any → Stun（眩晕效果）
- [ ] Stun → Idle（眩晕结束）

### 3. 动画流畅性测试

- [ ] 所有动画过渡平滑
- [ ] 没有动画卡顿或跳帧
- [ ] 混合效果自然（尤其是 locomotion 的方向切换）
- [ ] OneShot 攻击动画叠加效果正确
- [ ] 优先级切换时没有动画冲突

### 4. 性能测试

- [ ] 多个敌人同时出现时没有明显卡顿
- [ ] 没有内存泄漏（监控运行一段时间）
- [ ] AnimationTree 参数同步稳定

### 5. 编辑器配置验证

在 Godot 编辑器中：
- [ ] 打开 Dinosaur.tscn
- [ ] 选择 AnimationTree 节点
- [ ] 在 Tree Root 编辑器中查看完整结构
- [ ] 验证所有连接无错误
- [ ] 播放场景测试动画

---

## 常见问题

### Q: 动画树 blend_position 不生效？
**A**：
1. 检查 locomotion BlendSpace2D 是否配置正确
2. 确保 set_locomotion() 在 physics_process_state() 中持续调用
3. 验证参数路径："parameters/locomotion/blend_position"
4. 检查 AnimationTree 是否激活 (active = true)

### Q: 攻击 OneShot 不播放？
**A**：
1. 检查 attack_oneshot 节点是否为 OneShot 类型
2. 验证 fire_attack() 是否被调用
3. 检查参数路径："parameters/attack_oneshot/request"
4. 确保 attack 动画已在 AnimationPlayer 中定义

### Q: 控制状态（Hit/Stun）转换不工作？
**A**：
1. 检查 control_sm 是否为 StateMachine 类型
2. 验证 enter_control_state() 中的 travel() 调用
3. 确保 hit, stunned 状态在 control_sm 中存在
4. 检查 control_blend (Blend2) 是否正确配置

### Q: 精灵在 walk_left 和 walk_right 之间切换？
**A**：
1. 这是正常行为，blend_position.x 在 -1 到 1 之间变化
2. 可以在混合点中使用相同的 walk 动画，让 blend_position.x 的改变不影响视觉
3. 或在精灵脚本中根据 velocity.x 手动翻转精灵

### Q: 为什么我的自定义敌人状态不工作？
**A**：
1. 确保继承自 BaseState 或其子类
2. 检查是否实现了必要的方法 (enter, exit, physics_process_state)
3. 使用 set_locomotion() 等方法而不是直接访问 AnimationTree
4. 确保状态已添加到 EnemyStateMachine

### Q: 如何添加新的敌人类型？
**A**：
1. 继承现有的 Dinosaur.tscn 场景
2. 保持 AnimationTree 结构相同
3. 修改 AnimationPlayer 中的动画资源
4. 调整各状态的参数（速度、范围等）

---

## 最佳实践

### 1. 参数设置
- 总是从 owner 节点获取参数（通过 get_owner_property）
- 在状态脚本中导出常见参数作为默认值
- 允许场景编辑器覆盖脚本默认值

### 2. 动画同步
- 在 enter() 中设置初始动画状态
- 在 physics_process_state() 中实时更新 blend_position
- 使用 enter_control_state / exit_control_state 管理优先级

### 3. 状态转换
- 使用 transition_to() 安全切换状态
- 检查目标状态是否存在
- 在 exit() 中清理资源（停止定时器等）

### 4. 性能优化
- 不要在每帧都查询 AnimationTree（缓存引用）
- 使用 clampf() 限制 blend_position 范围
- 避免频繁创建新对象

---

## 后续优化方向

### 可选优化
1. **上层身体动画**：使用 AddNode 实现上下半身独立动画
2. **转身动画**：添加专门的转身状态
3. **技能系统**：扩展 AttackState 支持多种攻击类型
4. **动画事件**：在特定帧触发伤害判定

### 扩展性设计
1. **Boss 敌人**：继承 Dinosaur 的架构，添加更复杂的状态
2. **远程敌人**：添加 RangedAttack 状态和相应的动画
3. **自定义 AI**：通过修改状态转换逻辑实现不同行为

---

## 相关文件

- `Core/StateMachine/BaseState.gd` - 核心基类（已改进）
- `Core/StateMachine/CommonStates/` - 通用状态脚本（已改进）
- `Scenes/Characters/Enemies/dinosaur/dinosaur.tscn` - 场景配置
- `.claude/Dinosaur_Optimization_Plan.md` - 优化方案
