# 状态机测试指南

迁移完成后的测试步骤和验证方法。

## 🧪 测试前准备

### 1. 打开 Godot 编辑器

1. 启动 Godot 4.4
2. 打开 `combo_demon` 项目
3. 等待编辑器完成加载

### 2. 检查错误和警告

1. 打开 **Output** 面板（底部）
2. 查看是否有红色错误信息
3. 查看是否有黄色警告信息

**预期结果**:
- ✅ 没有红色错误
- ⚠️ 可能有少量警告（未使用参数等）

### 3. 检查脚本语法

在编辑器中打开并检查以下文件是否有语法错误：

#### 核心文件
- `Util/StateMachine/base_state_machine.gd`
- `Util/StateMachine/base_state.gd`

#### Enemy 文件
- `Scenes/enemies/dinosaur/Scripts/States/enemy_state_machine.gd`
- `Scenes/enemies/dinosaur/Scripts/States/enemy_base_state.gd`

#### Boss 文件
- `Scenes/enemies/boss/Scripts/States/boss_state_machine.gd`
- `Scenes/enemies/boss/Scripts/States/boss_base_state.gd`

**如何检查**:
1. 在 FileSystem 面板中双击文件
2. 查看代码编辑器底部是否有红色下划线
3. 查看右侧是否有错误标记

## 🎮 Enemy 状态机测试

### 测试 1: Enemy 基础功能

1. **运行游戏** (F5 或点击播放按钮)
2. **观察 Enemy 行为**:
   - ✅ Enemy 应该在待机/巡逻状态
   - ✅ 靠近时应该进入追击状态
   - ✅ 追到附近时应该发动攻击

3. **测试受伤反应**:
   - 攻击 Enemy
   - ✅ 应该进入眩晕（Stun）状态
   - ✅ 眩晕结束后恢复正常行为

4. **检查控制台输出**:
   - 应该看到状态转换日志（如果启用了调试）
   - 格式类似：`[Enemy StateMachine] idle -> chase`

### 测试 2: Enemy 状态转换

测试所有状态转换路径：

| 从状态 | 到状态 | 触发条件 | 预期结果 |
|--------|--------|---------|---------|
| Idle | Wander | 待机时间结束 | ✅ 开始随机移动 |
| Idle | Chase | 检测到玩家 | ✅ 追击玩家 |
| Wander | Chase | 检测到玩家 | ✅ 追击玩家 |
| Chase | Attack | 进入攻击范围 | ✅ 发动攻击 |
| Chase | Idle/Wander | 玩家离开范围 | ✅ 返回巡逻 |
| Any | Stun | 受到伤害 | ✅ 进入眩晕 |
| Stun | Chase/Idle | 眩晕结束 | ✅ 恢复行为 |

### 测试 3: Enemy 击飞/击退效果

1. 使用具有击飞效果的攻击
   - ✅ Enemy 应该被击飞（Y 轴偏移）
   - ✅ 应该呈现抛物线轨迹
   - ✅ 落地后恢复

2. 使用具有击退效果的攻击
   - ✅ Enemy 应该被击退（X 轴移动）
   - ✅ 应该逐渐减速

3. 在眩晕中再次攻击
   - ✅ 眩晕时间应该重置
   - ✅ 击飞/击退效果应该叠加

## 👹 Boss 状态机测试

### 测试 1: Boss 基础功能

1. **进入 Boss 战场景**
2. **观察 Boss 初始行为**:
   - ✅ Boss 应该在待机/巡逻状态
   - ✅ 检测到玩家后进入战斗状态

3. **测试 Boss 攻击**:
   - ✅ Boss 应该使用各种攻击模式
   - ✅ 攻击应该有冷却时间

### 测试 2: Boss 阶段转换（关键！）

这是最重要的测试，验证新架构的 Boss 特有逻辑。

#### Phase 1 → Phase 2 (血量 66%)

1. **减少 Boss 血量至 66%**
2. **观察行为**:
   - ✅ 控制台输出：`"Boss 阶段改变回调: Phase 2"`
   - ✅ Boss 应该根据距离切换状态：
     - 近距离 → Circle（绕圈）
     - 远距离 → Chase（追击）

3. **测试阶段转换期间的无敌**:
   - 在阶段转换瞬间攻击 Boss
   - ✅ 伤害应该被忽略（不会进入 Stun）
   - ✅ 0.1 秒后恢复正常受伤反应

#### Phase 2 → Phase 3 (血量 33%)

