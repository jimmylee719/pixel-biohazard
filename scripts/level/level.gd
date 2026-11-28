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
const FLOOR_CHARS := ".PDBKTXGAMVWRYNSLQOxFEZUJIowpqru+jknmvyztls^!:$*|?;"

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
## 雪地上的腳印（v0.11）
var tracks: SnowTracks
## 這個區域的警戒狀態（ALERT／EVASION／CAUTION、呼叫同伴）
var alert: AlertNetwork
## 家具（地圖上的 C）合併後的長方形：畫腳下的影子、機具周圍的警示框用
var _prop_rects: Array[Rect2i] = []
## 裝飾用的光暈（SetDresser 依 GLOW 加進來；LightAccents 畫）：{pos, color, size, power}
var accent_lights: Array[Dictionary] = []
## 家具的圖和它所在的格子／房間（房間黑幕：沒看到的房間，裡面的家具整個藏起來）
var _prop_nodes: Array = []
var _props_shown_for: Array = [-1]


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
	tracks = SnowTracks.new()
	tracks.name = "SnowTracks"
	tracks.level = self
	add_child(tracks)
	_bake_navigation()
	queue_redraw()


## 地板直接畫在世界圖層，會被燈光照亮、在黑暗中看不見。沒開暖氣的室內地板偏藍（結霜）。
## 順序：地板材質（家具底下也畫）→ 水面 → 地上的漆（標線、警示框、門檻、編號）→ 痕跡 → 陰影 → 出入口。
## 全部只畫一次（地圖或暖氣狀態變了才重畫），不要在這裡放每幀都變的東西。
func _draw() -> void:
	for cell in _floor_cells:
		_draw_floor_cell(cell)
	for rect in _prop_rects:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				_draw_floor_cell(Vector2i(x, y))
	_draw_water()
	_draw_floor_paint()
	_draw_floor_decals()
	_draw_floor_shadows()
	for door_id in _data.doors:
		_draw_exit_mat(_data.doors[door_id].cell)


func _draw_floor_cell(cell: Vector2i) -> void:
	var rect := Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE))
	var src := Rect2(Vector2(posmod(cell.x, 4), posmod(cell.y, 4)) * TILE, Vector2(TILE, TILE))
	var kind := floor_kind_at(cell)
	var tex := Art.tex("tiles/floor_lab") if kind == "safe" else Art.tex(SetDresser.FLOOR_TEX.get(kind, "tiles/floor_slab"))
	var open_air := not _is_indoor_cell(cell)
	if tex == null:
		draw_rect(rect, SNOW_FLOOR_A if open_air else INDOOR_FLOOR_A)
		return
	var tint := Color.WHITE
	if open_air:
		tint = Color(1.5, 1.5, 1.5) if kind == "snow" else Color(1.15, 1.15, 1.18)
	elif kind == "safe":
		tint = Color(1.12, 1.08, 1.0)
	elif is_cold(_cell_center(cell)):
		# 沒暖氣的室內：地板偏藍（結霜）
		tint = Color(0.82, 0.95, 1.18)
	# 大範圍的深淺變化（很緩）：大廳的地板才不會像一張重複的壁紙
	var k := 1.0 + 0.045 * (sin(cell.x * 0.37 + cell.y * 0.23) + sin(cell.x * 0.13 - cell.y * 0.31 + 1.7))
	draw_texture_rect_region(tex, rect, src, Color(tint.r * k, tint.g * k, tint.b * k))


## 這格的地板材質（SetDresser.FLOOR_TEX 的鍵；安全屋 = "safe"）
func floor_kind_at(cell: Vector2i) -> String:
	if is_safe_cell(cell):
		return "safe"
	return SetDresser.set_data(set_at(cell)).get("floor", "concrete")


func _is_wall_cell(cell: Vector2i) -> bool:
	return "#=".contains(char_at(cell))


func _is_floor_cell(cell: Vector2i) -> bool:
	return not (SOLID_CHARS + "=~").contains(char_at(cell))


