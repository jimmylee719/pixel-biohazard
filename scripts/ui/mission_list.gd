## 手機「任務」App：主線、支線的清單。選一個任務按確認（或點一下）= 開／關這個任務的指引箭頭。
## 可以同時勾好幾個：每個任務的箭頭顏色不同（主線永遠黃色；支線藍、紫、紅、綠、白），清單前面的小方塊就是那個顏色。
class_name MissionList
extends Control

const AREA := Rect2(148, 58, 184, 194)
const LINE := 13.0

var main: Node
var cursor := 0
var _font: Font
var _rows: Array[Dictionary] = []
var _scroll := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	visible = false
	_font = load("res://assets/fonts/Cubic_11.ttf")


## 可以選的任務（還沒完成的排前面）
func entries() -> Array:
	var out := []
	for is_main in [true, false]:
		for m in Missions.list_visible():
			if m.main == is_main and not Missions.is_done(m.id):
				out.append(m)
	return out


func move(step: int) -> void:
	var n := entries().size()
	if n == 0:
		return
	cursor = posmod(cursor + step, n)
	Sfx.play("ui_move")
	queue_redraw()


func toggle() -> void:
	var list := entries()
	if cursor >= list.size():
		return
	var m: Dictionary = list[cursor]
	WorldState.toggle_pin(m.id, m.main)
	Sfx.play("ui_confirm")
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for row in _rows:
			if row.rect.has_point(event.position):
				cursor = row.index
				toggle()
				accept_event()
				return


func _draw() -> void:
	_rows.clear()
	var list := entries()
	cursor = clampi(cursor, 0, maxi(list.size() - 1, 0))
	# 先排版（算每一行的位置），游標那一項跑出畫面就捲動
	var lines := []
	var y := 0.0
	for is_main in [true, false]:
		lines.append({"y": y, "text": tr("MAIN OPS") if is_main else tr("SIDE OPS"), "head": true})
		y += LINE + 1
		var any := false
		for i in list.size():
			var m: Dictionary = list[i]
			if m.main != is_main:
				continue
			any = true
			var desc := _wrap(tr(m.desc), AREA.size.x - 16)
			lines.append({"y": y, "mission": m, "index": i, "h": LINE * (1 + desc.size()) + 3, "desc": desc})
			y += LINE * (1 + desc.size()) + 4
		for m in Missions.list_visible():
			if m.main == is_main and Missions.is_done(m.id):
				any = true
				lines.append({"y": y, "text": "[x] " + tr(m.title), "done": true})
				y += LINE
		if not any:
			lines.append({"y": y, "text": "  --", "done": true})
			y += LINE
		y += 5
	var view_h := AREA.size.y - 16
	for l in lines:
		if l.has("index") and l.index == cursor:
			if l.y - _scroll < 0:
				_scroll = l.y - LINE
			elif l.y + l.h - _scroll > view_h:
				_scroll = l.y + l.h - view_h
	_scroll = clampf(_scroll, 0.0, maxf(y - view_h, 0.0))
	for l in lines:
		var at: Vector2 = AREA.position + Vector2(0, l.y - _scroll)
		if at.y < AREA.position.y - 2 or at.y + l.get("h", LINE) > AREA.position.y + view_h + 4:
			continue
		if l.has("head"):
			_text(at + Vector2(0, 10), l.text, Color(0.6, 0.95, 0.85))
		elif l.has("done"):
			_text(at + Vector2(0, 10), l.text, Color(0.4, 0.48, 0.5))
		else:
			var m: Dictionary = l.mission
			var rect := Rect2(at, Vector2(AREA.size.x, l.h))
			_rows.append({"rect": rect, "index": l.index})
			if l.index == cursor:
				draw_rect(rect, Color(0.16, 0.15, 0.08))
				draw_rect(rect, Color(1, 0.85, 0.4, 0.7), false, 1.0)
			# 指引的小方塊：有箭頭 = 那個顏色的實心；沒有 = 空心
			var box := Rect2(at + Vector2(3, 3), Vector2(7, 7))
			if Missions.is_pinned(m.id):
				draw_rect(box, Missions.pin_color(m.id))
			else:
				draw_rect(box, Color(0.4, 0.48, 0.5), false, 1.0)
			_text(at + Vector2(14, 10), tr(m.title), Color(0.92, 0.95, 0.96))
			for j in l.desc.size():
				_text(at + Vector2(14, 10 + LINE * (j + 1)), l.desc[j], Color(0.6, 0.68, 0.7))
	var hint := tr("[%s] arrow on/off") % (main._key_name("interact") if main else "E")
	_text(Vector2(AREA.position.x, AREA.end.y - 3), hint, Color(0.55, 0.64, 0.67))


func _wrap(s: String, width: float) -> Array[String]:
	var out: Array[String] = []
	var line := ""
	# 中文沒有空白：一個字一個字量；英文以單字為單位
	var tokens: Array[String] = []
	var word := ""
	for ch in s:
		if ch == " ":
			if word != "":
				tokens.append(word)
			tokens.append(" ")
			word = ""
		elif ch.unicode_at(0) > 0x2E80:
			if word != "":
				tokens.append(word)
				word = ""
			tokens.append(ch)
		else:
			word += ch
	if word != "":
		tokens.append(word)
	for t in tokens:
		if _font.get_string_size(line + t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x > width and line != "":
			out.append(line.strip_edges())
			line = "" if t == " " else t
		else:
			line += t
	if line.strip_edges() != "":
		out.append(line.strip_edges())
	return out


func _text(at: Vector2, s: String, c: Color) -> void:
	draw_string(_font, at.floor(), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)
