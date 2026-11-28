## 牆的高度感（3/4 俯視）：
##   牆頂整塊往上畫 Level.WALL_RAISE 像素（在 Level._add_solid），
##   下面是地板的牆格畫一整格高的牆面：上緣的亮邊、牆板、色帶或管線（依房間種類）、踢腳板，
##   牆頂的邊緣畫亮的稜線、右側畫暗線，看起來像一塊突起來的方塊；
##   離地板很遠的實心牆（建築外面的岩盤、沒有用到的空間）畫成接近全黑，建築的輪廓才清楚。
## 畫在 Structure 圖層（在角色上面）；角色站在牆前面時由 OverWall 畫回牆上面。
## v0.14：牆比人高（牆面 FACE = 32、牆頂 8，共 40px）。牆頂也由這裡畫（Level 的牆多邊形隱藏），
##   主角所在的房間南邊那道牆、或主角就站在牆後面時，那道牆「切低」畫回舊的高度（牆面 16、牆頂 8），
##   房間靠南牆的地板、家具、敵人才看得到（剖面式，常見的 3/4 俯視做法）。
## 有兩個：FACES 畫在家具下面（靠牆的高櫃子會蓋住一部分牆面＝櫃子在牆前面），
##        CAPS 畫在家具上面（牆北邊的家具，底部被牆頂蓋住一點＝家具在牆後面）。
class_name WallFaces
extends Node2D

enum Mode { FACES, CAPS }

## 牆面的高度（像素）。牆面從牆格的下緣往上畫 FACE（比一格高：上面 FACE - 16 那一段伸進北邊那格），
## 牆頂再往上 WALL_RAISE - (FACE - 16) = 8px。v0.14 起牆比角色高。
const FACE := 32.0
## 牆面伸出牆格上緣的部分
const UPPER := FACE - 16.0
## 牆面上的細節（decor/ 的圖，tools/gen_pixel_art.py）
const WALL_DECOR := {
	"lab": ["monitor", "sign_bio", "poster", "vent", "alarm", "lamp"],
	"office": ["board", "poster", "lamp", "monitor"],
	"dorm": ["poster", "board", "lamp"],
	"industrial": ["pipe", "vent", "alarm", "lamp"],
	"military": ["pipe", "board", "alarm", "lamp"],
	"hut": ["board", "lamp"],
}
const VOID := Color(0.035, 0.038, 0.05)
## 壁燈每隔幾格一盞（有節奏，不是亂數）
const LAMP_EVERY := 6

var level: Level
var mode := Mode.FACES
var _cells: Array[Vector2i] = []
var _tops: Array[Vector2i] = []
## 實心牆的深處：格子 → 0.5（半暗）／1.0（全黑）
var _void := {}
## 牆面格子 → 掛在上面的東西（decor/ 的圖名）；"lamp" = 壁燈（LightAccents 畫光暈）
var decor := {}
## 牆面格子 → 房號（門旁邊的小牌子）
var _numbers := {}
## CAPS：要補畫牆頂的格子（北邊是家具）→ 牆頂的貼圖
var caps := {}
## CAPS：北邊是家具的窗戶格子（窗框上緣那一段補畫在家具上面）
var window_caps := {}
## CAPS 用：FACES 那一個（切低的牆格子從它拿）
var faces_ref: WallFaces
## 切低的牆格子（整條柱子：牆面那格往上直到不是牆）
var cut := {}
## 牆面格子 → 它那一柱的牆格子、牆後面（北邊）第一個不是牆的格子
var _column := {}
var _behind := {}
var _player_cell := Vector2i(-999, -999)
## 切低時的牆面高度、牆頂偏移
const CUT_FACE := 16.0
const CUT_RAISE := 8.0