## 區域的出入口（換地圖的門）：鋼製門檻板＋兩道警示條
func _draw_exit_mat(cell: Vector2i) -> void:
	var p := Vector2(cell) * TILE
	draw_rect(Rect2(p + Vector2(1, 1), Vector2(TILE - 2, TILE - 2)), Color(0.15, 0.16, 0.19))
	draw_rect(Rect2(p + Vector2(2, 2), Vector2(TILE - 4, TILE - 4)), Color(0.30, 0.31, 0.35))
	draw_rect(Rect2(p + Vector2(2, 2), Vector2(TILE - 4, 1)), Color(0.42, 0.44, 0.49))
	for i in 3:
		draw_rect(Rect2(p + Vector2(3 + i * 4, 4), Vector2(2, 2)), Color(0.80, 0.64, 0.16))
		draw_rect(Rect2(p + Vector2(3 + i * 4, TILE - 6), Vector2(2, 2)), Color(0.80, 0.64, 0.16))
	draw_rect(Rect2(p + Vector2(4, 7), Vector2(TILE - 8, 2)), Color(0.20, 0.21, 0.24))


## 地上的漆和金屬件（畫在陰影下面，會被牆腳的陰影壓暗）：
##   沿牆的標線（依房間種類的顏色：實驗室青綠、倉庫／機房黃色、地毯的鑲邊）、
##   大型機具周圍的黃黑警示框、室內門的門檻、碼頭的泊位編號、雪地上的車轍。
func _draw_floor_paint() -> void:
	for cell in _floor_cells:
		var ch := char_at(cell)
		var p := Vector2(cell) * TILE
		if ch == "+":
			# 門檻：一條鋼板（門開著的時候看得到）
			var side := _is_wall_cell(cell + Vector2i.LEFT) or _is_wall_cell(cell + Vector2i.RIGHT)
			var r := Rect2(p + Vector2(0, 4), Vector2(TILE, 8)) if side else Rect2(p + Vector2(4, 0), Vector2(8, TILE))
			draw_rect(r, Color(0.20, 0.21, 0.25))
			draw_rect(Rect2(r.position, Vector2(r.size.x, 1) if side else Vector2(1, r.size.y)), Color(0.38, 0.40, 0.45))
			draw_rect(Rect2(r.position + (Vector2(0, 7) if side else Vector2(7, 0)), Vector2(r.size.x, 1) if side else Vector2(1, r.size.y)), Color(0.08, 0.08, 0.10))
			continue
		var info := SetDresser.set_data(set_at(cell))
		if info.has("line") and not is_safe_cell(cell):
			_draw_wall_line(cell, info.line)
		# 碼頭邊（下面是水）：每六格漆一個泊位編號
		if char_at(cell + Vector2i.DOWN) == "~" and cell.x % 6 == 3 and ch == ".":
			SetDresser.draw_text(self, p + Vector2(4, 4), "B%d" % (cell.x / 6 % 9 + 1), Color(0.82, 0.66, 0.16, 0.7))
	# 機具周圍的警示框
	for rect in _prop_rects:
		if rect.size.x < 2 or rect.size.y < 2:
			continue
		var forced := prop_override(rect.position)
		if SetDresser.MACHINES.has(forced) or (forced == "" and SetDresser.set_data(set_at(rect.position)).get("hazard_box", false)
				and _is_indoor_cell(rect.position)):
			_draw_hazard_box(rect)
	_draw_tracks()


