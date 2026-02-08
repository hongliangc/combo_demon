extends CharacterBody2D
class_name ForestBee

## 森林蜜蜂敌人 - 飞行敌人
##
## 行为：
## - 在空中悬浮巡逻
## - 发现玩家后俯冲攻击
## - 攻击后返回原位置

signal died()

@export var max_health: float = 30.0
@export var fly_speed: float = 80.0
@export var attack_speed: float = 150.0
@export var detection_range: float = 150.0
@export var attack_damage: float = 8.0
@export var patrol_range: float = 100.0

var health: float
var is_dead: bool = false
var is_attacking: bool = false
var player: Node2D = null
var home_position: Vector2
var patrol_offset: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	health = max_health
	home_position = global_position
	add_to_group("enemy")

	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 查找玩家
	_find_player()

	if is_attacking:
		_attack_move(delta)
	elif player and global_position.distance_to(player.global_position) < detection_range:
		_start_attack()
	else:
		_patrol(delta)

	move_and_slide()
	_update_sprite()


func _find_player() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")


func _patrol(delta: float) -> void:
	patrol_offset += delta * 2.0
	var target = home_position + Vector2(sin(patrol_offset) * patrol_range, cos(patrol_offset * 0.5) * 20)
	var direction = (target - global_position).normalized()
	velocity = direction * fly_speed


func _start_attack() -> void:
	if is_attacking:
		return

	is_attacking = true
	sprite.play("attack")


func _attack_move(delta: float) -> void:
	if player:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * attack_speed

		# 检查是否到达目标附近
		if global_position.distance_to(player.global_position) < 20:
			_end_attack()
	else:
		_end_attack()


func _end_attack() -> void:
	is_attacking = false

	# 返回原位
	await get_tree().create_timer(0.5).timeout
	var tween = create_tween()
	tween.tween_property(self, "global_position", home_position, 1.0)


func _update_sprite() -> void:
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0

	if is_dead:
		return

	if not is_attacking:
		sprite.play("fly")


func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_node("HealthComponent"):
		body.get_node("HealthComponent").take_damage(attack_damage)


func take_damage(amount: float) -> void:
	if is_dead:
		return

	health -= amount
	sprite.play("hit")

	if health <= 0:
		die()


func die() -> void:
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO
	died.emit()

	# 下落
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y + 50, 0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