func setup(lv: Level) -> void:
	level = lv
	process_mode = Node.PROCESS_MODE_ALWAYS  # 過場（遊戲暫停）時鏡頭跟著主角，牆也要跟著切
	_cells.clear()
	_tops.clear()
	_void.clear()
	decor.clear()
	_numbers.clear()
	if mode == Mode.CAPS:
		queue_redraw()
		return
	for y in lv._map.size():
		for x in String(lv._map[y]).length():
			var c := Vector2i(x, y)
			if lv.char_at(c) != "#":
				continue
			var depth := _solid_depth(c)
			if depth >= 2:
				_void[c] = 1.0
				continue
			if depth == 1:
				_void[c] = 0.5
			_tops.append(c)
			if not "#=".contains(lv.char_at(c + Vector2i.DOWN)) and c.y + 1 < lv._map.size():
				_cells.append(c)
				_plan_decor(c)
	for f in _cells:
		var col: Array[Vector2i] = []
		var b := f
		while lv.char_at(b) == "#" and col.size() < 6:
			col.append(b)
			b += Vector2i.UP
		_column[f] = col
		_behind[f] = b
	_player_cell = Vector2i(-999, -999)
	cut.clear()
	queue_redraw()


func _process(_delta: float) -> void:
	if mode != Mode.FACES or level == null:
		return
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	if pl == null:
		return
	var pc := level.cell_of(pl.global_position)
	if pc == _player_cell:
		return
	_player_cell = pc
	var new_cut := {}
	var my_room: int = level.room_of.get(pc, -1)
	for f in _cells:
		var b: Vector2i = _behind[f]
		if not level._is_floor_cell(b):
			continue
		var same_room: bool = my_room >= 0 and level.room_of.get(b, -2) == my_room and level._is_indoor_cell(b)
		var close: bool = absi(pc.x - f.x) <= 4 and pc.y <= b.y and pc.y >= b.y - 3
		if same_room or close:
			for c in _column[f]:
				new_cut[c] = true
	if new_cut.hash() != cut.hash():
		cut = new_cut
		queue_redraw()
		var caps_node := get_parent().get_node_or_null("WallCaps") as WallFaces
		if caps_node:
			caps_node.queue_redraw()


func raise_of(c: Vector2i) -> float:
	var src := faces_ref if faces_ref else self
	return CUT_RAISE if src.cut.has(c) else Level.WALL_RAISE


func _wall_tex(c: Vector2i) -> Texture2D:
	return Art.tex(SetDresser.WALL_TEX.get(level.wall_style_at(c), "tiles/wall_slab"))


## 這格牆離最近的「不是牆」有多遠（0 = 旁邊就有、1、2 = 兩格內都是牆）
func _solid_depth(c: Vector2i) -> int:
	for r in [1, 2]:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) == r and level.char_at(c + Vector2i(dx, dy)) != "#":
					return r - 1
		# 牆面在牆格自己身上往下畫一格，再往下一排也要是牆才算深處
		if level.char_at(c + Vector2i(0, r + 1)) != "#":
			return r - 1
	return 2


## 決定這格牆面掛什麼（固定亂數）：壁燈有固定間隔、門旁邊掛房號，其他依房間種類
func _plan_decor(c: Vector2i) -> void:
	var below := c + Vector2i.DOWN
	if not level._is_indoor_cell(below):
		return
	# 門旁邊（門在同一排牆的右邊）：房號牌
	if level.char_at(c + Vector2i.RIGHT) == "+":
		var fl := level.floor_number()
		_numbers[c] = ("B%02d" if fl < 1 else str(fl) + "%02d") % (absi(hash(c * 11)) % 40 + 1)
		return
	# 靠牆的高櫃子會擋住牆面：不掛東西
	if "CH".contains(level.char_at(below)):
		return
	var set_info := SetDresser.set_data(level.set_at(below))
	if set_info.get("rocks", false) or set_info.get("wall", "") == "rock":
		return
	var pool: Array = set_info.get("decor", WALL_DECOR.get(level.theme_at(c), []))
	if posmod(c.x + c.y * 2, LAMP_EVERY) == 2:
		decor[c] = "lamp"
		return
	var h := absi(hash(c * 3 + Vector2i(7, level.area_id.length())))
	if pool.is_empty() or h % 4 != 0 or decor.get(c + Vector2i.LEFT, "") != "":
		return
	var pick: String = pool[(h / 4) % pool.size()]
	if pick != "lamp" and pick != "conduit" and pick != "pipe":
		decor[c] = pick


