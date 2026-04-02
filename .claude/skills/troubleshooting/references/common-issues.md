# 常见问题速查表

按模块分类，格式：**现象** → **原因** → **修复步骤**

---

## 状态机问题

### 状态卡在 hit/stun 不恢复
**原因**：exit() 中未停止 timer 或未断开 animation_finished 信号，导致状态无法正常退出。
**修复**：
1. 检查 HitState/StunState 的 `exit()` 方法
2. 确认调用了 `stop_timer()` 和 `exit_control_state()`
3. 确认 `animation_finished` 信号在 exit() 中 disconnect
4. 检查 `decide_next_state()` 是否正确调用

### 状态切换被拒绝（优先级不足）
**原因**：BEHAVIOR(0) 无法打断 CONTROL(2) 或 REACTION(1) 状态。
**修复**：
1. 查看日志：`[StateMachine] Rejected: X -> Y (priority: N vs M)`
2. 检查目标状态的 `priority` 属性设置
3. 如果是恢复场景，使用 `force_transition()` 或确保从高优先级状态主动 `transition_to()` 低优先级

### 多个状态同时发出 transitioned 竞态
**原因**：多个触发源（timer + 伤害）在同一帧发出切换请求，第二个被 `from_state != current_state` 过滤。
**修复**：
1. 这是正常的防护机制，检查日志确认是否有 `Ignoring transition from X (current=Y)`
2. 如果第二个切换确实需要生效，检查触发时机，确保高优先级的后发出

---

## 伤害系统问题

### 伤害数字不显示
**原因**：DamageNumbersAnchor 节点缺失或全局位置错误。
**修复**：
1. 检查角色场景中是否有 `DamageNumbersAnchor` (Node2D) 子节点
2. 确认 DamageNumbersAnchor 的 position 在角色头顶（负 Y 偏移）
3. 确认 `DamageNumbers` Autoload 已注册

### 击退/眩晕效果不生效
**原因**：Damage Resource 的 effects 数组为空或效果类型配置错误。
**修复**：
1. 检查 .tres 文件的 `effects` 数组是否包含正确的 AttackEffect 子类
2. 确认效果类 `apply_effect()` 方法正确实现
3. 添加日志：`DebugConfig.debug("effects: %s" % damage.get_effects_description(), "", "combat")`

### 无敌状态不结束
**原因**：`set_invincible(true, 0.0)` 传了 0 duration，导致永久无敌。
**修复**：
1. 确保 `set_invincible(enabled, duration)` 的 duration > 0
2. 检查是否有其他代码再次设置了 is_invincible = true

### 一次攻击多次触发伤害
**原因**：HitBox 持续激活，每帧都检测到碰撞。
**修复**：
1. 检查 HitBox 是否在攻击动画结束后 disable（`monitoring = false`）
2. 检查是否有 hit_targets 数组防止同一目标多次受伤
3. 确认攻击动画帧中正确设置了 HitBox 的 enable/disable

---

## 动画问题

### control_blend 不切回 locomotion
**原因**：hit/stun 状态的 `exit()` 中未调用 `exit_control_state()`。
**修复**：
1. 在 HitState/StunState 的 `exit()` 中添加 `exit_control_state()`
2. 确认 exit() 确实被调用（添加日志确认）

### BlendSpace2D 位置无效
**原因**：`blend_position` 参数路径错误或 BlendSpace2D 配置问题。
**修复**：
1. 检查 AnimationTree 中参数路径是否为 `parameters/locomotion/blend_position`
2. 确认 BlendSpace2D 中的动画点配置正确（idle 在原点，run 在 (1,1) 等）
3. 打印调试：`DebugConfig.debug("blend: %s" % tree.get("parameters/locomotion/blend_position"), "", "animation")`

### 动画速度异常
**原因**：loco_timescale 或 ctrl_timescale 被设置后未重置。
**修复**：
1. 在状态的 `exit()` 中调用 `reset_time_scale()`
2. 检查是否有其他状态设置了 time scale 但未在退出时重置

---

## 物理碰撞问题

### HitBox/HurtBox 不检测碰撞
**原因**：Layer/Mask 未正确配置。
**修复**：
1. 确认物理层配置：
   - Player: Layer 2
   - Enemy: Layer 4
   - Player Projectile: Layer 3
   - Enemy Projectile: Layer 5
