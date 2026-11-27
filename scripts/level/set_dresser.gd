## 佈景：決定地圖上每一塊家具（C）畫成什麼、地板用哪種材質、牆上掛什麼。
## 依「房間種類」（set）挑：區域資料 sets = [{rect, set}] 指定某個範圍是餐廳、醫務室……，
## 沒指定的地方用區域主題（theme）對應的預設種類；戶外用區域資料 outdoor_set（預設 yard）。
## 挑選規則（固定亂數，同一格每次都一樣）：
##   - 2x2 以上的一整塊 → 大型物件（貨櫃、木箱堆、油槽、卡車、發電機組……，圖檔 <名稱>_<寬>x<高>）
##   - 橫的一排（2 格以上）→ 靠牆（上面是牆）用 back_wide、不靠牆用 island_wide（_l／_m／_r 三段）
##   - 單格 → 靠牆用 back（櫃子、層架、冰箱）、不靠牆用 island（桌子、推車、木箱）
##   - 區域資料 props = {"x,y": 圖檔路徑} 可以指定某一塊就是某樣東西（x,y = 那一塊的左上角）
##     指定時一律先找「剛好這個大小的整張圖」<名稱>_<寬>x<高>（1 排的也是：console_bank_4x1、forklift_2x1……），
##     沒有才用 _l／_m／_r 三段或單格的圖。地標級的物件和它的格數見 LANDMARKS（大小不對會警告）。
##     RUNS 裡的東西（欄杆）指定一次就整排都是它：橫排用原圖接起來、直排用 <名稱>_v。
## 每種房間另外有：line（地上沿牆的標線顏色）、dado（牆面的色帶）、pipes（牆面上方的管線顏色）、hazard_box（大型機具周圍畫警示框）。
## 圖在 assets/sprites/set/（tools/gen_scene_art.py）。
class_name SetDresser
extends RefCounted

