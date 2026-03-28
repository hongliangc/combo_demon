extends BaseTrap
class_name SawRail

## 锯齿轨道 — 沿预设路径移动的锯齿
## 难度：★★★ | 效果：高伤害 + 击退

@export_group("锯齿配置")
## 移动速度（像素/秒）
@export var move_speed: float = 100.0
## 是否往返（false=单向循环，true=来回移动）
@export var ping_pong: bool = true
## 锯齿旋转速度（弧度/秒，纯视觉）
@export var saw_spin_speed: float = 8.0

@onready var _path_follow: PathFollow2D = $Path2D/PathFollow2D
@onready var _saw_visual: Node2D = $Path2D/PathFollow2D/SawVisual
@onready var _damage_zone: Area2D = $Path2D/PathFollow2D/DamageZone

var _direction: float = 1.0

func _on_trap_ready() -> void:
	_damage_zone.body_entered.connect(_on_saw_hit)
	if ping_pong:
		_path_follow.loop = false

func _process(delta: float) -> void:
	super._process(delta)
	if not is_active:
		return
	# 移动
	_path_follow.progress += move_speed * _direction * delta
	if ping_pong:
		if _path_follow.progress_ratio >= 1.0:
			_path_follow.progress_ratio = 1.0
			_direction = -1.0
		elif _path_follow.progress_ratio <= 0.0:
			_path_follow.progress_ratio = 0.0
			_direction = 1.0
	# 旋转视觉
	_saw_visual.rotation += saw_spin_speed * delta

func _on_saw_hit(body: Node2D) -> void:
	_apply_damage_to(body)
