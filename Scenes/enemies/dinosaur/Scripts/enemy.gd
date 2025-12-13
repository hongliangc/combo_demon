extends CharacterBody2D
class_name Enemy

# 发送信号给StunState
signal damaged(damage: Damage)

@export_group("Textures")
@export var textures: Array[Texture2D] = []


@export_group("Health")
@export var max_health := 100
@export var health := 100

@export_group("Wander")
@export var min_wander_time := 2.5
@export var max_wander_time := 10.0
@export var wander_speed := 50.0

@export_group("Chase")
@export var detection_radius := 100.0
@export var chase_radius := 200.0
@export var follow_radius := 25.0
@export var chase_speed := 75

@onready var sprite : Sprite2D = $Sprite2D
@onready var damage_numbers_anchor: Node2D= $DamageNumbersAnchor
var stunned : bool = false
var alive : bool = true

@onready var anim_player: AnimationPlayer =  $AnimationPlayer
func _ready() -> void:
	sprite.texture = textures.pick_random()


func on_death() -> void:
	velocity = Vector2.ZERO
	anim_player.play("death")
	pass # 用于爆装备


func dislay_damage_number(damage: Damage) -> void:
	var is_critical = false
	if damage.amount > damage.max_amount *0.8:
		is_critical = true
	DamageNumbers.display_number(damage.amount, damage_numbers_anchor.global_position, is_critical)


func on_damaged(damage: Damage, attacker_position: Vector2 = Vector2.ZERO) -> void:
	print("========== Enemy.on_damaged 被调用 ==========")
	print("当前位置: ", global_position)
	print("当前速度: ", velocity)

	# 显示伤害数字
	dislay_damage_number(damage)
	print("enemy on_damage damage")
	damage.debug_print()

	# 应用攻击特效（击飞、击退等）
	print("特效数量: ", damage.effects.size())
	if damage.effects.size() > 0:
		print("开始应用特效...")
		damage.apply_effects(self, attacker_position)
		print("特效应用完成，当前velocity: ", velocity)

	# 通知状态机切换（在特效应用之后）
	print("发送 damaged 信号到状态机...")
	damaged.emit(damage)
	print("==========================================")