const SETS := {
	"lab": {"floor": "epoxy", "wall": "panel", "line": Color(0.20, 0.62, 0.58, 0.55), "dado": Color(0.16, 0.42, 0.42), "hazard_box": true,
		"back": ["set/shelf_lab", "set/fridge_lab", "decor/fume_hood", "props/cabinet", "set/shelf_lab", "decor/server_rack"],
		"back_wide": ["props/bench"], "island": ["set/cart_lab", "set/centrifuge", "decor/specimen_tank"],
		"island_wide": ["set/lab_island"], "big": ["set/cryo_tank"],
		"decor": ["monitor", "sign_bio", "vent", "clock", "conduit", "cctv", "lamp"],
		"decals": ["papers", "cables", "blood_0", "drag", "drain", "stain"]},
	"medical": {"floor": "tile", "wall": "panel", "dado": Color(0.42, 0.56, 0.50),
		"back": ["set/med_cabinet", "set/shelf_linen", "set/fridge_lab", "set/sink", "set/med_cabinet"],
		"back_wide": ["set/med_bed"], "island": ["set/stretcher_stand", "set/cart_lab"], "island_wide": ["set/med_bed"],
		"decor": ["clock", "sign_bio", "notice", "lamp", "exit_sign"], "decals": ["blood_0", "blood_1", "drag", "papers", "drain"]},
	"mess": {"floor": "checker", "wall": "panel", "dado": Color(0.52, 0.47, 0.36),
		"back": ["set/fridge", "set/stove", "set/sink", "set/shelf_food", "set/oven_rack", "set/vending", "set/water_cooler"],
		"back_wide": ["set/counter"], "island": ["set/table_small"], "island_wide": ["set/mess_table"], "big": ["set/mess_block"],
		"decor": ["notice", "clock", "poster", "exit_sign", "lamp"], "decals": ["papers", "debris", "blood_2", "puddle", "drain"]},
	"lounge": {"floor": "lino", "wall": "panel", "dado": Color(0.44, 0.30, 0.22),
		"back": ["set/vending", "decor/bookshelf", "set/water_cooler", "set/plant", "set/locker_gear"],
		"back_wide": ["set/sofa"], "island": ["set/table_small", "set/plant"], "island_wide": ["set/sofa"],
		"decor": ["frame", "notice", "clock", "poster", "coat_hooks", "exit_sign"], "decals": ["papers", "blood_0", "debris"]},
	"office": {"floor": "carpet", "wall": "panel", "line": Color(0.62, 0.52, 0.32, 0.4), "dado": Color(0.34, 0.25, 0.17),
		"back": ["set/shelf_files", "props/cabinet", "decor/bookshelf", "set/copier", "set/plant", "set/shelf_files"],
		"back_wide": ["set/desk_wide"], "island": ["decor/desk_computer", "set/plant"], "island_wide": ["set/desk_wide"],
		"big": ["set/meeting_table"], "decor": ["board", "wall_map", "frame", "clock", "notice"], "decals": ["papers", "papers", "blood_2"]},
	"dorm": {"floor": "lino", "wall": "panel", "dado": Color(0.26, 0.32, 0.42),
		"back": ["decor/wardrobe", "set/locker_gear", "set/shelf_linen", "decor/wardrobe"],
		"back_wide": ["set/bunk2"], "island": ["set/footlocker", "set/table_small"], "island_wide": ["set/bunk2"],
		"decor": ["poster", "coat_hooks", "frame", "mirror", "lamp"], "decals": ["papers", "blood_0", "drag", "debris"]},
	"storage": {"floor": "concrete", "wall": "concrete", "line": Color(0.80, 0.64, 0.14, 0.5), "pipes": Color(0.36, 0.38, 0.42), "hazard_box": true,
		"back": ["set/shelf_boxes", "set/shelf_parts", "set/crate_stack", "set/shelf_boxes"],
		"back_wide": ["set/crates_long"], "island": ["set/crate_wood", "set/crate_stack", "set/drum", "decor/pallet"],
		"island_wide": ["set/crates_long"], "big": ["set/crates"],
		"decor": ["hazard_plate", "fuse_panel", "lamp", "stencil"], "decals": ["debris", "oil", "scuff", "crack", "stain", "arrow_r"]},
	"utility": {"floor": "metal", "wall": "concrete", "line": Color(0.80, 0.64, 0.14, 0.5), "pipes": Color(0.50, 0.28, 0.16), "hazard_box": true,
		"back": ["set/switchgear", "set/tank_v", "set/tool_chest", "set/gas_cylinders", "set/switchgear", "set/pump"],
		"back_wide": ["set/workbench"], "island": ["set/generator_unit", "set/pump", "set/drums", "set/cable_reel"],
		"island_wide": ["set/pipe_run"], "big": ["set/genset", "set/boiler"],
		"decor": ["valve", "gauge", "fuse_panel", "hazard_plate", "alarm", "lamp"], "decals": ["oil", "grate", "puddle", "cables", "stain", "drain"]},
	"garage": {"floor": "concrete", "wall": "concrete", "line": Color(0.80, 0.64, 0.14, 0.5), "pipes": Color(0.36, 0.38, 0.42), "hazard_box": true,
		"back": ["set/tool_chest", "set/shelf_parts", "set/gas_cylinders", "set/tires", "set/shelf_parts"],
		"back_wide": ["set/workbench"], "island": ["set/tires", "set/drum", "set/cable_reel", "set/crate_wood"],
		"island_wide": ["set/drums_row"], "big": ["set/truck", "set/crates", "set/container0", "set/tank"],
		"decor": ["hazard_plate", "stencil", "alarm", "lamp"], "decals": ["oil", "oil", "scuff", "debris", "stain", "arrow_l", "crack"]},
	"comms": {"floor": "access", "wall": "panel", "dado": Color(0.24, 0.30, 0.20),
		"back": ["set/radio_rack", "set/server", "set/tape_drive", "set/console", "set/server"],
		"back_wide": ["set/desk_wide"], "island": ["set/console", "set/oscilloscope"], "island_wide": ["set/map_table"],
		"decor": ["wall_map", "speaker", "cctv", "clock", "conduit", "monitor"], "decals": ["cables", "cables", "papers"]},
	"military": {"floor": "concrete", "wall": "concrete", "line": Color(0.80, 0.64, 0.14, 0.45), "pipes": Color(0.26, 0.32, 0.20), "hazard_box": true,
		"back": ["set/gun_cabinet", "set/shelf_parts", "set/locker_gear", "set/ammo_stack", "set/radio_rack"],
		"back_wide": ["set/workbench"], "island": ["set/ammo_stack", "set/sandbag_wall", "set/weapon_bench", "set/crate_wood"],
		"island_wide": ["set/map_table"], "big": ["set/crates", "set/container2"],
		"decor": ["flag", "wall_map", "stencil", "alarm", "lamp"], "decals": ["scuff", "oil", "debris", "crack", "stain"]},
	"barracks": {"floor": "concrete", "wall": "concrete", "pipes": Color(0.26, 0.32, 0.20),
		"back": ["set/locker_gear", "set/gun_cabinet", "set/footlocker"], "back_wide": ["set/cot"],
		"island": ["set/footlocker"], "island_wide": ["set/cot"],
		"decor": ["flag", "coat_hooks", "poster", "lamp"], "decals": ["debris", "papers"]},
	"hut": {"floor": "wood", "wall": "wood",
		"back": ["decor/wardrobe", "set/shelf_food", "set/stove", "decor/bookshelf", "set/shelf_boxes"],
		"back_wide": ["set/bed"], "island": ["set/table_small", "set/crate_wood", "set/footlocker"], "island_wide": ["set/workbench"],
		"decor": ["coat_hooks", "frame", "board", "lamp", "window_dark"], "decals": ["debris", "papers"]},
	"cave": {"floor": "rock", "wall": "rock",
		"back": ["set/stalagmite", "decor/ice_pillar", "set/ice_block"], "island": ["set/stalagmite", "set/ice_block", "decor/ice_pillar"],
		"decals": ["frost", "frost", "blood_1"]},
	"cabin": {"floor": "carpet", "wall": "ship", "line": Color(0.62, 0.52, 0.32, 0.4), "dado": Color(0.50, 0.38, 0.20),
		"back": ["decor/wardrobe", "set/luggage", "set/plant", "set/shelf_linen"], "back_wide": ["set/bed"],
		"island": ["set/luggage", "set/table_round"], "island_wide": ["set/sofa"],
		"decor": ["porthole", "frame", "mirror", "lamp"], "decals": ["papers", "blood_0", "debris"]},
	"saloon": {"floor": "wood", "wall": "ship", "dado": Color(0.50, 0.38, 0.20),
		"back": ["set/slot_machine", "set/plant", "set/piano", "set/slot_machine", "set/vending"], "back_wide": ["set/bar_counter"],
		"island": ["set/table_round", "set/plant"], "island_wide": ["set/sofa"], "big": ["set/mess_block"],
		"decor": ["porthole", "frame", "curtain", "life_ring", "lamp"], "decals": ["papers", "blood_2", "debris"]},
	"theater": {"floor": "carpet_red", "wall": "ship", "line": Color(0.70, 0.56, 0.28, 0.45), "dado": Color(0.42, 0.12, 0.16),
		"back": ["set/plant", "set/piano"], "back_wide": ["set/theater_seats"], "island": ["set/plant"], "island_wide": ["set/theater_seats"],
		"decor": ["curtain", "frame", "exit_sign"], "decals": ["papers", "blood_0"]},
	"hold": {"floor": "metal", "wall": "ship", "line": Color(0.80, 0.64, 0.14, 0.5), "pipes": Color(0.44, 0.46, 0.50), "hazard_box": true,
		"back": ["set/shelf_boxes", "set/crate_stack", "set/switchgear"], "back_wide": ["set/crates_long"],
		"island": ["set/crate_wood", "set/drum", "set/luggage", "set/crate_tarp"], "island_wide": ["set/crates_long"],
		"big": ["set/container0", "set/container1", "set/crates", "set/container2"],
		"decor": ["valve", "hazard_plate", "gauge", "lamp"], "decals": ["oil", "grate", "puddle", "stain", "scuff"]},
	# ── 戶外 ──
	"yard": {"floor": "snow", "wall": "concrete",
		"back": ["set/crate_tarp", "set/drums", "set/wood_pile", "set/gas_cylinders"], "back_wide": ["set/crates_long"],
		"island": ["set/crate_tarp", "set/snow_mound", "set/drum", "set/sled", "set/signpost", "set/lamp_post"],
		"island_wide": ["set/barrier", "set/pipe_run"], "big": ["set/container0", "set/container1", "set/crates", "set/tank", "set/truck", "set/container3"]},
	"dock": {"floor": "dock", "wall": "concrete",
		"back": ["set/crate_stack", "set/drums", "set/gas_cylinders", "set/tires"], "back_wide": ["set/crates_long"],
		"island": ["set/bollard", "set/drum", "set/crate_wood", "set/tires", "set/cable_reel", "set/lamp_post"],
		"island_wide": ["set/barrier", "set/drums_row"],
		"big": ["set/container0", "set/container1", "set/container2", "set/crates", "set/container3"],
		"hazard_box": true, "decals": ["oil", "puddle", "debris", "manhole", "scuff", "stain", "puddle"]},
	"deck": {"floor": "deck", "wall": "ship",
		"back": ["set/cowl_vent", "set/winch", "set/crate_tarp"], "back_wide": ["set/crates_long"],
		"island": ["set/bollard", "set/deck_chair", "set/cowl_vent", "set/winch", "set/deck_chair"], "island_wide": ["set/barrier"],
		"big": ["set/lifeboat", "set/container1", "set/crates"]},
	"wild": {"floor": "snow", "wall": "rock", "rocks": true},
}
## 區域主題（theme）→ 預設的房間種類
const THEME_SET := {"lab": "lab", "office": "office", "dorm": "dorm", "industrial": "storage", "military": "military",
	"hut": "hut", "cave": "cave", "outdoor": "yard"}
