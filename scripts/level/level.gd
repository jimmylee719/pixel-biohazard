## 依區域資料（Areas.DATA）建立一個區域：地板、牆壁碰撞、遮光體、導航網格、互動物件、門、敵人路線、溫度區域。
## 原型階段用色塊，之後換成 TileMapLayer 和正式美術時，只要保留同樣的對外函式即可。
## 地圖符號見 scripts/world/areas.gd。
class_name Level
extends Node2D

signal zone_heat_changed(zone_name: String, heated: bool)

const TILE := 16
const WALL_LAYER := 1
## 窗戶：擋路但不擋視線、不擋光（Sight 只看 WALL_LAYER）
const WINDOW_LAYER := 8
## 看不穿的格子（第一人稱視角的射線、房間判定用）
const SOLID_CHARS := "#CH"

const INDOOR_FLOOR_A := Color(0.42, 0.44, 0.48)
const INDOOR_FLOOR_B := Color(0.38, 0.40, 0.44)
const SNOW_FLOOR_A := Color(0.70, 0.74, 0.80)
const SNOW_FLOOR_B := Color(0.66, 0.70, 0.77)
const SAFE_FLOOR_A := Color(0.55, 0.50, 0.42)
const SAFE_FLOOR_B := Color(0.51, 0.46, 0.39)
const DOOR_COLOR := Color(0.55, 0.45, 0.25)
const COLD_TINT := Color(0.55, 0.75, 1.0)
const WALL_COLOR := Color(0.20, 0.22, 0.26)
const WALL_EDGE_COLOR := Color(0.30, 0.33, 0.38)
const ROCK_COLOR := Color(0.16, 0.17, 0.20)
const ROCK_EDGE_COLOR := Color(0.32, 0.34, 0.40)
const CABINET_COLOR := Color(0.30, 0.24, 0.18)
const CABINET_EDGE_COLOR := Color(0.42, 0.34, 0.25)
const LOCKER_COLOR := Color(0.22, 0.30, 0.34)
const LOCKER_EDGE_COLOR := Color(0.40, 0.55, 0.60)
const FLOOR_CHARS := ".PDBKTXGAMVWRYNSLQOxFEZUJIowpqru+"

## 建立前設定
var area_id := Areas.START_AREA

var title := ""
var outdoor := false
## 安全屋：沒有敵人、燈光溫暖
var safe := false
var zones := {}
## [{"type": String, "points": Array[Vector2]}]
var enemy_defs: Array[Dictionary] = []
var bounds := Rect2()

var _data := {}
var _map: Array = []
var _floor_cells: Array[Vector2i] = []
var _waypoints := {}
var _start_position := Vector2.ZERO
var _nav_region: NavigationRegion2D
var _structure_layer: CanvasLayer
var _interactables: Array[Interactable] = []
var _rebake_pending := false
## 格子 → 房間編號（見 _build_rooms）
var room_of := {}
var room_count := 0
var _inner_doors: Array[InteriorDoor] = []
## 有兩間以上的房間時才有（看不到別的房間）
var fog: RoomFog
## 這個區域的警戒狀態（ALERT／EVASION／CAUTION、呼叫同伴）
var alert: AlertNetwork


func _ready() -> void:
	_data = Areas.get_area(area_id)
	_map = _data.map
	title = _data.title
	outdoor = _data.outdoor
	safe = _data.get("safe", false)
	zones = _data.zones
	alert = AlertNetwork.new()
	alert.name = "AlertNetwork"
	add_child(alert)
	_parse_map()
	_build_solids()
	_spawn_interactables()
	_build_inner_doors()
	_build_rooms()
	if room_count > 1:
		var fog_layer := CanvasLayer.new()
		fog_layer.name = "RoomFog"
		fog_layer.layer = 2
		fog_layer.follow_viewport_enabled = true
		add_child(fog_layer)
		fog = RoomFog.new()
		fog.setup(self)
		fog_layer.add_child(fog)
	_bake_navigation()
	queue_redraw()


