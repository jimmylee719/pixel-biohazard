## 聲納雷達（v0.11，右上角）：參考經典潛行遊戲「右上角小雷達＋警戒時變成倒數」的介面節奏，內容換成本作的「聲音」主題：
##   - 周圍的牆（地圖格子）、自己（三角形＝面向）
##   - v0.14：雷達範圍內所有在偵查的敵人（人、怪物）都畫出來：點＋視野扇形（被牆擋住的地方截斷），
##     平常淡藍、起疑／警戒時紅色；沒有視覺的（爬行者、鳴骨者）畫聽覺範圍的圈。牆畫成青色的線框。
##     走路的敵人另外有腳步聲波。
##   - 警戒（ALERT）／搜索（EVASION）：雷達有一點雜訊，但地圖和發現你的敵人（含視野）照樣顯示，下方 ALERT／EVASION 倒數（v0.14）；戒備（CAUTION）：下方小倒數
##   - 1962 年的記憶、Boss 戰：沒有訊號
## main 控制 visible（跟戰術 HUD 一樣）。
class_name SonarRadar
extends Control

const SIZE := Vector2(80, 60)
## 一格畫幾個像素
const CELL := 3.0
## 聽得到腳步的距離（格）
const HEAR_TILES := 11.0
const FRAME := Color(0.45, 0.62, 0.62, 0.9)
const BG := Color(0.01, 0.04, 0.05, 0.78)
const WALL := Color(0.3, 0.52, 0.5, 0.85)
const EDGE := Color(0.35, 0.95, 0.9, 0.95)
const FLOOR := Color(0.05, 0.16, 0.2, 0.55)
const CONE := Color(0.3, 0.7, 1.0, 0.33)
const CONE_HUNT := Color(1.0, 0.3, 0.25, 0.38)
const GLASS := Color(0.35, 0.6, 0.75, 0.6)

var main: Node
var touch := false
var _font: Font
## 聽到的腳步：enemy id → [位置, 剩幾秒]
var _pings := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = load("res://assets/fonts/Cubic_11.ttf")


func box_rect() -> Rect2:
	var view := get_viewport_rect().size
	return Rect2(Vector2(view.x - SIZE.x - 6, 44 if touch else 6), SIZE)


func _process(delta: float) -> void:
	if not visible or main == null or main._player == null:
		return
	var player: Player = main._player
	for id in _pings.keys():
		_pings[id][1] -= delta
		if _pings[id][1] <= 0.0:
			_pings.erase(id)
	for e in main.enemies:
		if not is_instance_valid(e) or e.is_dead or e.is_dormant:
			continue
		if e.velocity.length() > 8.0 and e.global_position.distance_to(player.global_position) < HEAR_TILES * Level.TILE:
			_pings[e.get_instance_id()] = [e.global_position, 1.2]
	queue_redraw()


func _draw() -> void:
	if main == null or main._player == null or main.level == null:
		return
	var r := box_rect()
	draw_rect(r, BG)
	var lv: Level = main.level
	var net: AlertNetwork = lv.alert
	var phase := net.phase if net else AlertNetwork.Phase.NONE
	var no_signal: bool = main.current_era() > 0.5 or lv.camera_mode() == "fixed"
	if no_signal:
		_draw_static(r)
		_center_text(r, tr("NO CARRIER"), Color(0.6, 0.7, 0.7))
		draw_rect(r, FRAME, false, 1.0)
		return
	# v0.14：警戒中雷達只有一點雜訊，地圖、發現你的敵人和他們的視野照樣顯示
	_draw_map(r)
	if phase == AlertNetwork.Phase.ALERT:
		_draw_static(r, 0.22)
		var blink := int(Time.get_ticks_msec() / 250) % 2 == 0
		draw_rect(Rect2(r.position + Vector2(0, r.size.y - 13), Vector2(r.size.x, 13)), Color(0, 0, 0, 0.65))
		draw_string(_font, r.position + Vector2(3, r.size.y - 1), "ALERT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(1, 0.25, 0.2) if blink else Color(0.7, 0.12, 0.1))
	elif phase == AlertNetwork.Phase.EVASION:
		_draw_static(r, 0.15)
		draw_rect(Rect2(r.position + Vector2(0, r.size.y - 13), Vector2(r.size.x, 13)), Color(0, 0, 0, 0.65))
		draw_string(_font, r.position + Vector2(3, r.size.y - 1), "EVASION %05.2f" % maxf(net.timer, 0.0),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.8, 0.3))
	elif phase == AlertNetwork.Phase.CAUTION:
		draw_rect(Rect2(r.position + Vector2(0, r.size.y - 11), Vector2(r.size.x, 11)), Color(0, 0, 0, 0.6))
		draw_string(_font, r.position + Vector2(3, r.size.y - 1), "CAUTION %05.2f" % maxf(net.timer, 0.0),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.95, 0.4))
	draw_rect(r, FRAME, false, 1.0)
	# 左上角的切角（同戰術 HUD）
	draw_rect(Rect2(r.position, Vector2(5, 1)), Color(0.85, 0.9, 0.92))
	draw_rect(Rect2(r.position, Vector2(1, 5)), Color(0.85, 0.9, 0.92))


