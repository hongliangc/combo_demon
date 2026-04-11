# Module Registry — Combo Demon 核心类速查表

> 路径以 `res://` 为根。详细 API 直接查阅源码。

---

## 角色基类

| 类名 | 路径 | 职责 |
|---|---|---|
| `BaseCharacter` | `Core/Characters/BaseCharacter.gd` | 所有角色通用基类：生命系统、HurtBox 连接、伤害信号转发 |
| `EnemyBase` | `Core/Characters/EnemyBase.gd` | 敌人基类：AI 参数配置、状态机集成、精灵方向、死亡动画 |
| `PlayerBase` | `Core/Characters/PlayerBase.gd` | 玩家基类：重力系统、五大组件引用、技能调度 (pending_combat_skill) |
| `BossBase` | `Core/Characters/BossBase.gd` | Boss 基类：三阶段生命、攻击冷却、巡逻点工具、阶段转换特效 |

**继承链**: `CharacterBody2D` → `BaseCharacter` → `EnemyBase` / `PlayerBase` / `BossBase`

**BossBase 枚举**: `Phase { PHASE_1, PHASE_2, PHASE_3 }`
**BossBase 信号**: `phase_changed(new_phase: int)`, `boss_defeated()`

**EnemyBase @export**: `detection_radius`, `chase_radius`, `follow_radius`, `chase_speed`, `wander_speed`, `min/max_wander_time`

---

## 状态机

| 类名 | 路径 | 职责 |
|---|---|---|
| `BaseStateMachine` | `Core/StateMachine/BaseStateMachine.gd` | 通用状态机：状态注册、优先级转换、owner/target 注入 |
| `EnemyStateMachine` | `Core/StateMachine/EnemyStateMachine.gd` | 敌人状态机：BASIC/RANGED/BOSS 预设，自动创建标准状态 |
| `BaseState` | `Core/StateMachine/BaseState.gd` | 状态基类：生命周期、AnimationTree 控制、Timer、移动工具、优先级 |

**继承链**: `Node` → `BaseStateMachine` → `EnemyStateMachine`；`Node` → `BaseState`

**BaseState 枚举**: `StatePriority { BEHAVIOR=0, REACTION=1, CONTROL=2 }`
**BaseState 信号**: `transitioned(from_state: BaseState, new_state_name: String)`
**BaseState 关键方法**: `enter/exit/process_state/physics_process_state`, `on_damaged`, `transition_to`, `force_transition`, `can_transition_to`, `set_locomotion`, `enter/exit_control_state`, `fire_attack/abort_attack`, `start/stop_timer`, `move_toward/away_from_target`, `try_attack/try_chase`

**EnemyStateMachine 枚举**: `Preset { CUSTOM, BASIC, RANGED, BOSS }`
**EnemyStateMachine 方法**: `force_stun(duration)`, `force_hit()`, `force_knockback()`, `is_controlled()`, `can_act()`

---

## CommonStates（通用状态）

| 类名 | 路径 | 优先级 | 职责 |
|---|---|---|---|
| `IdleState` | `Core/StateMachine/CommonStates/IdleState.gd` | BEHAVIOR | 随机等待后转 wander，持续检测玩家 |
| `WanderState` | `Core/StateMachine/CommonStates/WanderState.gd` | BEHAVIOR | 随机方向移动后转 idle，检测玩家 |
| `ChaseState` | `Core/StateMachine/CommonStates/ChaseState.gd` | BEHAVIOR | 追击目标，超出放弃，进入 follow_radius 转攻击 |
| `AttackState` | `Core/StateMachine/CommonStates/AttackState.gd` | BEHAVIOR | fire_attack() 循环攻击，支持 SpecialSkill 插队 |
| `HitState` | `Core/StateMachine/CommonStates/HitState.gd` | REACTION | 受击硬直，播放 hit 动画后自动恢复 |
| `KnockbackState` | `Core/StateMachine/CommonStates/KnockbackState.gd` | REACTION | 击退物理模拟，velocity 摩擦减速后恢复 |
| `StunState` | `Core/StateMachine/CommonStates/StunState.gd` | CONTROL | 眩晕锁定，不可打断，定时恢复 |
| `SpecialSkillState` | `Core/StateMachine/CommonStates/SpecialSkillState.gd` | BEHAVIOR | 特技基类：冷却+概率触发，子类重写 execute_skill |

