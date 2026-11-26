## 依區域資料（Areas.all()）建立一個區域：地板、牆壁碰撞、遮光體、導航網格、互動物件、門、敵人路線、溫度區域。
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
## 牆比地板高：牆頂往上畫 WALL_RAISE 像素（蓋住牆後面一點點地板＝3/4 俯視的高度感），牆面見 WallFaces
const WALL_RAISE := 8.0
## 擋住角色的東西（牆、櫃子、置物櫃、窗戶）：地上的陰影、角色在牆前面時的遮擋判定用
const OCCLUDER_CHARS := "#CH="

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
const FLOOR_CHARS := ".PDBKTXGAMVWRYNSLQOxFEZUJIowpqru+jknmvyztls^"

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
## 水面（地圖符號 ~）：走不過去、看得過去
var _water_cells: Array[Vector2i] = []
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
	if not _data.get("hazards", []).is_empty():
		var haze := SporeHaze.new()
		haze.name = "SporeHaze"
		add_child(haze)
		haze.setup(self)
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
	for cell in _floor_cells:
		var rect := Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE))
		var src := Rect2(Vector2(posmod(cell.x, 4), posmod(cell.y, 4)) * TILE, Vector2(TILE, TILE))
		var cell_safe := is_safe_cell(cell)
		var tex := floor_tex_at(cell)
		var open_air := not _is_indoor_cell(cell)
		if tex == null:
			draw_rect(rect, SNOW_FLOOR_A if open_air else INDOOR_FLOOR_A)
			continue
		var tint := Color.WHITE
		if open_air:
			tint = Color(1.5, 1.5, 1.5) if tex == Art.tex("tiles/floor_snow") else Color(1.15, 1.15, 1.18)
		elif cell_safe:
			tint = Color(1.12, 1.08, 1.0)
		elif is_cold(_cell_center(cell)):
			# 沒暖氣的室內：地板偏藍（結霜）
			tint = Color(0.82, 0.95, 1.18)
		draw_texture_rect_region(tex, rect, src, tint)
	_draw_water()
	_draw_floor_decals()
	_draw_floor_shadows()
	for door_id in _data.doors:
		var cell: Vector2i = _data.doors[door_id].cell
		draw_rect(Rect2(Vector2(cell) * TILE + Vector2(2, 2), Vector2(TILE - 4, TILE - 4)), DOOR_COLOR)


## 牆、家具旁邊的地板陰影（光從左上來：右邊、下面的地板影子比較長），讓東西看起來「站」在地上
func _draw_floor_shadows() -> void:
	for cell in _floor_cells:
		var p := Vector2(cell) * TILE
		var n := OCCLUDER_CHARS.contains(char_at(cell + Vector2i.UP))
		var w := OCCLUDER_CHARS.contains(char_at(cell + Vector2i.LEFT))
		var e := OCCLUDER_CHARS.contains(char_at(cell + Vector2i.RIGHT))
		var nw := OCCLUDER_CHARS.contains(char_at(cell + Vector2i(-1, -1)))
		if n:
			for i in 5:
				draw_rect(Rect2(p + Vector2(0, i), Vector2(TILE, 1)), Color(0, 0, 0.03, 0.42 - i * 0.08))
		if w:
			for i in 6:
				draw_rect(Rect2(p + Vector2(i, 0), Vector2(1, TILE)), Color(0, 0, 0.03, 0.36 - i * 0.06))
		elif nw and not n:
			draw_colored_polygon(PackedVector2Array([p, p + Vector2(6, 0), p + Vector2(0, 6)]), Color(0, 0, 0.03, 0.3))
		if e:
			draw_rect(Rect2(p + Vector2(TILE - 2, 0), Vector2(2, TILE)), Color(0, 0, 0.03, 0.18))


## 戶外區域裡的室內空間（例如倉庫）：地板畫成室內的樣子
func _is_indoor_cell(cell: Vector2i) -> bool:
	for r in _data.get("indoor_rects", []):
		if (r as Rect2i).has_point(cell):
			return true
	# 合併進來的區域（Areas._compose）：建築是室內、相鄰的戶外區域是戶外
	var region := region_data(cell)
	if not region.is_empty():
		return not region.get("outdoor", false)
	return not outdoor


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