## 地板材質（tools/gen_scene_art.py tiles）：水泥板、環氧樹脂、小磁磚、棋盤格、亞麻、地毯、木板、柚木甲板、花紋鋼板、高架地板、濕水泥、雪
const FLOOR_TEX := {"tile": "tiles/floor_tile", "carpet": "tiles/floor_carpet", "lino": "tiles/floor_lino", "wood": "tiles/floor_wood",
	"deck": "tiles/floor_deck", "metal": "tiles/floor_metal", "dock": "tiles/floor_dock", "asphalt": "tiles/floor_asphalt",
	"rock": "tiles/floor_rock", "ice": "tiles/floor_ice", "concrete": "tiles/floor_slab", "snow": "tiles/floor_snowpack",
	"epoxy": "tiles/floor_epoxy", "checker": "tiles/floor_checker", "access": "tiles/floor_access", "carpet_red": "tiles/floor_carpet_red"}
## 牆頂的貼圖：已經是最後的顏色（Level 不再壓暗）
const WALL_TEX := {"panel": "tiles/wall_panel", "ship": "tiles/wall_ship", "wood": "tiles/wall_wood", "rock": "tiles/wall_rock",
	"concrete": "tiles/wall_slab"}
## 地標級的物件（每棟建築主廳的主角）和它佔的格數：props 指定時那一塊 C 要剛好這麼大
const LANDMARKS := {"set/reactor": Vector2i(3, 3), "set/turbine": Vector2i(4, 2), "set/drill_rig": Vector2i(3, 3),
	"set/snow_crawler": Vector2i(4, 2), "set/crane": Vector2i(2, 2), "set/specimen_tank": Vector2i(2, 2), "set/scanner": Vector2i(3, 2),
	"set/server_bank": Vector2i(3, 2), "set/workbench": Vector2i(3, 2), "set/reception_desk": Vector2i(4, 2), "set/pillar": Vector2i(1, 1),
	"set/railing": Vector2i(1, 1), "set/forklift": Vector2i(2, 1), "set/console_bank": Vector2i(4, 1), "set/tape_reel_bank": Vector2i(3, 1),
	"set/antenna_mast": Vector2i(2, 2), "set/pump_station": Vector2i(3, 2), "set/stage": Vector2i(6, 2), "set/bar_island": Vector2i(4, 2),
	"set/pool_table": Vector2i(2, 2), "set/grand_piano": Vector2i(2, 2), "set/lifeboat": Vector2i(3, 1), "set/winch": Vector2i(2, 2),
	"set/engine_block": Vector2i(4, 3), "set/watchtower": Vector2i(2, 2), "set/gate_barrier": Vector2i(3, 1), "set/tent": Vector2i(3, 2),
	"set/sled": Vector2i(2, 1), "set/ice_drill": Vector2i(2, 2)}