func _draw_map(r: Rect2) -> void:
	var lv: Level = main.level
	var player: Player = main._player
	var center := r.get_center()
	var pc := player.global_position / Level.TILE
	var half := r.size / CELL * 0.5
	var c0 := Vector2i(floori(pc.x - half.x) - 1, floori(pc.y - half.y) - 1)
	var c1 := Vector2i(ceili(pc.x + half.x) + 1, ceili(pc.y + half.y) + 1)
	# 地板淡淡一層、牆只畫貼著地板的邊（青色線框）
	for y in range(c0.y, c1.y):
		for x in range(c0.x, c1.x):
			var cell := Vector2i(x, y)
			var ch := lv.char_at(cell)
			var p := center + (Vector2(x, y) - pc) * CELL
			if ch == "" or ch == " ":
				continue
			if ch != "#":
				var fr := Rect2(p, Vector2(CELL, CELL)).intersection(r)
				if fr.size.x > 0 and fr.size.y > 0:
					draw_rect(fr, GLASS if ch == "=" else (Color(0.06, 0.16, 0.22) if ch == "~" else FLOOR))
				continue
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var nb := lv.char_at(cell + d)
				if nb == "#" or nb == "" or nb == " ":
					continue
				var a := p
				var b := p
				match d:
					Vector2i.UP:
						b = p + Vector2(CELL, 0)
					Vector2i.DOWN:
						a = p + Vector2(0, CELL)
						b = p + Vector2(CELL, CELL)
					Vector2i.LEFT:
						b = p + Vector2(0, CELL)
					Vector2i.RIGHT:
						a = p + Vector2(CELL, 0)
						b = p + Vector2(CELL, CELL)
				if r.has_point(a) and r.has_point(b):
					draw_line(a, b, EDGE, 1.0)
	# 聽到的腳步
	for id in _pings:
		var pos: Vector2 = _pings[id][0]
		var p := center + (pos / Level.TILE - pc) * CELL
		if r.grow(-2).has_point(p):
			var k: float = _pings[id][1] / 1.2
			draw_arc(p, 2.0 + (1.0 - k) * 4.0, 0.0, TAU, 10, Color(0.6, 0.85, 0.9, 0.7 * k), 1.0)
	# 雷達範圍內所有在偵查的敵人：點＋視野（被牆截斷）
	for e in main.enemies:
		if not is_instance_valid(e) or e.is_dead or e.stashed or not e.is_inside_tree():
			continue
		var p: Vector2 = center + (e.global_position / Level.TILE - pc) * CELL
		if not r.grow(-1).has_point(p):
			continue
		var asleep: bool = e.is_dormant or e.is_asleep()
		var hunting: bool = e.state == Enemy.State.ALERT or e.state == Enemy.State.SUSPICIOUS
		if not asleep and e.has_sight:
			var reach: float = e.get_effective_range()
			var ang: float = e.facing.angle()
			var half_a: float = e.get_half_angle()
			var pts := PackedVector2Array([p])
			var rays := 10
			for i in rays + 1:
				var dir := Vector2.RIGHT.rotated(ang - half_a + half_a * 2.0 * i / rays)
				var dist := _ray(lv, e.global_position, dir, reach)
				var q: Vector2 = p + dir * dist / Level.TILE * CELL
				pts.append(Vector2(clampf(q.x, r.position.x, r.end.x), clampf(q.y, r.position.y, r.end.y)))
			# 去掉重疊的點（被牆截斷或貼到雷達邊時會重疊），退化的扇形不畫
			var clean := PackedVector2Array()
			for q in pts:
				if clean.is_empty() or clean[clean.size() - 1].distance_to(q) > 0.3:
					clean.append(q)
			if clean.size() >= 3 and not Geometry2D.triangulate_polygon(clean).is_empty():
				draw_colored_polygon(clean, CONE_HUNT if hunting else CONE)
		elif not asleep and e.proximity_sense > 0.0:
			# 沒有視覺：聽覺範圍的圈
			draw_arc(p, maxf(e.proximity_sense, 2.0 * Level.TILE) / Level.TILE * CELL, 0.0, TAU, 16,
				Color(CONE_HUNT if hunting else CONE, 0.6), 1.0)
		var dot := Color(1, 0.35, 0.3) if e.faction == "human" else Color(0.95, 0.85, 0.5)
		if asleep:
			dot = Color(dot, 0.45)
		draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), dot)
	# 自己
	var f: Vector2 = player.facing
	var side := f.orthogonal()
	draw_colored_polygon(PackedVector2Array([center + f * 4.0, center - f * 2.5 + side * 2.5, center - f * 2.5 - side * 2.5]),
		Color(0.95, 1.0, 1.0))


## 視線走多遠會撞到牆（像素）
func _ray(lv: Level, from: Vector2, dir: Vector2, reach: float) -> float:
	var d := 0.0
	var step := Level.TILE * 0.5
	while d < reach:
		d += step
		var ch := lv.char_at(lv.cell_of(from + dir * d))
		if ch == "#" or ch == "" or ch == "H":
			return maxf(d - step * 0.5, 0.0)
	return reach


func _near_floor(lv: Level, c: Vector2i) -> bool:
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var ch := lv.char_at(c + d)
		if ch != "" and ch != "#" and ch != " ":
			return true
	return false


func _draw_static(r: Rect2, amount := 1.0) -> void:
	var frame := int(Time.get_ticks_msec() / 60)
	for i in int(90 * amount):
		var h := hash(Vector2i(i, frame))
		var p := r.position + Vector2(posmod(h, int(r.size.x)), posmod(h >> 8, int(r.size.y)))
		draw_rect(Rect2(p, Vector2(2, 1)), Color(0.5, 0.6, 0.6, 0.35))


func _center_text(r: Rect2, s: String, c: Color, size := 12, dy := 0.0) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(r.get_center().x - w * 0.5, r.get_center().y + size * 0.35 + dy).floor()
	draw_string(_font, at + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.8))
	draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