func _draw() -> void:
	if mode == Mode.CAPS:
		_draw_caps()
		return
	var t := float(Level.TILE)
	var dark := Color(0.06, 0.065, 0.08)
	# 牆頂（由上往下畫：下面那格的牆頂蓋住上面那格）
	var all_walls: Array = _tops.duplicate()
	all_walls.append_array(_void.keys())
	all_walls.sort_custom(func(a, b): return a.y < b.y)
	for c in all_walls:
		_draw_top(c, Rect2(Vector2(c) * t - Vector2(0, raise_of(c)), Vector2(t, t)))
	# 實心牆的深處：蓋黑（邊緣一圈半暗）
	for c in _void:
		draw_rect(Rect2(Vector2(c) * t - Vector2(0, raise_of(c)), Vector2(t, t)), Color(VOID, 0.6 if _void[c] < 1.0 else 1.0))
	# 牆頂的稜線（上、左亮，右暗）
	for c in _tops:
		var p := Vector2(c) * t - Vector2(0, raise_of(c))
		var rim := _rim(c)
		if level.char_at(c + Vector2i.UP) != "#":
			draw_rect(Rect2(p, Vector2(t, 1)), rim)
		if level.char_at(c + Vector2i.LEFT) != "#":
			draw_rect(Rect2(p, Vector2(1, t)), rim.darkened(0.2))
		if level.char_at(c + Vector2i.RIGHT) != "#":
			draw_rect(Rect2(p + Vector2(t - 1, 0), Vector2(1, t)), dark)
	for c in _cells:
		_draw_face(c)


func _draw_top(c: Vector2i, rect: Rect2) -> void:
	var tex := _wall_tex(c)
	var t := int(Level.TILE)
	if tex:
		var src := Rect2(Vector2(posmod(c.x * t, tex.get_width()), posmod(c.y * t, tex.get_height())), rect.size)
		draw_texture_rect_region(tex, rect, src)
	else:
		draw_rect(rect, Level.WALL_COLOR)


func _rim(c: Vector2i) -> Color:
	var cols: Array = SetDresser.WALL_FACE.get(level.wall_style_at(c), SetDresser.WALL_FACE.concrete)
	return (cols[0] as Color).lerp(Color(0.62, 0.66, 0.74), 0.5)