## 沿著牆、離牆 5px 的一條線（轉角會接起來）。磨損：固定亂數缺幾段。
func _draw_wall_line(cell: Vector2i, col: Color) -> void:
	var p := Vector2(cell) * TILE
	var n := _is_wall_cell(cell + Vector2i.UP)
	var s := _is_wall_cell(cell + Vector2i.DOWN)
	var w := _is_wall_cell(cell + Vector2i.LEFT)
	var e := _is_wall_cell(cell + Vector2i.RIGHT)
	var worn := absi(hash(cell * 9 + Vector2i(3, area_id.length())))
	if col.g < 0.7 and worn % 6 == 0:
		return  # 這一格的漆磨掉了
	var x0 := 5.0 if w else 0.0
	var x1 := 11.0 if e else float(TILE)
	var y0 := 9.0 if n else 0.0
	var y1 := 4.0 if s else float(TILE)
	if n:
		draw_rect(Rect2(p + Vector2(x0, 9), Vector2(x1 - x0, 1)), col)
	if s:
		draw_rect(Rect2(p + Vector2(x0, 3), Vector2(x1 - x0, 1)), col)
	if w:
		draw_rect(Rect2(p + Vector2(5, y0), Vector2(1, y1 - y0)), col)
	if e:
		draw_rect(Rect2(p + Vector2(10, y0), Vector2(1, y1 - y0)), col)
	# 凸出來的牆角：把兩邊的線接起來
	if not n and not w and _is_wall_cell(cell + Vector2i(-1, -1)):
		draw_rect(Rect2(p + Vector2(0, 9), Vector2(6, 1)), col)
		draw_rect(Rect2(p + Vector2(5, 0), Vector2(1, 9)), col)
	if not n and not e and _is_wall_cell(cell + Vector2i(1, -1)):
		draw_rect(Rect2(p + Vector2(10, 9), Vector2(6, 1)), col)
		draw_rect(Rect2(p + Vector2(10, 0), Vector2(1, 9)), col)
	if not s and not w and _is_wall_cell(cell + Vector2i(-1, 1)):
		draw_rect(Rect2(p + Vector2(0, 3), Vector2(6, 1)), col)
		draw_rect(Rect2(p + Vector2(5, 4), Vector2(1, 12)), col)
	if not s and not e and _is_wall_cell(cell + Vector2i(1, 1)):
		draw_rect(Rect2(p + Vector2(10, 3), Vector2(6, 1)), col)
		draw_rect(Rect2(p + Vector2(10, 4), Vector2(1, 12)), col)


## 大型機具周圍的黃黑相間警示框（離機具 3px、只畫在地板上）
func _draw_hazard_box(rect: Rect2i) -> void:
	var r := Rect2(Vector2(rect.position) * TILE - Vector2(4, 4), Vector2(rect.size) * TILE + Vector2(8, 8))
	var yellow := Color(0.82, 0.66, 0.14, 0.8)
	var black := Color(0.05, 0.05, 0.06, 0.7)
	var i := 0
	var x := r.position.x
	while x < r.end.x:
		for y in [r.position.y, r.end.y - 2]:
			if _is_floor_cell(cell_of(Vector2(x + 2, y + 1))):
				draw_rect(Rect2(x, y, 4, 2), yellow if i % 2 == 0 else black)
		x += 4
		i += 1
	var y2 := r.position.y + 2
	while y2 < r.end.y - 2:
		for x2 in [r.position.x, r.end.x - 2]:
			if _is_floor_cell(cell_of(Vector2(x2 + 1, y2 + 2))):
				draw_rect(Rect2(x2, y2, 2, 4), yellow if i % 2 == 0 else black)
		y2 += 4
		i += 1


## 雪地廠區的車轍：挑幾排、幾列，連續七格以上的空地才畫（看起來是車子真的開過的路線）
func _draw_tracks() -> void:
	var th := Art.tex("decor/track_h")
	var tv := Art.tex("decor/track_v")
	if th == null or tv == null:
		return
	var open := {}
	for cell in _floor_cells:
		if char_at(cell) == "." and not _is_indoor_cell(cell) and floor_kind_at(cell) == "snow":
			open[cell] = true
	if open.is_empty():
		return
	var salt := area_id.length()
	for cell in open:
		# 每一段從最左（最上）那格開始算長度
		if absi(hash(Vector2i(cell.y, salt))) % 5 == 0 and not open.has(cell + Vector2i.LEFT):
			var n := 1
			while open.has(cell + Vector2i(n, 0)):
				n += 1
			if n >= 7:
				for i in n:
					draw_texture(th, Vector2(cell + Vector2i(i, 0)) * TILE)
		if absi(hash(Vector2i(salt + 5, cell.x))) % 6 == 0 and not open.has(cell + Vector2i.UP):
			var m := 1
			while open.has(cell + Vector2i(0, m)):
				m += 1
			if m >= 7:
				for i in m:
					draw_texture(tv, Vector2(cell + Vector2i(0, i)) * TILE)


