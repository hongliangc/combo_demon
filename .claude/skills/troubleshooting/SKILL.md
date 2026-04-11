---
name: troubleshooting
description: "Debug and troubleshoot Combo Demon issues. Use when encountering bugs, errors, unexpected behavior, state machine freezes, damage not triggering, animation glitches, or any runtime problem. Triggers on: bug, error, fix, debug, not working, broken, stuck, crash, freeze, issue, problem, troubleshoot."
---

# 问题排查指南

## 分层定位

| 现象 | 首先检查 | 日志通道 |
|------|---------|---------|
| 动画不播放 | BaseState helper, .tscn BlendTree | `animation` |
| 伤害不触发 | HealthComponent, HitBoxComponent | `combat` |
| 状态卡死 | BaseStateMachine, BaseState | `state_machine` |
| 敌人不追踪 | EnemyBase, ChaseState | `state_machine` |
| Boss 阶段不转换 | BossBase, health_changed | `combat` |

## 排查流程

1. **开启日志** — 确认 `debug_config.json` 对应通道 enabled
2. **添加临时日志** — `DebugConfig.debug("变量: %s" % var, "", "channel")`
3. **MCP 运行** — run_project → 触发场景 → get_debug_output → 分析 → stop_project
4. **数据流验证** — 沿链路逐节点检查（碰撞层/信号连接/is_instance_valid/优先级）

## 按需加载

具体问题速查步骤 → Read `references/common-issues.md`
