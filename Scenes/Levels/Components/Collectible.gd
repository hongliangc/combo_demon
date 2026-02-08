extends Area2D
class_name Collectible

## 收集物组件 - 可拾取的物品（金币、钥匙、宝石等）
##
## 功能：
## - 自动拾取
## - 拾取动画
## - 类型区分
## - 发出收集信号

signal collected(item_type: String)

@export_enum("coin", "key", "gem_red", "gem_green", "gem_blue", "gem_yellow", "heart") var item_type: String = "coin"
@export var value: int = 1
@export var float_animation: bool = true
@export var float_amplitude: float = 4.0
@export var float_speed: float = 2.0

var _initial_y: float = 0.0
var _time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

# 纹理映射
const TEXTURES: Dictionary = {
	"coin": "res://Assets/Art/Ninja_Adventure/Items/Treasure/GoldCoin.png",
	"key": "res://Assets/Art/Ninja_Adventure/Items/Treasure/GoldKey.png",
	"gem_red": "res://Assets/Art/Ninja_Adventure/Items/Resource/GemRed.png",
	"gem_green": "res://Assets/Art/Ninja_Adventure/Items/Resource/GemGreen.png",
	"gem_blue": "res://Assets/Art/Ninja_Adventure/Items/Resource/GemPurple.png",
	"gem_yellow": "res://Assets/Art/Ninja_Adventure/Items/Resource/GemYellow.png",
	"heart": "res://Assets/Art/Ninja_Adventure/Items/Potion/Heart.png"
}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_setup_sprite()
	_initial_y = position.y


func _setup_sprite() -> void:
	if sprite and TEXTURES.has(item_type):
		sprite.texture = load(TEXTURES[item_type])


func _process(delta: float) -> void:
	if float_animation:
		_time += delta
		position.y = _initial_y + sin(_time * float_speed) * float_amplitude


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_collect()


func _collect() -> void:
	# 禁用碰撞防止重复收集
	collision.set_deferred("disabled", true)

	# 播放收集动画
	_play_collect_animation()

	# 发出信号
	collected.emit(item_type)

	# 通知LevelManager
	_notify_level_manager()


func _play_collect_animation() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "position:y", sprite.position.y - 20, 0.2)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.2)

	tween.set_parallel(false)
	tween.tween_callback(queue_free)


func _notify_level_manager() -> void:
	match item_type:
		"coin":
			LevelManager.collect_item("coin", value)
		"key":
			LevelManager.collect_item("key", value)
		"gem_red", "gem_green", "gem_blue", "gem_yellow":
			LevelManager.collect_item("coin", value * 10)  # 宝石值更多
		"heart":
			# 恢复生命值
			var player = get_tree().get_first_node_in_group("player")
			if player and player.has_node("HealthComponent"):
				player.get_node("HealthComponent").heal(20)
