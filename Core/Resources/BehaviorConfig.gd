extends Resource
class_name BehaviorConfig

## 统一行为配置 Resource
## 替代散落在 EnemyBase/BossBase 上的 @export 属性
## 支持 Enemy 和 Boss 共用，Boss 字段通过 @export_group("Boss") 分组

# ---- Health ----
@export_group("Health")
@export var max_health := 100
@export var health := 100

# ---- Idle ----
@export_group("Idle")
@export var min_idle_time := 1.0
@export var max_idle_time := 3.0

# ---- Wander ----
@export_group("Wander")
@export var min_wander_time := 2.5
@export var max_wander_time := 10.0
@export var wander_speed := 50.0

# ---- Chase ----
@export_group("Chase")
@export var detection_radius := 100.0
@export var chase_abandon_distance := 200.0
@export var attack_activation_radius := 25.0
@export var chase_speed := 75.0

# ---- Stun ----
@export_group("Stun")
@export var stun_duration := 1.0
@export var stun_anim_speed := 1.0

# ---- Hit ----
@export_group("Hit")
@export var hit_duration := 0.3

# ---- Movement ----
@export_group("Movement")
## 水平移动模式：仅允许 X 轴移动（用于地面敌人如 Snail/Boar）
@export var ground_only := false
@export var has_gravity := false
@export var gravity := 800.0

# ---- Boss 扩展 ----
@export_group("Boss")
@export var is_boss := false
@export var attack_range := 300.0
@export var min_distance := 150.0
@export var stun_immunity_duration := 1.5
