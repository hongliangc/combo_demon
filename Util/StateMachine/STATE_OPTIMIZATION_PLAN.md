# 状态机优化方案 - 通用模板化设计

## 📊 现状分析

### Enemy 状态分析

| 状态 | 行数 | 复杂度 | 可模板化 | 优化方案 |
|------|------|--------|----------|----------|
| **enemy_idle** | 26 | ⭐ | ✅ 是 | 使用优化后的 `idle_state.gd` |
| **enemy_wander** | 35 | ⭐⭐ | ✅ 是 | 创建 `wander_state.gd` 通用模板 |
| **enemy_chase** | 35 | ⭐⭐ | ✅ 是 | 使用优化后的 `chase_state.gd` |
| **enemy_attack** | 38 | ⭐⭐ | ✅ 是 | 创建 `attack_state.gd` 支持 AttackComponent |
| **enemy_stun** | 122 | ⭐⭐⭐⭐⭐ | ❌ 否 | **保留**（复杂物理系统：击飞/击退/抛物线） |

**Enemy 可优化率**: 4/5 = 80%

### Boss 状态分析

| 状态 | 行数 | 复杂度 | 可模板化 | 优化方案 |
|------|------|--------|----------|----------|
| **boss_idle** | 36 | ⭐ | ✅ 是 | 使用优化后的 `idle_state.gd` + @export |
| **boss_patrol** | 39 | ⭐⭐⭐ | ❌ 否 | **保留**（Boss 特有巡逻点系统） |
| **boss_chase** | 87 | ⭐⭐⭐ | ⚠️ 部分 | 使用 `chase_state.gd` + 自定义攻击逻辑 |
| **boss_circle** | 58 | ⭐⭐⭐⭐ | ❌ 否 | **保留**（Boss 特有绕圈算法） |
| **boss_attack** | 218 | ⭐⭐⭐⭐⭐ | ⚠️ 框架 | 创建 `phased_attack_state.gd` 支持多阶段 |
| **boss_retreat** | 308 | ⭐⭐⭐⭐⭐ | ⚠️ 框架 | 创建 `retreat_state.gd` + Boss 扩展 |
| **boss_special_attack** | 136 | ⭐⭐⭐⭐ | ⚠️ 框架 | 创建 `special_attack_state.gd` |
| **boss_enrage** | 101 | ⭐⭐⭐⭐ | ❌ 否 | **保留**（Boss 第三阶段特有） |
| **boss_stun** | 49 | ⭐⭐ | ✅ 是 | 使用优化后的 `stun_state.gd` |

**Boss 可优化率**: 4/9 = 44% (直接替换) + 3/9 = 33% (框架支持) = 77% 总优化率

---

## 🎯 通用状态框架设计

### 1. 基础状态模板（直接使用）

#### ✅ **idle_state.gd** (已存在，需优化)
```gdscript
@export var min_idle_time := 1.0          # 最短待机时间
@export var max_idle_time := 3.0          # 最长待机时间
@export var detection_radius := 100.0     # 检测半径
@export var idle_animation := "idle"      # 动画名称
@export var next_state_on_timeout := "wander"  # 超时后的状态
@export var enable_player_detection := true    # 是否检测玩家
```

**适用**: enemy_idle ✓, boss_idle ✓

---

#### ✅ **chase_state.gd** (已存在，需优化)
```gdscript
@export var chase_speed := 100.0          # 追击速度
@export var attack_range := 50.0          # 攻击范围
@export var give_up_range := 300.0        # 放弃距离
@export var chase_animation := "run"      # 动画
@export var use_owner_speed := true       # 使用 owner.chase_speed
@export var random_movement := false      # 添加随机偏移
@export var random_offset := 0.2          # 随机偏移量
```

**适用**: enemy_chase ✓, boss_chase (部分) ⚠️

---

#### ❌ **wander_state.gd** (需要创建)
```gdscript
@export var wander_speed := 50.0          # 巡游速度
@export var min_wander_time := 2.0        # 最短巡游时间
@export var max_wander_time := 5.0        # 最长巡游时间
@export var detection_radius := 100.0     # 检测半径
@export var wander_animation := "walk"    # 动画
@export var random_direction := true      # 随机方向
```

**适用**: enemy_wander ✓

---

#### ❌ **attack_state.gd** (需要创建)
```gdscript
@export var attack_interval := 3.0        # 攻击间隔
@export var attack_duration := 1.0        # 攻击动作时长
@export var attack_range := 50.0          # 攻击范围
@export var attack_animation := "attack"  # 动画
@export var attack_name := "basic_attack" # 攻击名称（传给 AttackComponent）
@export var use_attack_component := true  # 使用 AttackComponent
@export var stop_movement := true         # 攻击时停止移动
```

**适用**: enemy_attack ✓

---

#### ✅ **stun_state.gd** (已存在，需优化)
```gdscript
@export var stun_duration := 0.5          # 眩晕时长
@export var stun_animation := "stun"      # 动画
@export var reset_on_damage := true       # 受伤时重置时间
@export var detection_radius := 150.0     # 恢复后检测半径
@export var deceleration_rate := 5.0      # 减速率
```

**适用**: boss_stun ✓

**注意**: enemy_stun 包含复杂的击飞/击退物理系统（抛物线、重力模拟），**不能直接替换**，需要保留。

---

### 2. 高级状态框架（提供基础 + 重载）

