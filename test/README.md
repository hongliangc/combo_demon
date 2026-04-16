# Combo Demon 测试框架

基于 [GUT 9.3](https://github.com/bitwes/Gut) 的单元测试 + 集成测试框架。

## 目录结构

```
test/
├── base/                        # 测试基础设施
│   ├── gut_test_base.gd         # 测试基类（mock 工厂、自定义断言）
│   └── signal_tracker.gd        # 信号追踪器
├── unit/                        # 单元测试
│   ├── test_damage_system.gd    # Damage Resource
│   ├── test_attack_effects.gd   # AttackEffect 子类
│   ├── test_behavior_config.gd  # BehaviorConfig Resource
│   ├── test_health_component.gd # HealthComponent（扣血/治疗/死亡/无敌）
│   ├── test_state_machine.gd    # BaseStateMachine（注册/转换/优先级）
│   └── test_base_state.gd       # BaseState（距离工具/优先级/路由）
├── integration/                 # 集成测试
│   └── test_damage_pipeline.gd  # Damage→Health→Signal→StateMachine 全链路
├── fixtures/                    # 共享测试资源
├── install_gut.sh               # GUT 安装脚本
├── run_tests.sh                 # 测试运行脚本
└── README.md                    # 本文件
```

## 安装

```bash
# 1. 安装 GUT 插件
bash test/install_gut.sh

# 2. 打开 Godot 编辑器导入资源（首次必须）
#    或命令行: godot --headless --import

# 3. 启用插件（可选，仅编辑器内运行需要）
#    Project → Project Settings → Plugins → GUT → Enable
```

如果安装不完整（缺 gui/cli 子目录），强制重装：
```bash
bash test/install_gut.sh --force
```

## 运行测试

### 命令行（推荐）

```bash
# 运行全部测试
bash test/run_tests.sh

# 仅运行单元测试
bash test/run_tests.sh unit

# 仅运行集成测试
bash test/run_tests.sh integration

# 运行指定测试文件
bash test/run_tests.sh test_health_component
bash test/run_tests.sh test_state_machine
bash test/run_tests.sh damage_system          # 自动补 test_ 前缀
```

### 自定义 Godot 路径

```bash
# 如果 Godot 不在默认路径
GODOT_PATH="/path/to/godot" bash test/run_tests.sh
```

### Godot 编辑器内运行

启用 GUT 插件后，底部面板出现 GUT tab，点击 Run All 即可。

## 编写测试

### 基本模板

所有测试继承 `GutTestBase`（而非直接继承 `GutTest`）：

```gdscript
extends GutTestBase

## 文件名: test/unit/test_我的模块.gd
## 命名规则: test_功能_场景_预期结果

# before_each / after_each 每个 test_ 方法前后执行
func before_each() -> void:
    pass  # 初始化测试数据

func after_each() -> void:
    pass  # 清理

func test_基本功能() -> void:
    var dmg = create_damage(50.0)
    assert_eq(dmg.amount, 50.0)
```

### Mock 工厂方法

`GutTestBase` 提供以下工厂方法，无需手动构造：

```gdscript
# 创建 Damage Resource
var dmg = create_damage(30.0)                              # 基础伤害
var dmg = create_stun_damage(20.0, 2.0)                    # 带眩晕
var dmg = create_knockback_damage(15.0, 500.0)             # 带击退

# 创建 BehaviorConfig
var cfg = create_behavior_config()                         # 默认值
var cfg = create_behavior_config({                         # 自定义
    "max_health": 500,
    "detection_radius": 250.0,
    "is_boss": true
})
```

### 信号追踪

```gdscript
# 方式1: GUT 内置（推荐，简单场景）
func test_signal_emitted() -> void:
    watch_signals(health_comp)
    health_comp.take_damage(create_damage(10.0))
    assert_signal_emitted(health_comp, "damaged")
    assert_signal_emit_count(health_comp, "damaged", 1)

# 方式2: SignalTracker（需要检查参数）
func test_signal_args() -> void:
    var tracker = track_signal(health_comp, "health_changed")
    health_comp.take_damage(create_damage(25.0))
    assert_eq(tracker.count, 1)
    assert_eq(tracker.last_args[0], 75.0)   # current health
    assert_eq(tracker.last_args[1], 100.0)  # max health
```

### 场景树节点测试

```gdscript
func before_each() -> void:
    # add_child_autofree: 测试结束后自动 queue_free
    var node = CharacterBody2D.new()
    add_child_autofree(node)

func test_with_scene_tree() -> void:
    # wait_frames: 等待帧处理（触发 _ready / _process）
    await wait_frames(1)
    # wait_for_signal: 等待信号带超时
    await wait_for_signal(obj.my_signal, 2.0)
```

### 自定义断言

```gdscript
# 范围断言
assert_between(value, 10.0, 20.0, "Should be in range")

# Vector2 近似比较
assert_vector2_approx(actual, Vector2(1.0, 0.0), 0.01)

# 节点存在 + 类型检查
assert_node_exists(parent, "HealthComponent", HealthComponent)
```

## 测试覆盖指南

新增功能时，根据类型选择测试重点：

| 变更类型 | 测试重点 | 放置目录 |
|---------|---------|---------|
| 新 Resource | 属性默认值、has_effect()、效果组合 | `unit/` |
| 新 Component | 信号发射、@export 默认值、边界值 | `unit/` |
| 新 State | enter()/exit() 调用、优先级阻断、timer | `unit/` |
| 新敌人 | 状态机切换链路、伤害触发 | `integration/` |
| 新 Boss | 阶段转换、攻击池、无敌帧 | `integration/` |
| 新 Effect | apply_effect() 行为、叠加/互斥 | `unit/` |
| 系统链路 | 信号流端到端、多组件协作 | `integration/` |

## 现有测试用例清单

### unit/test_damage_system.gd (10 tests)
- `test_damage_creation_with_amount` — 伤害值设置
- `test_damage_default_effects_empty` — 默认无效果
- `test_damage_has_effect_with_stun` — 检测眩晕效果
- `test_damage_has_effect_without_effect` — 检测不存在的效果
- `test_damage_has_effect_multiple` — 多效果检测
- `test_damage_randomize_in_range` — 随机伤害在范围内
- `test_damage_effects_description_empty` — 空效果描述
- `test_damage_effects_description_with_effects` — 有效果的描述
- `test_create_stun_damage_has_stun_effect` — 工厂方法：眩晕伤害
- `test_create_knockback_damage_has_knockback_effect` — 工厂方法：击退伤害

### unit/test_attack_effects.gd (9 tests)
- `test_base_effect_defaults` — 基类默认值
- `test_base_effect_description` — 基类描述
- `test_stun_effect_defaults` — 眩晕默认值
- `test_stun_effect_custom_duration` — 自定义眩晕时间
- `test_stun_effect_description_contains_duration` — 眩晕描述
- `test_knockback_effect_creation` — 击退创建
- `test_knockup_effect_creation` — 击飞创建
- `test_gather_effect_creation` — 聚集创建
- `test_force_stun_effect_creation` — 强制眩晕创建
- `test_multiple_effects_on_damage` — 多效果组合

### unit/test_behavior_config.gd (8 tests)
- `test_default_health` — 默认生命值
- `test_default_wander` — 默认游荡参数
- `test_default_chase` — 默认追击参数
- `test_default_stun` — 默认眩晕参数
- `test_default_not_boss` — 默认非 Boss
- `test_boss_config_fields` — Boss 扩展字段
- `test_create_config_with_defaults` — 工厂默认值
- `test_create_config_with_overrides` — 工厂覆盖
- `test_create_config_partial_override` — 部分覆盖

### unit/test_health_component.gd (16 tests)
- `test_initial_health` — 初始生命值
- `test_health_percent_full` — 满血百分比
- `test_take_damage_reduces_health` — 扣血
- `test_take_damage_emits_damaged_signal` — 受伤信号
- `test_take_damage_emits_health_changed` — 血量变化信号
- `test_take_damage_health_not_below_zero` — 不低于0
- `test_take_damage_when_dead_ignored` — 死亡后忽略
- `test_invincible_blocks_damage` — 无敌挡伤
- `test_set_invincible_toggle` — 无敌开关
- `test_lethal_damage_triggers_death` — 致死伤害
- `test_overkill_triggers_death_once` — 超杀只死一次
- `test_multiple_hits_trigger_death_once` — 多次攻击只死一次
- `test_heal_restores_health` — 治疗恢复
- `test_heal_does_not_exceed_max` — 治疗不超上限
- `test_heal_emits_health_changed` — 治疗信号
- `test_heal_when_dead_ignored` — 死亡后不可治疗
- `test_reset_health_restores_full` — 重置满血
- `test_health_percent_after_damage` — 受伤后百分比
- `test_health_percent_at_zero` — 0血百分比

### unit/test_state_machine.gd (13 tests)
- `test_states_registered` — 状态注册
- `test_initial_state_set` — 初始状态
- `test_get_current_state_name` — 获取状态名
- `test_is_in_state` — 状态判断
- `test_transition_behavior_to_behavior` — 行为→行为转换
- `test_transition_behavior_to_reaction` — 行为→反应转换
- `test_transition_behavior_to_control` — 行为→控制转换
- `test_transition_rejected_from_non_current_state` — 拒绝非当前状态
- `test_transition_to_nonexistent_state_ignored` — 不存在状态忽略
- `test_control_blocks_behavior` — 控制阻断行为
- `test_reaction_cannot_interrupt_control` — 反应不打断控制
- `test_force_transition_ignores_priority` — 强制转换
- `test_force_transition_nonexistent_state` — 强制转换不存在状态

### unit/test_base_state.gd (12 tests)
- `test_priority_ordering` — 优先级排序
- `test_default_priority_is_behavior` — 默认行为优先级
- `test_default_can_be_interrupted` — 默认可打断
- `test_get_distance_to_target_no_target` — 无目标距离
- `test_get_distance_to_target_same_position` — 同位置距离
- `test_get_direction_to_target` — 目标方向
- `test_is_target_in_range_true` — 在范围内
- `test_is_target_in_range_false` — 不在范围内
- `test_is_target_alive_with_alive_property` — 目标存活
- `test_is_target_alive_no_target` — 无目标
- `test_get_owner_property_exists` — 获取存在属性
- `test_get_owner_property_missing_returns_default` — 获取不存在属性
- `test_transition_to_emits_signal` — 转换发射信号
- `test_transition_to_nonexistent_returns_false` — 转换不存在状态

### integration/test_damage_pipeline.gd (8 tests)
- `test_damage_reduces_health` — 伤害扣血
- `test_damage_emits_health_changed_and_damaged` — 信号链
- `test_lethal_damage_emits_died` — 致死→死亡信号
- `test_state_machine_starts_in_idle` — 初始 idle
- `test_on_damaged_routes_to_hit_state` — 普通伤害→hit
- `test_on_damaged_with_stun_routes_to_stun` — 眩晕伤害→stun
- `test_on_damaged_with_knockback_routes_to_hit` — 击退无状态→hit
- `test_on_damaged_with_knockback_routes_to_knockback_state` — 击退有状态→knockback
- `test_multiple_damages_track_health_correctly` — 连续伤害累计