## 這個位置的氣候：合併進來的區域可以有自己的氣候（例如港口的暴風雪）
func climate_at(pos: Vector2) -> String:
	var r := region_data(cell_of(pos))
	return r.climate if r.get("climate", "") != "" else climate_id()


## 這格屬於哪個合併進來的範圍（Areas._compose 的 regions，最裡面的那個）；不在任何範圍 = {}
func region_data(cell: Vector2i) -> Dictionary:
	var i: int = _data.get("region_cells", {}).get(cell, -1)
	return _data.regions[i] if i >= 0 else {}


## 這格是哪種房間（SetDresser.SETS）：sets 指定的範圍 > 區域的 set > 戶外的 outdoor_set > 主題的預設
func set_at(cell: Vector2i) -> String:
	for s in _data.get("sets", []):
		if (s.rect as Rect2i).has_point(cell):
			return s.set
	var r := region_data(cell)
	if not _is_indoor_cell(cell):
		var os: String = r.get("outdoor_set", "") if not r.is_empty() else _data.get("outdoor_set", "")
		return os if os != "" else "yard"
	var own: String = r.get("set", "") if not r.is_empty() else _data.get("set", "")
	if own != "":
		return own
	return SetDresser.THEME_SET.get(theme_at(cell), "storage")


func floor_tex_at(cell: Vector2i) -> Texture2D:
	if is_safe_cell(cell):
		return Art.tex("tiles/floor_lab")
	var d := SetDresser.set_data(set_at(cell))
	return Art.tex(SetDresser.FLOOR_TEX.get(d.get("floor", "concrete"), "tiles/floor_concrete"))


## 牆的材質：看牆旁邊的地板是哪種房間（下面 > 上面 > 左右）
func wall_style_at(cell: Vector2i) -> String:
	for d in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i(1, 1), Vector2i(-1, 1)]:
		var c: Vector2i = cell + d
		var ch := char_at(c)
		if ch != "#" and ch != "" and ch != " ":
			return SetDresser.set_data(set_at(c)).get("wall", "concrete")
	return "concrete"


func prop_override(cell: Vector2i) -> String:
	return _data.get("props", {}).get("%d,%d" % [cell.x, cell.y], "")


## 這格的室內主題：合併進來的房間用自己的主題
func theme_at(cell: Vector2i) -> String:
	var r := region_data(cell)
	return r.theme if r.get("theme", "") != "" else theme()


## 主角站的地方每秒失去多少體溫（負數 = 正在回暖）。
## 安全屋、有暖氣的室內、火堆旁邊會回暖；戶外、沒暖氣的室內會失溫（依氣候）。
func exposure_at(pos: Vector2) -> float:
	var c := Climates.get_climate(climate_at(pos))
	if is_safe_cell(cell_of(pos)):
		return -c.recover * 2.0
	if not _is_indoor_cell(cell_of(pos)):
		return c.outdoor_loss
	if is_cold(pos):
		return c.cold_loss
	return -c.recover


## 腳步聲的地面：區域資料可以用 step 指定（例如鐵板 "metal"），不然戶外是雪、室內是水泥
## 這個位置的危險區域（區域資料 hazards）："spores"，沒有就是空字串
func hazard_at(pos: Vector2) -> String:
	var c := cell_of(pos)
	for h in _data.get("hazards", []):
		if (h.rect as Rect2i).has_point(c):
			return h.kind
	return ""


func step_surface(pos: Vector2) -> String:
	var r := region_data(cell_of(pos))
	if r.get("step", "") != "":
		return r.step
	if r.is_empty() and _data.has("step"):
		return _data.step
	if not _is_indoor_cell(cell_of(pos)):
		return "snow"
	return "concrete"


