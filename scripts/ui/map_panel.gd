## 全螢幕地圖（按地圖鍵 M 直接打開）：看得到自己在哪（紅色閃爍的箭頭＝位置和面向）、可以放大縮小、拖著看。
## 去過的地方亮、只有地圖還沒去過的地方暗藍、完全不知道的地方不畫。勾了指引的任務用各自的顏色標出來
## （目標在這張地圖 = 菱形；不在 = 往那邊的門畫圈）。藍色星號 = 解鎖情報的隱藏要素。
## 操作：方向 = 移動地圖；武器鍵／互動鍵（或滾輪、右上的 − ＋）= 縮小／放大；道具鍵／裝填鍵（或 ◀ ▶）= 換一張地圖；
##       閃躲鍵 = 回到自己的位置；地圖鍵／取消 = 關閉。打開時遊戲暫停（main 控制）。
class_name MapPanel
extends Control

signal closed
signal change_area(step: int)

const ZOOMS := [2.0, 3.0, 4.0, 6.0, 8.0, 12.0]
const BG := Color(0.015, 0.03, 0.04, 0.96)
const TEXT := Color(0.86, 0.92, 0.94)
const DIM := Color(0.55, 0.64, 0.67)
const GOLD := Color(1.0, 0.85, 0.4)

var main: Node
## main 填的資料：{rows, explored, known, player, facing, stars, safe_cells, title, info, pins: [{color, cell, doors, title}]}
var map := {}
var zoom_index := 2
## 畫面中心對到地圖的哪一格
var center := Vector2.ZERO
var _font: Font
var _opened_frame := -1
var _drag := false
var _buttons := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_font = load("res://assets/fonts/Cubic_11.ttf")


func open() -> void:
	visible = true
	_opened_frame = Engine.get_process_frames()
	fit()
	focus_player()
	queue_redraw()


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func scale_px() -> float:
	return ZOOMS[zoom_index]


func map_size() -> Vector2:
	var rows: Array = map.get("rows", [])
	var w := 0
	for row in rows:
		w = maxi(w, String(row).length())
	return Vector2(w, rows.size())


## 一開始選一個整張地圖大致放得進畫面的倍率（至少 3）
func fit() -> void:
	var view := get_viewport_rect().size - Vector2(20, 44)
	var ms := map_size()
	zoom_index = 0
	for i in ZOOMS.size():
		if ms.x * ZOOMS[i] <= view.x and ms.y * ZOOMS[i] <= view.y:
			zoom_index = i
	zoom_index = maxi(zoom_index, 1)


func focus_player() -> void:
	if map.get("player") != null:
		center = Vector2(map.player) / Level.TILE
	else:
		center = map_size() * 0.5
	_clamp_center()


func zoom_by(step: int) -> void:
	var z := clampi(zoom_index + step, 0, ZOOMS.size() - 1)
	if z != zoom_index:
		zoom_index = z
		Sfx.play("ui_move")
		_clamp_center()
		queue_redraw()


func _clamp_center() -> void:
	var ms := map_size()
	var half := (get_viewport_rect().size - Vector2(0, 30)) * 0.5 / scale_px()
	center.x = ms.x * 0.5 if ms.x <= half.x * 2.0 else clampf(center.x, half.x - 2.0, ms.x - half.x + 2.0)
	center.y = ms.y * 0.5 if ms.y <= half.y * 2.0 else clampf(center.y, half.y - 2.0, ms.y - half.y + 2.0)