**SpecialSkillState @export**: `skill_cooldown`, `skill_probability`, `recheck_delay`
**SpecialSkillState 关键方法**: `can_trigger(distance)`, `execute_skill()`, `finish_skill()`, `_check_condition(distance)`, `_apply_damage_to_player(damage)`, `_make_damage(amount, knockback)`

---

## 组件

| 类名 | 路径 | 职责 |
|---|---|---|
| `HealthComponent` | `Core/Components/HealthComponent.gd` | 生命值、受伤、无敌、治疗、死亡、伤害数字 |
| `HitBoxComponent` | `Core/Components/HitBoxComponent.gd` | 攻击碰撞区：检测 HurtBox 并调用 take_damage |
| `HurtBoxComponent` | `Core/Components/HurtBoxComponent.gd` | 受击碰撞区：接收伤害并发出 damaged 信号 |
| `MovementComponent` | `Core/Components/MovementComponent.gd` | 输入、加速度、跳跃物理、精灵/HitBox 翻转 |
| `CombatComponent` | `Core/Components/CombatComponent.gd` | 伤害类型列表管理，供 HitBox 读取当前伤害类型 |

**继承**: `Node` → `HealthComponent/MovementComponent/CombatComponent`；`Area2D` → `HitBoxComponent/HurtBoxComponent`

**HealthComponent 信号**: `health_changed(current, maximum)`, `damaged(damage, attacker_position)`, `died()`
**HealthComponent 方法**: `take_damage`, `heal`, `die`, `set_invincible(enabled, duration)`, `get_health_percent`, `reset_health`, `is_character_alive`

**MovementComponent 信号**: `direction_changed`, `movement_ability_changed`, `velocity_changed`, `sprite_flipped`, `jump_started`, `jump_apex_reached`, `landed`
**MovementComponent 方法**: `set_movement_enabled`, `perform_jump(is_air_jump)`, `apply_dash_speed`, `set_velocity`, `set/get_facing_direction`, `is_grounded`, `is_falling_down`

**CombatComponent 信号**: `damage_type_changed(new_damage: Damage)`
**CombatComponent 方法**: `switch_to_physical/knockup/special_attack()`, `switch_to_damage_type(index)`, `get_current_damage()`

---

## 资源

| 类名 | 路径 | 职责 |
|---|---|---|
| `Damage` | `Core/Resources/Damage.gd` | 伤害数据容器：伤害值范围、特效列表、随机化 |
| `AttackEffect` | `Core/Resources/AttackEffect.gd` | 攻击特效基类，子类实现具体逻辑 |

**Damage 属性**: `amount`, `min_amount`, `max_amount`, `effects: Array[AttackEffect]`
**Damage 方法**: `apply_effects`, `has_effect`, `randomize_damage`, `get_effects_description`

**AttackEffect 子类**: `StunEffect`, `KnockUpEffect`, `KnockBackEffect`, `GatherEffect`, `ForceStunEffect`
**AttackEffect 方法**: `apply_effect(target, damage_source_position)`, `get_description()`

---

## Autoloads

| 类名 | 路径 | 职责 |
|---|---|---|
| `GameManager` | `Core/Autoloads/GameManager.gd` | 游戏状态机 (MENU→PLAYING→GAME_OVER)、角色选择、场景切换 |
| `LevelManager` | `Core/Autoloads/LevelManager.gd` | 多关卡进度、收集物统计、目标检查、胜利/失败流程 |
| `DebugConfig` | `Core/Autoloads/DebugConfig.gd` | 结构化日志：级别/分类/路径配置，从 JSON 加载 |

**GameManager 枚举**: `GameState { MENU, CHARACTER_SELECT, PLAYING, PAUSED, GAME_OVER }`
**GameManager 信号**: `game_state_changed(old, new)`, `character_selection_completed(data)`
**GameManager 方法**: `set_selected_character`, `start_game`, `pause_game`, `resume_game`, `game_over`, `restart_game`, `has_selected_character`

**LevelManager 信号**: `level_started`, `level_completed`, `item_collected`, `objective_updated`, `boss_defeated`, `game_completed`
**LevelManager 方法**: `start_level(index)`, `complete_level`, `collect_item(type, amount)`, `on_boss_defeated`, `can_complete_level`, `has_key`, `use_key`

**DebugConfig 枚举**: `LogLevel { DEBUG=0, INFO=1, WARNING=2, ERROR=3 }`
**DebugConfig 方法**: `debug/info/warn/error(message, caller_path, category)`, `set_category_config`, `reload_config`, `set_global_enabled`, `set_global_min_level`
**DebugConfig 分类**: `"state_machine"`, `"animation"`, `"combat"`, `"movement"`
