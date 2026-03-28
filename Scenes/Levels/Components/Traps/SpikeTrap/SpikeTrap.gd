extends BaseTrap
class_name SpikeTrap

## 地刺陷阱 — 周期性从地面伸出尖刺
## 难度：★☆☆ | 效果：伤害 + 击退

@export_group("地刺节奏")
## 伸出动画时长
@export var extend_time: float = 0.3
## 伸出后停留时长
@export var stay_time: float = 1.5
## 缩回动画时长
@export var retract_time: float = 0.3
## 缩回后安全等待时长
@export var safe_time: float = 2.0

@onready var _spike_visual: Node2D = $SpikeVisual
@onready var _damage_zone: Area2D = $DamageZone

func _on_trap_ready() -> void:
	_damage_zone.body_entered.connect(_on_body_entered)
	_spike_visual.scale.y = 0.0
	_start_cycle()

func _on_body_entered(body: Node2D) -> void:
	_apply_damage_to(body)

func _start_cycle() -> void:
	while is_inside_tree():
		# 安全期
		is_active = false
		_damage_zone.set_deferred("monitoring", false)
		await get_tree().create_timer(safe_time).timeout
		if not is_inside_tree():
			return
		# 伸出
		var tween_up := create_tween()
		tween_up.tween_property(_spike_visual, "scale:y", 1.0, extend_time)
		await tween_up.finished
		if not is_inside_tree():
			return
		# 激活伤害
		is_active = true
		_damage_zone.set_deferred("monitoring", true)
		await get_tree().create_timer(stay_time).timeout
		if not is_inside_tree():
			return
		# 缩回
		is_active = false
		_damage_zone.set_deferred("monitoring", false)
		var tween_down := create_tween()
		tween_down.tween_property(_spike_visual, "scale:y", 0.0, retract_time)
		await tween_down.finished
