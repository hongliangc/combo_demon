extends Node2D
class_name player_spawn

## 角色场景预加载（用于编辑器测试和备用）
var player_selection: Dictionary = {
	"hahashin": preload("res://Scenes/charaters/hahashin.tscn"),
}

@export_group("Character Selection")
@export_enum("hahashin")
var player_name: String = "hahashin"

## 是否使用 GameManager 的角色选择
@export var use_game_manager: bool = true

var player = null

@onready var camera: Camera2D = $"../Camera2D"
@export var sensitivity := 0.25
var aim_position:Vector2

## CameraManager 引用（用于检查是否正在进行镜头切换）
var _camera_manager: CameraManager = null

func _ready() -> void:
	_spawn_player()
	_setup_camera()


## 生成玩家角色
func _spawn_player() -> void:
	# 优先使用 GameManager 的角色选择
	if use_game_manager and GameManager and GameManager.has_selected_character():
		player = GameManager.create_player()
		if player:
			player.global_position = self.global_position
			add_child(player)
			print("PlayerSpawn: Spawned character from GameManager - ", GameManager.selected_character.display_name)
			return

	# 备用方案：使用预设的角色
	if player_selection.has(player_name):
		var scene: PackedScene = player_selection[player_name]
		player = scene.instantiate()
		player.global_position = self.global_position
		add_child(player)
		print("PlayerSpawn: Spawned default character - ", player_name)
	else:
		push_error("PlayerSpawn: Character not found - ", player_name)


## 设置摄像机
func _setup_camera() -> void:
	if not camera:
		return

	# 获取当前屏幕分辨率（不含缩放）
	var screen_size = get_viewport_rect().size
	print("Screen resolution: ", screen_size)

	# 计算摄像机可视区域（世界范围）
	var visible_world = screen_size * camera.zoom
	print("Visible world size: ", visible_world)

	# 延迟查找 CameraManager（等待玩家子节点初始化）
	call_deferred("_find_camera_manager")

## 查找玩家的 CameraManager 组件
func _find_camera_manager() -> void:
	if player:
		_camera_manager = player.get_node_or_null("CameraManager")
	
func _physics_process(_delta: float) -> void:
	if player and camera:
		# 如果 CameraManager 正在进行镜头切换，跳过跟随逻辑
		if _camera_manager and _camera_manager.is_transitioning:
			return

		var base_pos = player.global_position
		var world_mouse = get_global_mouse_position()

		var offset = world_mouse - base_pos
		# 限制偏移在屏幕范围的一半以内, offset最大get_viewport_rect的一半
		var max_offset = get_viewport_rect().size * 0.5
		offset.x = clamp(offset.x, -max_offset.x, max_offset.x)
		offset.y = clamp(offset.y, -max_offset.y, max_offset.y)
		#基于offset的一半，1/4屏幕中心位置
		offset = Vector2.ZERO # 不跟随鼠标
		var target_pos = base_pos + offset * sensitivity

		# print("base_pos:{0} world_mouse:{1}, offset:{2}, target_pos:{3}".format([base_pos, world_mouse, offset, target_pos]))
		camera.global_position = camera.global_position.lerp(target_pos, 0.25)
	