func _draw_face(c: Vector2i) -> void:
	var t := float(Level.TILE)
	var p := Vector2(c) * t
	var below := c + Vector2i.DOWN
	var style := level.wall_style_at(c)
	var cols: Array = SetDresser.WALL_FACE.get(style, SetDresser.WALL_FACE.concrete)
	var hi: Color = cols[0]
	var lo: Color = cols[1]
	var indoor := level._is_indoor_cell(below)
	var set_info := SetDresser.set_data(level.set_at(below))
	# 外牆、承重牆（上面還是牆）比隔間牆暗、牆腳是一段水泥基座
	var thick := level.char_at(c + Vector2i.UP) == "#"
	if thick:
		hi = hi.darkened(0.12)
		lo = lo.darkened(0.12)
	if not indoor:
		hi = hi.lerp(Color(0.52, 0.58, 0.68), 0.25)
	var mid := hi.lerp(lo, 0.4)
	var low := cut.has(c)
	var up := 0.0 if low else UPPER
	# 上半段（伸進北邊那格）：素面牆板＋牆頂前緣的亮邊；下半段接著是細節（色帶、管線、踢腳）。切低的牆沒有上半段
	if low:
		draw_rect(Rect2(p + Vector2(0, -1), Vector2(t, 1)), hi.lightened(0.28))
	else:
		_draw_upper_band(c, hi, lo, thick)
		draw_rect(Rect2(p + Vector2(0, -1), Vector2(t, 1)), lo.lerp(hi, 0.35))
	draw_rect(Rect2(p, Vector2(t, 2)), hi)
	draw_rect(Rect2(p + Vector2(0, 2), Vector2(t, 8)), mid)
	draw_rect(Rect2(p + Vector2(0, 10), Vector2(t, 3)), hi.lerp(lo, 0.7))
	# 牆板接縫：隔間牆每格一條、外牆每兩格一條
	if not thick or c.x % 2 == 0:
		draw_rect(Rect2(p + Vector2(0, 1), Vector2(1, 12)), lo.darkened(0.25))
		draw_rect(Rect2(p + Vector2(1, 2), Vector2(1, 10)), hi.lerp(lo, 0.15))
	if style == "wood":
		for wy in [5, 10]:
			draw_rect(Rect2(p + Vector2(0, wy), Vector2(t, 1)), lo.darkened(0.3))
	elif style == "ship":
		for rx in [3, 8, 13]:
			draw_rect(Rect2(p + Vector2(rx, 2), Vector2(1, 1)), hi.lightened(0.3))
			draw_rect(Rect2(p + Vector2(rx, 11), Vector2(1, 1)), hi.lightened(0.15))
	# 依房間種類：牆面的色帶（實驗室青綠、醫務室淺綠、辦公室木飾板……）或上方的管線（機房、倉庫）
	var decor_y := 3.0
	if indoor and set_info.has("pipes"):
		var pc: Color = set_info.pipes
		draw_rect(Rect2(p + Vector2(0, 2), Vector2(t, 1)), pc.lightened(0.35))
		draw_rect(Rect2(p + Vector2(0, 3), Vector2(t, 2)), pc)
		draw_rect(Rect2(p + Vector2(0, 5), Vector2(t, 1)), lo.darkened(0.45))
		draw_rect(Rect2(p + Vector2(7, 1), Vector2(2, 5)), lo.darkened(0.55))  # 管夾
		if absi(hash(c * 5)) % 5 == 0:
			# 往下接的支管
			draw_rect(Rect2(p + Vector2(12, 5), Vector2(2, 8)), pc.darkened(0.15))
			draw_rect(Rect2(p + Vector2(12, 5), Vector2(1, 8)), pc.lightened(0.25))
		decor_y = 7.0
	elif indoor and set_info.has("dado"):
		var dc: Color = set_info.dado
		draw_rect(Rect2(p + Vector2(0, 9), Vector2(t, 1)), dc.lightened(0.3))
		draw_rect(Rect2(p + Vector2(0, 10), Vector2(t, 3)), dc)
	# 踢腳板／基座
	if thick:
		draw_rect(Rect2(p + Vector2(0, 11), Vector2(t, 1)), hi.lerp(lo, 0.3))
		draw_rect(Rect2(p + Vector2(0, 12), Vector2(t, 4)), lo.darkened(0.35))
	else:
		draw_rect(Rect2(p + Vector2(0, 13), Vector2(t, 1)), hi.lerp(lo, 0.5))
		draw_rect(Rect2(p + Vector2(0, 14), Vector2(t, 2)), lo.darkened(0.5))
	if not indoor:
		# 戶外：牆腳積雪
		var hgt := 2.0 + float(absi(hash(c * 13)) % 2)
		draw_rect(Rect2(p + Vector2(0, t - hgt), Vector2(t, hgt)), Color(0.66, 0.72, 0.80))
		draw_rect(Rect2(p + Vector2(float(absi(hash(c * 17)) % 9), t - hgt - 1), Vector2(6, 1)), Color(0.74, 0.79, 0.86))
	# 轉角：牆面兩側的邊（旁邊不是牆時）
	if level.char_at(c + Vector2i.LEFT) != "#":
		draw_rect(Rect2(p - Vector2(0, up), Vector2(1, 16.0 + up)), hi.lightened(0.18))
	if level.char_at(c + Vector2i.RIGHT) != "#":
		draw_rect(Rect2(p + Vector2(t - 1, -up), Vector2(1, 16.0 + up)), lo.darkened(0.4))
	# 房號牌
	if _numbers.has(c):
		draw_rect(Rect2(p + Vector2(2, 3), Vector2(13, 7)), Color(0.07, 0.08, 0.10))
		draw_rect(Rect2(p + Vector2(2, 3), Vector2(13, 1)), Color(0.30, 0.33, 0.38))
		SetDresser.draw_text(self, p + Vector2(3, 4), _numbers[c], Color(0.86, 0.80, 0.56))
		return
	# 牆上掛的東西
	var name: String = decor.get(c, "")
	if name != "":
		var tex := Art.tex("decor/" + name)
		if tex and (name == "lamp" or decor_y + tex.get_height() <= 13.0):
			draw_texture(tex, p + Vector2(floorf((t - tex.get_width()) * 0.5), 2.0 if name == "lamp" and decor_y < 4.0 else decor_y))
	elif indoor and absi(hash(c * 3 + Vector2i(7, level.area_id.length()))) % 13 == 1:
		# 舊的水痕
		draw_rect(Rect2(p + Vector2(6, decor_y + 1), Vector2(2, 12 - decor_y)), Color(0.20, 0.17, 0.14, 0.45))


