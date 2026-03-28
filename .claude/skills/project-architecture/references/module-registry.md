# Module Registry — Combo Demon 核心类速查表

> 所有路径以 `res://` 为根。API 签名直接来自源码。

---

## 角色基类 (Character Base Classes)

### BaseCharacter
- **路径**: `Core/Characters/BaseCharacter.gd`
- **职责**: 所有角色的通用基类，集成生命系统、HurtBox 自动连接、伤害信号转发给状态机
- **继承**: `CharacterBody2D` → `BaseCharacter`
- **关键 API**:
  - `_on_character_ready() -> void` — 子类初始化钩子，在 `_ready` 末尾调用
  - `_handle_death() -> void` — 自定义死亡逻辑钩子，由 HealthComponent.died 触发
  - `_setup_health_signals() -> void` — 连接 HurtBoxComponent→HealthComponent 信号链
- **信号**:
  - `damaged(damage: Damage, attacker_position: Vector2)` — 转发给状态机（由 HealthComponent.damaged 触发）
- **依赖**: `HealthComponent`（子节点）、`HurtBoxComponent`（子节点）、`DamageNumbersAnchor`（子节点）

---

### EnemyBase
- **路径**: `Core/Characters/EnemyBase.gd`
- **职责**: 标准敌人基类，在 BaseCharacter 之上增加 AI 参数配置、状态机集成、精灵方向管理、死亡动画
- **继承**: `BaseCharacter` → `EnemyBase`
- **关键 API**:
  - `_on_enemy_ready() -> void` — 敌人特定初始化钩子（在 `_on_character_ready` 末尾调用）
  - `_update_sprite_facing() -> void` — 根据 velocity.x 翻转 Sprite2D/AnimatedSprite2D
  - `_apply_enemy_data() -> void` — 从 EnemyData 资源加载 AI 参数
  - `_play_default_death_animation() -> void` — 白闪3次+淡出的默认死亡动画（async）
- **信号**: 继承自 BaseCharacter（`damaged`）
- **依赖**: `EnemyData`（可选 @export）、`AnimationPlayer`、`AnimationTree`（可选）、`EnemyStateMachine`（可选）
- **@export 参数**:
  - `detection_radius: float = 100.0` — 检测玩家半径
  - `chase_radius: float = 200.0` — 追击放弃半径
  - `follow_radius: float = 25.0` — 攻击触发半径
  - `chase_speed: int = 75` — 追击速度
  - `wander_speed: float = 50.0` — 游荡速度
  - `min_wander_time: float = 2.5` / `max_wander_time: float = 10.0` — 游荡时间范围

---

### PlayerBase
- **路径**: `Core/Characters/PlayerBase.gd`
- **职责**: 玩家角色基类，提供重力系统、五大自治组件引用、技能调度中转（pending_combat_skill）
- **继承**: `BaseCharacter` → `PlayerBase`
- **关键 API**:
  - `_on_player_ready() -> void` — 子类初始化钩子
  - `set_pending_skill(skill_name: String, metadata: Dictionary = {}) -> void` — 设置待执行技能（Ground/Air 状态写入）
  - `consume_pending_skill() -> Dictionary` — 读取并清空待执行技能（Combat 状态消费）
  - `trigger_fall_death() -> void` — 触发坠落死亡（由 KillZone 调用）
  - `switch_to_physical() -> void` / `switch_to_knockup() -> void` / `switch_to_special_attack() -> void` — 委托 CombatComponent 切换伤害类型（动画 method track 调用）
- **信号**: 继承自 BaseCharacter（`damaged`）
- **依赖**: `MovementComponent`、`CombatComponent`、`SkillManager`（均为子节点 @onready）

---

### BossBase
- **路径**: `Core/Characters/BossBase.gd`
- **职责**: Boss 基类，提供三阶段生命系统、攻击冷却管理、巡逻点工具、阶段转换特效（无敌+击退波）
- **继承**: `BaseCharacter` → `BossBase`
- **关键 API**:
  - `_on_boss_ready() -> void` — 子类初始化钩子
  - `_on_phase_transition() -> void` — 阶段转换后的子类钩子
  - `_update_facing() -> void` — 朝向更新钩子（physics_process 中调用）
  - `check_phase_transition() -> void` — 检查并触发阶段转换（health_changed 时自动调用）
  - `change_phase(new_phase: Phase) -> void` — 执行阶段切换，触发特效和信号
  - `activate_phase_transition_effect() -> void` — 1 秒无敌 + 击退周围单位
  - `get_next_patrol_point() -> Vector2` — 循环取下一个巡逻点
  - `is_at_position(target_pos: Vector2, threshold: float = 20.0) -> bool` — 判断是否到达目标位置
