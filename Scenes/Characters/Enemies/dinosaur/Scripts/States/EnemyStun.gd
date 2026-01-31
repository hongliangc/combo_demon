extends "res://Core/StateMachine/CommonStates/StunState.gd"

## Enemy 特定的眩晕状态
## 继承自 StunState，所有物理模拟逻辑已在基类实现
## 此类仅保留 Enemy 特有的行为定制（如果有）

# 所有功能已在 StunState 基类中实现：
# - 击飞/击退物理模拟（重力、摩擦力）
# - 眩晕计时器管理
# - on_damaged() 处理击飞/击退特效
# - enter()/exit()/physics_process_state()
#
# 可通过 Inspector 配置的参数（继承自 StunState）：
# - stun_duration: 眩晕持续时间
# - reset_on_damage: 受伤时是否重置眩晕时间
# - gravity: 重力加速度
# - friction: 横向摩擦力系数
# - detection_radius: 恢复后检测玩家的半径
# - chase_state_name: 检测到玩家时切换的状态名
# - wander_state_name: 未检测到玩家时切换的状态名
