extends BaseTrap
class_name FlameJet

## 火焰喷射 — 周期性喷出火焰柱
## 难度：★☆☆ | 效果：伤害 + 击退

@export_group("火焰节奏")
## 喷射方向（归一化）
@export var direction: Vector2 = Vector2.UP
## 火焰喷射持续时长
@export var fire_duration: float = 2.0
## 关闭后冷却时长
@export var cooldown_duration: float = 3.0
## 喷射前预警时长（闪烁）
@export var warn_time: float = 0.5
## 火焰长度（像素）
@export var flame_length: float = 64.0

@onready var _nozzle: Sprite2D = $Nozzle
@onready var _flame: ColorRect = $Flame
@onready var _damage_zone: Area2D = $DamageZone

func _on_trap_ready() -> void:
	_damage_zone.body_entered.connect(_on_body_entered)
	# 根据方向旋转整个火焰
	rotation = Vector2.UP.angle_to(direction)
	_flame.visible = false
	_damage_zone.set_deferred("monitoring", false)
	is_active = false
	_start_cycle()

func _on_body_entered(body: Node2D) -> void:
	_apply_damage_to(body)

func _start_cycle() -> void:
	while is_inside_tree():
		# 冷却期
		await get_tree().create_timer(cooldown_duration).timeout
		if not is_inside_tree():
			return
		# 预警闪烁
		await _warn_blink()
		if not is_inside_tree():
			return
		# 喷火
		_flame.visible = true
		is_active = true
		_damage_zone.set_deferred("monitoring", true)
		await get_tree().create_timer(fire_duration).timeout
		if not is_inside_tree():
			return
		# 关闭
		_flame.visible = false
		is_active = false
		_damage_zone.set_deferred("monitoring", false)

func _warn_blink() -> void:
	var blinks := int(warn_time / 0.15)
	for i in blinks:
		_nozzle.modulate = Color(1.0, 0.3, 0.0, 1.0) if i % 2 == 0 else Color.WHITE
		await get_tree().create_timer(0.15).timeout
		if not is_inside_tree():
			return
	_nozzle.modulate = Color.WHITE