- **信号**:
  - `phase_changed(new_phase: int)` — 阶段变化时发出
  - `boss_defeated()` — 死亡时发出
- **依赖**: `HealthComponent`（触发 health_changed 以检查阶段）、`AnimationPlayer`、`AnimationTree`（可选）
- **枚举**: `Phase { PHASE_1, PHASE_2, PHASE_3 }`

---

## 状态机 (State Machine)

### BaseStateMachine
- **路径**: `Core/StateMachine/BaseStateMachine.gd`
- **职责**: 通用状态机基类，管理状态注册、优先级转换、owner/target 注入，可被 Enemy/Boss/Player 复用
- **继承**: `Node` → `BaseStateMachine`
- **关键 API**:
  - `force_transition(new_state_name: String) -> void` — 强制切换状态（忽略优先级）
  - `get_current_state_name() -> String` — 返回当前状态名称
  - `is_in_state(state_name: String) -> bool` — 检查是否处于指定状态
  - `recover_from_stun() -> void` — 停止 stun timer、重置 stunned 标志、转换到 wander/idle
- **信号**: 无（通过 BaseState.transitioned 传递）
- **依赖**: `BaseState`（子节点状态）、owner 节点的 `damaged` 信号（自动连接）

---

### EnemyStateMachine
- **路径**: `Core/StateMachine/EnemyStateMachine.gd`
- **职责**: 敌人状态机模板，提供 BASIC/RANGED/BOSS 预设，自动创建标准状态节点
- **继承**: `BaseStateMachine` → `EnemyStateMachine`
- **关键 API**:
  - `force_stun(duration: float = -1.0) -> void` — 强制进入眩晕状态（可覆盖时长）
  - `force_hit() -> void` — 强制进入受击状态
  - `force_knockback() -> void` — 强制进入击退状态
  - `is_controlled() -> bool` — 是否处于控制层状态（CONTROL 优先级）
  - `can_act() -> bool` — 是否可以行动（BEHAVIOR 优先级）
- **信号**: 继承自 BaseStateMachine
- **依赖**: CommonStates 脚本路径（auto_create_states 为 true 时动态加载）
- **枚举**: `Preset { CUSTOM, BASIC, RANGED, BOSS }`

---

### BaseState
- **路径**: `Core/StateMachine/BaseState.gd`
- **职责**: 所有状态的通用基类，提供生命周期、AnimationTree 控制、Timer 管理、移动工具方法和优先级系统
- **继承**: `Node` → `BaseState`
- **关键 API**:
  - `enter() -> void` — 进入状态（子类重写）
  - `exit() -> void` — 退出状态（子类重写）
  - `process_state(delta: float) -> void` — 状态的 _process（子类重写）
  - `physics_process_state(delta: float) -> void` — 状态的 _physics_process（子类重写）
  - `on_damaged(damage: Damage, attacker_position: Vector2) -> void` — 受伤回调，自动路由至 stun/knockback/hit 状态
  - `can_transition_to(new_state: BaseState) -> bool` — 优先级检查
  - `set_locomotion(blend: Vector2) -> void` — 设置 AnimationTree locomotion 混合位置
  - `set_locomotion_state(state_name: String) -> void` — 切换 locomotion StateMachine 节点的动画
  - `enter_control_state(state_name: String) -> void` — 切换到 control 层（blend_amount=1.0）
  - `exit_control_state() -> void` — 返回 locomotion 层（blend_amount=0.0）
  - `fire_attack() -> void` — 触发 attack_oneshot
  - `abort_attack() -> void` — 中止 attack_oneshot
  - `set_locomotion_time_scale(scale: float) -> void` — 设置 locomotion 动画速度
  - `set_control_time_scale(scale: float) -> void` — 设置 control 动画速度
  - `start_timer(duration: float, callback: Callable = Callable(), one_shot: bool = true) -> Timer` — 懒创建复用 Timer
  - `stop_timer() -> void` — 停止定时器
  - `decide_next_state() -> void` — 根据目标距离决定转换到 chase 还是 idle
  - `transition_to(state_name: String) -> bool` — 安全状态转换（检查目标状态存在性）
  - `move_toward_target(speed: float, call_move_slide: bool = true) -> void` — 向目标移动
  - `move_away_from_target(speed: float, call_move_slide: bool = true) -> void` — 远离目标移动
  - `get_distance_to_target() -> float` — 获取到目标的距离
  - `try_attack(radius: float = -1.0) -> bool` — 尝试转换到攻击状态
  - `try_chase(radius: float = -1.0) -> bool` — 尝试转换到追击状态
