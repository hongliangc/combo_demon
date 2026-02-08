extends CharacterBody2D
class_name ForestBoar

## 森林野猪敌人 - 平台跳跃风格
##
## 行为：
## - 左右巡逻
## - 发现玩家后冲刺攻击
## - 碰到墙壁或边缘转向

signal died()

@export var max_health: float = 50.0
@export var move_speed: float = 60.0
@export var chase_speed: float = 120.0
@export var detection_range: float = 200.0
@export var attack_damage: float = 10.0
@export var gravity: float = 800.0

var health: float
var direction: int = 1  # 1=右, -1=左
var is_chasing: bool = false
var is_dead: bool = false
var player: Node2D = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray_ground: RayCast2D = $RayGround  # 检测地面边缘
@onready var ray_wall: RayCast2D = $RayWall      # 检测墙壁
@onready var hitbox: Area2D = $Hitbox
@onready var health_bar: ProgressBar = $HealthBar if has_node("HealthBar") else null


func _ready() -> void:
	health = max_health
	add_to_group("enemy")

	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)

	_update_health_bar()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 应用重力
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	# 查找玩家
	_find_player()

	# 移动逻辑
	if is_chasing and player:
		_chase_player()
	else:
		_patrol()

	# 检测边缘和墙壁
	_check_obstacles()

	move_and_slide()
	_update_sprite()


func _find_player() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")

	if player:
		var distance = global_position.distance_to(player.global_position)
		is_chasing = distance < detection_range


func _patrol() -> void:
	velocity.x = direction * move_speed


func _chase_player() -> void:
	if player:
		direction = 1 if player.global_position.x > global_position.x else -1
		velocity.x = direction * chase_speed


func _check_obstacles() -> void:
	if not is_on_floor():
		return

	# 检测前方是否有地面
	if ray_ground and not ray_ground.is_colliding():
		direction *= -1
		_update_ray_direction()

	# 检测墙壁
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
		return

	if abs(velocity.x) > 10:
		if is_chasing:
			sprite.play("run")
		else:
			sprite.play("walk")
	else:
		sprite.play("idle")


func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_node("HealthComponent"):
		body.get_node("HealthComponent").take_damage(attack_damage)


func take_damage(amount: float) -> void:
	if is_dead:
		return

	health -= amount
	_update_health_bar()

	# 受击闪烁
	_flash_damage()

	if health <= 0:
		die()


func _flash_damage() -> void:
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	if not is_dead:
		sprite.modulate = Color.WHITE


func _update_health_bar() -> void:
	if health_bar:
		health_bar.value = (health / max_health) * 100


func die() -> void:
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO
	sprite.play("hit")

	died.emit()

	# 等待动画播放完毕
	await get_tree().create_timer(0.5).timeout
	queue_free()
