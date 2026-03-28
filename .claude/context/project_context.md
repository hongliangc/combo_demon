# Combo Demon - 项目上下文

> 架构详情见 CLAUDE.md，此文件仅记录变更历史和补充信息

## 最近更新

### 2026-03-26: 10 种新敌人特殊技能系统 ✅
- `SpecialSkillState` 基类：冷却 + 概率触发机制，ChaseState/AttackState 每帧检查 `can_trigger(distance)`
- **Group A**（扩展 AttackState，20% 概率）：Bear(地震), Cyclope(蓄力), Mouse(三连斩), Lizard(毒), Flam(自爆)
- **Group B**（独立 SpecialSkillState 节点）：Spirit(传送), Dragon(吐火球), BlueBat(俯冲), Slime(分裂), SkullBlue(寒霜新星)
- Slime.gd 继承 EnemyBase，监听 health_changed 信号在 HP<50% 时触发分裂

### 2026-03-20: Boss 状态机重构 ✅
- BossPhaseConfig Resource 替代旧三层体系
- `evaluate_combat_transition()` 统一攻击入口
- Callable combo 工厂、_boss 懒缓存、Player 缓存
- `_dispatch_attack()` 提升到 BossBaseState
- 移除 BossEnrage、BossSpecialAttack、special_attack_cooldown

### 2026-02-08: 状态机 + AnimationTree 架构 ✅
- 三层优先级: BEHAVIOR(0) < REACTION(1) < CONTROL(2)
- BaseState 内置 AnimationTree 控制方法
- ForestEnemyState 地面敌人基类

### 2026-01-19: Player 组件化重构 ✅
- 278行单体 → 119行主类 + 5个自治组件

---

**最后更新**: 2026-03-26
**项目状态**: ✅ 可运行