## 區域的音樂（區域資料 music 可以指定）：安全屋、Boss 戰、戶外、室內
func music_id(pos := Vector2(-1, -1)) -> String:
	var r := region_data(cell_of(pos)) if pos.x >= 0 else {}
	if r.get("music", "") != "":
		return r.music
	if _data.has("music"):
		return _data.music
	if safe or (pos.x >= 0 and is_safe_cell(cell_of(pos))):
		return "safe_room"
	match boss_name():
		"TUNDRA MOTHER":
			return "boss_bear"
		"THE DEEP WELL":
			return "boss_well"
	if pos.x >= 0:
		return "explore_station" if is_indoor_at(pos) else "explore_outdoor"
	return "explore_outdoor" if outdoor else "explore_station"


## 區域的環境音（區域資料 ambience 可以指定）
func ambience_id(powered: bool, pos := Vector2(-1, -1)) -> String:
	var r := region_data(cell_of(pos)) if pos.x >= 0 else {}
	if r.get("ambience", "") != "":
		return r.ambience
	if r.is_empty() and _data.has("ambience"):
		return _data.ambience
	var out := not is_indoor_at(pos) if pos.x >= 0 else outdoor
	if out and Climates.has_exposure(climate_at(pos) if pos.x >= 0 else climate_id()):
		return "amb_blizzard"
	if out:
		return ""
	if pos.x >= 0:
		powered = powered and (is_lit_at(pos) or not outdoor)
	return "amb_station_hum" if powered else "amb_station_dark"


# ── 房間（合併進來的房間、室內門分隔的空間）────────────────

## 這個位置屬於哪個區域 id：合併進來的房間（例如 station_safe）或主區域本身
func region_at(pos: Vector2) -> String:
	return region_data(cell_of(pos)).get("id", area_id)


## 這個位置是不是「室內」：室內區域，或戶外地圖裡的建築（indoor_rects，包含合併進來的整棟建築）
func is_indoor_at(pos: Vector2) -> bool:
	return _is_indoor_cell(cell_of(pos))


## 這個位置的燈有沒有亮：整個區域恢復電力，或所在的房間（合併進來的建築）自己有電
func is_lit_at(pos: Vector2) -> bool:
	if is_lit():
		return true
	return region_data(cell_of(pos)).get("powered", false) and WorldState.power_on


func region_title(region_id: String) -> String:
	for r in _data.get("regions", []):
		if r.id == region_id:
			return r.title
	return title


func is_safe_cell(cell: Vector2i) -> bool:
	if safe:
		return true
	return region_data(cell).get("safe", false)


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
				if ch == "+" or ch == "#" or SOLID_CHARS.contains(ch) or ch == "=" or ch == "~":
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
	# 合併進來的區域：旗標用原本的區域 id、名稱（Areas._tag_zones）
	var key := "heat:%s:%s" % [zones[zone_name].get("area", area_id), zones[zone_name].get("name", zone_name)]
	if WorldState.has_flag(key):
		return WorldState.get_flag(key)  # 玩家用配電箱切換過
	if zones[zone_name].get("powered", false) and WorldState.power_on:
		return true  # 恢復電力：暖氣跟著恢復
	return zones[zone_name].heated


## 配電箱提示上顯示的名稱
func zone_label(zone_name: String) -> String:
	return zones.get(zone_name, {}).get("label", zone_name)


## 恢復電力後燈亮著的區域
## 這個位置的鏡頭設定（區域資料 camera_zones）：{zoom, tilt, frame}；沒有就是空字典
func camera_zone_at(pos: Vector2) -> Dictionary:
	var c := cell_of(pos)
	for z in _data.get("camera_zones", []):
		if (z.rect as Rect2i).has_point(c):
			return z
	return {}


func is_lit() -> bool:
	# lit = 一直有燈（例如 1962 年的記憶：那時候研究站還有電）
	return _data.get("lit", false) or (_data.get("powered_area", false) and WorldState.power_on)