## 指定一次就整排都是它的東西（橫排用原圖接起來、直排用 <名稱>_v）
const RUNS := ["set/railing"]
## 不管在哪種房間，周圍都畫警示框的機具
const MACHINES := ["set/reactor", "set/turbine", "set/drill_rig", "set/crane", "set/engine_block", "set/pump_station", "set/winch",
	"set/genset", "set/boiler", "set/specimen_tank", "set/cryo_tank", "set/scanner"]
## 會發光的東西：[顏色, 光暈中心離圖底部多高, 光暈大小, 強度]（裝飾用的加色光暈，見 LightAccents；不影響潛行的明暗判定）
const GLOW := {
	"set/reactor": [Color(0.35, 0.85, 1.0), 26.0, Vector2(64, 48), 0.5], "set/specimen_tank": [Color(0.3, 0.95, 0.85), 22.0, Vector2(48, 44), 0.55],
	"set/cryo_tank": [Color(0.4, 0.8, 1.0), 16.0, Vector2(40, 36), 0.4], "set/server_bank": [Color(0.3, 1.0, 0.7), 14.0, Vector2(56, 28), 0.3],
	"set/console_bank": [Color(0.35, 1.0, 0.8), 12.0, Vector2(72, 26), 0.4], "set/console": [Color(0.35, 1.0, 0.8), 12.0, Vector2(26, 22), 0.4],
	"set/scanner": [Color(0.35, 1.0, 0.8), 22.0, Vector2(34, 28), 0.4], "set/tape_reel_bank": [Color(1.0, 0.72, 0.3), 12.0, Vector2(56, 22), 0.3],
	"set/stage": [Color(1.0, 0.78, 0.4), 12.0, Vector2(104, 40), 0.4], "set/lamp_post": [Color(1.0, 0.82, 0.5), 4.0, Vector2(64, 46), 0.5],
	"set/watchtower": [Color(1.0, 0.82, 0.5), 40.0, Vector2(36, 28), 0.5], "set/boiler": [Color(1.0, 0.55, 0.2), 6.0, Vector2(30, 22), 0.5],
	"set/vending": [Color(1.0, 0.75, 0.7), 12.0, Vector2(28, 26), 0.3], "set/slot_machine": [Color(0.5, 1.0, 0.8), 14.0, Vector2(24, 22), 0.35],
	"set/fridge_lab": [Color(0.6, 0.9, 1.0), 12.0, Vector2(24, 24), 0.25], "set/server": [Color(0.3, 1.0, 0.7), 12.0, Vector2(22, 26), 0.25],
	"set/radio_rack": [Color(1.0, 0.75, 0.35), 12.0, Vector2(22, 26), 0.25], "set/oscilloscope": [Color(0.35, 1.0, 0.8), 12.0, Vector2(22, 20), 0.35],
	"set/bar_island": [Color(1.0, 0.78, 0.45), 16.0, Vector2(64, 30), 0.25], "set/antenna_mast": [Color(1.0, 0.25, 0.2), 62.0, Vector2(20, 20), 0.6],
	"set/drill_rig": [Color(1.0, 0.25, 0.2), 86.0, Vector2(20, 20), 0.6], "set/gate_barrier": [Color(1.0, 0.25, 0.2), 13.0, Vector2(18, 18), 0.5],
}
## 3x5 的數字、字母（牆上的房號、碼頭的泊位編號）：每個字 15 個位元，由左上到右下
const FONT := {"0": 0b111101101101111, "1": 0b010110010010111, "2": 0b111001111100111, "3": 0b111001111001111, "4": 0b101101111001001,
	"5": 0b111100111001111, "6": 0b111100111101111, "7": 0b111001001001001, "8": 0b111101111101111, "9": 0b111101111001111,
	"A": 0b111101111101101, "B": 0b110101110101110, "C": 0b111100100100111, "-": 0b000000111000000}