1. **继续减少 Boss 血量至 33%**
2. **观察行为**:
   - ✅ 控制台输出：`"Boss 阶段改变回调: Phase 3"`
   - ✅ Boss 应该立即进入 Enrage（狂暴）状态
   - ✅ 速度明显提升
   - ✅ 攻击频率提升

3. **测试第三阶段的击晕免疫**:
   - 攻击 Boss
   - ✅ Boss 应该**不会进入** Stun 状态
   - ✅ 控制台可能输出：`"Boss 狂暴中，无法击晕！"`

### 测试 3: Boss 所有状态

| 状态 | 触发条件 | 预期行为 | 测试结果 |
|-----|---------|---------|---------|
| Idle | 初始/失去目标 | 待机 | [ ] |
| Patrol | 无玩家时 | 巡逻移动 | [ ] |
| Chase | 检测到玩家，距离适中 | 追击并边追边打 | [ ] |
| Circle | Phase 2+，近距离 | 绕圈移动 | [ ] |
| Attack | 进入攻击范围 | 发动攻击 | [ ] |
| SpecialAttack | 触发特殊攻击条件 | 使用强力技能 | [ ] |
| Retreat | 距离过近 | 后退拉开距离 | [ ] |
| Stun | Phase 1/2 受伤 | 眩晕 | [ ] |
| Enrage | Phase 3 | 狂暴快速攻击 | [ ] |

### 测试 4: Boss 攻击模式

根据阶段测试不同的攻击模式：

**Phase 1**:
- [ ] 单发追踪弹
- [ ] 扇形弹幕（3 发）
- [ ] 激光攻击

**Phase 2**:
- [ ] 小扇形弹幕（3 发）
- [ ] 边追边打
- [ ] 更频繁的特殊攻击

**Phase 3**:
- [ ] 密集扇形弹幕（6 发）
- [ ] 三连发追踪弹
- [ ] 螺旋弹幕
- [ ] 激光+弹幕组合

## 🐛 常见问题和解决方案

### 问题 1: 游戏无法运行，报错 "Class not found"

**原因**: 脚本类名或继承关系有误

**检查**:
1. 打开 `Util/StateMachine/base_state_machine.gd`
2. 确认第一行是 `extends Node`
3. 确认第二行是 `class_name BaseStateMachine`

4. 打开 `Util/StateMachine/base_state.gd`
5. 确认第一行是 `extends Node`
6. 确认第二行是 `class_name BaseState`

**解决**:
- 重启 Godot 编辑器
- Project → Reload Current Project

### 问题 2: Enemy/Boss 不移动或行为异常

**原因**: owner_node 或 target_node 为 null

**检查**:
1. 在 Enemy/Boss 场景中打开 StateMachine 节点
2. 在 Inspector 中查看脚本属性
3. **不需要**手动设置 `Owner Node Group` 和 `Target Node Group`
4. 确保玩家在 "player" 组中

**调试**:
在 `enemy_state_machine.gd` 的 `_ready()` 后添加：
```gdscript
func _ready() -> void:
    super._ready()
    print("Enemy StateMachine 初始化")
    print("Owner Node: ", owner_node)
    print("Target Node: ", target_node)
```

### 问题 3: 状态转换不工作

**症状**: 卡在某个状态不切换

**检查**:
1. 打开控制台
2. 查看是否有 `"[StateMachine] 状态 'xxx' 不存在"` 警告
3. 检查状态节点名称（大小写敏感）

**常见错误**:
- ❌ 节点名: `Chase`, 代码: `"chase"` ✅
- ❌ 节点名: `chase`, 代码: `"Chase"` ❌
- ❌ 节点名: `boss_chase`, 代码: `"chase"` ❌

**解决**:
- 状态节点名应该是：`Idle`, `Chase`, `Attack` 等
- 代码中使用小写：`"idle"`, `"chase"`, `"attack"`

### 问题 4: Boss 阶段转换不触发

**检查**:
1. Boss 是否发出 `phase_changed` 信号？
   - 打开 `boss.gd`
   - 搜索 `phase_changed.emit(`

2. 信号是否连接？
   - 在 Boss 的 `_ready()` 后添加调试：
   ```gdscript
   func _ready() -> void:
       # ... 现有代码
       print("Boss phase_changed 信号: ", phase_changed.get_connections())
   ```

### 问题 5: 第三阶段仍然会眩晕

**原因**: `boss_base_state.gd` 的 `on_damaged` 逻辑错误