func set_zone_heated(zone_name: String, heated: bool) -> void:
	if is_zone_heated(zone_name) == heated:
		return
	WorldState.set_zone_heated(zones[zone_name].get("area", area_id), zones[zone_name].get("name", zone_name), heated)
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
			if ch == "~":
				_water_cells.append(Vector2i(x, y))
				continue
			_floor_cells.append(Vector2i(x, y))
			if ch == "P":
				_start_position = _cell_center(Vector2i(x, y))
			elif not FLOOR_CHARS.contains(ch):
				_waypoints[ch] = _cell_center(Vector2i(x, y))
	bounds = Rect2(Vector2.ZERO, Vector2(width, _map.size()) * TILE)

	for def in _data.enemies:
		var points: Array[Vector2] = []
		# 合併進來的房間（Areas._compose）：巡邏點已經換成格子座標
		for c in def.get("cells", []):
			points.append(_cell_center(c))
		for ch in String(def.get("route", "")):
			assert(_waypoints.has(ch), "%s 缺少巡邏點 %s" % [area_id, ch])
			points.append(_waypoints[ch])
		enemy_defs.append({"type": def.type, "points": points, "key": def.get("key", "%s:%d" % [area_id, enemy_defs.size()])})


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
		var wall := _add_solid(rect, WALL_COLOR, WALL_EDGE_COLOR, WALL_RAISE)
		var style := wall_style_at(rect.position + Vector2i(0, rect.size.y - 1))
		var wall_tex := Art.tex(SetDresser.WALL_TEX.get(style, "tiles/wall_concrete"))
		if wall_tex:
			wall.texture = wall_tex
			wall.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			wall.color = Color(0.45, 0.47, 0.54) if style == "concrete" else Color(0.62, 0.64, 0.7)
	# 家具、設備：依房間種類擺（SetDresser）。y 排序：前面的蓋住後面的。
	var props := Node2D.new()
	props.name = "Props"
	props.y_sort_enabled = true
	# 這個圖層不受黑暗影響（地形永遠看得懂），所以家具本身壓暗一點，才不會在暗的房間裡發亮
	props.modulate = Color(0.62, 0.65, 0.74)
	var prop_rects := _merge_rects("C")
	for rect in prop_rects:
		var base := _add_solid(rect, CABINET_COLOR, CABINET_EDGE_COLOR)
		var base_outline: CanvasItem = _structure_layer.get_child(_structure_layer.get_child_count() - 1)
		base.color = Color(0.05, 0.055, 0.07, 0.55)  # 家具底下的影子
		base_outline.visible = false
		if SetDresser.dress(self, rect, props) == 0:
			base_outline.visible = true
			if SetDresser.set_data(set_at(rect.position)).get("rocks", false):
				base.color = ROCK_COLOR.darkened(0.35)
				_add_rocks(rect, base)
			else:
				base.color = CABINET_COLOR
				_add_furniture(rect)
	_structure_layer.add_child(props)
	for rect in _merge_rects("="):
		_add_window(rect)
	for rect in _merge_rects("~"):
		_add_water(rect)
	var faces := WallFaces.new()
	faces.name = "WallFaces"
	_structure_layer.add_child(faces)
	faces.setup(self)
	var front := CanvasLayer.new()
	front.name = "OverWall"
	front.layer = 1
	front.follow_viewport_enabled = true
	add_child(front)
	var over := OverWall.new()
	over.level = self
	front.add_child(over)
	for rect in _merge_rects("H"):
		_add_solid(rect, LOCKER_COLOR, LOCKER_EDGE_COLOR)
		_add_prop_sprites(rect, Art.tex("props/locker"))


## 室內的主題（區域資料 theme）：決定家具、地板痕跡、牆上的細節
const THEME_SINGLE := {
	"lab": ["props/cabinet", "decor/server_rack", "decor/specimen_tank", "decor/fume_hood"],
	"office": ["decor/desk_computer", "decor/bookshelf", "props/cabinet"],
	"dorm": ["decor/wardrobe", "decor/bookshelf", "decor/desk_computer"],
	"industrial": ["decor/machinery", "decor/pallet", "props/cabinet"],
	"military": ["decor/ammo_crates", "decor/weapon_rack", "decor/pallet", "decor/sandbags"],
	"hut": ["decor/wardrobe", "decor/pallet", "decor/bookshelf"],
	"cave": ["decor/ice_pillar"],
}
const THEME_WIDE := {"lab": "props/bench", "office": "decor/desk_row", "dorm": "decor/bunk", "industrial": "decor/crate_row",
	"military": "decor/crate_row", "hut": "decor/crate_row"}
