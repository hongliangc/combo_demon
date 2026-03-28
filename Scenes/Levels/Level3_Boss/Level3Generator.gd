@tool
extends Node2D

## Boss Arena Generator — @tool 脚本
## 使用方法:
##   1. 在编辑器中打开 Level3.tscn
##   2. 选中根节点 Level3, 在 Inspector 中确认 Script 为此脚本
##   3. 勾选 Inspector 中的 "Generate Arena" 复选框
##   4. 保存场景 (Ctrl+S)
##   5. 将 Script 改回 Level3.gd
##
## Arena 设计: 50×28 tiles (800×448 px)
##   - 不规则洞穴墙壁 + 实心地板
##   - 2 个掩体柱子 (遮挡Boss水平攻击)
##   - 5 个浮空平台 (阶梯式, 高度差≤3 tiles)
##   - 所有跳跃均可达 (gap≤5, height≤3)

const ATLAS_ID := 0

@export var generate_arena: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			seed(12345)
			_generate()
			print("Boss Arena generated!")
		generate_arena = false


func _generate() -> void:
	var ground := $TileMap/Ground as TileMapLayer
	var back := $TileMap/BackRock as TileMapLayer
	var grass := $TileMap/Grass as TileMapLayer
	var test := $TileMap/Test as TileMapLayer

	if not ground:
		push_error("Missing TileMap/Ground node")
		return

	ground.clear()
	if back:
		back.clear()
	if grass:
		grass.clear()
	if test:
		test.clear()

	# --- 1. Build terrain shape ---
	var terrain_cells: Array[Vector2i] = []

	# Floor: full width, y=22 to y=27
	for x in range(50):
		for y in range(22, 28):
			terrain_cells.append(Vector2i(x, y))

	# Left wall (irregular cave shape)
	var left_wall_width := {
		5: 2, 6: 2, 7: 3, 8: 3, 9: 3,
		10: 3, 11: 3, 12: 3, 13: 4, 14: 3,
		15: 3, 16: 3, 17: 3, 18: 3, 19: 4, 20: 4, 21: 5
	}
	for y in left_wall_width:
		var w: int = left_wall_width[y]
		for x in range(w):
			terrain_cells.append(Vector2i(x, y))

	# Right wall (mirror of left)
	for y in left_wall_width:
		var w: int = left_wall_width[y]
		for x in range(50 - w, 50):
			terrain_cells.append(Vector2i(x, y))

	# Pillars — cover for boss horizontal attacks (laser)
	# Left pillar: x=14-16, y=19-21 (connects to floor at y=22)
	for x in range(14, 17):
		for y in range(19, 22):
			terrain_cells.append(Vector2i(x, y))
	# Right pillar: x=33-35, y=19-21
	for x in range(33, 36):
		for y in range(19, 22):
			terrain_cells.append(Vector2i(x, y))

	# --- 2. Place ground tiles by neighbor detection ---
	# Atlas layout (5 cols × 5 rows):
	#   col 0 = left edge, col 1-3 = center variants, col 4 = right edge
	#   row 0 = grass surface, row 1 = sub-surface, row 2-3 = body fill, row 4 = bottom
	var cell_set := {}
	for c in terrain_cells:
		cell_set[c] = true

	for c in terrain_cells:
		var has_top := cell_set.has(c + Vector2i(0, -1))
		var has_bottom := cell_set.has(c + Vector2i(0, 1))
		var has_left := cell_set.has(c + Vector2i(-1, 0))
		var has_right := cell_set.has(c + Vector2i(1, 0))

		# Column: left/right edge or center
		var col: int
		if not has_left and not has_right:
			col = randi() % 3 + 1  # isolated narrow, use center
		elif not has_left:
			col = 0  # left edge
		elif not has_right:
			col = 4  # right edge
		else:
			col = randi() % 3 + 1  # center (1, 2, or 3)

		# Row: layered top-down
		var row: int
		if not has_top:
			if has_left and has_right:
				row = 0  # wide grass surface
			else:
				row = 1  # narrow/edge surface (wall steps, corners)
		elif not cell_set.has(c + Vector2i(0, -2)):
			# Sub-surface only under wide surfaces
			var above := c + Vector2i(0, -1)
			if cell_set.has(above + Vector2i(-1, 0)) and cell_set.has(above + Vector2i(1, 0)):
				row = 1  # sub-surface under wide grass
			else:
				row = randi() % 2 + 2  # body fill under narrow surface
		elif not has_bottom:
			row = 4  # bottom edge
		else:
			row = randi() % 2 + 2  # body fill: row 2 or 3

		ground.set_cell(c, ATLAS_ID, Vector2i(col, row))

	var surface_coords := _find_surface_cells(terrain_cells)

	# --- 3. Floating platforms ---
	_place_platform(ground, 9, 13, 19, 2)     # Side left
	_place_platform(ground, 36, 40, 19, 2)    # Side right
	_place_platform(ground, 17, 19, 17, 2)    # Step left (above pillar)
	_place_platform(ground, 30, 32, 17, 2)    # Step right (above pillar)
	_place_platform(ground, 21, 28, 15, 2)    # Center high

	# --- 4. Decoration: BackRock ---
	if back:
		_place_back_decoration(back)

	# --- 5. Decoration: Grass ---
	if grass:
		_place_grass_decoration(grass, surface_coords)


