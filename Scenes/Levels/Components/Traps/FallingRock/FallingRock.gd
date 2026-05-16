extends BaseTrap
class_name FallingRock

## 落石陷阱 — 玩家经过时从上方掉落石头
## 难度：★★☆ | 效果：伤害 + 眩晕

@export_group("落石配置")
## 下落速度（像素/秒）
@export var fall_speed: float = 400.0
## 预警阴影显示时长
@export var warning_time: float = 0.5
## 落地后重置时长
@export var reset_time: float = 3.0
## 下落距离（像素）
@export var fall_distance: float = 128.0

@onready var _trigger_zone: Area2D = $TriggerZone
@onready var _rock: Node2D = $Rock
@onready var _shadow: ColorRect = $Shadow
@onready var _damage_zone: Area2D = $Rock/DamageZone

var _rock_origin: Vector2
var _is_falling: bool = false
var _has_landed: bool = false

func _on_trap_ready() -> void:
	_rock_origin = _rock.position
	_shadow.modulate.a = 0.0
	_trigger_zone.body_entered.connect(_on_trigger_entered)
	_damage_zone.body_entered.connect(_on_rock_hit)
	_damage_zone.set_deferred("monitoring", false)

func _process(delta: float) -> void:
	super._process(delta)
	if _is_falling and not _has_landed:
		_rock.position.y += fall_speed * delta
		if _rock.position.y >= _rock_origin.y + fall_distance:
			_rock.position.y = _rock_origin.y + fall_distance
			_land()

func _on_trigger_entered(body: Node2D) -> void:
	if body.is_in_group(&"player") and not _is_falling and not _has_landed:
		_start_warning()

func _on_rock_hit(body: Node2D) -> void:
	_apply_damage_to(body)

func _start_warning() -> void:
	_is_falling = true
	# 显示阴影预警
	var tween := create_tween()
	tween.tween_property(_shadow, "modulate:a", 0.6, warning_time)
	await tween.finished
	if not is_inside_tree():
		return
	# 开始下落
	_rock.visible = true
	_damage_zone.set_deferred("monitoring", true)

func _land() -> void:
	_has_landed = true
	_is_falling = false
	_damage_zone.set_deferred("monitoring", false)
	# 重置
	await get_tree().create_timer(reset_time).timeout
	if not is_inside_tree():
		return
	_rock.position = _rock_origin
	_rock.visible = true
	_shadow.modulate.a = 0.0
	_has_landed = false