const THEME_DECALS := {
	"lab": ["papers", "cables", "blood_0", "blood_1", "grate", "drag"],
	"office": ["papers", "papers", "blood_2", "debris"],
	"dorm": ["papers", "blood_0", "debris", "drag"],
	"industrial": ["oil", "grate", "stripes", "debris", "cables"],
	"military": ["stripes", "oil", "debris", "grate"],
	"hut": ["debris", "papers"],
	"cave": ["frost", "frost", "blood_1"],
}


func theme() -> String:
	return _data.get("theme", "outdoor" if outdoor else "lab")


## 室內的 C：依主題放家具。寬的（兩格以上）是一整排（實驗桌、辦公桌、上下鋪、木箱），窄的每格挑一種（固定亂數）
func _add_furniture(cell_rect: Rect2i) -> void:
	var t := theme_at(cell_rect.position)
	if t == "cave":
		for y in range(cell_rect.position.y, cell_rect.end.y):
			for x in range(cell_rect.position.x, cell_rect.end.x):
				_add_prop_sprites(Rect2i(x, y, 1, 1), Art.tex("decor/ice_pillar"))
		return
	if cell_rect.size.x < 2:
		var pool: Array = THEME_SINGLE.get(t, THEME_SINGLE.lab)
		for y in range(cell_rect.position.y, cell_rect.end.y):
			var pick: String = pool[absi(hash(Vector2i(cell_rect.position.x, y) + Vector2i(area_id.length(), 0))) % pool.size()]
			_add_prop_sprites(Rect2i(cell_rect.position.x, y, 1, 1), Art.tex(pick))
		return
	var base: String = THEME_WIDE.get(t, "props/bench")
	for y in range(cell_rect.position.y, cell_rect.end.y):
		for x in range(cell_rect.position.x, cell_rect.end.x):
			var part := "_m"
			if x == cell_rect.position.x:
				part = "_l"
			elif x == cell_rect.end.x - 1:
				part = "_r"
			var tex := Art.tex(base + part)
			if tex == null:
				return
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.position = Vector2(x * TILE, (y + 1) * TILE - tex.get_height())
			_structure_layer.add_child(s)


## 地板的痕跡（紙張、血跡、電線、鐵格板、油漬……依主題），畫在地板上、受光影響
func _draw_floor_decals() -> void:
	for cell in _floor_cells:
		if char_at(cell) != "." or is_safe_cell(cell):
			continue
		var set_info := SetDresser.set_data(set_at(cell))
		# 戶外（雪地、甲板）只用那種地面自己的痕跡，不放室內的警示線、鐵格板
		var pool: Array = set_info.get("decals", [] if not _is_indoor_cell(cell) else THEME_DECALS.get(theme_at(cell), []))
		if pool.is_empty():
			continue
		var h := absi(hash(cell * 7 + Vector2i(area_id.length() * 13, 3)))
		if h % 100 >= 10:
			continue
		var tex := Art.tex("decor/" + pool[(h / 100) % pool.size()])
		if tex:
			draw_texture(tex, Vector2(cell) * TILE)


## 戶外的 C：每格一顆積雪的岩石（三種隨機，固定亂數），底下的色塊當成岩縫
func _add_rocks(cell_rect: Rect2i, base: Polygon2D) -> void:
	if Art.tex("props/rock_0") == null:
		return
	base.color = ROCK_COLOR.darkened(0.35)
	for y in range(cell_rect.position.y, cell_rect.end.y):
		for x in range(cell_rect.position.x, cell_rect.end.x):
			var h := absi(hash(Vector2i(x, y)))
			var tex := Art.tex("props/rock_%d" % (h % 3))
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.flip_h = (h / 3) % 2 == 0
			s.position = Vector2(x * TILE + (TILE - tex.get_width()) * 0.5 + (h / 7) % 3 - 1, (y + 1) * TILE - tex.get_height() + 3)
			_structure_layer.add_child(s)


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


