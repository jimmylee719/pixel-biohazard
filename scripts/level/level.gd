## 用文字地圖建立關卡：地板、牆壁碰撞、遮光體、導航網格、巡邏點。
## 原型階段用色塊，之後換成 TileMapLayer 和正式美術時，只要保留同樣的對外函式即可。
##
## 地圖符號：
##   #  牆壁
##   C  櫃子（擋路、擋視線）
##   .  地板
##   P  主角出生點
##   1～9  敵人巡邏點（依數字順序來回巡邏，1 是敵人出生點）
class_name Level
extends Node2D

const TILE := 16
const WALL_LAYER := 1

const MAP: Array[String] = [
	"########################################",
	"#..................#####################",
	"#..1...........2...#####################",
	"#..................#####################",
	"#...CC......CC.....#####################",
	"#...CC......CC.....#####################",
	"#..................#####################",
	"#..................#####################",
	"#...CC......CC.....#####################",
	"#...CC......CC.....#####################",
	"#..............3...#####################",
	"#..................#####################",
	"########...#############################",
	"########...#############################",
	"########...#############################",
	"########.4.#############################",
	"########...#############################",
	"########.....................C.......###",
	"########.........5.......6...C.......###",
	"########.............................###",
	"##################################...###",
	"##################################...###",
	"##################################.P.###",
	"##################################...###",
	"########################################",
]

const FLOOR_COLOR_A := Color(0.42, 0.44, 0.48)
const FLOOR_COLOR_B := Color(0.38, 0.40, 0.44)
const WALL_COLOR := Color(0.20, 0.22, 0.26)
const WALL_EDGE_COLOR := Color(0.30, 0.33, 0.38)
const CABINET_COLOR := Color(0.30, 0.24, 0.18)
const CABINET_EDGE_COLOR := Color(0.42, 0.34, 0.25)

var player_spawn := Vector2.ZERO
var patrol_points: Array[Vector2] = []
var bounds := Rect2()

var _floor_cells: Array[Vector2i] = []
var _nav_region: NavigationRegion2D
var _structure_layer: CanvasLayer


func _ready() -> void:
	_parse_map()
	_build_solids()
	_bake_navigation()
	queue_redraw()


## 地板直接畫在世界圖層，會被燈光照亮、在黑暗中看不見。
func _draw() -> void:
	for cell in _floor_cells:
		var color := FLOOR_COLOR_A if (cell.x + cell.y) % 2 == 0 else FLOOR_COLOR_B
		draw_rect(Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE)), color)


func get_navigation_map() -> RID:
	return _nav_region.get_navigation_map()


func _parse_map() -> void:
	var width := 0
	var waypoints := {}
	for y in MAP.size():
		var row: String = MAP[y]
		width = maxi(width, row.length())
		for x in row.length():
			var ch := row[x]
			if ch == "#" or ch == "C":
				continue
			_floor_cells.append(Vector2i(x, y))
			var center := _cell_center(Vector2i(x, y))
			if ch == "P":
				player_spawn = center
			elif ch.is_valid_int():
				waypoints[ch.to_int()] = center
	var keys := waypoints.keys()
	keys.sort()
	for k in keys:
		patrol_points.append(waypoints[k])
	bounds = Rect2(Vector2.ZERO, Vector2(width, MAP.size()) * TILE)
	assert(player_spawn != Vector2.ZERO, "地圖缺少主角出生點 P")
	assert(patrol_points.size() >= 2, "地圖至少需要兩個巡邏點")


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


## 把同種類的相鄰格子合併成長方形，減少碰撞體和遮光體的數量。
func _merge_rects(symbol: String) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	var open := {}  # Vector2i(x0, x1) -> 在 result 裡的索引（上一列延伸下來的長方形）
	for y in MAP.size():
		var row: String = MAP[y]
		var runs: Array[Vector2i] = []
		var x := 0
		while x < row.length():
			if row[x] == symbol:
				var start := x
				while x < row.length() and row[x] == symbol:
					x += 1
				runs.append(Vector2i(start, x))
			else:
				x += 1
		var next_open := {}
		for run in runs:
			if open.has(run):
				var idx: int = open[run]
				result[idx].size.y += 1
				next_open[run] = idx
			else:
				result.append(Rect2i(run.x, y, run.y - run.x, 1))
				next_open[run] = result.size() - 1
		open = next_open
	return result


func _build_solids() -> void:
	# 導航區域：牆壁的碰撞體放在它底下，烘焙時才會被當成障礙物。
	_nav_region = NavigationRegion2D.new()
	_nav_region.name = "Navigation"
	add_child(_nav_region)

	# 牆壁的外觀放在獨立的 CanvasLayer，不受黑暗影響，讓玩家永遠看得懂建築結構。
	_structure_layer = CanvasLayer.new()
	_structure_layer.name = "Structure"
	_structure_layer.layer = 1
	_structure_layer.follow_viewport_enabled = true
	add_child(_structure_layer)

	for rect in _merge_rects("#"):
		_add_solid(rect, WALL_COLOR, WALL_EDGE_COLOR)
	for rect in _merge_rects("C"):
		_add_solid(rect, CABINET_COLOR, CABINET_EDGE_COLOR)


func _add_solid(cell_rect: Rect2i, fill: Color, edge: Color) -> void:
	var rect := Rect2(Vector2(cell_rect.position) * TILE, Vector2(cell_rect.size) * TILE)
	var points := PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])

	var body := StaticBody2D.new()
	body.collision_layer = WALL_LAYER
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = rect.size
	shape.shape = rect_shape
	shape.position = rect.get_center()
	body.add_child(shape)
	_nav_region.add_child(body)

	# 遮光體：讓手電筒和身邊的光被牆擋住，產生視線遮蔽。
	var occluder := LightOccluder2D.new()
	var occ_poly := OccluderPolygon2D.new()
	occ_poly.polygon = points
	occluder.occluder = occ_poly
	add_child(occluder)

	var visual := Polygon2D.new()
	visual.polygon = points
	visual.color = fill
	_structure_layer.add_child(visual)
	var outline := Line2D.new()
	outline.points = points
	outline.closed = true
	outline.width = 1.0
	outline.default_color = edge
	_structure_layer.add_child(outline)


func _bake_navigation() -> void:
	var nav_poly := NavigationPolygon.new()
	nav_poly.agent_radius = 6.0
	nav_poly.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_poly.parsed_collision_mask = WALL_LAYER
	nav_poly.add_outline(PackedVector2Array([
		bounds.position,
		Vector2(bounds.end.x, bounds.position.y),
		bounds.end,
		Vector2(bounds.position.x, bounds.end.y),
	]))
	_nav_region.navigation_polygon = nav_poly
	_nav_region.bake_navigation_polygon(false)
