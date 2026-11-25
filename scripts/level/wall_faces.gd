## 牆的正面（3/4 俯視的「高度感」）：下面是地板的牆格，下半部畫成牆面（有亮面、接縫、踢腳板），
## 上半部是牆頂（暗）。畫在牆格自己裡面，不會蓋到站在牆前面的角色。
class_name WallFaces
extends Node2D

## 牆面佔牆格的高度（像素）
const FACE := 10.0

var level: Level
var _cells: Array[Vector2i] = []


func setup(lv: Level) -> void:
	level = lv
	_cells.clear()
	for y in lv._map.size():
		for x in String(lv._map[y]).length():
			var c := Vector2i(x, y)
			if lv.char_at(c) == "#" and not "#=".contains(lv.char_at(c + Vector2i.DOWN)) and c.y + 1 < lv._map.size():
				_cells.append(c)
	queue_redraw()


func _draw() -> void:
	var t := float(Level.TILE)
	var outdoor := level.outdoor
	var top := Color(0.13, 0.14, 0.17) if not outdoor else Color(0.2, 0.21, 0.25)
	var face_hi := Color(0.46, 0.48, 0.54) if not outdoor else Color(0.5, 0.52, 0.58)
	var face_lo := Color(0.3, 0.31, 0.36) if not outdoor else Color(0.34, 0.36, 0.42)
	for c in _cells:
		var p := Vector2(c) * t
		var indoor := not outdoor or level._is_indoor_cell(c + Vector2i.DOWN)
		var hi := face_hi if indoor else Color(0.55, 0.58, 0.64)
		var lo := face_lo if indoor else Color(0.38, 0.4, 0.46)
		# 牆頂的邊（亮一點的一條線，讓牆頂和牆面分開）
		draw_rect(Rect2(p + Vector2(0, t - FACE - 1), Vector2(t, 1)), top.lightened(0.25))
		# 牆面：上亮下暗的漸層
		for i in int(FACE):
			var k := float(i) / FACE
			draw_rect(Rect2(p + Vector2(0, t - FACE + i), Vector2(t, 1)), hi.lerp(lo, k))
		# 牆板接縫（每兩格一條）、踢腳板
		if c.x % 2 == 0:
			draw_rect(Rect2(p + Vector2(0, t - FACE), Vector2(1, FACE)), lo.darkened(0.3))
		draw_rect(Rect2(p + Vector2(0, t - 2), Vector2(t, 2)), lo.darkened(0.45))
		# 偶爾有管線或污漬（固定的亂數，每次一樣）
		var h := absi(hash(c)) % 13
		if h == 0:
			draw_rect(Rect2(p + Vector2(3, t - FACE + 2), Vector2(t - 6, 2)), Color(0.25, 0.27, 0.3))
		elif h == 1:
			draw_rect(Rect2(p + Vector2(6, t - FACE + 3), Vector2(3, FACE - 5)), Color(0.32, 0.26, 0.2, 0.6))
