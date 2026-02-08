extends CharacterBody2D
class_name ForestSnail

## 森林蜗牛敌人 - 缓慢但防御高
##
## 行为：
## - 缓慢巡逻
## - 受到攻击时缩进壳中（减少伤害）
## - 碰到玩家造成伤害

signal died()

@export var max_health: float = 80.0
@export var move_speed: float = 30.0
@export var attack_damage: float = 5.0
@export var gravity: float = 800.0
@export var hide_damage_reduction: float = 0.5  # 缩壳时减伤50%

var health: float
var direction: int = 1
var is_dead: bool = false
var is_hiding: bool = false
var hide_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray_ground: RayCast2D = $RayGround
@onready var ray_wall: RayCast2D = $RayWall
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	health = max_health
	add_to_group("enemy")

	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 应用重力
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	# 缩壳计时
	if is_hiding:
		hide_timer -= delta
		if hide_timer <= 0:
			is_hiding = false

	# 移动
	if not is_hiding:
		_patrol()
		_check_obstacles()
	else:
		velocity.x = 0

	move_and_slide()
	_update_sprite()


func _patrol() -> void:
	velocity.x = direction * move_speed


func _check_obstacles() -> void:
	if not is_on_floor():
		return

	if ray_ground and not ray_ground.is_colliding():
		direction *= -1
		_update_ray_direction()

	if ray_wall and ray_wall.is_colliding():
		direction *= -1
		_update_ray_direction()


func _update_ray_direction() -> void:
	if ray_ground:
		ray_ground.position.x = abs(ray_ground.position.x) * direction

	if ray_wall:
		ray_wall.target_position.x = abs(ray_wall.target_position.x) * direction


func _update_sprite() -> void:
	sprite.flip_h = direction < 0

	if is_dead:
		sprite.play("dead")
	elif is_hiding:
		sprite.play("hide")
	elif abs(velocity.x) > 5:
		sprite.play("walk")
	else:
		sprite.play("walk")


func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_node("HealthComponent"):
		body.get_node("HealthComponent").take_damage(attack_damage)


func take_damage(amount: float) -> void:
	if is_dead:
		return

	# 缩壳时减伤
	if is_hiding:
		amount *= hide_damage_reduction

	health -= amount

	# 受击后缩进壳中
	if not is_hiding and health > 0:
		is_hiding = true
		hide_timer = 2.0

	# 闪烁
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	if not is_dead:
		sprite.modulate = Color.WHITE

	if health <= 0:
		die()


func die() -> void:
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO
	sprite.play("dead")

	died.emit()

	await get_tree().create_timer(1.0).timeout
	queue_free()