## 牆、家具旁邊的地板陰影（光從左上來：右邊、下面的地板影子比較長），讓東西看起來「站」在地上。
## 牆的影子比家具的深；牆角再壓一點（環境遮蔽）；家具腳下另外有一塊貼地的影子；戶外的牆腳積雪。
func _draw_floor_shadows() -> void:
	for cell in _floor_cells:
		var p := Vector2(cell) * TILE
		var cn := char_at(cell + Vector2i.UP)
		var cw := char_at(cell + Vector2i.LEFT)
		var n := OCCLUDER_CHARS.contains(cn)
		var w := OCCLUDER_CHARS.contains(cw)
		var e := OCCLUDER_CHARS.contains(char_at(cell + Vector2i.RIGHT))
		var nw := OCCLUDER_CHARS.contains(char_at(cell + Vector2i(-1, -1)))
		if n:
			var deep := cn == "#"
			var rows := 6 if deep else 4
			for i in rows:
				draw_rect(Rect2(p + Vector2(0, i), Vector2(TILE, 1)), Color(0, 0, 0.03, (0.46 if deep else 0.34) * (1.0 - float(i) / rows)))
		if w:
			var deep_w := cw == "#"
			var cols := 5 if deep_w else 4
			for i in cols:
				draw_rect(Rect2(p + Vector2(i, 0), Vector2(1, TILE)), Color(0, 0, 0.03, (0.36 if deep_w else 0.28) * (1.0 - float(i) / cols)))
		elif nw and not n:
			draw_colored_polygon(PackedVector2Array([p, p + Vector2(6, 0), p + Vector2(0, 6)]), Color(0, 0, 0.03, 0.28))
		if e:
			draw_rect(Rect2(p + Vector2(TILE - 2, 0), Vector2(2, TILE)), Color(0, 0, 0.03, 0.18))
		if n and w:
			draw_rect(Rect2(p, Vector2(4, 4)), Color(0, 0, 0.03, 0.2))
		if n and e:
			draw_rect(Rect2(p + Vector2(TILE - 4, 0), Vector2(4, 4)), Color(0, 0, 0.03, 0.16))
		# 戶外的雪地：牆腳堆一道被風吹過來的積雪
		if (cn == "#" or char_at(cell + Vector2i.DOWN) == "#") and not _is_indoor_cell(cell) and floor_kind_at(cell) == "snow":
			var h := absi(hash(cell * 5 + Vector2i(1, 2)))
			var snow := Color(0.84, 0.88, 0.95, 0.5)
			if cn == "#":
				for i in 4:
					draw_rect(Rect2(p + Vector2(i * 4, 0), Vector2(4, 1 + (h >> (i * 2)) % 3)), snow)
			else:
				for i in 4:
					var hh := 1 + (h >> (i * 2 + 8)) % 3
					draw_rect(Rect2(p + Vector2(i * 4, 8 - hh), Vector2(4, hh)), snow)
	# 家具腳下的影子：單格的小東西（燈柱、盆栽）是一小塊，大型物件是整塊、前緣比較深
	for rect in _prop_rects:
		var r := Rect2(Vector2(rect.position) * TILE, Vector2(rect.size) * TILE)
		if rect.size.x == 1:
			for y in range(rect.position.y, rect.end.y):
				var q := Vector2(rect.position.x, y) * TILE
				draw_rect(Rect2(q + Vector2(2, 8), Vector2(12, 7)), Color(0, 0, 0.03, 0.3))
				draw_rect(Rect2(q + Vector2(1, 10), Vector2(14, 5)), Color(0, 0, 0.03, 0.28))
		else:
			draw_rect(r.grow_individual(-1, -3, -1, 0), Color(0, 0, 0.03, 0.34))
			draw_rect(Rect2(r.position + Vector2(0, r.size.y - 6), Vector2(r.size.x, 6)), Color(0, 0, 0.03, 0.26))


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
	return Art.tex(SetDresser.FLOOR_TEX.get(floor_kind_at(cell), "tiles/floor_slab"))


## SetDresser 放家具時登記：這張圖屬於哪一格（房間黑幕用）
func register_prop(node: CanvasItem, cell: Vector2i) -> void:
	_prop_nodes.append([node, cell])