## 牆面的顏色（亮、暗）
const WALL_FACE := {
	"panel": [Color(0.50, 0.53, 0.58), Color(0.28, 0.30, 0.35)],
	"concrete": [Color(0.42, 0.44, 0.48), Color(0.23, 0.24, 0.28)],
	"ship": [Color(0.66, 0.69, 0.72), Color(0.38, 0.41, 0.46)],
	"wood": [Color(0.46, 0.34, 0.24), Color(0.25, 0.18, 0.13)],
	"rock": [Color(0.30, 0.34, 0.40), Color(0.14, 0.16, 0.20)],
}


static func set_data(set_id: String) -> Dictionary:
	return SETS.get(set_id, SETS.storage)


static func _pick(pool: Array, cell: Vector2i, salt: int) -> String:
	if pool.is_empty():
		return ""
	return pool[absi(hash(cell * 5 + Vector2i(salt, salt * 3))) % pool.size()]


## 用小字畫一串數字（一個字 3x5，間隔 1）
static func draw_text(ci: CanvasItem, pos: Vector2, text: String, col: Color) -> void:
	for i in text.length():
		var bits: int = FONT.get(text[i], 0)
		for k in 15:
			if bits & (1 << (14 - k)):
				ci.draw_rect(Rect2(pos + Vector2(i * 4 + k % 3, k / 3), Vector2.ONE), col)


