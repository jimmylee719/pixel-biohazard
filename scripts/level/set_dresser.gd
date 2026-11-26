## 佈景：決定地圖上每一塊家具（C）畫成什麼、地板用哪種材質、牆上掛什麼。
## 依「房間種類」（set）挑：區域資料 sets = [{rect, set}] 指定某個範圍是餐廳、醫務室……，
## 沒指定的地方用區域主題（theme）對應的預設種類；戶外用區域資料 outdoor_set（預設 yard）。
## 挑選規則（固定亂數，同一格每次都一樣）：
##   - 2x2 以上的一整塊 → 大型物件（貨櫃、木箱堆、油槽、卡車、發電機組……，圖檔 <名稱>_<寬>x<高>）
##   - 橫的一排（2 格以上）→ 靠牆（上面是牆）用 back_wide、不靠牆用 island_wide（_l／_m／_r 三段）
##   - 單格 → 靠牆用 back（櫃子、層架、冰箱）、不靠牆用 island（桌子、推車、木箱）
##   - 區域資料 props = {"x,y": 圖檔路徑} 可以指定某一塊就是某樣東西（x,y = 那一塊的左上角）
## 圖在 assets/sprites/set/（tools/gen_scene_art.py）。
class_name SetDresser
extends RefCounted

const SETS := {
	"lab": {"floor": "tile", "wall": "panel",
		"back": ["set/shelf_lab", "set/fridge_lab", "decor/fume_hood", "props/cabinet", "set/shelf_lab", "decor/server_rack"],
		"back_wide": ["props/bench"], "island": ["set/cart_lab", "set/centrifuge", "decor/specimen_tank"],
		"island_wide": ["set/lab_island"], "big": ["set/cryo_tank"],
		"decor": ["monitor", "sign_bio", "vent", "clock", "conduit", "cctv", "lamp"],
		"decals": ["papers", "cables", "blood_0", "drag", "grate"]},
	"medical": {"floor": "tile", "wall": "panel",
		"back": ["set/med_cabinet", "set/shelf_linen", "set/fridge_lab", "set/sink", "set/med_cabinet"],
		"back_wide": ["set/med_bed"], "island": ["set/stretcher_stand", "set/cart_lab"], "island_wide": ["set/med_bed"],
		"decor": ["clock", "sign_bio", "notice", "lamp", "exit_sign"], "decals": ["blood_0", "blood_1", "drag", "papers"]},
	"mess": {"floor": "lino", "wall": "panel",
		"back": ["set/fridge", "set/stove", "set/sink", "set/shelf_food", "set/oven_rack", "set/vending", "set/water_cooler"],
		"back_wide": ["set/counter"], "island": ["set/table_small"], "island_wide": ["set/mess_table"], "big": ["set/mess_block"],
		"decor": ["notice", "clock", "poster", "exit_sign", "lamp"], "decals": ["papers", "debris", "blood_2"]},
	"lounge": {"floor": "lino", "wall": "panel",
		"back": ["set/vending", "decor/bookshelf", "set/water_cooler", "set/plant", "set/locker_gear"],
		"back_wide": ["set/sofa"], "island": ["set/table_small", "set/plant"], "island_wide": ["set/sofa"],
		"decor": ["frame", "notice", "clock", "poster", "coat_hooks", "exit_sign"], "decals": ["papers", "blood_0", "debris"]},
	"office": {"floor": "carpet", "wall": "panel",
		"back": ["set/shelf_files", "props/cabinet", "decor/bookshelf", "set/copier", "set/plant", "set/shelf_files"],
		"back_wide": ["set/desk_wide"], "island": ["decor/desk_computer", "set/plant"], "island_wide": ["set/desk_wide"],
		"big": ["set/meeting_table"], "decor": ["board", "wall_map", "frame", "clock", "notice"], "decals": ["papers", "papers", "blood_2"]},
	"dorm": {"floor": "lino", "wall": "panel",
		"back": ["decor/wardrobe", "set/locker_gear", "set/shelf_linen", "decor/wardrobe"],
		"back_wide": ["set/bunk2"], "island": ["set/footlocker", "set/table_small"], "island_wide": ["set/bunk2"],
		"decor": ["poster", "coat_hooks", "frame", "mirror", "lamp"], "decals": ["papers", "blood_0", "drag", "debris"]},
	"storage": {"floor": "concrete", "wall": "concrete",
		"back": ["set/shelf_boxes", "set/shelf_parts", "set/crate_stack", "set/shelf_boxes"],
		"back_wide": ["set/crates_long"], "island": ["set/crate_wood", "set/crate_stack", "set/drum", "decor/pallet"],
		"island_wide": ["set/crates_long"], "big": ["set/crates"],
		"decor": ["hazard_plate", "conduit", "fuse_panel", "lamp", "stencil"], "decals": ["debris", "oil", "stripes"]},
	"utility": {"floor": "metal", "wall": "concrete",
		"back": ["set/switchgear", "set/tank_v", "set/tool_chest", "set/gas_cylinders", "set/switchgear", "set/pump"],
		"back_wide": ["set/workbench"], "island": ["set/generator_unit", "set/pump", "set/drums", "set/cable_reel"],
		"island_wide": ["set/pipe_run"], "big": ["set/genset", "set/boiler"],
		"decor": ["pipe", "valve", "gauge", "fuse_panel", "hazard_plate", "alarm"], "decals": ["oil", "grate", "stripes", "cables"]},
	"garage": {"floor": "dock", "wall": "concrete",
		"back": ["set/tool_chest", "set/shelf_parts", "set/gas_cylinders", "set/tires", "set/shelf_parts"],
		"back_wide": ["set/workbench"], "island": ["set/tires", "set/drum", "set/cable_reel", "set/crate_wood"],
		"island_wide": ["set/drums_row"], "big": ["set/truck", "set/crates", "set/container0", "set/tank"],
		"decor": ["hazard_plate", "conduit", "stencil", "alarm", "lamp"], "decals": ["oil", "oil", "stripes", "debris"]},
	"comms": {"floor": "metal", "wall": "panel",
		"back": ["set/radio_rack", "set/server", "set/tape_drive", "set/console", "set/server"],
		"back_wide": ["set/desk_wide"], "island": ["set/console", "set/oscilloscope"], "island_wide": ["set/map_table"],
		"decor": ["wall_map", "speaker", "cctv", "clock", "conduit", "monitor"], "decals": ["cables", "cables", "papers"]},
	"military": {"floor": "concrete", "wall": "concrete",
		"back": ["set/gun_cabinet", "set/shelf_parts", "set/locker_gear", "set/ammo_stack", "set/radio_rack"],
		"back_wide": ["set/workbench"], "island": ["set/ammo_stack", "set/sandbag_wall", "set/weapon_bench", "set/crate_wood"],
		"island_wide": ["set/map_table"], "big": ["set/crates", "set/container2"],
		"decor": ["flag", "wall_map", "stencil", "conduit", "alarm", "lamp"], "decals": ["stripes", "oil", "debris"]},
	"barracks": {"floor": "concrete", "wall": "concrete",
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
	"cabin": {"floor": "carpet", "wall": "ship",
		"back": ["decor/wardrobe", "set/luggage", "set/plant", "set/shelf_linen"], "back_wide": ["set/bed"],
		"island": ["set/luggage", "set/table_round"], "island_wide": ["set/sofa"],
		"decor": ["porthole", "frame", "mirror", "lamp"], "decals": ["papers", "blood_0", "debris"]},
	"saloon": {"floor": "wood", "wall": "ship",
		"back": ["set/slot_machine", "set/plant", "set/piano", "set/slot_machine", "set/vending"], "back_wide": ["set/bar_counter"],
		"island": ["set/table_round", "set/plant"], "island_wide": ["set/sofa"], "big": ["set/mess_block"],
		"decor": ["porthole", "frame", "curtain", "life_ring", "lamp"], "decals": ["papers", "blood_2", "debris"]},
	"theater": {"floor": "carpet", "wall": "ship",
		"back": ["set/plant", "set/piano"], "back_wide": ["set/theater_seats"], "island": ["set/plant"], "island_wide": ["set/theater_seats"],
		"decor": ["curtain", "frame", "exit_sign"], "decals": ["papers", "blood_0"]},
	"hold": {"floor": "metal", "wall": "ship",
		"back": ["set/shelf_boxes", "set/crate_stack", "set/switchgear"], "back_wide": ["set/crates_long"],
		"island": ["set/crate_wood", "set/drum", "set/luggage", "set/crate_tarp"], "island_wide": ["set/crates_long"],
		"big": ["set/container0", "set/container1", "set/crates", "set/container2"],
		"decor": ["pipe", "valve", "hazard_plate", "conduit"], "decals": ["oil", "grate", "stripes"]},
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
		"decals": ["oil", "stripes", "debris"]},
	"deck": {"floor": "deck", "wall": "ship",
		"back": ["set/cowl_vent", "set/winch", "set/crate_tarp"], "back_wide": ["set/crates_long"],
		"island": ["set/bollard", "set/deck_chair", "set/cowl_vent", "set/winch", "set/deck_chair"], "island_wide": ["set/barrier"],
		"big": ["set/lifeboat", "set/container1", "set/crates"]},
	"wild": {"floor": "snow", "wall": "rock", "rocks": true},
}
## 區域主題（theme）→ 預設的房間種類
const THEME_SET := {"lab": "lab", "office": "office", "dorm": "dorm", "industrial": "storage", "military": "military",
	"hut": "hut", "cave": "cave", "outdoor": "yard"}