## 只顯示這些房間裡的家具（rooms 是空的 = 全部顯示）。RoomFog 在看得到的房間變了的時候呼叫。
func show_prop_rooms(rooms: Array) -> void:
	if rooms == _props_shown_for:
		return
	_props_shown_for = rooms.duplicate()
	for entry in _prop_nodes:
		var node: CanvasItem = entry[0]
		node.visible = rooms.is_empty() or not room_of.has(entry[1]) or rooms.has(room_of[entry[1]])


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

	# 牆頂：貼圖已經是最後的顏色；外框不畫（稜線、牆面由 WallFaces 畫）
	var caps := {}
	for rect in _merge_rects("#"):
		var wall := _add_solid(rect, WALL_COLOR, WALL_EDGE_COLOR, WALL_RAISE)
		(_structure_layer.get_child(_structure_layer.get_child_count() - 1) as CanvasItem).visible = false
		var style := wall_style_at(rect.position + Vector2i(0, rect.size.y - 1))
		var wall_tex := Art.tex(SetDresser.WALL_TEX.get(style, "tiles/wall_slab"))
		if wall_tex:
			wall.texture = wall_tex
			wall.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			wall.color = Color.WHITE
		# 牆的北邊（後面）是家具、置物櫃：牆頂凸出來的那一段要補畫在家具上面
		for x in range(rect.position.x, rect.end.x):
			if "CH".contains(char_at(Vector2i(x, rect.position.y - 1))):
				caps[Vector2i(x, rect.position.y)] = wall_tex
	# 家具、設備：依房間種類擺（SetDresser）。y 排序：前面的蓋住後面的。
	var props := Node2D.new()
	props.name = "Props"
	props.y_sort_enabled = true
	# 這個圖層不受黑暗影響（地形永遠看得懂），所以家具本身壓暗一點，才不會在暗的房間裡發亮
	props.modulate = Color(0.62, 0.65, 0.74)
	_prop_rects = _merge_rects("C")
	var dressed: Array[Rect2i] = []
	for rect in _prop_rects:
		var base := _add_solid(rect, CABINET_COLOR, CABINET_EDGE_COLOR)
		var base_outline: CanvasItem = _structure_layer.get_child(_structure_layer.get_child_count() - 1)
		# 有圖的家具：底下不畫色塊（地板和貼地的影子畫在 _draw），不然小東西旁邊會多一塊黑方塊
		base.visible = false
		base_outline.visible = false
		if SetDresser.dress(self, rect, props) == 0:
			base.visible = true
			base_outline.visible = true
			if SetDresser.set_data(set_at(rect.position)).get("rocks", false):
				base.color = ROCK_COLOR.darkened(0.35)
				_add_rocks(rect, base)
			else:
				base.color = CABINET_COLOR
				_add_furniture(rect)
		else:
			dressed.append(rect)
	_prop_rects = dressed
	for rect in _merge_rects("="):
		_add_window(rect)
	for rect in _merge_rects("~"):
		_add_water(rect)
	# 牆面畫在家具下面：靠牆的高櫃子、地標會蓋住後面的牆面（櫃子在牆前面）
	var faces := WallFaces.new()
	faces.name = "WallFaces"
	_structure_layer.add_child(faces)
	faces.setup(self)
	_structure_layer.add_child(props)
	for rect in _merge_rects("H"):
		_add_solid(rect, LOCKER_COLOR, LOCKER_EDGE_COLOR)
		_add_prop_sprites(rect, Art.tex("props/locker"))
	var wall_caps := WallFaces.new()
	wall_caps.name = "WallCaps"
	wall_caps.mode = WallFaces.Mode.CAPS
	wall_caps.caps = caps
	_structure_layer.add_child(wall_caps)
	wall_caps.setup(self)
	# 裝飾用的光暈（壁燈、螢幕、警示燈）：加色疊在最上面
	var accents := LightAccents.new()
	accents.name = "LightAccents"
	_structure_layer.add_child(accents)
	accents.setup(self, faces)
	var front := CanvasLayer.new()
	front.name = "OverWall"
	front.layer = 1
	front.follow_viewport_enabled = true
	add_child(front)
	var over := OverWall.new()
	over.level = self
	front.add_child(over)


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