2. HurtBox（受击方）：设置自身 Layer 为角色层，Mask 为对方攻击层
3. HitBox（攻击方）：设置自身 Layer 为攻击层，Mask 为对方角色层
4. 确认 Area2D 的 `monitoring` 和 `monitorable` 都为 true

### 穿墙
**原因**：CollisionShape2D 尺寸不匹配或未调用 move_and_slide()。
**修复**：
1. 确认 CharacterBody2D 有正确的 CollisionShape2D
2. 确认 `_physics_process()` 中调用了 `move_and_slide()`
3. 检查移动速度是否过快（超出碰撞检测范围）

---

## Boss 问题

### 阶段不触发
**原因**：health_changed 信号未连接或百分比计算错误。
**修复**：
1. 确认 `_on_character_ready()` 中连接了 `health_component.health_changed.connect(_on_health_changed)`（BossBase 已自动连接）
2. 检查 `phase_2_health_percent` 和 `phase_3_health_percent` 的值
3. 添加日志：`DebugConfig.debug("health_percent: %f, phase: %s" % [health_percent, current_phase], "", "combat")`

### 死亡后不消失
**原因**：`_handle_death()` 中 await 后 self 已被释放。
**修复**：
1. 在 await 之后添加 `if not is_instance_valid(self): return`
2. 确认 `queue_free()` 在所有代码路径中都会被调用

---

## 特殊技能问题

### 技能永远不触发
**原因**：cooldown 过长、probability 过低、或 _check_condition() 始终返回 false。
**修复**：
1. 检查 @export 配置：`skill_cooldown`（默认 8s）、`skill_probability`（默认 0.2 = 20%）
2. 检查 `_check_condition(distance)` 的距离判断逻辑
3. 临时设置 `skill_probability = 1.0` 和 `skill_cooldown = 0.0` 测试

### finish_skill() 未调用导致永远冷却
**原因**：`execute_skill()` 中 await 后异常退出，未调用 `finish_skill()`。
**修复**：
1. 确保 execute_skill() 的所有分支（包括异常路径）都调用 `finish_skill()`
2. 在 await 后添加 `is_instance_valid(self)` 检查，仍然需要调用 finish_skill()

### 技能执行中被攻击打断
**原因**：SpecialSkillState 默认 priority=BEHAVIOR(0)，被 hit/stun 打断。
**修复**：
1. 如果技能不应被打断：设置 `priority = StatePriority.CONTROL`
2. 如果可以被打断但需要清理：在 `exit()` 中清理技能状态
3. 注意：设为 CONTROL 后，hit/stun 也无法打断，需要权衡

---

## 空引用 / 节点问题

### await 后 self 已被释放
**原因**：await 异步期间节点被 `queue_free()` 销毁，后续代码访问已释放对象。
**修复**：
1. 在每个 await 之后添加 `if not is_instance_valid(self): return`
2. 高风险位置：`_handle_death()`, `execute_skill()`, combo await 链
3. 同样检查 `owner_node` 和 `target_node` 的有效性

### @onready 变量为 null
**原因**：节点路径错误、节点名称拼写错误、或场景树中缺少该节点。
**修复**：
1. 检查 .tscn 中节点名称是否与代码中的 `$NodeName` 或 `%UniqueNode` 匹配
2. 确认节点存在于场景树中（不是被意外删除）
3. 注意 Inherited Scene 中的覆盖问题

### 信号未连接 / 连接重复
**原因**：代码中 `.connect()` 调用位置错误或被多次执行。
**修复**：
1. 优先在编辑器中连接信号（Inspector → Node → Signals）
2. 代码连接时用 `if not signal.is_connected(callable): signal.connect(callable)`
3. 在 `exit()` 中 disconnect 的信号必须在 `enter()` 中重新 connect

---

## 关卡 / UI 问题

### 场景切换后旧引用报错
**原因**：切换场景后，旧场景节点被释放，但 Autoload 或 Timer 仍持有引用。
**修复**：
1. 在场景退出时（`_exit_tree()`）清理所有外部引用
2. Timer 在 `_exit_tree()` 中停止
3. Autoload 中不要缓存场景内节点引用

### UI 层级遮挡
**原因**：UIManager 的 CanvasLayer 排序问题。
**修复**：
1. 确认面板添加到正确的 UILayer（GAME=10, MENU=20, POPUP=30）
2. 检查 CanvasLayer.layer 值
3. 检查是否有 z_index 覆盖
