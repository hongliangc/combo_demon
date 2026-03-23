@tool
extends Path2D
class_name CollectiblePath

## 沿路径自动排列收集物（基于 PathFollow2D）
##
## 使用方式：
## 1. 添加此节点到关卡场景
## 2. 编辑 Curve 画出路径
## 3. 设置 count 和 item_type，编辑器自动预览
## 4. 运行时自动沿路径生成 Collectible

const CollectibleScene = preload("res://Scenes/Levels/Components/Collectible.tscn")

@export_enum("coin", "key", "gem_red", "gem_green", "gem_blue", "gem_yellow", "heart") var item_type: String = "coin":
	set(v):
		item_type = v
		if Engine.is_editor_hint():
			queue_redraw()

@export_range(1, 50) var count: int = 5:
	set(v):
		count = v
		if Engine.is_editor_hint():
			queue_redraw()


func _ready() -> void:
	if Engine.is_editor_hint():
		if curve and not curve.changed.is_connected(queue_redraw):
			curve.changed.connect(queue_redraw)
	else:
		_spawn_collectibles()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	if not curve or curve.point_count < 2:
		return

	var length := curve.get_baked_length()
	if length < 1.0:
		return

	for i in count:
		var ratio := 0.5 if count == 1 else float(i) / float(count - 1)
		var pos := curve.sample_baked(ratio * length)
		draw_circle(pos, 6.0, Color(1.0, 0.85, 0.0, 0.8))
		draw_arc(pos, 6.0, 0, TAU, 16, Color(1.0, 0.7, 0.0), 1.5)


func _spawn_collectibles() -> void:
	if not curve or curve.point_count < 2:
		return

	for i in count:
		var ratio := 0.5 if count == 1 else float(i) / float(count - 1)

		var follower := PathFollow2D.new()
		follower.rotates = false
		add_child(follower)
		follower.progress_ratio = ratio

		var collectible := CollectibleScene.instantiate()
		collectible.item_type = item_type
		follower.add_child(collectible)
