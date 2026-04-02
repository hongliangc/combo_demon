extends Area2D
class_name BKTrapEntity

## 地面陷阱 — 接触触发，爆炸 + ForceStun

@export var trap_lifetime := 8.0
@export var damage_config: Damage
@export var stun_duration := 0.5

var _triggered := false

func _ready() -> void:
	modulate.a = 0.3
	var lifetime_timer := get_tree().create_timer(trap_lifetime)
	lifetime_timer.timeout.connect(_expire)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if not body.is_in_group("player"):
		return
	_triggered = true
	_trigger(body)

func _trigger(body: Node2D) -> void:
	modulate.a = 1.0
	# 通过 HurtBoxComponent 应用伤害
	if damage_config:
		var dmg := damage_config.duplicate(true) as Damage
		var stun_effect := ForceStunEffect.new()
		stun_effect.duration = stun_duration
		dmg.effects.append(stun_effect)
		# 查找 body 上的 HurtBoxComponent 并应用伤害
		for child in body.get_children():
			if child.has_method("take_damage"):
				child.take_damage(dmg, global_position)
				break
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(self):
		queue_free()

func _expire() -> void:
	if _triggered:
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
