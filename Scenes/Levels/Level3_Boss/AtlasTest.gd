@tool
extends Node2D

## Atlas 物品分类 & 测试工具
## 按钮:
##   Generate Grid: 生成 25×25 参考网格 + 分类标签
##   Generate Test: 从分类层提取物品，整理展示 + 打印坐标目录

@export var generate_grid: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_generate()
			print("Atlas grid + category labels generated!")
		generate_grid = false

@export var generate_test: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_generate_test_display()
			print("Test display generated! Check Output for catalog.")
		generate_test = false


# ============================================================
# Reference Grid
# ============================================================

func _generate() -> void:
	var ref_layer := $Reference as TileMapLayer
	if not ref_layer:
		push_error("Missing Reference TileMapLayer")
		return

	ref_layer.clear()

	# Remove old grid/category labels (keep test labels "TL_*")
	for child in get_children():
		if child is Label and not child.name.begins_with("TL_"):
			child.queue_free()

	for row in range(25):
		for col in range(25):
			ref_layer.set_cell(Vector2i(col, row), 0, Vector2i(col, row))

	# Column numbers (top)
	for col in range(25):
		var label := Label.new()
		label.text = str(col)
		label.position = Vector2(col * 16 + 4, -16)
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_color", Color.YELLOW)
		add_child(label)
		label.owner = get_tree().edited_scene_root

	# Row numbers (left)
	for row in range(25):
		var label := Label.new()
		label.text = str(row)
		label.position = Vector2(-20, row * 16 + 2)
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_color", Color.YELLOW)
		add_child(label)
		label.owner = get_tree().edited_scene_root

	# Category section labels
	var categories := [
		["Cat_Bush", "1. 草丛 Bush"],
		["Cat_Tree", "2. 树 Tree"],
		["Cat_Wood", "3. 木板/桥 Wood/Bridge"],
		["Cat_Mushroom", "4. 蘑菇 Mushroom"],
		["Cat_Flower", "5. 花朵/植物 Flower/Plant"],
		["Cat_Chest", "6. 宝箱 Chest"],
		["Cat_KeyTool", "7. 钥匙/工具 Key/Tool"],
		["Cat_Pot", "8. 壶罐/袋子 Pot/Bag"],
		["Cat_Potion", "9. 药水 Potion"],
		["Cat_Water", "10. 瀑布/水 Water"],
		["Cat_Rock", "11. 岩石 Rock"],
		["Cat_Leaf", "12. 藤蔓/叶子 Vine/Leaf"],
		["Cat_Other", "13. 其他 Other"],
	]

	for entry in categories:
		var node_name: String = entry[0]
		var display_name: String = entry[1]
		var cat_layer := get_node_or_null(node_name) as TileMapLayer
		if cat_layer:
			var label := Label.new()
			label.text = display_name
			label.position = Vector2(-8, cat_layer.position.y - 18)
			label.add_theme_font_size_override("font_size", 11)
			label.add_theme_color_override("font_color", Color.CYAN)
			add_child(label)
			label.owner = get_tree().edited_scene_root


# ============================================================
# Test Display: extract & organize all annotated items
# ============================================================

func _generate_test_display() -> void:
	var test_layer := $TestDisplay as TileMapLayer
	if not test_layer:
		push_error("Missing TestDisplay TileMapLayer")
		return
	test_layer.clear()

	# Remove old test labels
	for child in get_children():
		if child is Label and child.name.begins_with("TL_"):
			child.queue_free()

	# Scan all Cat_* layers
	var all_categories := []
	for child in get_children():
		if not (child is TileMapLayer):
			continue
		if not child.name.begins_with("Cat_"):
			continue
		var cells: Array[Vector2i] = child.get_used_cells()
		if cells.size() == 0:
			continue
		var items := _find_connected_items(child, cells)
		all_categories.append({
			"name": String(child.name).replace("Cat_", ""),
			"items": items,
		})

	# Layout: one row per category, items side by side
	var y := 0
	var catalog_lines: PackedStringArray = ["=== ITEM CATALOG ==="]
	var label_idx := 0

	for cat in all_categories:
		var cat_name: String = cat["name"]
		var items: Array = cat["items"]

		# Category label
		var label := Label.new()
		label.name = "TL_%d" % label_idx
		label_idx += 1
		label.text = cat_name
		label.position = Vector2(
			test_layer.position.x,
			test_layer.position.y + y * 16 - 14
		)
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color.LIME_GREEN)
		add_child(label)
		label.owner = get_tree().edited_scene_root

		catalog_lines.append("--- %s ---" % cat_name)

		# Place items side by side
		var x := 0
		var max_h := 0
		for item in items:
			var w: int = item["w"]
			var h: int = item["h"]
			var ax: int = item["atlas_x"]
			var ay: int = item["atlas_y"]

			for tile_data in item["tiles"]:
				var cell: Vector2i = tile_data["cell"]
				var atlas: Vector2i = tile_data["atlas"]
				var lx: int = cell.x - item["min_x"]
				var ly: int = cell.y - item["min_y"]
				test_layer.set_cell(Vector2i(x + lx, y + ly), 0, atlas)

			catalog_lines.append("  [%d, %d, %d, %d]" % [ax, ay, w, h])
			x += w + 1
			if h > max_h:
				max_h = h

		y += max_h + 2

	catalog_lines.append("=== END ===")
	print("\n".join(catalog_lines))


# ============================================================
# Connected-component item extraction
# ============================================================

func _find_connected_items(layer: TileMapLayer, cells: Array) -> Array:
	var cell_set := {}
	for c in cells:
		cell_set[c] = true

	var visited := {}
	var items := []
	var directions := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	for c in cells:
		if visited.has(c):
			continue

		# BFS flood fill
		var queue: Array[Vector2i] = [c]
		var component: Array[Vector2i] = []
		visited[c] = true

		while queue.size() > 0:
			var current: Vector2i = queue.pop_front()
			component.append(current)
			for dir in directions:
				var nb: Vector2i = current + dir
				if cell_set.has(nb) and not visited.has(nb):
					visited[nb] = true
					queue.append(nb)

		# Bounding box
		var min_x: int = component[0].x
		var min_y: int = component[0].y
		var max_x: int = component[0].x
		var max_y: int = component[0].y
		for p in component:
			min_x = mini(min_x, p.x)
			min_y = mini(min_y, p.y)
			max_x = maxi(max_x, p.x)
			max_y = maxi(max_y, p.y)

		# Collect tile atlas coords
		var tiles := []
		for p in component:
			tiles.append({"cell": p, "atlas": layer.get_cell_atlas_coords(p)})

		# Atlas origin from top-left corner
		var atlas_origin := Vector2i(-1, -1)
		var top_left := Vector2i(min_x, min_y)
		if cell_set.has(top_left):
			atlas_origin = layer.get_cell_atlas_coords(top_left)
		else:
			for p in component:
				if p.y == min_y:
					atlas_origin = layer.get_cell_atlas_coords(p)
					break

		items.append({
			"min_x": min_x, "min_y": min_y,
			"w": max_x - min_x + 1, "h": max_y - min_y + 1,
			"atlas_x": atlas_origin.x, "atlas_y": atlas_origin.y,
			"tiles": tiles,
		})

	# Sort: top to bottom, then left to right
	items.sort_custom(func(a, b):
		if a["min_y"] != b["min_y"]:
			return a["min_y"] < b["min_y"]
		return a["min_x"] < b["min_x"]
	)

	return items