## 地板直接畫在世界圖層，會被燈光照亮、在黑暗中看不見。沒開暖氣的室內地板偏藍（結霜）。
func _draw() -> void:
	var concrete := Art.tex("tiles/floor_concrete")
	var frost := Art.tex("tiles/floor_frost")
	var lab := Art.tex("tiles/floor_lab")
	for cell in _floor_cells:
		var even := (cell.x + cell.y) % 2 == 0
		var rect := Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE))
		if outdoor and not _is_indoor_cell(cell):
			draw_rect(rect, SNOW_FLOOR_A if even else SNOW_FLOOR_B)
			continue
		# 室內：地板貼圖（64px 一張 = 4x4 格）。安全屋是無菌室的地板；沒暖氣的地方結霜。
		var cell_safe := is_safe_cell(cell)
		var cold := not cell_safe and is_cold(_cell_center(cell))
		var tex: Texture2D = lab if cell_safe else (frost if cold else concrete)
		if tex:
			var src := Rect2(Vector2(posmod(cell.x, 4), posmod(cell.y, 4)) * TILE, Vector2(TILE, TILE))
			draw_texture_rect_region(tex, rect, src, Color(0.85, 0.85, 0.9) if cell_safe else Color.WHITE)
			continue
		var color: Color
		if cell_safe:
			color = SAFE_FLOOR_A if even else SAFE_FLOOR_B
		else:
			color = INDOOR_FLOOR_A if even else INDOOR_FLOOR_B
			if cold:
				color = color * COLD_TINT
		draw_rect(rect, color)
	for door_id in _data.doors:
		var cell: Vector2i = _data.doors[door_id].cell
		draw_rect(Rect2(Vector2(cell) * TILE + Vector2(2, 2), Vector2(TILE - 4, TILE - 4)), DOOR_COLOR)


## 戶外區域裡的室內空間（例如倉庫）：地板畫成室內的樣子
func _is_indoor_cell(cell: Vector2i) -> bool:
	for r in _data.get("indoor_rects", []):
		if (r as Rect2i).has_point(cell):
			return true
	return false


func get_navigation_map() -> RID:
	return _nav_region.get_navigation_map()


func get_interactables() -> Array[Interactable]:
	return _interactables


## 執行中新增的互動物件（例如木箱破掉後掉出來的東西）
func add_interactable(item: Interactable) -> void:
	item.level = self
	add_child(item)
	item.sync_from_state()
	_interactables.append(item)