## 這一塊家具畫成什麼。回傳加進 parent 的節點數（0 = 沒有圖，呼叫端畫色塊）。
static func dress(level: Level, rect: Rect2i, parent: Node) -> int:
	var set_id := level.set_at(rect.position)
	var d := set_data(set_id)
	var salt := level.area_id.length()
	var forced: String = level.prop_override(rect.position)
	if d.get("rocks", false) and forced == "":
		return 0
	# 指定的東西：先找剛好這個大小的整張圖（1 排、單格也一樣），地標就是這樣放的
	if forced != "":
		var whole := Art.tex("%s_%dx%d" % [forced, rect.size.x, rect.size.y])
		if whole:
			_place(level, parent, whole, rect.position.x * Level.TILE, rect.end.y * Level.TILE, rect.position, forced)
			return 1
		if LANDMARKS.has(forced) and LANDMARKS[forced] != rect.size and not RUNS.has(forced):
			# 那一塊 C 的大小和地標不合：還是把圖放上去（靠左下），並提醒改地圖
			var want: Vector2i = LANDMARKS[forced]
			push_warning("%s：props %d,%d = %s 要 %dx%d 格的 C，現在是 %dx%d" % [level.area_id, rect.position.x, rect.position.y,
				forced, want.x, want.y, rect.size.x, rect.size.y])
			var lm := Art.tex("%s_%dx%d" % [forced, want.x, want.y]) if want != Vector2i.ONE else Art.tex(forced)
			if lm:
				_place(level, parent, lm, rect.position.x * Level.TILE, rect.end.y * Level.TILE, rect.position, forced)
				return 1
	# 大型物件
	if rect.size.x >= 2 and rect.size.y >= 2:
		var names: Array = [forced] if forced != "" else d.get("big", [])
		var fits: Array = []
		for n in names:
			if Art.tex("%s_%dx%d" % [n, rect.size.x, rect.size.y]):
				fits.append(n)
		if not fits.is_empty():
			var pick := _pick(fits, rect.position, salt)
			var tex := Art.tex("%s_%dx%d" % [pick, rect.size.x, rect.size.y])
			_place(level, parent, tex, rect.position.x * Level.TILE, rect.end.y * Level.TILE, rect.position, pick)
			return 1
		# 沒有剛好大小的圖：一排一排擺
		var n := 0
		for y in range(rect.position.y, rect.end.y):
			n += dress(level, Rect2i(rect.position.x, y, rect.size.x, 1), parent)
		return n
	var count := 0
	var run := forced if RUNS.has(forced) else ""
	if rect.size.x >= 2:
		var back := level.char_at(rect.position + Vector2i.UP) == "#"
		var pool: Array = d.get("back_wide" if back else "island_wide", d.get("island_wide", d.get("back_wide", [])))
		var base: String = forced if forced != "" else _pick(pool, rect.position, salt)
		if base != "" and Art.tex(base + "_l"):
			for x in range(rect.position.x, rect.end.x):
				var part := "_m"
				if x == rect.position.x:
					part = "_l"
				elif x == rect.end.x - 1:
					part = "_r"
				_place(level, parent, Art.tex(base + part), x * Level.TILE, (rect.position.y + 1) * Level.TILE, Vector2i(x, rect.position.y),
					base if x == rect.position.x else "")
				count += 1
			return count
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, rect.position.y)
			if run != "" and level.prop_override(cell) == "":
				# 整排都是同一樣東西（欄杆）
				_place(level, parent, Art.tex(run), x * Level.TILE, (cell.y + 1) * Level.TILE, cell, "")
				count += 1
			else:
				count += dress(level, Rect2i(x, rect.position.y, 1, 1), parent)
		return count
	# 單格（直的一排 = 一格一格擺，由上往下，前面的蓋住後面的）
	for y in range(rect.position.y, rect.end.y):
		var cell := Vector2i(rect.position.x, y)
		var name: String = level.prop_override(cell)
		if name == "" and run != "":
			name = run
		if name == "":
			var against := level.char_at(cell + Vector2i.UP) == "#" or (y > rect.position.y)
			var pool: Array = d.get("back" if against else "island", d.get("island", d.get("back", [])))
			name = _pick(pool, cell, salt)
		var tex := Art.tex(name)
		if RUNS.has(name) and rect.size.y > 1 and Art.tex(name + "_v"):
			tex = Art.tex(name + "_v")
		if tex:
			_place(level, parent, tex, cell.x * Level.TILE + floori((Level.TILE - tex.get_width()) * 0.5), (cell.y + 1) * Level.TILE, cell, name)
			count += 1
	return count


static func _place(level: Level, parent: Node, tex: Texture2D, x: float, bottom: float, cell: Vector2i, name: String) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = Vector2(0, -tex.get_height())
	s.position = Vector2(x, bottom)
	parent.add_child(s)
	# 房間黑幕：沒看到的房間，裡面的東西整個藏起來（高的東西才不會從黑幕上面露出來）
	level.register_prop(s, cell)
	if GLOW.has(name):
		var gl: Array = GLOW[name]
		level.accent_lights.append({"pos": Vector2(x + tex.get_width() * 0.5, bottom - gl[1]), "color": gl[0], "size": gl[2], "power": gl[3]})