func _add_solid(cell_rect: Rect2i, fill: Color, edge: Color, raise := 0.0) -> Polygon2D:
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
	visual.position = Vector2(0, -raise)
	visual.color = fill
	_structure_layer.add_child(visual)
	var outline := Line2D.new()
	outline.position = Vector2(0, -raise)
	outline.points = points
	outline.closed = true
	outline.width = 1.0
	outline.default_color = edge
	_structure_layer.add_child(outline)
	return visual


## 水面：走不過去（和窗戶同一個碰撞圖層：不擋視線、不擋光），畫在 _draw
func _add_water(cell_rect: Rect2i) -> void:
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


func _draw_water() -> void:
	for cell in _water_cells:
		var p := Vector2(cell) * TILE
		draw_rect(Rect2(p, Vector2(TILE, TILE)), Color(0.035, 0.075, 0.105))
		var h := absi(hash(cell * 11))
		# 水面的反光（固定的短橫線）
		draw_rect(Rect2(p + Vector2(h % 9, 3 + (h / 9) % 4), Vector2(5, 1)), Color(0.10, 0.20, 0.26))
		draw_rect(Rect2(p + Vector2((h / 37) % 10, 10 + (h / 370) % 4), Vector2(4, 1)), Color(0.07, 0.15, 0.20))
		# 岸邊：碼頭的水泥邊緣和它在水裡的影子
		if char_at(cell + Vector2i.UP) != "~":
			draw_rect(Rect2(p, Vector2(TILE, 3)), Color(0.34, 0.36, 0.40))
			draw_rect(Rect2(p + Vector2(0, 3), Vector2(TILE, 1)), Color(0.86, 0.68, 0.16) if (cell.x % 2 == 0) else Color(0.10, 0.10, 0.11))
			draw_rect(Rect2(p + Vector2(0, 4), Vector2(TILE, 4)), Color(0.01, 0.03, 0.05))


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
	frame.position = rect.position - Vector2(0, WALL_RAISE)
	frame.size = rect.size + Vector2(0, WALL_RAISE)
	frame.color = Color(0.2, 0.22, 0.26)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_structure_layer.add_child(frame)
	var glass := ColorRect.new()
	glass.position = rect.position + Vector2(2, 2 - WALL_RAISE)
	glass.size = rect.size - Vector2(4, 4 - WALL_RAISE)
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
					var bkey := "%d,%d" % [x, y]
					if _data.get("breaker_cells", {}).has(bkey):
						breaker.zone_name = _data.breaker_cells[bkey]
					else:
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
				"&":
					var reel := MemoryReel.new()
					var rinfo: Dictionary = _data.get("reels", {}).get("%d,%d" % [x, y], {})
					reel.target_area = rinfo.get("to", "")
					reel.target_entry = rinfo.get("entry", "start")
					reel.scene = rinfo.get("scene", "")
					reel.flag = rinfo.get("flag", "")
					reel.needs = rinfo.get("needs", "")
					reel.locked_text = rinfo.get("text", "")
					reel.prompt_text = rinfo.get("prompt", "Play the reel")
					item = reel
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
				"t":
					var gear := GearPickup.new()
					gear.gear_id = _data.get("gear", {}).get("%d,%d" % [x, y], "")
					item = gear
				"l":
					item = AreaMapPickup.new()
				"s":
					var safe_box := SafeBox.new()
					var info: Dictionary = _data.get("safes", {}).get("%d,%d" % [x, y], {})
					safe_box.reveal = info.get("reveal", "")
					safe_box.text = info.get("text", "")
					item = safe_box
				_:
					# 一般物品（彈藥、藥品、武器……見 Items.MAP_PICKUPS）
					if Items.MAP_PICKUPS.has(row[x]):
						var pickup := ItemPickup.new()
						pickup.pickup_item = Items.MAP_PICKUPS[row[x]][0]
						pickup.pickup_count = Items.MAP_PICKUPS[row[x]][1]
						item = pickup
			if item == null:
				continue
			var key := "%d,%d" % [x, y]
			item.item_name = _data.names.get(key, "")
			# 合併進來的房間（Areas.rooms()）：用原本房間的 id 和座標，存檔紀錄不變
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