## 會擋路的物件（木箱、木板）：碰撞體放在導航區域底下，烘焙時才會被當成障礙物。
func add_nav_obstacle(pos: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = WALL_LAYER
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = size
	shape.shape = rect_shape
	body.add_child(shape)
	body.position = pos
	_nav_region.add_child(body)
	return body


## 地形改變了（木板被拆掉）：重新烘焙導航網格，敵人才走得過去。
func rebake_navigation() -> void:
	_rebake_pending = true
	_rebake.call_deferred()


func _rebake() -> void:
	if not _rebake_pending:
		return
	_rebake_pending = false
	_nav_region.bake_navigation_polygon(false)


func get_message(item_name: String) -> String:
	return _data.messages.get(item_name, "")


## 讀到／撿到這個物件會學到的頻率（0 = 沒有）
func get_learned_freq(item_name: String) -> int:
	return _data.get("learn", {}).get(item_name, 0)


# ── 門與入口 ──────────────────────────────────────────

## 進入這個區域時站的位置。entry = "start"（遊戲開始點）或門的 id。
func get_entry_position(entry: String) -> Vector2:
	var entries: Dictionary = _data.get("entries", {})
	if entries.has(entry):
		return _cell_center(entries[entry])
	if entry == Areas.START_ENTRY or not _data.doors.has(entry):
		return _start_position
	var door: Dictionary = _data.doors[entry]
	return _cell_center(door.cell + door.spawn_dir)


## 主角站在哪一扇門上（沒有就回傳空字串）。
func door_at(pos: Vector2) -> String:
	var cell := cell_of(pos)
	for door_id in _data.doors:
		if _data.doors[door_id].cell == cell:
			return door_id
	return ""


func door_target(door_id: String) -> String:
	return _data.doors[door_id].to


## 這扇門需要的權限等級（0 = 不需要）
func door_access(door_id: String) -> int:
	return _data.doors[door_id].get("access", 0)


## 這扇門是電動門（要先恢復電力）
func door_needs_power(door_id: String) -> bool:
	return _data.doors[door_id].get("power", false)


## 鏡頭模式："fixed" = 固定看整個區域（Boss 戰）
func camera_mode() -> String:
	return _data.get("camera", "follow")


func boss_name() -> String:
	return _data.get("boss", "")


func climate_id() -> String:
	return _data.get("climate", Areas.DEFAULT_CLIMATE)


## 主角站的地方每秒失去多少體溫（負數 = 正在回暖）。
## 安全屋、有暖氣的室內、火堆旁邊會回暖；戶外、沒暖氣的室內會失溫（依氣候）。
func exposure_at(pos: Vector2) -> float:
	var c := Climates.get_climate(climate_id())
	if is_safe_cell(cell_of(pos)):
		return -c.recover * 2.0
	if outdoor and not _is_indoor_cell(cell_of(pos)):
		return c.outdoor_loss
	if is_cold(pos):
		return c.cold_loss
	return -c.recover


## 腳步聲的地面：區域資料可以用 step 指定（例如鐵板 "metal"），不然戶外是雪、室內是水泥
func step_surface(pos: Vector2) -> String:
	if _data.has("step"):
		return _data.step
	if outdoor and not _is_indoor_cell(cell_of(pos)):
		return "snow"
	return "concrete"


## 區域的音樂（區域資料 music 可以指定）：安全屋、Boss 戰、戶外、室內
func music_id(pos := Vector2(-1, -1)) -> String:
	if _data.has("music"):
		return _data.music
	if safe or (pos.x >= 0 and is_safe_cell(cell_of(pos))):
		return "safe_room"
	match boss_name():
		"TUNDRA MOTHER":
			return "boss_bear"
		"THE DEEP WELL":
			return "boss_well"
	return "explore_outdoor" if outdoor else "explore_station"


## 區域的環境音（區域資料 ambience 可以指定）
func ambience_id(powered: bool) -> String:
	if _data.has("ambience"):
		return _data.ambience
	if outdoor and Climates.has_exposure(climate_id()):
		return "amb_blizzard"
	if outdoor:
		return ""
	return "amb_station_hum" if powered else "amb_station_dark"


# ── 房間（合併進來的房間、室內門分隔的空間）────────────────

## 這個位置屬於哪個區域 id：合併進來的房間（例如 station_safe）或主區域本身
func region_at(pos: Vector2) -> String:
	var cell := cell_of(pos)
	for r in _data.get("regions", []):
		if (r.rect as Rect2i).has_point(cell):
			return r.id
	return area_id


func region_title(region_id: String) -> String:
	for r in _data.get("regions", []):
		if r.id == region_id:
			return r.title
	return title


func is_safe_cell(cell: Vector2i) -> bool:
	if safe:
		return true
	for r in _data.get("regions", []):
		if r.safe and (r.rect as Rect2i).has_point(cell):
			return true
	return false


func is_safe_at(pos: Vector2) -> bool:
	return is_safe_cell(cell_of(pos))


func get_inner_doors() -> Array[InteriorDoor]:
	return _inner_doors


func _build_inner_doors() -> void:
	var defs: Dictionary = _data.get("inner_doors", {})
	for cell in _floor_cells:
		if char_at(cell) != "+":
			continue
		var key := "%d,%d" % [cell.x, cell.y]
		var def: Dictionary = defs.get(key, {})
		var door := InteriorDoor.new()
		# 左右是牆 = 門板橫的（上下通行）
		var side := (SOLID_CHARS + "+").contains(char_at(cell + Vector2i.LEFT)) or (SOLID_CHARS + "+").contains(char_at(cell + Vector2i.RIGHT))
		var horizontal := side
		door.setup(cell, horizontal, def.get("access", 0), def.get("safe", false))
		add_child(door)
		_inner_doors.append(door)
		if door.safe_door:
			# 只擋敵人的牆（也讓敵人的導航不會規劃進安全屋）
			var barrier := StaticBody2D.new()
			barrier.collision_layer = InteriorDoor.SAFE_BARRIER_LAYER
			barrier.collision_mask = 0
			var bs := CollisionShape2D.new()
			var br := RectangleShape2D.new()
			br.size = Vector2(TILE, TILE)
			bs.shape = br
			bs.position = _cell_center(cell)
			barrier.add_child(bs)
			_nav_region.add_child(barrier)
	# 相鄰的門格是同一道門：一起開關
	var by_cell := {}
	for d in _inner_doors:
		by_cell[d.cell] = d
	for d in _inner_doors:
		for n in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if by_cell.has(d.cell + n):
				d.partners.append(by_cell[d.cell + n])


## 用室內門把地板分成一間一間的房間（洪水填充）。家具、窗戶算在旁邊那間。
func _build_rooms() -> void:
	room_of.clear()
	room_count = 0
	for start in _floor_cells:
		if room_of.has(start) or char_at(start) == "+":
			continue
		var stack: Array[Vector2i] = [start]
		room_of[start] = room_count
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = c + d
				if room_of.has(n):
					continue
				var ch := char_at(n)
				if ch == "+" or ch == "#" or SOLID_CHARS.contains(ch) or ch == "=":
					continue
				room_of[n] = room_count
				stack.append(n)
		room_count += 1
	# 家具、置物櫃、窗戶：歸給旁邊的房間
	for y in _map.size():
		for x in String(_map[y]).length():
			var cell := Vector2i(x, y)
			var ch := char_at(cell)
			if ch == "#" or room_of.has(cell) or ch == "+":
				continue
			for d in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
				if room_of.has(cell + d) and char_at(cell + d) != "+":
					room_of[cell] = room_of[cell + d]
					break


## 主角現在看得到哪些房間：所在的房間；站在門口就是門兩邊的房間
func visible_rooms(pos: Vector2) -> Array[int]:
	var cell := cell_of(pos)
	var result: Array[int] = []
	if room_of.has(cell) and char_at(cell) != "+":
		result.append(room_of[cell])
		return result
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if room_of.has(cell + d) and not result.has(room_of[cell + d]):
			result.append(room_of[cell + d])
	return result


## 無線電通報成功時從哪裡來增援：{"type": 敵人種類, "count": 幾個, "doors": [門 id…]}；沒設定 = 不會增援
func reinforcements() -> Dictionary:
	return _data.get("reinforcements", {})


## 樓層（樓梯提示用）
func floor_number() -> int:
	return _data.get("floor", 1)


## 雪地車開往的區域（沒有就是空字串）
func snowcat_destination() -> String:
	return _data.get("snowcat_to", "")


func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


# ── 溫度 ──────────────────────────────────────────────

func zone_at(pos: Vector2) -> String:
	var cell := cell_of(pos)
	for zone_name in zones:
		if (zones[zone_name].rect as Rect2i).has_point(cell):
			return zone_name
	return ""


func is_cold(pos: Vector2) -> bool:
	var zone := zone_at(pos)
	return zone != "" and not is_zone_heated(zone)


func is_zone_heated(zone_name: String) -> bool:
	if not zones.has(zone_name):
		return true
	var key := "heat:%s:%s" % [area_id, zone_name]
	if WorldState.has_flag(key):
		return WorldState.get_flag(key)  # 玩家用配電箱切換過
	if zones[zone_name].get("powered", false) and WorldState.power_on:
		return true  # 恢復電力：暖氣跟著恢復
	return zones[zone_name].heated


## 配電箱提示上顯示的名稱
func zone_label(zone_name: String) -> String:
	return zones.get(zone_name, {}).get("label", zone_name)


## 恢復電力後燈亮著的區域
func is_lit() -> bool:
	return _data.get("powered_area", false) and WorldState.power_on


func set_zone_heated(zone_name: String, heated: bool) -> void:
	if is_zone_heated(zone_name) == heated:
		return
	WorldState.set_zone_heated(area_id, zone_name, heated)
	queue_redraw()
	zone_heat_changed.emit(zone_name, heated)


## 世界狀態被還原（回到檢查點）後，讓地圖上的東西跟著更新。
func sync_from_state() -> void:
	for item in _interactables:
		item.sync_from_state()
	for zone_name in zones:
		zone_heat_changed.emit(zone_name, is_zone_heated(zone_name))
	queue_redraw()


# ── 建立 ──────────────────────────────────────────────

func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


func _parse_map() -> void:
	var width := 0
	for y in _map.size():
		var row: String = _map[y]
		width = maxi(width, row.length())
		for x in row.length():
			var ch := row[x]
			if ch == "#" or ch == "C" or ch == "H" or ch == "=":
				continue
			_floor_cells.append(Vector2i(x, y))
			if ch == "P":
				_start_position = _cell_center(Vector2i(x, y))
			elif not FLOOR_CHARS.contains(ch):
				_waypoints[ch] = _cell_center(Vector2i(x, y))
	bounds = Rect2(Vector2.ZERO, Vector2(width, _map.size()) * TILE)

	for def in _data.enemies:
		var points: Array[Vector2] = []
		for ch in String(def.route):
			assert(_waypoints.has(ch), "%s 缺少巡邏點 %s" % [area_id, ch])
			points.append(_waypoints[ch])
		enemy_defs.append({"type": def.type, "points": points})


## 把同種類的相鄰格子合併成長方形，減少碰撞體和遮光體的數量。
func _merge_rects(symbol: String) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	var open := {}  # Vector2i(x0, x1) -> 在 result 裡的索引（上一列延伸下來的長方形）
	for y in _map.size():
		var row: String = _map[y]
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

	# 牆壁的外觀放在獨立的 CanvasLayer，不受黑暗影響，讓玩家永遠看得懂地形。
	_structure_layer = CanvasLayer.new()
	_structure_layer.name = "Structure"
	_structure_layer.layer = 1
	_structure_layer.follow_viewport_enabled = true
	add_child(_structure_layer)

	for rect in _merge_rects("#"):
		var wall := _add_solid(rect, WALL_COLOR, WALL_EDGE_COLOR)
		var wall_tex := Art.tex("tiles/wall_concrete")
		if wall_tex:
			wall.texture = wall_tex
			wall.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			wall.color = Color(0.38, 0.4, 0.47)  # 牆頂比地板暗，地形一眼看得出來
	for rect in _merge_rects("C"):
		if outdoor:
			_add_solid(rect, ROCK_COLOR, ROCK_EDGE_COLOR)
		else:
			_add_solid(rect, CABINET_COLOR, CABINET_EDGE_COLOR)
			_add_furniture(rect)
	for rect in _merge_rects("="):
		_add_window(rect)
	var faces := WallFaces.new()
	faces.name = "WallFaces"
	_structure_layer.add_child(faces)
	faces.setup(self)
	for rect in _merge_rects("H"):
		_add_solid(rect, LOCKER_COLOR, LOCKER_EDGE_COLOR)
		_add_prop_sprites(rect, Art.tex("props/locker"))


## 室內的 C：寬的是實驗桌，窄的是檔案櫃（像素圖，有的話）
func _add_furniture(cell_rect: Rect2i) -> void:
	if cell_rect.size.x >= 2:
		var bench := Art.tex("props/bench")
		if bench:
			var s := Sprite2D.new()
			s.texture = bench
			s.centered = false
			s.position = Vector2(cell_rect.position) * TILE
			s.scale = Vector2(cell_rect.size) * TILE / bench.get_size()
			_structure_layer.add_child(s)
	else:
		_add_prop_sprites(cell_rect, Art.tex("props/cabinet"))


## 每一格放一個直立的道具（置物櫃、檔案櫃），底部對齊格子底部、往上突出一點（俯視 3/4 視角）
func _add_prop_sprites(cell_rect: Rect2i, tex: Texture2D) -> void:
	if tex == null:
		return
	for y in range(cell_rect.position.y, cell_rect.end.y):
		for x in range(cell_rect.position.x, cell_rect.end.x):
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			var size := tex.get_size()
			var k := minf(TILE / size.x, 26.0 / size.y)
			s.scale = Vector2(k, k)
			s.position = Vector2(x * TILE + (TILE - size.x * k) * 0.5, (y + 1) * TILE - size.y * k)
			_structure_layer.add_child(s)


func _add_solid(cell_rect: Rect2i, fill: Color, edge: Color) -> Polygon2D:
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
	return visual


## 窗戶：玻璃（看得穿、光透得過去），走不過去
func _add_window(cell_rect: Rect2i) -> void:
	var rect := Rect2(Vector2(cell_rect.position) * TILE, Vector2(cell_rect.size) * TILE)
	var body := StaticBody2D.new()
	body.collision_layer = WINDOW_LAYER
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = rect.size
	shape.shape = rect_shape
	shape.position = rect.get_center()
	body.add_child(shape)
	_nav_region.add_child(body)
	var frame := ColorRect.new()
	frame.position = rect.position
	frame.size = rect.size
	frame.color = Color(0.2, 0.22, 0.26)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_structure_layer.add_child(frame)
	var glass := ColorRect.new()
	glass.position = rect.position + Vector2(2, 2)
	glass.size = rect.size - Vector2(4, 4)
	glass.color = Color(0.55, 0.75, 0.9, 0.35)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_structure_layer.add_child(glass)


## 地圖上這格的符號（超出地圖 = 牆）
func char_at(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= _map.size():
		return "#"
	var row: String = _map[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return "#"
	return row[cell.x]


func _spawn_interactables() -> void:
	var breaker_index := 0
	for y in _map.size():
		var row: String = _map[y]
		for x in row.length():
			var item: Interactable = null
			match row[x]:
				"H":
					item = Locker.new()
				"=":
					item = WindowPane.new()
				"B":
					item = BottlePickup.new()
				"K":
					item = SupplyCrate.new()
				"T":
					item = TapePickup.new()
				"X":
					var breaker := Breaker.new()
					breaker.zone_name = _data.breakers[breaker_index]
					breaker_index += 1
					item = breaker
				"G":
					var stairs := ExitPoint.new()
					stairs.target_area = _data.get("stairs", {}).get("%d,%d" % [x, y], "")
					item = stairs
				"Q":
					item = AccessCard.new()
				"F":
					item = FuelCan.new()
				"E":
					item = Generator.new()
				"Z":
					item = Snowcat.new()
				"O":
					item = Terminal.new()
				"U":
					item = Uplink.new()
				"o":
					item = OilDrum.new()
				"w", "p":
					var breakable := Breakable.new()
					breakable.kind = "crate" if row[x] == "w" else "barricade"
					breakable.loot = _data.get("loot", {}).get("%d,%d" % [x, y], [])
					item = breakable
				"q":
					item = ExtinguisherMount.new()
				"r":
					item = StonePile.new()
				"J":
					item = ShaftLift.new()
				"x":
					var corpse := CorpseDecor.new()
					corpse.position = _cell_center(Vector2i(x, y))
					add_child(corpse)
				"R":
					item = RadioConsole.new()
				"Y":
					item = StorageBox.new()
				"N":
					item = ReadableNote.new()
				"A", "M", "V", "W", "S", "L", "I", "u":
					var pickup := ItemPickup.new()
					pickup.pickup_item = Items.MAP_PICKUPS[row[x]][0]
					pickup.pickup_count = Items.MAP_PICKUPS[row[x]][1]
					item = pickup
			if item == null:
				continue
			var key := "%d,%d" % [x, y]
			item.item_name = _data.names.get(key, "")
			# 合併進來的房間（Areas.ROOMS）：用原本房間的 id 和座標，存檔紀錄不變
			item.item_id = _data.get("item_keys", {}).get(key, "%s:%s" % [area_id, key])
			item.hidden_flag = _data.get("hidden", {}).get(key, "")
			item.level = self
			item.position = _cell_center(Vector2i(x, y))
			add_child(item)
			item.sync_from_state()
			_interactables.append(item)


func _bake_navigation() -> void:
	var nav_poly := NavigationPolygon.new()
	nav_poly.agent_radius = 6.0
	nav_poly.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_poly.parsed_collision_mask = WALL_LAYER | WINDOW_LAYER | InteriorDoor.SAFE_BARRIER_LAYER
	nav_poly.add_outline(PackedVector2Array([
		bounds.position,
		Vector2(bounds.end.x, bounds.position.y),
		bounds.end,
		Vector2(bounds.position.x, bounds.end.y),
	]))
	_nav_region.navigation_polygon = nav_poly
	_nav_region.bake_navigation_polygon(false)