## 地板的痕跡（紙張、血跡、電線、鐵格板、油漬……依房間種類），畫在地板上、受光影響。
## 有原因的痕跡優先：通往戶外的門口有吹進來的雪和濕腳印、沒暖氣的房間結霜、碼頭邊積水；其他才是零星的雜物。
func _draw_floor_decals() -> void:
	for cell in _floor_cells:
		if char_at(cell) != "." or is_safe_cell(cell):
			continue
		var at := Vector2(cell) * TILE
		var h := absi(hash(cell * 7 + Vector2i(area_id.length() * 13, 3)))
		var indoor := _is_indoor_cell(cell)
		if indoor:
			# 旁邊就是戶外：雪從門口吹進來
			var blown := false
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var nb: Vector2i = cell + d
				if _is_floor_cell(nb) and not _is_indoor_cell(nb) and floor_kind_at(nb) == "snow":
					blown = true
			if blown:
				_decal("snow_blown", at + Vector2(0, 3))
				continue
			if is_cold(_cell_center(cell)) and h % 100 < 5:
				_decal("frost" if h % 3 != 0 else "bootprints", at)
				continue
		elif char_at(cell + Vector2i.DOWN) == "~" and h % 100 < 30:
			_decal("puddle", at + Vector2(0, 3))
			continue
		var set_info := SetDresser.set_data(set_at(cell))
		# 戶外（雪地、甲板）只用那種地面自己的痕跡，不放室內的警示線、鐵格板
		var pool: Array = set_info.get("decals", [] if not indoor else THEME_DECALS.get(theme_at(cell), []))
		if pool.is_empty() or h % 100 >= 9:
			continue
		var pick: String = pool[(h / 100) % pool.size()]
		if pick == "stain" and not (_is_floor_cell(cell + Vector2i.RIGHT) and _is_floor_cell(cell + Vector2i.DOWN)):
			continue  # 大片的污漬要有兩格寬的空地
		_decal(pick, at)


