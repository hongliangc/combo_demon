extends BaseTrap
class_name LaunchPad

## 弹射器 — 踩上去将玩家弹射到高处
## 难度：★★☆ | 效果：强制击飞（无伤害）

@export_group("弹射配置")
## 弹射力度
@export var launch_force: float = 700.0
## 弹射方向（归一化，默认向上）
@export var launch_direction: Vector2 = Vector2.UP

@onready var _damage_zone: Area2D = $DamageZone
@onready var _visual: ColorRect = $Visual

func _on_trap_ready() -> void:
	# 弹射器无伤害
	damage_amount = 0.0
	_build_damage()
	_damage_zone.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not is_active or _cooldown_timer > 0.0:
		return
	if body.is_in_group(&"player"):
		_cooldown_timer = damage_cooldown
		var dir := launch_direction.normalized()
		body.velocity = dir * launch_force
		# 弹射视觉反馈：短暂缩放
		var tween := create_tween()
		tween.tween_property(_visual, "scale", Vector2(1.2, 0.6), 0.08)
		tween.tween_property(_visual, "scale", Vector2.ONE, 0.15)
