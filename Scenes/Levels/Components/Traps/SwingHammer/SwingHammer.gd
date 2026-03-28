extends BaseTrap
class_name SwingHammer

## 锤摆 — 从天花板悬挂的大锤来回摆动
## 难度：★★★ | 效果：高伤害 + 击飞

@export_group("摆锤配置")
## 摆臂长度（像素）
@export var arm_length: float = 80.0
## 摆幅半角（度）
@export var swing_angle: float = 60.0
## 完整摆动周期（秒）
@export var swing_period: float = 3.0

@onready var _arm: Node2D = $Arm

var _time: float = 0.0

func _on_trap_ready() -> void:
	# 锤头碰撞
	var damage_zone: Area2D = $Arm/HammerHead/DamageZone
	damage_zone.body_entered.connect(_on_hammer_hit)
	# 随机起始相位避免同步
	_time = randf() * swing_period

func _process(delta: float) -> void:
	super._process(delta)
	if is_active:
		_time += delta
		var angle := deg_to_rad(swing_angle) * sin(_time * TAU / swing_period)
		_arm.rotation = angle

func _on_hammer_hit(body: Node2D) -> void:
	_apply_damage_to(body)
