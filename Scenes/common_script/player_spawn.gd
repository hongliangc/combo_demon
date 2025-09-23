extends Node2D
class_name player_spawn

var player_selection: Dictionary = {
	"hahashin": preload("res://Scenes/charaters/hahashin.tscn"),
}

@export_group("Charactor Selection") 
@export_enum("hahashin") 
var player_name: String = "hahashin"
var player = null

@onready var camera: Camera2D = $"../Camera2D"
@export var sensitivity := 0.25
var aim_position:Vector2

func _ready() -> void:
	var scene : PackedScene = player_selection[player_name]
	player = scene.instantiate()
	player.global_position = self.global_position
	add_child(player)
	
		# 获取当前屏幕分辨率（不含缩放）
	var screen_size = get_viewport_rect().size
	print("Screen resolution: ", screen_size)

	# 计算摄像机可视区域（世界范围）
	var visible_world = screen_size * camera.zoom
	print("Visible world size: ", visible_world)
	
func _physics_process(delta: float) -> void:
	if player and camera:
		var base_pos = player.global_position
		var world_mouse = get_global_mouse_position()

		var offset = world_mouse - base_pos
		# 限制偏移在屏幕范围的一半以内, offset最大get_viewport_rect的一半
		var max_offset = get_viewport_rect().size * 0.5
		offset.x = clamp(offset.x, -max_offset.x, max_offset.x)
		offset.y = clamp(offset.y, -max_offset.y, max_offset.y)
		#基于offset的一半，1/4屏幕中心位置
		var target_pos = base_pos + offset * sensitivity

		# print("base_pos:{0} world_mouse:{1}, offset:{2}, target_pos:{3}".format([base_pos, world_mouse, offset, target_pos]))
		camera.global_position = camera.global_position.lerp(target_pos, 0.25)
	
