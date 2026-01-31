extends Node
class_name BulletPool

@export var bullet_selection := {
	"fire_bullet": {
		"bullet_scene": preload("res://Scenes/Weapons/bullet/fire/FireBullet.tscn"),
		"sound_effect": preload("res://Assets/Sound/hitHurt.wav"),
		"bullet_count": 10,
	},
	"bubble_bullet": {
		"bullet_scene": preload("res://Scenes/Weapons/bullet/bubble/BubbleBullet.tscn"),
		"sound_effect": preload("res://Assets/Sound/hitHurt.wav"),
		"bullet_count": 20,
	}
}

# 子弹池：类型 -> [可复用子弹列表]
var pools := {}

func _ready():
	# 初始化各类子弹池
	for bullet_type in bullet_selection.keys():
		var count = bullet_selection[bullet_type]["bullet_count"]
		var scene = bullet_selection[bullet_type]["bullet_scene"]
		pools[bullet_type] = []
		for i in range(count):
			var bullet = scene.instantiate()
			bullet.name = "%s_%d" % [bullet_type, i]
			bullet.visible = false
			add_child(bullet)
			pools[bullet_type].append(bullet)

# 获取空闲子弹（如无空闲自动扩容）
func get_bullet(bullet_type: String) -> Node:
	if not pools.has(bullet_type):
		push_error("Unknown bullet type: " + bullet_type)
		return null

	var pool = pools[bullet_type]
	for bullet in pool:
		if not bullet.visible:
			bullet.visible = true
			return bullet

	# 自动扩容
	var bullet = bullet_selection[bullet_type]["bullet_scene"].instantiate()
	bullet.name = "%s_%d" % [bullet_type, pool.size()]
	bullet.visible = true
	add_child(bullet)
	pool.append(bullet)
	return bullet

# 子弹用完返回池
func return_bullet(bullet: Node, bullet_type: String) -> void:
	if not pools.has(bullet_type):
		push_error("Unknown bullet type in return_bullet")
		return
	bullet.visible = false
	bullet.position = Vector2.ZERO
	# 如果有 reset 方法，可以调用以清空状态
	if bullet.has_method("reset"):
		bullet.reset()