#### ❌ **retreat_state.gd** (需要创建 - Boss 用)
```gdscript
@export var retreat_speed_multiplier := 1.2
@export var retreat_distance := 150.0     # 目标后退距离
@export var safe_distance := 100.0        # 安全距离
@export var retreat_animation := "run"
@export var attack_while_retreating := false  # 边退边打
@export var retreat_attack_interval := 1.0
```

**适用**: boss_retreat (作为基类，Boss 扩展闪现/击退技能)

---

#### ❌ **phased_attack_state.gd** (需要创建 - 多阶段攻击)
```gdscript
@export var attack_duration := 1.0
@export var attack_delay := 0.5           # 攻击前摇
@export var use_phase_system := false     # 是否使用阶段系统

# 虚方法 - 子类重载
func get_attack_pattern():
    # Boss 重载此方法，根据 phase 返回攻击模式
    pass

func perform_attack():
    # 调用 get_attack_pattern()
    pass
```

**适用**: boss_attack (作为基类，Boss 重载 get_attack_pattern)

---

### 3. Boss 特有状态（保留自定义）

| 状态 | 原因 | 处理方式 |
|------|------|----------|
| **boss_patrol** | Boss 特有巡逻点系统 (`get_next_patrol_point()`) | 保留，添加 @export 参数 |
| **boss_circle** | Boss 特有绕圈算法（切向 + 径向） | 保留，添加 @export 参数 |
| **boss_enrage** | Boss 第三阶段狂暴模式 | 保留，添加 @export 参数 |
| **enemy_stun** | 复杂击飞/击退物理模拟 | 保留（122 行，无法简化） |

---

## 🔧 实施步骤

### 阶段 1: 优化现有通用状态
- [x] 优化 `idle_state.gd` - 增加配置参数
- [x] 优化 `chase_state.gd` - 支持更多场景
- [x] 优化 `stun_state.gd` - 增加配置灵活性

### 阶段 2: 创建新通用状态
- [ ] 创建 `wander_state.gd`
- [ ] 创建 `attack_state.gd`
- [ ] 创建 `retreat_state.gd`
- [ ] 创建 `phased_attack_state.gd`

### 阶段 3: 替换 Enemy 状态
- [ ] enemy_idle → idle_state
- [ ] enemy_wander → wander_state
- [ ] enemy_chase → chase_state
- [ ] enemy_attack → attack_state
- [x] enemy_stun - **保留**（物理系统复杂）

### 阶段 4: 优化 Boss 状态
- [ ] boss_idle → idle_state
- [ ] boss_chase → chase_state (+ 自定义追击攻击)
- [ ] boss_stun → stun_state
- [ ] boss_patrol - 添加 @export 参数
- [ ] boss_circle - 添加 @export 参数
- [ ] boss_enrage - 添加 @export 参数
- [ ] boss_attack → 继承 phased_attack_state
- [ ] boss_retreat → 继承 retreat_state
- [ ] boss_special_attack → 继承 phased_attack_state

### 阶段 5: 测试验证
- [ ] 测试 Enemy AI 完整流程
- [ ] 测试 Boss AI 完整流程
- [ ] 测试所有阶段转换
- [ ] 性能测试

---

## 📈 预期收益

### 代码减少
- **Enemy**: ~134 行 → ~0 行 (使用通用模板) = **100% 减少**
- **Boss**: ~617 行 → ~200 行 (保留特有 + 配置) = **67% 减少**

### 可维护性
- ✅ 新建 enemy1/2/3 只需配置参数
- ✅ 行为统一，易于调试
- ✅ Bug 修复一次，所有实体受益

### 扩展性
- ✅ 通用状态可被任何实体继承
- ✅ 支持组合（通用状态 + 自定义逻辑）
- ✅ @export 参数支持 Inspector 可视化配置

---

## 🎨 使用示例

### Enemy1 (使用全通用模板)
```gdscript
# 状态机配置（无需写代码）
states/
  idle/ → IdleState (min_idle_time=1.0, detection_radius=100)
  wander/ → WanderState (wander_speed=50, min_time=2, max_time=5)
  chase/ → ChaseState (chase_speed=75, attack_range=25)
  attack/ → AttackState (attack_interval=3.0, attack_name="slash")
  stun/ → StunState (stun_duration=1.0)
```

### Boss (通用 + 自定义)
```gdscript
states/
  idle/ → IdleState (配置参数)
  patrol/ → BossPatrolState (自定义 - 巡逻点)
  chase/ → ChaseState (配置参数 + chase_attack)
  circle/ → BossCircleState (自定义 - 绕圈)
  attack/ → BossAttackState extends PhasedAttackState (重载)
  retreat/ → BossRetreatState extends RetreatState (扩展闪现)
  enrage/ → BossEnrageState (自定义 - 狂暴)
  stun/ → StunState (配置参数)
```

---

## ⚠️ 注意事项

1. **enemy_stun 不能替换**
   - 包含 122 行复杂物理模拟
   - 击飞抛物线、重力、8方向地图特殊处理
   - 必须保留原实现

2. **Boss 特有状态保留**
   - patrol, circle, enrage 是 Boss 独有机制
   - 通用化意义不大
   - 只需添加 @export 参数提高可配置性

3. **向后兼容**
   - 保证现有游戏逻辑不变
   - 通过 MCP 测试验证

---

**最终目标**: 创建一套灵活、可配置、易扩展的状态机框架，让 enemy1/enemy2/enemy3 的创建从"写代码"变成"配置参数"。