func _decal(decal: String, at: Vector2) -> void:
	var tex := Art.tex("decor/" + decal)
	if tex:
		draw_texture(tex, at + Vector2(maxf(0.0, floorf((TILE - tex.get_width()) * 0.5)), 0) if tex.get_width() < TILE else at)


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
		# 離岸越遠越深
		var depth := 0
		while depth < 3 and char_at(cell + Vector2i(0, -depth - 1)) == "~":
			depth += 1
		var base := Color(0.045, 0.095, 0.13).lerp(Color(0.02, 0.045, 0.07), depth / 3.0)
		draw_rect(Rect2(p, Vector2(TILE, TILE)), base)
		var h := absi(hash(cell * 11))
		# 水面的反光（固定的短橫線，兩種亮度）
		draw_rect(Rect2(p + Vector2(h % 9, 3 + (h / 9) % 4), Vector2(5, 1)), base.lightened(0.14))
		draw_rect(Rect2(p + Vector2((h / 37) % 10, 10 + (h / 370) % 4), Vector2(4, 1)), base.lightened(0.08))
		if h % 4 == 0:
			draw_rect(Rect2(p + Vector2((h / 5) % 8, 7), Vector2(7, 1)), Color(0.20, 0.34, 0.42, 0.5))
		# 岸邊：碼頭的水泥邊緣（亮的上緣、黃黑警示條）和它在水裡的影子、繫船的鐵環
		if char_at(cell + Vector2i.UP) != "~":
			draw_rect(Rect2(p, Vector2(TILE, 3)), Color(0.30, 0.32, 0.36))
			draw_rect(Rect2(p, Vector2(TILE, 1)), Color(0.42, 0.44, 0.49))
			draw_rect(Rect2(p + Vector2(0, 3), Vector2(TILE, 1)), Color(0.86, 0.68, 0.16) if (cell.x % 2 == 0) else Color(0.10, 0.10, 0.11))
			draw_rect(Rect2(p + Vector2(0, 4), Vector2(TILE, 5)), Color(0.01, 0.03, 0.05))
			draw_rect(Rect2(p + Vector2(0, 9), Vector2(TILE, 1)), Color(0.01, 0.03, 0.05, 0.5))
			if cell.x % 4 == 1:
				draw_rect(Rect2(p + Vector2(6, 5), Vector2(4, 3)), Color(0.34, 0.24, 0.16))
				draw_rect(Rect2(p + Vector2(7, 6), Vector2(2, 1)), Color(0.01, 0.03, 0.05))


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
	# 窗框上緣的亮邊、窗台、玻璃上一道反光、每格一根窗櫺
	var bars: Array = [[frame.position, Vector2(frame.size.x, 1), Color(0.50, 0.54, 0.62)],
		[rect.position + Vector2(0, rect.size.y - 3), Vector2(rect.size.x, 3), Color(0.12, 0.13, 0.16)],
		[rect.position + Vector2(0, rect.size.y - 4), Vector2(rect.size.x, 1), Color(0.40, 0.43, 0.50)],
		[glass.position + Vector2(1, 1), Vector2(glass.size.x - 2, 1), Color(0.80, 0.92, 1.0, 0.35)]]
	for i in range(1, cell_rect.size.x):
		bars.append([Vector2(rect.position.x + i * TILE - 1, glass.position.y), Vector2(2, glass.size.y), Color(0.2, 0.22, 0.26)])
	for b in bars:
		var bar := ColorRect.new()
		bar.position = b[0]
		bar.size = b[1]
		bar.color = b[2]
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_structure_layer.add_child(bar)


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
				Extras.SYMBOL:
					var ex: Dictionary = _data.get("extras", {}).get("%d,%d" % [x, y], {})
					if ex.get("kind", "") == "item":
						var extra_item := ItemPickup.new()
						extra_item.pickup_item = ex.item
						extra_item.pickup_count = ex.get("count", 1)
						item = extra_item
					elif not ex.is_empty():
						var extra := ExtraPickup.new()
						extra.info = ex
						item = extra
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
			if item is ItemPickup and item.hidden_flag == "":
				item.stand = _stand_for(Vector2i(x, y))
				if item.stand != "":
					_stand_cells[Vector2i(x, y)] = true
					add_nav_obstacle(item.position + Vector2(0, 2), Vector2(13, 10))
			add_child(item)
			item.sync_from_state()
			_interactables.append(item)


## 放道具的桌子（v0.10：道具不放地上）。回傳桌子種類；"" = 這一格不能放桌子（放地上）。
## 桌子會擋路，所以只放在「擋住也不會把路切斷」的格子：四周能走的格子彼此還連得起來、旁邊不是門。
const STAND_WOOD := ["office", "dorm", "lounge", "mess", "cabin", "saloon", "theater", "hut"]
const STAND_STEEL := ["lab", "medical", "comms", "utility"]
var _stand_cells := {}


func _stand_for(cell: Vector2i) -> String:
	if not Areas.is_real():
		return ""
	var set_id := set_at(cell)
	if set_id == "wild" or set_id == "cave":
		return ""
	var ring: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0),
		Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0)]
	var open: Array[bool] = []
	for d in ring:
		var ch := char_at(cell + d)
		if (d.x == 0 or d.y == 0) and (ch == "D" or ch == "+" or ch == "G" or ch == "="):
			return ""
		open.append(ch != "" and not "#CH=~ ".contains(ch) and not _stand_cells.has(cell + d))
	# 轉角那一格要兩邊都能走才算連著（不能從兩個家具中間斜著穿過去）
	var walk: Array[bool] = []
	for i in 8:
		walk.append(open[i] and (i % 2 == 1 or (open[(i + 7) % 8] or open[(i + 1) % 8])))
	var groups := 0
	for i in 8:
		if walk[i] and not walk[(i + 7) % 8]:
			groups += 1
	var any := walk.has(true)
	if not any or groups > 1 or not (open[1] or open[3] or open[5] or open[7]):
		return ""
	if STAND_WOOD.has(set_id):
		return "wood"
	return "steel" if STAND_STEEL.has(set_id) else "crate"


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
