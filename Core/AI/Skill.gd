# Core/AI/Skill.gd
class_name Skill extends Resource

## 技能声明 Resource — 选择条件 + 控制标志 + 执行参数

# ==== 选择层（SkillSet 读取）====
## 唯一标识，用于 cd key 和日志
@export var id: StringName = &""
## 目标状态节点名（StateMachine 中的 AIState.name，小写）
@export var state_name: StringName = &""
## 本技能专属冷却（秒）
@export var cooldown: float = 1.5
## 加权随机权重（0 = 不进入普通池，仅 pick_tagged 可选）
@export var weight: int = 1
## 阶段解锁（含端点）
@export var min_phase: int = 0
## -1 = 不限上限
@export var max_phase: int = -1
## 距离门槛（0 = 不限）
@export var min_range: float = 0.0
@export var max_range: float = 0.0
## 分类标签
@export var tags: Array[StringName] = []
## Boss 脚本中的前置条件方法名（空 = 无条件）
@export var precondition_method: StringName = &""

# ==== 控制层（AIController 读取）====
## false = 执行期间只有 EV_DIED / EV_ATTACK_FINISHED 可打断
@export var interruptible: bool = true

# ==== 执行层（State 读取）====
## 状态专属参数字典
@export var params: Dictionary = {}

# ==== 伤害层（HitBox 在 Skill fire 时读入）====
## HitBox 命中时基础伤害值（实际命中走 DamagePipeline.amount）
@export var damage_amount: float = 0.0
## DamageTags bitmask（Physical/Magical/DOT/Crit/True 等）
@export_flags("Physical:1","Magical:2","DOT:4","Crit:8","True:16") var damage_tags: int = 0
## 命中时挂在受击者身上的 BuffEntity 列表
@export var attached_buffs: Array[BuffEntity] = []