- **信号**:
  - `transitioned(from_state: BaseState, new_state_name: String)` — 状态转换请求
- **依赖**: `BaseStateMachine`（注入 `state_machine`、`owner_node`、`target_node`）
- **枚举**: `StatePriority { BEHAVIOR = 0, REACTION = 1, CONTROL = 2 }`

---

## CommonStates（通用状态）

### IdleState
- **路径**: `Core/StateMachine/CommonStates/IdleState.gd`
- **职责**: 通用待机状态，随机等待后转换到 wander，期间持续检测玩家进入追击/攻击
- **继承**: `BaseState` → `IdleState`
- **关键 API**: 继承 BaseState 生命周期；`_on_idle_timeout() -> void` — 定时超时回调
- **信号**: 继承 `transitioned`
- **依赖**: 无额外依赖
- **@export 参数**: `min_idle_time: float = 1.0`、`max_idle_time: float = 3.0`、`next_state_on_timeout: String = "wander"`

---

### WanderState
- **路径**: `Core/StateMachine/CommonStates/WanderState.gd`
- **职责**: 通用游荡状态，随机方向移动一段时间后转换到 idle，期间检测玩家进入追击
- **继承**: `BaseState` → `WanderState`
- **关键 API**: 继承 BaseState 生命周期；`_on_wander_timeout() -> void` — 定时超时回调
- **信号**: 继承 `transitioned`
- **依赖**: owner 的 `wander_speed`、`min_wander_time`、`max_wander_time` 属性（动态读取）
- **@export 参数**: `min_wander_time: float = 2.0`、`max_wander_time: float = 5.0`、`next_state_on_timeout: String = "idle"`

---

### ChaseState
- **路径**: `Core/StateMachine/CommonStates/ChaseState.gd`
- **职责**: 通用追击状态，向目标移动，超出 chase_radius 放弃，进入 follow_radius 转攻击，支持 SpecialSkill 插队
- **继承**: `BaseState` → `ChaseState`
- **关键 API**: 继承 BaseState 生命周期；`_update_animation_locomotion() -> void` — 更新 blend_position
- **信号**: 继承 `transitioned`
- **依赖**: owner 的 `chase_speed`、`chase_radius`、`follow_radius` 属性；`SpecialSkillState`（可选，通过状态机查找）

---

### AttackState
- **路径**: `Core/StateMachine/CommonStates/AttackState.gd`
- **职责**: 通用攻击状态，触发 fire_attack()，按 attack_interval 间隔循环攻击，支持 SpecialSkill 插队和自定义攻击钩子
- **继承**: `BaseState` → `AttackState`
- **关键 API**:
  - `perform_attack() -> void` — 执行攻击（使用 AttackComponent 或调用 on_custom_attack）
  - `on_custom_attack() -> void` — 自定义攻击钩子（子类重写）
- **信号**: 继承 `transitioned`
- **依赖**: `AttackComponent`（可选，use_attack_component=true 时）；`SpecialSkillState`（可选）
- **@export 参数**: `attack_interval: float = 3.0`

---