## Find the topmost terrain cell in each column
func _find_surface_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var col_min_y: Dictionary = {}  # x -> min y
	for c in cells:
		if not col_min_y.has(c.x) or c.y < col_min_y[c.x]:
			col_min_y[c.x] = c.y
	var result: Array[Vector2i] = []
	for x in col_min_y:
		result.append(Vector2i(x, col_min_y[x]))
	return result


## Place a rectangular platform with proper edge/corner tiles
func _place_platform(layer: TileMapLayer, x_start: int, x_end: int, y_top: int, height: int) -> void:
	for x in range(x_start, x_end + 1):
		for dy in range(height):
			var col: int
			if x == x_start:
				col = 0  # left edge
			elif x == x_end:
				col = 4  # right edge
			else:
				col = randi() % 3 + 1  # center

			var row: int
			if dy == 0:
				row = 0  # grass surface
			elif dy == 1:
				row = 1  # sub-surface
			elif dy == height - 1:
				row = 4  # bottom
			else:
				row = randi() % 2 + 2  # body fill

			layer.set_cell(Vector2i(x, y_top + dy), ATLAS_ID, Vector2i(col, row))


## Place bush formations as background decoration
## Bush atlas (from AtlasTest Cat_Bush annotation):
##   5 variants, each 8 cols × 3 rows at atlas cols 17-24
##   Top row: cols 19-22 only (rounded top), middle+bottom: cols 17-24
##   Variant 0: rows 0-2, Variant 1: rows 3-5, ..., Variant 4: rows 12-14
func _place_back_decoration(layer: TileMapLayer) -> void:
	# Full bushes (8 wide × 3 tall, with rounded top)
	var bush_placements := [
		[Vector2i(6, 8), 0],      # Left cave area, variant 0
		[Vector2i(18, 7), 1],     # Center-left, variant 1
		[Vector2i(27, 8), 2],     # Center-right, variant 2
		[Vector2i(38, 7), 3],     # Right cave area, variant 3
	]
	for entry in bush_placements:
		var pos: Vector2i = entry[0]
		var variant: int = entry[1]
		_place_bush(layer, pos, variant)

	# Small accent bushes (4 wide × 3 tall, center portion only)
	var accent_placements := [
		[Vector2i(13, 14), 4],    # Behind left pillar, variant 4
		[Vector2i(34, 14), 0],    # Behind right pillar, variant 0
	]
	for entry in accent_placements:
		var pos: Vector2i = entry[0]
		var variant: int = entry[1]
		_place_small_bush(layer, pos, variant)


## Place a full bush (8 wide × 3 tall with rounded top)
func _place_bush(layer: TileMapLayer, pos: Vector2i, variant: int) -> void:
	var row_start := variant * 3
	# Top row: only center 4 tiles (atlas cols 19-22)
	for dx in range(4):
		layer.set_cell(Vector2i(pos.x + 2 + dx, pos.y), ATLAS_ID, Vector2i(19 + dx, row_start))
	# Middle and bottom rows: full 8 tiles (atlas cols 17-24)
	for dy in range(1, 3):
		for dx in range(8):
			layer.set_cell(Vector2i(pos.x + dx, pos.y + dy), ATLAS_ID, Vector2i(17 + dx, row_start + dy))


## Place a small bush (4 wide × 3 tall, center only)
func _place_small_bush(layer: TileMapLayer, pos: Vector2i, variant: int) -> void:
	var row_start := variant * 3
	for dy in range(3):
		for dx in range(4):
			layer.set_cell(Vector2i(pos.x + dx, pos.y + dy), ATLAS_ID, Vector2i(19 + dx, row_start + dy))


## Place decoration items on terrain surface
## From AtlasTest annotations:
##   Grass blades: atlas (9-12, 0)
##   Mushroom 1x1: atlas (15,15), (15,16)
##   Flower 1x1: atlas (21,15), (21,16), (16,17), (22,17), (15,19)
func _place_grass_decoration(layer: TileMapLayer, surface_cells: Array[Vector2i]) -> void:
	# 1×1 decoration tiles (mushrooms + flowers)
	var deco_tiles := [
		Vector2i(15, 15),  # mushroom
		Vector2i(15, 16),  # mushroom
		Vector2i(21, 15),  # flower
		Vector2i(21, 16),  # flower
		Vector2i(16, 17),  # flower
		Vector2i(22, 17),  # flower
		Vector2i(15, 19),  # flower
	]

	for pos in surface_cells:
		# Skip wall areas
		if pos.x < 5 or pos.x > 44:
			continue
		# Skip pillar tops (decoration would clip into pillar)
		if (pos.x >= 14 and pos.x <= 16) or (pos.x >= 33 and pos.x <= 35):
			continue

		var chance := randi() % 10
		var deco_pos := Vector2i(pos.x, pos.y - 1)

		if chance == 0:
			# Decoration item (mushroom/flower, single tile)
			var tile: Vector2i = deco_tiles[randi() % deco_tiles.size()]
			layer.set_cell(deco_pos, ATLAS_ID, tile)
		elif chance <= 3:
			# Grass blade (single tile)
			var col: int = 9 + randi() % 4   # cols 9-12
			layer.set_cell(deco_pos, ATLAS_ID, Vector2i(col, 0))
