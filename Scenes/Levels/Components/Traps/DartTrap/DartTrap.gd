extends BaseTrap
class_name DartTrap

## 箭矢陷阱 — 墙壁中周期性射出飞行物
## 难度：★★☆ | 效果：伤害 + 击退

@export_group("射击配置")
## 射击方向（归一化）
@export var fire_direction: Vector2 = Vector2.LEFT
## 射击间隔（秒）
@export var fire_interval: float = 2.0
## 抛射物速度
@export var projectile_speed: float = 300.0
## 抛射物存活时间
@export var projectile_lifetime: float = 5.0

var _projectile_scene: PackedScene = preload("res://Scenes/Levels/Components/Traps/DartTrap/TrapProjectile.tscn")
var _fire_timer: float = 0.0

func _on_trap_ready() -> void:
	_fire_timer = fire_interval

func _process(delta: float) -> void:
	super._process(delta)
	if not is_active:
		return
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_interval
		_fire()

func _fire() -> void:
	var projectile: TrapProjectile = _projectile_scene.instantiate()
	projectile.direction = fire_direction.normalized()
	projectile.speed = projectile_speed
	projectile.damage_amount = damage_amount
	projectile.attached_buffs = effects
	projectile.lifetime = projectile_lifetime
	projectile.global_position = global_position
	# 根据方向旋转视觉
	projectile.rotation = fire_direction.angle()
	get_tree().current_scene.add_child(projectile)
