# 四层架构详细说明

## Framework 层（核心框架）

与业务无关的通用游戏开发能力，可跨项目复用。

### 状态机框架 — `Core/StateMachine/`
- `BaseStateMachine.gd` — 通用状态机：owner/target 注入、优先级转换、信号连接、AnimationTree 缓存
- `BaseState.gd` — 状态基类：生命周期（enter/exit/process_state/physics_process_state）、AnimationTree helper、Timer 管理、移动工具方法、优先级判定
- `EnemyStateMachine.gd` — 敌人预设状态机：BASIC/RANGED/BOSS 三种预设，自动创建 CommonStates
- `CommonStates/IdleState.gd` — 待机状态：随机等待时间 → wander 或 chase
- `CommonStates/WanderState.gd` — 巡游状态：随机方向移动 → idle 或 chase
- `CommonStates/ChaseState.gd` — 追击状态：向目标移动，检查攻击范围和特殊技能触发
- `CommonStates/AttackState.gd` — 攻击状态：播放攻击动画，检查自定义攻击和特殊技能
- `CommonStates/HitState.gd` — 受击状态（REACTION 优先级）：播放受击动画 → 恢复
- `CommonStates/KnockbackState.gd` — 击退状态（REACTION）：应用击退速度 → 减速 → 恢复
- `CommonStates/StunState.gd` — 眩晕状态（CONTROL 优先级）：锁定移动 → 定时恢复
- `CommonStates/SpecialSkillState.gd` — 特殊技能基类：冷却 + 概率触发机制，子类重写 execute_skill()

### 组件系统 — `Core/Components/`
- `HealthComponent.gd` — 生命值管理：take_damage、heal、die、无敌、伤害数字显示
- `HitBoxComponent.gd` — 攻击判定：area_entered → 对 HurtBox 发送 damage
- `HurtBoxComponent.gd` — 受击判定：接收 damage → 发出 damaged 信号
- `MovementComponent.gd` — 移动组件：加速/减速、跳跃、朝向控制
- `CombatComponent.gd` — 战斗组件：伤害类型切换（Physical/KnockUp/Special）
- `SkillManager.gd` — 技能管理：特殊攻击编排（扇形检测 → 移动 → 动画 → 聚集）
- `AttackComponent.gd` — 攻击状态追踪
- `FollowCamera.gd` — 跟随相机

### 资源定义 — `Core/Resources/`
- `Damage.gd` — 伤害 Resource：amount + effects 数组，组合模式
- `AttackEffect.gd` — 效果基类：apply_effect(target, source_pos)、get_description()
- `KnockBackEffect.gd` — 击退效果：施加远离方向的速度
- `KnockUpEffect.gd` — 击飞效果：施加向上速度
- `StunEffect.gd` — 眩晕效果：锁定移动指定时间
- `ForceStunEffect.gd` — 强制眩晕：锁定移动 + 强制方向推
- `GatherEffect.gd` — 聚集效果：将目标拉向聚集点
- `CharacterData.gd` — 角色元数据：name、scene_path、stats
- `EnemyData.gd` — 敌人数据：AI 参数驱动配置

### 角色基类 — `Core/Characters/`
- `BaseCharacter.gd` — 角色基类：HurtBox↔HealthComponent 自动连接、damaged 信号转发
- `EnemyBase.gd` — 敌人基类：AI 参数(@export)、精灵管理、EnemyData 驱动、死亡动画
- `PlayerBase.gd` — 玩家基类：重力、5 个自治组件引用、pending_combat_skill
- `BossBase.gd` — Boss 基类：三阶段系统、巡逻点、冷却管理、相位转换特效

### 视觉效果 — `Core/Effects/`
- `AfterImageEffect.gd`, `GhostExpandEffect.gd`, `VortexEffect.gd`, `GatherTrailEffect.gd`, `EnemyHighlightEffect.gd`, `VfxHelper.gd`

### 数据文件 — `Core/Data/`
- `Characters/*.tres` — 角色数据（Hahashin, MageLocked, WarriorLocked）
- `SkillBook/*.tres` — 伤害数据（Physical, SpecialAttack, KnockBack, KnockUp）

---

## Services 层（全局服务）

跨场景的 Autoload 单例，通过全局名称访问。

- `GameManager.gd` — 游戏状态机（MENU/SELECT/PLAYING/OVER）、角色选择、场景切换
- `LevelManager.gd` — 关卡加载、目标追踪（treasures/keys/boss）、进度管理
- `UIManager.gd`（`Scenes/UI/Core/UIManager.gd`）— 6 层 UI 管理、场景过渡动画
- `SoundManager.gd` — 音频播放控制
- `TimeManager.gd` — 子弹时间、全局时间缩放
- `DamageNumbers.gd` — 浮动伤害数字显示
- `DebugConfig.gd` — 结构化日志：级别(DEBUG/INFO/WARNING/ERROR)、路径过滤、分类过滤、文件输出
- `BulletPool.gd` — 子弹对象池
- `EnemySpawner.gd` — 敌人生成管理

---

## Business 层（业务逻辑）

具体角色和关卡的实现代码。

### 敌人实现 — `Scenes/Characters/Enemies/`
- `Bear/`, `BlueBat/`, `Cyclope/`, `Dragon/`, `Flam/`, `Lizard/`, `Mouse/`, `SkullBlue/`, `Slime/`, `Spirit/` — 各敌人场景和脚本
- `boss/` — Boss 实现：Scripts/States/（7 个 Boss 状态）、Scripts/BossAttackManager.gd、Scripts/BossPhaseConfig.gd、Scripts/BossComboAttack.gd、Attacks/（BossAoe、BossLaser、BossProjectile）

### 玩家角色 — `Scenes/Characters/`
- 玩家角色场景和状态

### 关卡脚本 — `Scenes/Levels/`
- `Level1_Adventure/` — 收集宝物关卡
- `Level2_Maze/` — 找钥匙迷宫关卡
- `Level3_Boss/` — Boss 战关卡
- `Components/Traps/` — 陷阱系统（规划中）

---

## Presentation 层（表现层）

场景文件、UI、美术音频资源。

- `Scenes/**/*.tscn` — 所有场景文件（节点组合、属性配置）
- `Scenes/UI/` — UI 界面（菜单、HUD、血条、游戏结束等）
- `Assets/Art/` — 精灵、纹理、Tileset
- `Assets/Sound/` — 音效、BGM

---

## 层间通信规则

### 允许的调用方向
- **Presentation → Business**：.tscn 引用 Business 脚本（节点挂载）
- **Business → Framework**：Business 脚本继承/调用 Framework 基类和组件
- **任意层 → Services**：通过 Autoload 全局名直接访问（`GameManager`, `DebugConfig` 等）

### 禁止的调用方向
- **Framework → Business**：Framework 不能 import/引用任何 Business 代码
- **Framework → Presentation**：Framework 不能引用特定 .tscn 或 UI
- **Services → Business**（直接操作）：Services 不直接操作具体角色，通过信号或 group 间接通信

### 新增代码放置规则
| 代码类型 | 放置位置 |
|---------|---------|
| 可跨角色复用的基类/组件 | Framework: `Core/` |
| 全局跨场景的服务 | Services: `Core/Autoloads/` |
| 特定敌人/Boss 的 AI 逻辑 | Business: `Scenes/Characters/Enemies/角色名/` |
| 特定关卡的脚本 | Business: `Scenes/Levels/关卡名/` |
| 场景文件/UI/资源 | Presentation: `Scenes/`, `Assets/` |