## 牆面上半段（牆格上緣以上 UPPER 像素）：素面牆板、接縫、最上面牆頂前緣的亮邊
func _draw_upper_band(c: Vector2i, hi: Color, lo: Color, thick: bool) -> void:
	var t := float(Level.TILE)
	var top := Vector2(c) * t - Vector2(0, UPPER)
	var mid := hi.lerp(lo, 0.3)
	draw_rect(Rect2(top, Vector2(t, UPPER)), mid)
	draw_rect(Rect2(top + Vector2(0, -1), Vector2(t, 1)), hi.lightened(0.28))
	draw_rect(Rect2(top, Vector2(t, 2)), hi)
	draw_rect(Rect2(top + Vector2(0, UPPER - 3), Vector2(t, 2)), hi.lerp(lo, 0.55))
	if not thick or c.x % 2 == 0:
		draw_rect(Rect2(top + Vector2(0, 1), Vector2(1, UPPER - 1)), lo.darkened(0.25))
		draw_rect(Rect2(top + Vector2(1, 2), Vector2(1, UPPER - 3)), hi.lerp(lo, 0.15))


func _face_colors(c: Vector2i) -> Array:
	var cols: Array = SetDresser.WALL_FACE.get(level.wall_style_at(c), SetDresser.WALL_FACE.concrete)
	var hi: Color = cols[0]
	var lo: Color = cols[1]
	if level.char_at(c + Vector2i.UP) == "#":
		hi = hi.darkened(0.12)
		lo = lo.darkened(0.12)
	if not level._is_indoor_cell(c + Vector2i.DOWN):
		hi = hi.lerp(Color(0.52, 0.58, 0.68), 0.25)
	return [hi, lo]


## 家具在牆的北邊（後面）：把牆頂和伸上去的牆面補畫在家具上面
func _draw_caps() -> void:
	var t := float(Level.TILE)
	for c in window_caps:
		var wr := Rect2(Vector2(c) * t - Vector2(0, Level.WINDOW_RAISE), Vector2(t, Level.WINDOW_RAISE))
		draw_rect(wr, Color(0.2, 0.22, 0.26))
		draw_rect(Rect2(wr.position + Vector2(2, 2), Vector2(t - 4, wr.size.y - 2)), Color(0.55, 0.75, 0.9, 0.35))
		draw_rect(Rect2(wr.position, Vector2(t, 1)), Color(0.50, 0.54, 0.62))
		draw_rect(Rect2(wr.position + Vector2(3, 3), Vector2(t - 6, 1)), Color(0.80, 0.92, 1.0, 0.35))
	for c in caps:
		var r := raise_of(c)
		var low := r < Level.WALL_RAISE
		var cap_h := r if low else r - UPPER
		var tex: Texture2D = caps[c]
		var rect := Rect2(Vector2(c) * t - Vector2(0, r), Vector2(t, cap_h))
		if tex:
			var src := Rect2(Vector2(posmod(c.x * int(t), tex.get_width()), posmod(c.y * int(t), tex.get_height())), Vector2(t, cap_h))
			draw_texture_rect_region(tex, rect, src)
		else:
			draw_rect(rect, Level.WALL_COLOR)
		draw_rect(Rect2(rect.position, Vector2(t, 1)), _rim(c))
		if low:
			continue
		if not "#=".contains(level.char_at(c + Vector2i.DOWN)):
			var cols := _face_colors(c)
			_draw_upper_band(c, cols[0], cols[1], level.char_at(c + Vector2i.UP) == "#")
		else:
			# 厚牆：下一格的牆頂
			var rect2 := Rect2(Vector2(c) * t - Vector2(0, UPPER), Vector2(t, UPPER))
			if tex:
				draw_texture_rect_region(tex, rect2, Rect2(Vector2(posmod(c.x * int(t), tex.get_width()), posmod(c.y * int(t) + int(cap_h), tex.get_height())), Vector2(t, UPPER)))
			else:
				draw_rect(rect2, Level.WALL_COLOR)
