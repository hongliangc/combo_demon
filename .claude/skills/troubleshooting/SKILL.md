---
name: troubleshooting
description: "Debug and troubleshoot Combo Demon issues. Use when encountering bugs, errors, unexpected behavior, state machine freezes, damage not triggering, animation glitches, or any runtime problem. Triggers on: bug, error, fix, debug, not working, broken, stuck, crash, freeze, issue, problem, troubleshoot."
---

# 问题排查指南

遇到 bug 或异常行为时，按本 skill 流程排查：分层定位 → 日志追踪 → 数据流验证。

## 分层定位法

> 完整架构分层 → 读取 `project-architecture` skill 的 `references/layer-map.md`

**核心思路**：先判断现象属于哪个架构层，然后从该层入口文件开始排查。

| 现象 | 首先检查 | 日志通道 |
|------|---------|---------|
| 动画不播放/错位 | `BaseState.gd` helper, .tscn BlendTree | `animation` |
| 伤害不触发 | `HealthComponent.gd`, `HitBoxComponent.gd` | `combat` |
| 状态卡死/不切换 | `BaseStateMachine.gd`, `BaseState.gd` | `state_machine` |
| 敌人不追踪/不攻击 | `EnemyBase.gd`, `ChaseState.gd`, `AttackState.gd` | `state_machine` |
| Boss 阶段不转换 | `BossBase.gd`, health_changed 信号 | `combat` |
| 特殊技能不触发 | `SpecialSkillState.gd:can_trigger()` | `state_machine` |
| UI/关卡/碰撞/空引用 | UIManager / LevelManager / Layer-Mask / is_instance_valid | — |

## 日志排查流程

### Step 1: 开启日志通道

确认 `Core/Autoloads/debug_config.json` 中对应通道已开启：

```json
{
  "category_configs": {
    "combat": { "enabled": true, "min_level": "DEBUG" },
    "state_machine": { "enabled": true, "min_level": "DEBUG" },
    "animation": { "enabled": true, "min_level": "DEBUG" },
    "movement": { "enabled": true, "min_level": "DEBUG" }
  }
}
```

### Step 2: 添加临时日志

在怀疑的代码路径添加 DebugConfig 日志：

```gdscript
DebugConfig.debug("变量值: %s" % some_var, "", "combat")
```

### Step 3: MCP 运行 + 获取日志

```
1. mcp__godot__run_project — 运行游戏
2. 触发问题场景
3. mcp__godot__get_debug_output — 获取日志
4. 分析日志链路
5. mcp__godot__stop_project — 停止
```

### Step 4: 数据流验证

沿数据流链路逐节点检查：

**伤害不触发？检查链路**：
1. HitBox 的碰撞层是否正确（Layer 5, Mask 2）
2. HurtBox 是否在正确的 Layer 上（Layer 4, Mask 2+3）
3. HitBox 是否 enabled / monitoring = true
4. Damage Resource 是否非空
5. HealthComponent.take_damage() 是否被调用
6. health_changed 信号是否发出

**状态卡死？检查链路**：
1. 当前状态的 priority 值
2. 目标状态的 priority 值
3. can_transition_to() 返回值
4. exit() 中是否遗漏了信号断开或 timer 停止
5. from_state == current_state 验证（是否是过期请求）

## 排查检查清单

- [ ] 物理层 Layer/Mask 配置正确
- [ ] 信号是否已连接（编辑器中检查，或 _ready() 中 `.connect()`）
- [ ] `is_instance_valid()` 检查动态引用
- [ ] group 归属正确（player/enemy）
- [ ] AnimationTree.active = true
- [ ] BlendTree 节点连接完整（locomotion → loco_timescale → control_blend）
- [ ] exit() 中断开 animation_finished 信号
- [ ] Timer 在 exit() 中停止
- [ ] await 后检查节点有效性

## 详细问题速查

需要具体问题的排查步骤，读取 `references/common-issues.md`。