### HitState
- **路径**: `Core/StateMachine/CommonStates/HitState.gd`
- **职责**: 受击硬直状态（REACTION 层），播放 hit 动画，短暂停顿后自动恢复，支持连续受伤重置计时
- **继承**: `BaseState` → `HitState`
- **关键 API**: 继承 BaseState 生命周期；`on_damaged` 重写——可升级至 stun/knockback 或重置计时
- **信号**: 继承 `transitioned`
- **依赖**: AnimationTree（enter_control_state("hit")）
- **@export 参数**: `hit_duration: float = 0.2`、`reset_on_damage: bool = true`

---

### KnockbackState
- **路径**: `Core/StateMachine/CommonStates/KnockbackState.gd`
- **职责**: 击退物理模拟状态（REACTION 层），对 velocity 应用摩擦减速，低于阈值或碰墙后恢复
- **继承**: `BaseState` → `KnockbackState`
- **关键 API**: 继承 BaseState 生命周期；`on_damaged` 重写——可升级至 stun
- **信号**: 继承 `transitioned`
- **依赖**: owner 必须是 `CharacterBody2D`（直接操作 velocity）
- **@export 参数**: `friction: float = 5.0`、`min_velocity: float = 10.0`

---

### StunState
- **路径**: `Core/StateMachine/CommonStates/StunState.gd`
- **职责**: 眩晕锁定状态（CONTROL 层，不可被打断），锁定移动，定时自动恢复，支持击退速度自然减速
- **继承**: `BaseState` → `StunState`
- **关键 API**: 继承 BaseState 生命周期；`on_damaged` 重写——击退/击飞时重置计时
- **信号**: 继承 `transitioned`
- **依赖**: AnimationTree（enter_control_state("stunned")）；owner 的 `stunned` 属性（标志位）
- **@export 参数**: `stun_duration: float = 1.0`、`stun_anim_speed: float = 1.0`、`knockback_friction: float = 8.0`

---

### SpecialSkillState
- **路径**: `Core/StateMachine/CommonStates/SpecialSkillState.gd`
- **职责**: 特殊技能状态基类（BEHAVIOR 层），提供冷却+概率触发机制，子类重写 _check_condition 和 execute_skill
- **继承**: `BaseState` → `SpecialSkillState`
- **关键 API**:
  - `can_trigger(distance: float) -> bool` — 外部（Chase/Attack）检查冷却+概率是否可触发
  - `execute_skill() -> void` — 技能执行逻辑（子类重写，可用 await，完成后必须调用 finish_skill）
  - `finish_skill() -> void` — 重置冷却，转换回 chase
  - `_check_condition(distance: float) -> bool` — 子类重写：自定义触发条件
  - `_apply_damage_to_player(damage: Damage) -> void` — 对玩家 HurtBoxComponent 施加伤害
  - `_make_damage(amount: float, knockback: float = 0.0) -> Damage` — 创建带击退的伤害对象
- **信号**: 继承 `transitioned`
- **依赖**: target_node 的 `HurtBoxComponent`（_apply_damage_to_player 使用）
- **@export 参数**: `skill_cooldown: float = 8.0`、`skill_probability: float = 0.2`、`recheck_delay: float = 1.0`

---

## 组件 (Components)

### HealthComponent
- **路径**: `Core/Components/HealthComponent.gd`
- **职责**: 管理角色生命值、受伤、无敌、治疗、死亡，触发伤害数字显示和攻击特效
- **继承**: `Node` → `HealthComponent`
- **关键 API**:
  - `take_damage(damage_data: Damage, attacker_position: Vector2 = Vector2.ZERO) -> void` — 接收伤害入口
  - `heal(amount: float) -> void` — 治疗
  - `die() -> void` — 触发死亡流程
  - `set_invincible(enabled: bool, duration: float = 0.0) -> void` — 设置无敌（duration=0 为永久）
  - `get_health_percent() -> float` — 当前血量百分比
  - `reset_health() -> void` — 重置满血（复活用）
  - `is_character_alive() -> bool` — 存活检查
- **信号**:
  - `health_changed(current: float, maximum: float)` — 血量变化（血条 UI 更新）
  - `damaged(damage: Damage, attacker_position: Vector2)` — 受伤（状态机响应）
  - `died()` — 死亡
- **依赖**: `DamageNumbers`（Autoload）、`AttackEffect`（apply_effect）

---