const FLOOR_TEX := {"tile": "tiles/floor_tile", "carpet": "tiles/floor_carpet", "lino": "tiles/floor_lino", "wood": "tiles/floor_wood",
	"deck": "tiles/floor_deck", "metal": "tiles/floor_metal", "dock": "tiles/floor_dock", "asphalt": "tiles/floor_asphalt",
	"rock": "tiles/floor_rock", "ice": "tiles/floor_ice", "concrete": "tiles/floor_concrete", "snow": "tiles/floor_snow"}
const WALL_TEX := {"panel": "tiles/wall_panel", "ship": "tiles/wall_ship", "wood": "tiles/wall_wood", "rock": "tiles/wall_rock",
	"concrete": "tiles/wall_concrete"}
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


## 這一塊家具畫成什麼。回傳加進 parent 的節點數（0 = 沒有圖，呼叫端畫色塊）。
static func dress(level: Level, rect: Rect2i, parent: Node) -> int:
	var set_id := level.set_at(rect.position)
	var d := set_data(set_id)
	var salt := level.area_id.length()
	var forced: String = level.prop_override(rect.position)
	if d.get("rocks", false) and forced == "":
		return 0
	# 大型物件
	if rect.size.x >= 2 and rect.size.y >= 2:
		var names: Array = [forced] if forced != "" else d.get("big", [])
		var fits: Array = []
		for n in names:
			if Art.tex("%s_%dx%d" % [n, rect.size.x, rect.size.y]):
				fits.append(n)
		if not fits.is_empty():
			var tex := Art.tex("%s_%dx%d" % [_pick(fits, rect.position, salt), rect.size.x, rect.size.y])
			_place(parent, tex, rect.position.x * Level.TILE, rect.end.y * Level.TILE)
			return 1
		# 沒有剛好大小的圖：一排一排擺
		var n := 0
		for y in range(rect.position.y, rect.end.y):
			n += dress(level, Rect2i(rect.position.x, y, rect.size.x, 1), parent)
		return n
	var count := 0
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
				_place(parent, Art.tex(base + part), x * Level.TILE, (rect.position.y + 1) * Level.TILE)
				count += 1
			return count
		for x in range(rect.position.x, rect.end.x):
			count += dress(level, Rect2i(x, rect.position.y, 1, 1), parent)
		return count
	# 單格（直的一排 = 一格一格擺，由上往下，前面的蓋住後面的）
	for y in range(rect.position.y, rect.end.y):
		var cell := Vector2i(rect.position.x, y)
		var name: String = level.prop_override(cell)
		if name == "":
			var against := level.char_at(cell + Vector2i.UP) == "#" or (y > rect.position.y)
			var pool: Array = d.get("back" if against else "island", d.get("island", d.get("back", [])))
			name = _pick(pool, cell, salt)
		var tex := Art.tex(name)
		if tex:
			_place(parent, tex, cell.x * Level.TILE + floori((Level.TILE - tex.get_width()) * 0.5), (cell.y + 1) * Level.TILE)
			count += 1
	return count


static func _place(parent: Node, tex: Texture2D, x: float, bottom: float) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = Vector2(0, -tex.get_height())
	s.position = Vector2(x, bottom)
	parent.add_child(s)
