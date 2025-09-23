extends Node
class_name AttackComponent

@export var attack_data := {
	"slash_attack": {
		"scene": preload("res://Weapons/slash/claw/slash_attack.tscn"),
		"offset": {
			Vector2.LEFT: Vector2(-16, 0),
			Vector2.RIGHT: Vector2(16, 0),
			Vector2.UP: Vector2(0, -16),
			Vector2.DOWN: Vector2(0, 16),
		}
	}
}

func perform_attack(name: String, facing_direction: Vector2 , anchor: Node2D):
	if not attack_data.has(name):
		return

	# 获取方向
	var dir = Vector2.ZERO
	if abs(facing_direction.x) > abs(facing_direction.y):
		dir = Vector2.RIGHT if facing_direction.x > 0.0 else Vector2.LEFT
	else:
		dir = Vector2.DOWN if facing_direction.y > 0.0 else Vector2.UP
		
	var config = attack_data[name]
	var scene: PackedScene = config["scene"]
	var node = scene.instantiate()
	# 设置偏移
	var offset : Vector2= config["offset"].get(dir, Vector2.ZERO)
	node.position = offset
	# 设置技能旋转角度
	match dir:
		Vector2.LEFT: node.rotation_degrees = -90
		Vector2.RIGHT: node.rotation_degrees = 90
		Vector2.UP: node.rotation_degrees = 0
		Vector2.DOWN: node.rotation_degrees = 180

	#print("perform_attack offset:{0} archor pos:{1} ".format([offset, anchor.global_position]))
	anchor.add_child(node)
	if node.has_method("start"):
		node.start()
		