### HitBoxComponent
- **路径**: `Core/Components/HitBoxComponent.gd`
- **职责**: 攻击碰撞区域，area_entered 时检测 HurtBoxComponent 并调用 take_damage
- **继承**: `Area2D` → `HitBoxComponent`
- **关键 API**:
  - `update_attack() -> void` — 更新伤害（默认调用 damage.randomize_damage()，子类可重写）
  - `get_attacker_position() -> Vector2` — 获取攻击者位置（子类可重写）
- **信号**: 无（通过直接调用 HurtBoxComponent.take_damage 传递伤害）
- **依赖**: `Damage`（@export）、`HurtBoxComponent`（运行时碰撞检测）

---

### HurtBoxComponent
- **路径**: `Core/Components/HurtBoxComponent.gd`
- **职责**: 受击碰撞区域，接收 HitBoxComponent 的调用并向外发出 damaged 信号
- **继承**: `Area2D` → `HurtBoxComponent`
- **关键 API**:
  - `take_damage(damage: Damage, attacker_position: Vector2 = Vector2.ZERO) -> void` — 接收伤害并发出信号
- **信号**:
  - `damaged(damage: Damage, attacker_position: Vector2)` — 连接到 HealthComponent.take_damage
- **依赖**: `Damage`（数据类）

---

### MovementComponent
- **路径**: `Core/Components/MovementComponent.gd`
- **职责**: 自治移动组件，处理输入、加速度、跳跃物理、精灵翻转和 HitBox 翻转
- **继承**: `Node` → `MovementComponent`
- **关键 API**:
  - `set_movement_enabled(enabled: bool) -> void` — 启用/禁用移动能力
  - `perform_jump(is_air_jump: bool = false) -> void` — 执行跳跃
  - `apply_dash_speed(speed: float) -> void` — 应用冲刺速度（沿 last_face_direction）
  - `set_velocity(velocity: Vector2) -> void` — 强制设置速度（击飞用）
  - `set_facing_direction(direction: Vector2) -> void` — 强制设置朝向
  - `get_facing_direction() -> Vector2` — 获取当前朝向
  - `is_grounded() -> bool` — 是否在地面
  - `is_falling_down() -> bool` — 是否正在下落
- **信号**:
  - `direction_changed(new_direction: Vector2)`
  - `movement_ability_changed(can_move: bool)`
  - `velocity_changed(velocity: Vector2)`
  - `sprite_flipped(flip_h: bool)`
  - `jump_started()`、`jump_apex_reached()`、`landed()`
- **依赖**: owner 必须是 `CharacterBody2D`

---

### CombatComponent
- **路径**: `Core/Components/CombatComponent.gd`
- **职责**: 伤害类型管理，维护 damage_types 列表，供 HitBox 读取当前伤害类型
- **继承**: `Node` → `CombatComponent`
- **关键 API**:
  - `switch_to_physical() -> void` — 切换到物理伤害（索引 0）
  - `switch_to_knockup() -> void` — 切换到击飞伤害（索引 1）
  - `switch_to_special_attack() -> void` — 切换到特殊攻击伤害（索引 2）
  - `switch_to_damage_type(index: int) -> void` — 按索引切换
  - `get_current_damage() -> Damage` — 获取当前伤害类型
- **信号**:
  - `damage_type_changed(new_damage: Damage)` — 伤害类型切换时发出
- **依赖**: `Damage`（@export Array[Damage] damage_types）

---

## 资源 (Resources)

### Damage
- **路径**: `Core/Resources/Damage.gd`
- **职责**: 伤害数据容器，存储伤害值范围和攻击特效列表，提供随机化和特效查询
- **继承**: `Resource` → `Damage`
- **关键 API**:
  - `apply_effects(enemy: Node, damage_source_position: Vector2) -> void` — 按顺序应用所有特效
  - `has_effect(effect_type) -> bool` — 检查特效（传字符串类名或 Script）
  - `randomize_damage() -> void` — 在 min_amount~max_amount 范围内随机化 amount
  - `get_effects_description() -> String` — 返回所有特效描述文本
- **信号**: 无
- **依赖**: `AttackEffect`（effects 数组元素）
- **属性**: `amount: float`、`min_amount: float`、`max_amount: float`、`effects: Array[AttackEffect]`

---