**检查**:
打开 `boss_base_state.gd`，确认第 34-38 行：
```gdscript
func on_damaged(_damage: Damage):
    if boss and boss.current_phase != Boss.Phase.PHASE_3:
        transitioned.emit(self, "stun")
```

**特例**: `boss_enrage.gd` 有自己的 `on_damaged`：
```gdscript
func on_damaged(_damage: Damage):
    print("Boss 狂暴中，无法击晕！")
    # 不调用 super，不会切换到 stun
```

## ✅ 测试检查清单

完成所有测试后，勾选以下项目：

### 基础测试
- [ ] Godot 编辑器无错误加载
- [ ] 所有脚本无语法错误
- [ ] 游戏可以正常运行

### Enemy 测试
- [ ] Enemy 待机/巡逻正常
- [ ] Enemy 追击玩家正常
- [ ] Enemy 攻击玩家正常
- [ ] Enemy 受伤进入眩晕正常
- [ ] Enemy 击飞/击退效果正常
- [ ] Enemy 眩晕中再次受伤正常

### Boss 测试
- [ ] Boss 基础行为正常
- [ ] Boss Phase 1 → 2 转换正常
- [ ] Boss Phase 2 → 3 转换正常
- [ ] Boss 阶段转换期间无敌正常
- [ ] Boss Phase 3 不会眩晕
- [ ] Boss 所有攻击模式正常

### 性能测试
- [ ] 帧率正常（无明显下降）
- [ ] 没有内存泄漏
- [ ] 多个 Enemy 同时存在正常

## 🎯 测试通过标准

### 最低标准（必须通过）
1. ✅ 游戏可以运行
2. ✅ Enemy 基础行为正常
3. ✅ Boss 基础行为正常
4. ✅ 状态转换基本正常

### 完整标准（建议达到）
1. ✅ 所有 Enemy 状态正常
2. ✅ 所有 Boss 状态正常
3. ✅ Boss 阶段转换完全正常
4. ✅ 所有特殊效果（击飞/击退）正常
5. ✅ 无性能问题

## 🔧 测试失败后的回滚

如果测试严重失败，可以快速回滚：

### 方法 1: 使用备份文件

```bash
cd "e:\workspace\4.godot\combo_demon\Scenes\enemies"

# 恢复 Enemy
cp dinosaur/Scripts/States/enemy_state_machine.gd.backup dinosaur/Scripts/States/enemy_state_machine.gd
cp dinosaur/Scripts/States/enemy_base_state.gd.backup dinosaur/Scripts/States/enemy_base_state.gd

# 恢复 Boss
cp boss/Scripts/States/boss_state_machine.gd.backup boss/Scripts/States/boss_state_machine.gd
cp boss/Scripts/States/boss_base_state.gd.backup boss/Scripts/States/boss_base_state.gd
```

### 方法 2: 使用 Git

```bash
cd "e:\workspace\4.godot\combo_demon"
git checkout -- Scenes/enemies/dinosaur/Scripts/States/enemy_state_machine.gd
git checkout -- Scenes/enemies/dinosaur/Scripts/States/enemy_base_state.gd
git checkout -- Scenes/enemies/boss/Scripts/States/boss_state_machine.gd
git checkout -- Scenes/enemies/boss/Scripts/States/boss_base_state.gd
```

## 📊 测试报告模板

测试完成后，请填写以下报告：

```
# 状态机迁移测试报告

测试日期: ___________
测试人员: ___________

## 测试结果

### Enemy 状态机
- 基础功能: [ ] 通过 / [ ] 失败
- 状态转换: [ ] 通过 / [ ] 失败
- 击飞/击退: [ ] 通过 / [ ] 失败
- 问题描述: ___________

### Boss 状态机
- 基础功能: [ ] 通过 / [ ] 失败
- 阶段转换: [ ] 通过 / [ ] 失败
- Phase 1-2: [ ] 通过 / [ ] 失败
- Phase 2-3: [ ] 通过 / [ ] 失败
- 无敌判定: [ ] 通过 / [ ] 失败
- 问题描述: ___________

### 性能
- 帧率: _____ FPS (期望 > 60)
- 内存: [ ] 正常 / [ ] 泄漏
- 问题描述: ___________

## 总结
- 总体评分: ____ / 10
- 是否建议使用: [ ] 是 / [ ] 否
- 备注: ___________
```

---

**测试愉快！遇到问题请参考 [MIGRATION_COMPLETE.md](MIGRATION_COMPLETE.md) 中的故障排除部分。**
