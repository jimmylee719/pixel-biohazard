## 用文字地圖建立關卡：地板、牆壁碰撞、遮光體、導航網格、互動物件、敵人路線、溫度區域。
## 原型階段用色塊，之後換成 TileMapLayer 和正式美術時，只要保留同樣的對外函式即可。
##
## 地圖符號：
##   #  牆壁
##   C  櫃子／實驗桌（擋路、擋視線）
##   H  置物櫃（擋路、擋視線，可以躲進去）
##   .  地板
##   P  主角出生點
##   B  空瓶（可撿起、可投擲當誘餌）
##   X  配電箱（切換某個區域的暖氣）
##   G  出口（原型的終點）
##   1～9、a～i  敵人巡邏點，哪些點屬於哪隻敵人見 ENEMIES
class_name Level
extends Node2D

signal zone_heat_changed(zone_name: String, heated: bool)

const TILE := 16
const WALL_LAYER := 1

const MAP: Array[String] = [
	"############################################",
	"#......H...........#########################",
	"#.G.......1........####........X.........###",
	"#...............2..####.........a.....B..###",
	"#...CC......CC.....####..................###",
	"#...CC......CC............CCCCC..CCCCC...###",
	"#........................................###",
	"#..................####..d..............H###",
	"#...CC......CC....H####..................###",
	"#...CC......CC.....####...CCCCC..CCCCC...###",
	"#..............3...####................b.###",
	"#..................####H.c...............###",
	"########...############..................###",
	"########...#################...#############",
	"########.4.#################...#############",
	"########...#################...#############",
	"########...#################...#############",
	"########................C...............####",
	"########......B.5.....6.C...............####",
	"########............H...................####",
	"##################################....######",
	"##################################.B..######",
	"##################################..P.######",
	"##################################....######",
	"############################################",
]

## 每隻敵人：種類＋巡邏路線（依字元順序來回巡邏，第一個點是出生點）
const ENEMIES := [
	{"type": "patroller", "route": "123456"},
	{"type": "listener", "route": "abcd"},
]

## 溫度區域（格子座標）。heated = 一開始有沒有開暖氣。
const ZONES := {
	"lounge": {"rect": Rect2i(1, 1, 18, 11), "heated": true},
	"lab": {"rect": Rect2i(23, 2, 18, 11), "heated": true},
}
## 配電箱控制哪一個區域（依地圖上 X 出現的順序）
const BREAKER_ZONES: Array[String] = ["lounge"]

const FLOOR_COLOR_A := Color(0.42, 0.44, 0.48)
const FLOOR_COLOR_B := Color(0.38, 0.40, 0.44)
const COLD_TINT := Color(0.55, 0.75, 1.0)
const WALL_COLOR := Color(0.20, 0.22, 0.26)
const WALL_EDGE_COLOR := Color(0.30, 0.33, 0.38)
const CABINET_COLOR := Color(0.30, 0.24, 0.18)
const CABINET_EDGE_COLOR := Color(0.42, 0.34, 0.25)
const LOCKER_COLOR := Color(0.22, 0.30, 0.34)
const LOCKER_EDGE_COLOR := Color(0.40, 0.55, 0.60)

var player_spawn := Vector2.ZERO
## [{"type": String, "points": Array[Vector2]}]
var enemy_defs: Array[Dictionary] = []
var bounds := Rect2()

var _floor_cells: Array[Vector2i] = []
var _waypoints := {}
var _heated := {}
var _nav_region: NavigationRegion2D
var _structure_layer: CanvasLayer
var _interactables: Array[Interactable] = []


func _ready() -> void:
	for zone_name in ZONES:
		_heated[zone_name] = ZONES[zone_name].heated
	_parse_map()
	_build_solids()
	_spawn_interactables()
	_bake_navigation()
	queue_redraw()


## 地板直接畫在世界圖層，會被燈光照亮、在黑暗中看不見。沒開暖氣的區域地板偏藍（結霜）。
func _draw() -> void:
	for cell in _floor_cells:
		var color := FLOOR_COLOR_A if (cell.x + cell.y) % 2 == 0 else FLOOR_COLOR_B
		if is_cold(_cell_center(cell)):
			color = color * COLD_TINT
		draw_rect(Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE)), color)


func get_navigation_map() -> RID:
	return _nav_region.get_navigation_map()


func get_interactables() -> Array[Interactable]:
	return _interactables


# ── 溫度 ──────────────────────────────────────────────

func zone_at(pos: Vector2) -> String:
	var cell := Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))
	for zone_name in ZONES:
		if (ZONES[zone_name].rect as Rect2i).has_point(cell):
			return zone_name
	return ""


func is_cold(pos: Vector2) -> bool:
	var zone := zone_at(pos)
	return zone != "" and not _heated[zone]


func is_zone_heated(zone_name: String) -> bool:
	return _heated.get(zone_name, true)


func set_zone_heated(zone_name: String, heated: bool) -> void:
	if _heated.get(zone_name) == heated:
		return
	_heated[zone_name] = heated
	queue_redraw()
	zone_heat_changed.emit(zone_name, heated)


## 被抓到或過關後，把關卡恢復成初始狀態。
func reset_state() -> void:
	for zone_name in ZONES:
		set_zone_heated(zone_name, ZONES[zone_name].heated)
	for item in _interactables:
		item.reset()


# ── 建立 ──────────────────────────────────────────────

func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


func _parse_map() -> void:
	var width := 0
	for y in MAP.size():
		var row: String = MAP[y]
		width = maxi(width, row.length())
		for x in row.length():
			var ch := row[x]
			if ch == "#" or ch == "C" or ch == "H":
				continue
			_floor_cells.append(Vector2i(x, y))
			var center := _cell_center(Vector2i(x, y))
			if ch == "P":
				player_spawn = center
			elif ch != "." and ch != "B" and ch != "X" and ch != "G":
				_waypoints[ch] = center
	bounds = Rect2(Vector2.ZERO, Vector2(width, MAP.size()) * TILE)
	assert(player_spawn != Vector2.ZERO, "地圖缺少主角出生點 P")

	for def in ENEMIES:
		var points: Array[Vector2] = []
		for ch in String(def.route):
			assert(_waypoints.has(ch), "地圖缺少巡邏點 %s" % ch)
			points.append(_waypoints[ch])
		enemy_defs.append({"type": def.type, "points": points})


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
	for rect in _merge_rects("H"):
		_add_solid(rect, LOCKER_COLOR, LOCKER_EDGE_COLOR)


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


func _spawn_interactables() -> void:
	var breaker_index := 0
	for y in MAP.size():
		var row: String = MAP[y]
		for x in row.length():
			var center := _cell_center(Vector2i(x, y))
			var item: Interactable = null
			match row[x]:
				"H":
					item = Locker.new()
				"B":
					item = BottlePickup.new()
				"X":
					var breaker := Breaker.new()
					breaker.level = self
					breaker.zone_name = BREAKER_ZONES[breaker_index]
					breaker_index += 1
					item = breaker
				"G":
					item = ExitPoint.new()
			if item:
				item.position = center
				add_child(item)
				_interactables.append(item)


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