### AttackEffect
- **路径**: `Core/Resources/AttackEffect.gd`
- **职责**: 攻击特效基类，定义 apply_effect 接口，子类实现击飞/击退/眩晕/聚集等具体逻辑
- **继承**: `Resource` → `AttackEffect`
- **关键 API**:
  - `apply_effect(target: CharacterBody2D, damage_source_position: Vector2) -> void` — 应用特效（子类重写）
  - `get_description() -> String` — 获取特效描述（子类重写）
- **信号**: 无
- **依赖**: 无（子类依赖具体目标类型）
- **已知子类**: `StunEffect`、`KnockUpEffect`、`KnockBackEffect`、`GatherEffect`、`ForceStunEffect`

---

## 服务 / Autoloads

### GameManager
- **路径**: `Core/Autoloads/GameManager.gd`
- **职责**: 游戏状态机（MENU→CHARACTER_SELECT→PLAYING→PAUSED→GAME_OVER），管理角色选择和场景切换
- **继承**: `Node` → `GameManager`（Autoload 单例）
- **关键 API**:
  - `set_selected_character(character_data: Resource) -> void` — 选择角色
  - `start_game() -> void` — 开始游戏（委托 LevelManager）
  - `pause_game() -> void` / `resume_game() -> void`
  - `game_over() -> void` — 显示 GameOver UI
  - `restart_game() -> void` — 重载当前场景
  - `has_selected_character() -> bool`
- **信号**:
  - `game_state_changed(old_state: GameState, new_state: GameState)`
  - `character_selection_completed(character_data: Resource)`
- **依赖**: `LevelManager`（start_game 委托）、`UIManager`（场景切换）
- **枚举**: `GameState { MENU, CHARACTER_SELECT, PLAYING, PAUSED, GAME_OVER }`

---

### LevelManager
- **路径**: `Core/Autoloads/LevelManager.gd`
- **职责**: 多关卡进度管理，负责关卡加载、收集物统计、目标检查、胜利/失败流程
- **继承**: `Node` → `LevelManager`（Autoload 单例）
- **关键 API**:
  - `start_level(level_index: int) -> void` — 加载指定关卡（含场景切换）
  - `complete_level() -> void` — 完成当前关卡，自动推进或触发通关
  - `collect_item(item_type: String, amount: int = 1) -> void` — 记录收集物（"treasure"/"key"/"coin"）
  - `on_boss_defeated() -> void` — Boss 死亡回调，延迟后 complete_level
  - `can_complete_level() -> bool` — 检查当前关卡目标是否达成
  - `has_key() -> bool` / `use_key() -> bool` — 钥匙查询与消耗
- **信号**:
  - `level_started(level_index: int)`
  - `level_completed(level_index: int)`
  - `item_collected(item_type: String, count: int)`
  - `objective_updated(objective_type: String, current: int, required: int)`
  - `boss_defeated()`
  - `game_completed()`
- **依赖**: `UIManager`（场景切换和胜利提示）

---

### DebugConfig
- **路径**: `Core/Autoloads/DebugConfig.gd`
- **职责**: 结构化日志系统，支持日志级别、路径配置、分类配置、文件输出，从 JSON 配置文件加载
- **继承**: `Node` → `DebugConfig`（Autoload 单例）
- **关键 API**:
  - `debug(message: String, caller_path: String = "", category: String = "") -> void`
  - `info(message: String, caller_path: String = "", category: String = "") -> void`
  - `warn(message: String, caller_path: String = "", category: String = "") -> void`
  - `error(message: String, caller_path: String = "", category: String = "") -> void`
  - `set_category_config(category: String, enabled: bool, min_level: LogLevel = LogLevel.DEBUG) -> void` — 运行时配置分类
  - `reload_config() -> void` — 重新加载 debug_config.json
  - `set_global_enabled(enabled: bool) -> void`
  - `set_global_min_level(level: LogLevel) -> void`
- **信号**: 无
- **依赖**: `res://Core/Autoloads/debug_config.json`（配置文件）
- **枚举**: `LogLevel { DEBUG = 0, INFO = 1, WARNING = 2, ERROR = 3 }`
- **常用分类**: `"state_machine"`、`"animation"`、`"combat"`、`"movement"`
