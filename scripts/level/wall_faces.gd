## 牆的高度感（3/4 俯視）：
##   牆頂整塊往上畫 Level.WALL_RAISE 像素（在 Level._add_solid），
##   下面是地板的牆格畫一整格高的牆面（亮面、接縫、踢腳板），
##   牆頂的邊緣畫亮的稜線、右側畫暗線，看起來像一塊突起來的方塊。
## 畫在 Structure 圖層（在角色上面）；角色站在牆前面時由 OverWall 畫回牆上面。
class_name WallFaces
extends Node2D

## 牆面的高度（像素）。牆頂往上偏移 WALL_RAISE，所以單格厚的牆看得到 WALL_RAISE 高的牆頂。
const FACE := 16.0
## 牆面上的細節（decor/ 的圖，tools/gen_pixel_art.py）
const WALL_DECOR := {
	"lab": ["monitor", "sign_bio", "poster", "vent", "alarm", "lamp"],
	"office": ["board", "poster", "lamp", "monitor"],
	"dorm": ["poster", "board", "lamp"],
	"industrial": ["pipe", "vent", "alarm", "lamp"],
	"military": ["pipe", "board", "alarm", "lamp"],
	"hut": ["board", "lamp"],
}

var level: Level
var _cells: Array[Vector2i] = []
var _tops: Array[Vector2i] = []


func setup(lv: Level) -> void:
	level = lv
	_cells.clear()
	_tops.clear()
	for y in lv._map.size():
		for x in String(lv._map[y]).length():
			var c := Vector2i(x, y)
			if lv.char_at(c) != "#":
				continue
			_tops.append(c)
			if not "#=".contains(lv.char_at(c + Vector2i.DOWN)) and c.y + 1 < lv._map.size():
				_cells.append(c)
	queue_redraw()


func _draw() -> void:
	var t := float(Level.TILE)
	var r := Level.WALL_RAISE
	var outdoor := level.outdoor
	var rim := Color(0.62, 0.65, 0.72) if not outdoor else Color(0.78, 0.82, 0.88)
	var dark := Color(0.08, 0.09, 0.11)
	# 牆頂的稜線（左上亮、右邊暗）
	for c in _tops:
		var p := Vector2(c) * t - Vector2(0, r)
		if level.char_at(c + Vector2i.UP) != "#":
			draw_rect(Rect2(p, Vector2(t, 1)), rim)
		if level.char_at(c + Vector2i.LEFT) != "#":
			draw_rect(Rect2(p, Vector2(1, t)), rim.darkened(0.15))
		if level.char_at(c + Vector2i.RIGHT) != "#":
			draw_rect(Rect2(p + Vector2(t - 1, 0), Vector2(1, t)), dark)
	var top := Color(0.13, 0.14, 0.17) if not outdoor else Color(0.2, 0.21, 0.25)
	var face_hi := Color(0.46, 0.48, 0.54) if not outdoor else Color(0.5, 0.52, 0.58)
	var face_lo := Color(0.26, 0.27, 0.32) if not outdoor else Color(0.32, 0.34, 0.4)
	for c in _cells:
		var p := Vector2(c) * t
		var indoor := not outdoor or level._is_indoor_cell(c + Vector2i.DOWN)
		var hi := face_hi if indoor else Color(0.55, 0.58, 0.64)
		var lo := face_lo if indoor else Color(0.36, 0.38, 0.44)
		var y0 := t - FACE
		# 牆頂和牆面的交界（暗線）
		draw_rect(Rect2(p + Vector2(0, y0 - 1), Vector2(t, 1)), top)
		# 牆面：上亮下暗的漸層
		for i in int(FACE):
			var k := float(i) / FACE
			draw_rect(Rect2(p + Vector2(0, y0 + i), Vector2(t, 1)), hi.lerp(lo, k))
		# 轉角：牆面兩側的邊（旁邊不是牆時）
		if level.char_at(c + Vector2i.LEFT) != "#":
			draw_rect(Rect2(p + Vector2(0, y0), Vector2(1, FACE)), hi.lightened(0.15))
		if level.char_at(c + Vector2i.RIGHT) != "#":
			draw_rect(Rect2(p + Vector2(t - 1, y0), Vector2(1, FACE)), lo.darkened(0.35))
		# 牆板接縫（每兩格一條）、踢腳板
		if c.x % 2 == 0:
			draw_rect(Rect2(p + Vector2(0, y0 + 2), Vector2(1, FACE - 4)), lo.darkened(0.3))
		draw_rect(Rect2(p + Vector2(0, t - 3), Vector2(t, 3)), lo.darkened(0.45))
		# 牆上的細節（依區域主題，固定亂數）：螢幕、海報、生物危害標誌、管線、通風口、警報燈、壁燈……
		var h := absi(hash(c * 3 + Vector2i(7, level.area_id.length())))
		var pool: Array = WALL_DECOR.get(level.theme(), [])
		if not pool.is_empty() and h % 4 == 0:
			var tex := Art.tex("decor/" + pool[(h / 4) % pool.size()])
			if tex:
				var at := p + Vector2(floorf((t - tex.get_width()) * 0.5), y0 + 3)
				draw_texture(tex, at)
		elif h % 13 == 1:
			draw_rect(Rect2(p + Vector2(6, y0 + 4), Vector2(3, FACE - 7)), Color(0.32, 0.26, 0.2, 0.6))
