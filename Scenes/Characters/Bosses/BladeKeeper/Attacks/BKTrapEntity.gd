extends Area2D
class_name BKTrapEntity

## 地面陷阱 — 落地待机，接触触发爆炸动画 (+ 可选伤害 / 眩晕 buff)
## 默认 damage_amount=0 / stun_buff=null —— 纯视觉陷阱
## (与 v1 damage_config 未配置时行为一致；v1 的 Damage/ForceStunEffect 路径已移除)

@export var trap_lifetime := 8.0
## 命中伤害 (0 = 纯视觉陷阱)
@export var damage_amount: float = 0.0
## 命中附加的 buff (眩晕等，可空)
@export var stun_buff: BuffEntity

var _triggered := false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# 播放落地动画
	_sprite.play("land")
	_sprite.animation_finished.connect(_on_land_finished)

	modulate.a = 0.3
	var lifetime_timer := get_tree().create_timer(trap_lifetime)
	lifetime_timer.timeout.connect(_expire)
	body_entered.connect(_on_body_entered)

func _on_land_finished() -> void:
	if _sprite.animation == "land":
		# 落地完成，进入待机（停在最后一帧）
		_sprite.stop()

func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if not body.is_in_group("player"):
		return
	_triggered = true
	_trigger(body)

func _trigger(body: Node2D) -> void:
	modulate.a = 1.0
	# 播放爆炸动画
	_sprite.play("detonate")
	_sprite.animation_finished.connect(func(): queue_free())

	# v2 伤害路径: 经受击者的 DamagePipeline (旧 HurtBox.take_damage 已移除)
	if damage_amount <= 0.0:
		return
	var pipe: DamagePipeline = body.get_node_or_null(^"DamagePipeline")
	if pipe == null:
		return
	var ctx := DamageContext.new()
	ctx.source = self
	ctx.target = body
	ctx.raw_amount = damage_amount
	ctx.amount = damage_amount
	ctx.tags = DamageTags.PHYSICAL
	ctx.source_pos = global_position
	if stun_buff:
		ctx.attached_buffs = [stun_buff]
	pipe.process(ctx)

func _expire() -> void:
	if _triggered:
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
