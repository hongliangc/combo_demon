extends CharacterBody2D
class_name Enemy

# 发送信号给StunState
signal damaged(attack: Attack)

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


func dislay_damage_number(attack: Attack) -> void:
	var is_critical = false
	if attack.damage > attack.max_damage *0.8:
		is_critical = true
	DamageNumbers.display_number(attack.damage, damage_numbers_anchor.global_position, is_critical)


func on_damaged(attack: Attack) -> void:
	# 通知状态StunState机切换
	damaged.emit(attack)
	dislay_damage_number(attack)