func _process(delta: float) -> void:
	if not visible:
		return
	queue_redraw()
	if Engine.get_process_frames() == _opened_frame:
		return
	if Input.is_action_just_pressed("map") or Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("pause"):
		close()
		return
	var pan := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if pan.length() > 0.2:
		center += pan * delta * 140.0 / scale_px()
		_clamp_center()
	if Input.is_action_just_pressed("interact"):
		zoom_by(1)
	elif Input.is_action_just_pressed("weapon"):
		zoom_by(-1)
	elif Input.is_action_just_pressed("dodge"):
		focus_player()
	elif Input.is_action_just_pressed("reload"):
		change_area.emit(1)
	elif Input.is_action_just_pressed("item"):
		change_area.emit(-1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(-1)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				for id in _buttons:
					if _buttons[id].has_point(mb.position):
						match id:
							"-": zoom_by(-1)
							"+": zoom_by(1)
							"<": change_area.emit(-1)
							">": change_area.emit(1)
							"o": focus_player()
							"x": close()
						return
			_drag = mb.pressed
	elif event is InputEventMouseMotion and _drag:
		center -= (event as InputEventMouseMotion).relative / scale_px()
		_clamp_center()
	elif event is InputEventMagnifyGesture:
		zoom_by(1 if (event as InputEventMagnifyGesture).factor > 1.0 else -1)


func _draw() -> void:
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), BG)
	if map.is_empty():
		return
	var s := scale_px()
	var rows: Array = map.rows
	var ms := map_size()
	var w := int(ms.x)
	var area := Rect2(0, 16, view.x, view.y - 30)
	var origin := (area.get_center() - center * s).floor()
	var explored: PackedByteArray = map.explored
	var known: bool = map.known
	var x0 := maxi(int(floor((area.position.x - origin.x) / s)), 0)
	var x1 := mini(int(ceil((area.end.x - origin.x) / s)), w)
	var y0 := maxi(int(floor((area.position.y - origin.y) / s)), 0)
	var y1 := mini(int(ceil((area.end.y - origin.y) / s)), rows.size())
	for y in range(y0, y1):
		var row: String = rows[y]
		for x in range(x0, mini(x1, row.length())):
			var seen := explored.size() > y * w + x and explored[y * w + x] > 0
			if not seen and not known:
				continue
			var ch := row[x]
			var col: Color
			if ch == "#":
				col = Color(0.34, 0.42, 0.44)
			elif ch == "C" or ch == "H":
				col = Color(0.17, 0.23, 0.25)
			elif ch == "D":
				col = Color(0.95, 0.7, 0.3)
			elif ch == "+":
				col = Color(0.8, 0.6, 0.3)
			elif ch == "=":
				col = Color(0.5, 0.75, 0.9)
			elif ch == "~":
				col = Color(0.08, 0.2, 0.3)
			elif ch == "G":
				col = Color(0.75, 0.8, 0.55)
			elif map.safe_cells.has(Vector2i(x, y)):
				col = Color(0.2, 0.42, 0.3)
			else:
				col = Color(0.11, 0.17, 0.19)
			if not seen:
				col = col.darkened(0.45).lerp(Color(0.1, 0.16, 0.3), 0.45)
			draw_rect(Rect2(origin + Vector2(x, y) * s, Vector2(s, s)), col)
	var blink := int(Time.get_ticks_msec() / 300) % 2 == 0
	for c: Vector2i in map.stars:
		var p := origin + (Vector2(c) + Vector2(0.5, 0.5)) * s
		var col := Color(0.4, 0.7, 1.0)
		draw_line(p + Vector2(-3, 0), p + Vector2(3, 0), col, 1.0)
		draw_line(p + Vector2(0, -3), p + Vector2(0, 3), col, 1.0)
		draw_line(p + Vector2(-2, -2), p + Vector2(2, 2), col, 1.0)
		draw_line(p + Vector2(-2, 2), p + Vector2(2, -2), col, 1.0)
	# 勾了指引的任務
	for pin in map.get("pins", []):
		var col: Color = pin.color
		if not blink:
			col = col.darkened(0.25)
		for c: Vector2i in pin.get("doors", []):
			draw_arc(origin + (Vector2(c) + Vector2(0.5, 0.5)) * s, maxf(s * 0.9, 4.0), 0.0, TAU, 14, col, 1.0)
		if pin.get("cell") != null:
			var p := origin + (Vector2(pin.cell) + Vector2(0.5, 0.5)) * s
			var r := maxf(s * 0.8, 4.0)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), col)
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(0.02, 0.02, 0.03))
	# 自己：箭頭指向面對的方向
	if map.get("player") != null:
		var pp := origin + Vector2(map.player) / Level.TILE * s
		var f: Vector2 = map.get("facing", Vector2.DOWN)
		var side := f.orthogonal()
		var r := maxf(s, 4.0)
		var col := Color(1, 0.3, 0.25) if blink else Color(1, 0.9, 0.5)
		draw_colored_polygon(PackedVector2Array([pp + f * r * 1.4, pp - f * r * 0.8 + side * r * 0.9, pp - f * r * 0.8 - side * r * 0.9]), col)
		draw_arc(pp, r * 2.2, 0.0, TAU, 16, Color(col, 0.35), 1.0)
	# 上下的字
	draw_rect(Rect2(0, 0, view.x, 16), Color(0, 0.01, 0.02, 0.9))
	draw_rect(Rect2(0, view.y - 14, view.x, 14), Color(0, 0.01, 0.02, 0.9))
	_text(Vector2(6, 12), map.title, GOLD)
	_text(Vector2(6, view.y - 3), map.info, DIM)
	# 右上的按鈕（觸控、滑鼠）
	_buttons.clear()
	var bx := view.x - 6.0
	for id in ["x", "o", ">", "<", "+", "-"]:
		bx -= 18.0
		var r := Rect2(bx, 1, 16, 14)
		_buttons[id] = r
		draw_rect(r, Color(0.1, 0.15, 0.17))
		draw_rect(r, Color(0.3, 0.38, 0.4), false, 1.0)
		_text(r.position + Vector2(5, 11), {"x": "X", "o": "o", ">": ">", "<": "<", "+": "+", "-": "-"}[id], TEXT)
	# 圖例：勾選的任務
	var ly := 30.0
	for pin in map.get("pins", []):
		draw_rect(Rect2(8, ly - 7, 6, 6), pin.color)
		draw_string(_font, Vector2(18, ly), pin.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.8))
		draw_string(_font, Vector2(17, ly - 1), pin.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT)
		ly += 13.0


func _text(at: Vector2, s: String, c: Color) -> void:
	draw_string(_font, at.floor(), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)
